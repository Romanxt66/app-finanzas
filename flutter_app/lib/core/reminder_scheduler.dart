import 'reminder_scheduler_stub.dart' if (dart.library.io) 'reminder_scheduler_io.dart' as impl;
import 'reminders.dart';

/// Programa los recordatorios de cobro como avisos del sistema. Solo en la app de Android: en la web
/// (los navegadores no programan avisos) y en las pruebas no hace nada.
abstract class ReminderScheduler {
  static ReminderScheduler platform() => impl.createScheduler();

  /// Si este dispositivo puede programar avisos.
  bool get supported;

  /// Prepara el sistema de avisos; [onOpen] recibe la ruta que pide abrir un aviso tocado.
  Future<void> init(void Function(String route) onOpen);

  /// Ruta del aviso que abrió la app (si la abrió uno).
  Future<String?> launchRoute();

  /// Si el sistema deja mostrar avisos (null: no se sabe).
  Future<bool?> permission();

  /// Pide el permiso (Android 13+). Devuelve si quedó concedido.
  Future<bool> requestPermission();

  /// Sustituye los avisos programados por [plan].
  Future<void> schedule(List<PlannedReminder> plan, {required bool hideAmounts});

  /// Muestra un aviso ahora (o a la hora de [r] si es futura y [later] es true).
  Future<void> show(PlannedReminder r, {required bool hideAmounts, bool later = false});

  /// Quita todos los avisos de Alvea (al cerrar sesión).
  Future<void> cancelAll();

  /// Abre los ajustes de avisos de la app en el sistema.
  Future<void> openSystemSettings();
}

/// Sin avisos del sistema.
class NoopScheduler implements ReminderScheduler {
  const NoopScheduler();

  @override
  bool get supported => false;

  @override
  Future<void> init(void Function(String route) onOpen) async {}

  @override
  Future<String?> launchRoute() async => null;

  @override
  Future<bool?> permission() async => null;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> schedule(List<PlannedReminder> plan, {required bool hideAmounts}) async {}

  @override
  Future<void> show(PlannedReminder r, {required bool hideAmounts, bool later = false}) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> openSystemSettings() async {}
}
