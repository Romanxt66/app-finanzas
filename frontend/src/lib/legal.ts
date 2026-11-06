// Términos y política de privacidad (los mismos textos que la app Android). Son públicos: los enlazan el
// registro y la pantalla de consentimiento de Google. Si cambian, sube LEGAL_VERSION.

export const LEGAL_VERSION = '2026-11-06'

const ACCEPTED_KEY = 'legal_accepted'

/** Versión de los textos aceptada en este navegador (null = ninguna). */
export function acceptedLegal(): string | null {
  try {
    return localStorage.getItem(ACCEPTED_KEY)
  } catch {
    return null
  }
}

export function acceptLegal() {
  try {
    localStorage.setItem(ACCEPTED_KEY, LEGAL_VERSION)
  } catch {
    // sin almacenamiento (modo privado estricto): se volverá a pedir
  }
}

/** Correo de soporte (VITE_SUPPORT_EMAIL al compilar); si no hay, se remite a la ficha de la tienda. */
export const SUPPORT_EMAIL: string = import.meta.env.VITE_SUPPORT_EMAIL ?? ''

const contact = () =>
  SUPPORT_EMAIL
    ? `escríbenos a ${SUPPORT_EMAIL}`
    : 'escríbenos al correo de contacto que aparece en la ficha de Alvea en Google Play'

export type LegalSection = { title: string; paragraphs: string[] }
export type LegalDoc = {
  title: string
  headline: [string, string]
  lead: string
  sections: LegalSection[]
}

export const terms = (): LegalDoc => ({
  title: 'Términos y condiciones',
  headline: ['Las reglas, ', 'claras'],
  lead: 'Lo esencial: Alvea te ayuda a ordenar tu dinero, no lo mueve ni te asesora, y puedes irte cuando quieras.',
  sections: [
    {
      title: 'Qué es Alvea',
      paragraphs: [
        'Alvea es una aplicación para llevar tus finanzas personales: registrar cuentas, movimientos, presupuestos, metas, suscripciones y recordatorios de cobro. Es una herramienta de organización: no es un banco, no mueve tu dinero ni se conecta a tus cuentas bancarias.',
        'Al crear una cuenta o usar la app aceptas estos términos. Si no estás de acuerdo, no uses Alvea.',
      ],
    },
    {
      title: 'Tu cuenta',
      paragraphs: [
        'Debes ser mayor de edad (18 años) para crear una cuenta. Eres responsable de la información que registras y de mantener segura tu contraseña, tu PIN y el acceso a tu teléfono.',
        'Puedes entrar con correo y contraseña o con tu cuenta de Google, y activar la verificación en dos pasos y el bloqueo con PIN o huella. Si crees que alguien entró a tu cuenta, cambia la contraseña y cierra las demás sesiones desde Perfil.',
      ],
    },
    {
      title: 'Sin asesoría financiera',
      paragraphs: [
        'Los resúmenes, avisos, sugerencias y los comentarios de Alvi son orientativos y se calculan a partir de los datos que tú ingresas. No constituyen asesoría financiera, tributaria ni legal. Las decisiones sobre tu dinero son tuyas.',
      ],
    },
    {
      title: 'Uso aceptable',
      paragraphs: [
        'No uses Alvea para actividades ilícitas, para intentar acceder a cuentas ajenas, para sobrecargar o vulnerar el servicio ni para copiarlo o revenderlo. Podemos suspender cuentas que incumplan estas reglas.',
      ],
    },
    {
      title: 'Disponibilidad',
      paragraphs: [
        'Trabajamos para que Alvea esté disponible y tus datos respaldados, pero el servicio se ofrece «tal cual», sin garantía de funcionamiento ininterrumpido. Te recomendamos exportar tus movimientos (CSV) de vez en cuando.',
        'En la máxima medida permitida por la ley, no respondemos por pérdidas derivadas de decisiones tomadas con base en la información de la app ni por interrupciones del servicio.',
      ],
    },
    {
      title: 'Cerrar tu cuenta',
      paragraphs: [
        'Puedes dejar de usar Alvea cuando quieras y eliminar tu cuenta y todos tus datos desde Perfil → Eliminar cuenta (ver la política de privacidad). También podemos cerrar cuentas inactivas o que incumplan estos términos, avisándote antes cuando sea posible.',
      ],
    },
    {
      title: 'Cambios',
      paragraphs: [
        'Si cambiamos estos términos de forma importante, te lo pediremos aceptar de nuevo dentro de la app. La fecha de la versión vigente aparece al final.',
        `Estos términos se rigen por las leyes de la República de Colombia. Para dudas, ${contact()}.`,
      ],
    },
  ],
})

