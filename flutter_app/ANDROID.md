# Alvea para Android

La app Android sale del mismo código que la web (`flutter_app/`). No hace falta Android Studio: GitHub Actions
la compila en cada cambio (workflow `Android`, `.github/workflows/android.yml`).

- Identificador: `click.softlane.alvea`. **No se puede cambiar después de publicar en Google Play.**
- Servidor: `https://alvea2.softlane.click`, el mismo que la web. Para usar otro, crea la variable del repositorio
  `ALVEA_API_URL` (GitHub → Settings → Secrets and variables → Actions → Variables).
- Android 7.0 o superior. Icono adaptativo con icono temático en Android 13 o superior.

## Instalar la última versión en el teléfono

1. En el teléfono, abre <https://github.com/Romanxt66/app-finanzas/releases/tag/android-ultima> (con tu sesión de
   GitHub, porque el repositorio es tuyo) y descarga `alvea.apk`.
2. Ábrelo. Si Android lo pide, permite «Instalar apps desconocidas» para el navegador.
3. Cada vez que se fusiona un cambio en `cli/flutter-app` se publica una versión nueva en ese mismo enlace.

También está como artefacto `alvea-android` en cada ejecución del workflow, incluidas las de los PR.

> Mientras no configures la firma de publicación (abajo), cada APK se firma con una clave de prueba distinta:
> para actualizar, **desinstala la versión anterior** antes de instalar la nueva. Tus datos están en el servidor;
> solo se pierden el PIN y las preferencias de ese teléfono.

## Firma de publicación (una sola vez)

La firma identifica la app. Con ella, las actualizaciones se instalan encima de la anterior y se puede publicar
en Google Play. En tu PC, con el JDK que trae Android Studio (`keytool` está en `Android Studio/jbr/bin`):

```bash
keytool -genkey -v -keystore alvea-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias alvea
# Usa una contraseña de letras y números. Luego conviértelo a texto:
base64 -w0 alvea-upload.jks > alvea-upload.txt          # Windows (PowerShell):
# [Convert]::ToBase64String([IO.File]::ReadAllBytes("alvea-upload.jks")) > alvea-upload.txt
```

En GitHub → Settings → Secrets and variables → Actions → **New repository secret**, crea:

| Secret | Valor |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | el contenido de `alvea-upload.txt` |
| `ANDROID_KEYSTORE_PASSWORD` | la contraseña del almacén |
| `ANDROID_KEY_ALIAS` | `alvea` |
| `ANDROID_KEY_PASSWORD` | la contraseña de la clave (la misma, si no pusiste otra) |

Guarda `alvea-upload.jks` y sus contraseñas en un lugar seguro (gestor de contraseñas). Nunca los subas al
repositorio: `.gitignore` ya excluye `*.jks` y `key.properties`. Con la firma configurada, el workflow genera además
`alvea.aab` (el formato que pide Google Play).

## Publicar en Google Play

1. Crea una cuenta de desarrollador en <https://play.google.com/console> (pago único de 25 USD).
2. **Crear app** → nombre «Alvea», app gratuita. Deja activada la **firma de apps de Google Play**: Google guarda la
   clave definitiva, y si pierdes `alvea-upload.jks` se puede restablecer.
3. Sube `alvea.aab` (artefacto `alvea-android` del workflow) a **Pruebas internas** y prueba con tu cuenta.
4. Completa la ficha:
   - Icono: `brand/play-store-icon-512.png`.
   - Capturas: puedes usar las del artefacto `capturas-flutter` de la CI.
   - Política de privacidad: Play la exige a las apps de finanzas; basta una página pública.
   - Formulario de «Seguridad de los datos»: la app guarda correo, nombre y movimientos en tu servidor.
5. Cuando las pruebas vayan bien, promociona la versión a **Producción**.

Las siguientes versiones solo requieren subir el nuevo `alvea.aab`. El `versionCode` lo pone el workflow (número
de ejecución), así que siempre crece.

## Diferencias con la web

- **Desbloqueo con huella o rostro.** En Perfil → Seguridad, con un PIN creado, activa «Desbloquear también con
  huella o rostro».
- **Exportar CSV y descargar los códigos de recuperación.** Abre el diálogo «Guardar como» del sistema.
- **Avisos.** Aparecen en la campana. Las notificaciones del sistema con la app cerrada llegarán en una versión
  posterior.
- **Sin aviso de conexión.** Si no hay internet, cada pantalla muestra su error y permite reintentar.

## Compilar en tu PC (opcional)

Con Flutter 3.47.5 y Android Studio:

```bash
cd flutter_app
flutter run --dart-define=API_URL=https://alvea2.softlane.click        # en un teléfono conectado por USB
flutter build apk --release --dart-define=API_URL=https://alvea2.softlane.click
```

Sin `--dart-define=API_URL`, la app nativa no sabe a qué servidor conectarse y lo dice al primer intento.
