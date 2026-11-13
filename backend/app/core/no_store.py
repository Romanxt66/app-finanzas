"""Las respuestas de la API llevan datos financieros: que ningún navegador ni proxy las guarde."""

from starlette.types import ASGIApp, Message, Receive, Scope, Send


class NoStoreMiddleware:
    """Añade `Cache-Control: no-store` a lo que no fije su propia política de caché."""

    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        async def send_with_header(message: Message) -> None:
            if message["type"] == "http.response.start":
                headers = list(message.get("headers", []))
                if not any(k.lower() == b"cache-control" for k, _ in headers):
                    headers.append((b"cache-control", b"no-store"))
                message["headers"] = headers
            await send(message)

        await self.app(scope, receive, send_with_header)