export const privacy = (): LegalDoc => ({
  title: 'Política de privacidad',
  headline: ['Tus datos, ', 'tuyos'],
  lead: 'Lo esencial: guardamos lo que tú registras solo para mostrártelo, no lo vendemos y puedes borrarlo todo.',
  sections: [
    {
      title: 'Qué datos guardamos',
      paragraphs: [
        'Datos de la cuenta: nombre, correo y contraseña (guardada cifrada con un algoritmo de un solo sentido; nadie puede leerla).',
        'Si entras con Google, recibimos de Google solo tu nombre, tu correo, si está verificado y un identificador de tu cuenta de Google. No recibimos tu contraseña de Google ni accedemos a tu correo, contactos, archivos ni a ningún otro dato de tu cuenta de Google.',
        'Datos financieros que tú registras: cuentas, saldos, movimientos, categorías, presupuestos, metas, suscripciones y archivos que decidas importar (CSV o extractos). No pedimos claves bancarias ni accedemos a tus bancos.',
        'Datos técnicos mínimos: registros de errores de la app (sin el contenido de tus movimientos) para poder corregir fallos, y las sesiones abiertas (dispositivo y fecha) para que puedas cerrarlas.',
      ],
    },
    {
      title: 'Para qué los usamos',
      paragraphs: [
        'Solo para darte el servicio: mostrar tus resúmenes, calcular presupuestos y avisos, programar recordatorios en tu teléfono, proteger tu cuenta y responder tus solicitudes.',
        'No vendemos tus datos, no los usamos para publicidad y no los compartimos con terceros, salvo los proveedores que alojan el servidor (con obligación de confidencialidad) o cuando una autoridad competente lo exija por ley. El uso de la información recibida de las API de Google se ajusta a la Política de datos de usuario de los servicios de API de Google, incluidos sus requisitos de uso limitado.',
      ],
    },
    {
      title: 'Qué queda en tu teléfono',
      paragraphs: [
        'Preferencias (tema, tono, recordatorios), tu sesión, el PIN (cifrado) y una copia temporal de tus datos para que la app abra rápido y funcione sin conexión. La huella o el rostro nunca salen del teléfono: Alvea solo recibe un sí o un no del sistema.',
        'Los widgets y las notificaciones muestran cifras en tu pantalla de inicio: puedes desactivarlos cuando quieras.',
      ],
    },
    {
      title: 'Seguridad',
      paragraphs: [
        'Las comunicaciones viajan cifradas (HTTPS), el servidor guarda copias de respaldo y el acceso está protegido con contraseña o con tu cuenta de Google y, si la activas, verificación en dos pasos. Ningún sistema es infalible: si detectamos un incidente que afecte tus datos, te avisaremos.',
      ],
    },
    {
      title: 'Tus derechos',
      paragraphs: [
        `De acuerdo con la Ley 1581 de 2012 de Colombia (habeas data) y normas afines, puedes conocer, actualizar, rectificar y exportar tus datos (Movimientos → Exportar CSV), revocar esta autorización y eliminar tu cuenta y todos tus datos desde Perfil → Eliminar cuenta. Para cualquier solicitud, ${contact()}. Respondemos en un máximo de 15 días hábiles.`,
        'Cuando eliminamos una cuenta, borramos sus datos del servidor; las copias de respaldo se sobrescriben en un máximo de 30 días. Si entraste con Google, también puedes quitar el acceso de Alvea desde tu cuenta de Google (Seguridad → Apps de terceros).',
      ],
    },
    {
      title: 'Menores de edad',
      paragraphs: [
        'Alvea no está dirigida a menores de 18 años y no recopilamos a sabiendas datos de menores.',
      ],
    },
    {
      title: 'Cambios',
      paragraphs: [
        'Si cambiamos esta política de forma importante, te lo pediremos aceptar de nuevo dentro de la app. La fecha de la versión vigente aparece al final.',
      ],
    },
  ],
})
