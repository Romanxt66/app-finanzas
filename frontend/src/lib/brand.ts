/** Nombre visible del producto; configurable por entorno al construir (VITE_APP_NAME). */
export const APP_NAME: string = import.meta.env.VITE_APP_NAME ?? 'Alvea'

/** Descarga directa de la última APK de Android (configurable al construir con VITE_ANDROID_URL). */
export const ANDROID_URL: string =
  import.meta.env.VITE_ANDROID_URL ??
  'https://github.com/Romanxt66/app-finanzas/releases/download/android-ultima/alvea.apk'
