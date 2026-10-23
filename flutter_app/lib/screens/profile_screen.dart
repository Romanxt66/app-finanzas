import 'package:flutter/material.dart';

import '../core/state.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'categories_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.c;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Glass(
            strong: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app.user?.fullName ?? '',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  app.user?.email ?? '',
                  style: TextStyle(color: c.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Glass(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tema',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.system, label: Text('Auto')),
                    ButtonSegment(value: ThemeMode.light, label: Text('Claro')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Oscuro')),
                  ],
                  selected: {app.themeMode},
                  onSelectionChanged: (s) => app.setTheme(s.first),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Glass(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CategoriesScreen()),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Categorías',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(Icons.chevron_right, color: c.inkMuted),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () async {
              Navigator.pop(context);
              await app.logout();
            },
            child: const Text('Cerrar sesión'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () async {
              if (!await confirm(
                context,
                'Cerrar sesión en todos los dispositivos',
                'Tendrás que iniciar sesión de nuevo en cada uno.',
                action: 'Cerrar todas',
              )) {
                return;
              }
              try {
                if (context.mounted) Navigator.pop(context);
                await app.logoutEverywhere();
              } catch (e) {
                if (context.mounted) showError(context, e);
              }
            },
            child: Text(
              'Cerrar sesión en todos los dispositivos',
              style: TextStyle(color: c.negative),
            ),
          ),
        ],
      ),
    );
  }
}
