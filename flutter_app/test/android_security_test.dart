// Ajustes de seguridad del proyecto Android: si alguien los quita por error, este test lo avisa.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

  test('sin copias de seguridad ni transferencia de datos entre teléfonos', () {
    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:dataExtractionRules="@xml/data_extraction_rules"'));
    final rules = File('android/app/src/main/res/xml/data_extraction_rules.xml').readAsStringSync();
    expect(rules, contains('<cloud-backup>'));
    expect(rules, contains('<device-transfer>'));
    expect('domain="sharedpref"'.allMatches(rules).length, 2);
  });

  test('solo HTTPS y certificados del sistema en la versión publicada', () {
    expect(manifest, contains('android:networkSecurityConfig="@xml/network_security_config"'));
    final config = File('android/app/src/main/res/xml/network_security_config.xml').readAsStringSync();
    expect(config, contains('cleartextTrafficPermitted="false"'));
    expect(config, isNot(contains('src="user"')));
    expect(config, isNot(contains('cleartextTrafficPermitted="true"')));
  });

  test('solo se exponen a otras apps los componentes que lo necesitan', () {
    final exported = RegExp(
      r'android:name="([^"]+)"[^>]*?android:exported="true"|android:exported="true"[^>]*?android:name="([^"]+)"',
      dotAll: true,
    );
    final names = {for (final m in exported.allMatches(manifest)) m.group(1) ?? m.group(2)};
    expect(names, {'.MainActivity', '.QuickAddTileService'});
  });
}
