import time
from collections import defaultdict, deque
from collections.abc import Callable


class FailureLimiter:
    """Ventana deslizante de fallos por clave (p. ej. IP + correo), en memoria.

    Suficiente para una instancia; con varias réplicas habría que moverlo a Redis/BD.
    """

    def __init__(
        self,
        max_failures: int = 5,
        window_seconds: int = 15 * 60,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        self.max_failures = max_failures
        self.window = window_seconds
        self._clock = clock
        self._failures: dict[str, deque[float]] = defaultdict(deque)
        self._writes = 0

    # Cada tantas anotaciones se barren las claves caducadas: una clave solo se poda al volver a
    # usarse, y sin barrido unas pruebas con correos o IPs al azar acumularían memoria sin fin.
    _SWEEP_EVERY = 1000

    def _sweep(self) -> None:
        limit = self._clock() - self.window
        for key in [k for k, ev in self._failures.items() if not ev or ev[-1] <= limit]:
            del self._failures[key]

    def _prune(self, key: str) -> deque[float]:
        events = self._failures[key]
        limit = self._clock() - self.window
        while events and events[0] <= limit:
            events.popleft()
        if not events:
            self._failures.pop(key, None)
            return deque()
        return events

    def retry_after(self, key: str) -> int:
        """Segundos hasta poder reintentar (0 si no está bloqueado)."""
        events = self._prune(key)
        if len(events) < self.max_failures:
            return 0
        return max(1, int(events[0] + self.window - self._clock()) + 1)

    def record_failure(self, key: str) -> None:
        self._writes += 1
        if self._writes % self._SWEEP_EVERY == 0:
            self._sweep()
        self._prune(key)
        self._failures[key].append(self._clock())

    def reset(self, key: str) -> None:
        self._failures.pop(key, None)
