import 'reminder_scheduler.dart';

/// En la web no se programan avisos del sistema.
ReminderScheduler createScheduler() => const NoopScheduler();
