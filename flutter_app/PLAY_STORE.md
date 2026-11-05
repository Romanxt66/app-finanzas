# Publicar Alvea en Google Play

Guía para la ficha y los formularios de Play Console. La compilación y la firma están en `ANDROID.md`.

## Antes de subir la primera versión

- [ ] Firma de publicación configurada (secrets `ANDROID_*`, ver `ANDROID.md`): sin ella no se genera `alvea.aab`.
- [ ] Variable del repositorio `ALVEA_SUPPORT_EMAIL` con el correo de soporte (GitHub → Settings → Secrets and
      variables → Actions → Variables). Aparece en los términos, en la política de privacidad y en «Eliminar cuenta».
      Para la web, pásalo al construir la imagen: `docker build --build-arg SUPPORT_EMAIL=... flutter_app`.
- [ ] Backend con `DELETE /api/v1/auth/me` desplegado (borra la cuenta y sus datos; Google Play lo exige). Mientras no
      esté, el botón «Eliminar mi cuenta» explica cómo pedirlo por correo.
- [ ] Revisa los textos legales en `lib/screens/legal.dart` (responsable, correo y ciudad). Si los cambias de forma
      importante, sube `legalVersion`: la app pedirá aceptarlos de nuevo.
- [ ] Prueba la app desde **Pruebas internas** antes de producción. Para cuentas personales nuevas, Google exige además
      una **prueba cerrada con al menos 12 testers durante 14 días** antes de poder publicar en producción.

## Enlaces que pide Play Console

| Campo | Valor |
|---|---|
| Política de privacidad | `https://alvea2.softlane.click/privacidad` |
| Eliminación de la cuenta (URL) | `https://alvea2.softlane.click/privacidad` (sección «Tus derechos») |
| Términos (opcional) | `https://alvea2.softlane.click/terminos` |
| Sitio web | `https://alvea2.softlane.click` |

## Ficha de la tienda

**Nombre (máx. 30):** `Alvea: finanzas personales`

**Descripción breve (máx. 80):** `Tu dinero, claro: gastos, presupuestos, metas y cobros en un solo lugar.`

**Descripción completa:**

```
Alvea te ayuda a entender a dónde va tu dinero, sin complicaciones y sin anuncios.

• Anota un gasto en 3 toques: desde la app, desde el botón del panel rápido (junto al wifi) o desde un widget.
• Resumen del mes: saldo, ingresos, gastos y cuánto puedes gastar hoy sin pasarte.
• Presupuestos por categoría con avisos antes de que te pases.
• Metas de ahorro con su progreso.
• Suscripciones y pagos recurrentes: recordatorio antes de cada cobro y aviso si no te alcanza.
• Importa tus movimientos desde CSV o desde el extracto del banco.
• Widgets para la pantalla de inicio: saldo, disponible hoy, próximos cobros y tu meta.
• Seguridad: PIN, huella o rostro, y verificación en dos pasos.
• Diseño en blanco, negro y gris, con modo claro y oscuro.
• Funciona sin conexión: lo que anotes se envía cuando vuelvas a tener internet.

Alvea no se conecta a tu banco ni mueve tu dinero: tú decides qué registrar. Tus datos no se venden ni se usan para
publicidad, y puedes exportarlos o borrar tu cuenta cuando quieras.
```

**Categoría:** Finanzas. **Etiquetas:** presupuesto, control de gastos, ahorro.

**Gráficos:**
- Icono 512×512: `brand/play-store-icon-512.png`.
- Imagen destacada 1024×500: fondo negro con el logo y la frase «Tu dinero, claro.» (pendiente de crear).
- Capturas de teléfono (mínimo 2, recomendado 4–8): artefacto `capturas-flutter` de la CI, en oscuro y en claro.

## Seguridad de los datos (formulario)

| Pregunta | Respuesta |
|---|---|
| ¿Recopila o comparte datos? | Recopila: **sí**. Comparte con terceros: **no**. |
| ¿Cifrado en tránsito? | **Sí** (HTTPS). |
| ¿El usuario puede pedir que se borren sus datos? | **Sí** (en la app: Perfil → Eliminar cuenta, y por correo). |
| Información personal | Nombre y correo: recopilados, obligatorios, para **funcionalidad de la app** y **gestión de la cuenta**. |
| Información financiera | «Otra información financiera» (movimientos, saldos, presupuestos que escribe el usuario): recopilada, obligatoria, para **funcionalidad de la app**. |
| Información y rendimiento de la app | Registros de fallos: recopilados, para **análisis** (corregir errores). Sin datos financieros. |
| Ubicación, contactos, fotos, mensajes, ID de publicidad | **No** se recopilan. |

## Otros formularios

- **Clasificación de contenido:** utilidad/productividad, sin violencia, sin contenido sexual, sin apuestas, sin
  interacción entre usuarios. Resultado esperado: «Para todos» (PEGI 3 / Todos).
- **Público objetivo:** 18 años o más (lo dicen los términos). No está dirigida a niños.
- **Funciones financieras:** la app **no** ofrece préstamos, inversión, criptomonedas, pagos ni banca: es una herramienta
  de presupuesto y seguimiento de gastos personales.
- **Anuncios:** la app no contiene anuncios.
- **Acceso a la app:** Play revisa la app por dentro. Crea una cuenta de prueba (correo y contraseña sin verificación en
  dos pasos) e indícala en «Acceso a la app».
- **Permisos:** notificaciones (recordatorios de cobro), biometría (desbloqueo opcional), arranque del teléfono
  (reprogramar recordatorios) e internet. No usa alarmas exactas ni ubicación.

## Versiones

- `versionCode` = número de ejecución del workflow (siempre crece). `versionName` = `version` de `pubspec.yaml`:
  súbela (p. ej. `1.0.1+1`) cuando publiques cambios visibles.
- Sube el `alvea.aab` del artefacto `alvea-android`, no el APK.
