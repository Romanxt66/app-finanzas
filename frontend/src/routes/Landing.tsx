import { Link } from 'react-router-dom'
import { Backdrop, BrandLogo, Icon, type IconName } from '../design'
import { Alvi } from '../features/Alvi'
import { ANDROID_URL, APP_NAME } from '../lib/brand'
import { MOOD_FACES } from '../lib/mood'
import './landing.css'

const YEAR = new Date().getFullYear()

const FEATURES: { icon: IconName; title: string; text: string }[] = [
  {
    icon: 'home',
    title: 'Todo tu dinero, de un vistazo',
    text: 'Saldo total, ingresos, gastos y lo que te queda hoy en una sola pantalla, sin hojas de cálculo.',
  },
  {
    icon: 'target',
    title: 'Presupuestos que se repiten',
    text: 'Límites por día, semana o mes, generales o por categoría. Te avisamos al 80 % y si te pasas.',
  },
  {
    icon: 'chart',
    title: 'Análisis claro',
    text: 'En qué se va tu dinero, cómo cambia mes a mes y cuántas horas de trabajo cuesta cada gasto.',
  },
  {
    icon: 'swap',
    title: 'Recurrentes y suscripciones',
    text: 'Sueldo, arriendo o Netflix se registran solos y detectamos los cobros que olvidaste.',
  },
  {
    icon: 'bolt',
    title: 'Funciona sin internet',
    text: 'En Android anotas aunque no haya señal; todo se sincroniza solo al volver la conexión.',
  },
  {
    icon: 'download',
    title: 'Trae tu banco en segundos',
    text: 'Importa el extracto en CSV de tu banco y Alvea propone la categoría de cada movimiento.',
  },
]

const SAFETY: { icon: IconName; title: string; text: string }[] = [
  {
    icon: 'shield',
    title: 'Tus datos son solo tuyos',
    text: 'Sin anuncios y sin vender información. Nadie más ve tus movimientos.',
  },
  {
    icon: 'lock',
    title: 'Acceso protegido',
    text: 'Contraseñas cifradas, verificación en dos pasos y bloqueo con PIN o huella en el teléfono.',
  },
  {
    icon: 'trash',
    title: 'Tú decides',
    text: 'Exporta tus datos cuando quieras o elimina tu cuenta y todo lo que contiene en un minuto.',
  },
]

const STEPS = [
  ['Descarga la app', 'Toca «Descargar para Android» desde tu teléfono.'],
  ['Instálala', 'Si te lo pide, permite instalar apps del navegador.'],
  ['Entra con tu cuenta', 'La misma de la web: tus datos aparecen en los dos.'],
]

/** Escena del héroe: tarjetas de cristal que flotan (como en el inicio de sesión) con datos de ejemplo. */
function HeroStage() {
  return (
    <div className="cr-lp-stage" aria-hidden="true">
      <div className="cr-lp-float cr-lp-balance">
        <span className="cr-hero-label">Saldo total</span>
        <strong className="cr-lp-amount">$ 4.820.500</strong>
        <svg viewBox="0 0 120 32" className="cr-hero-spark">
          <path d="M2 26 C18 24 22 12 38 15 S62 28 78 14 S104 6 118 4" />
        </svg>
      </div>
      <div className="cr-lp-float cr-lp-budget">
        <span className="cr-lp-row">
          <span className="cr-hero-label">Presupuesto de hoy</span>
          <span className="cr-lp-pill">62 %</span>
        </span>
        <span className="cr-lp-track">
          <span className="cr-lp-fill" />
        </span>
        <span className="cr-hero-label">Te quedan $ 22.800</span>
      </div>
      <div className="cr-lp-float cr-lp-alvi">
        <Alvi face={MOOD_FACES[4]} size={64} />
        <span>
          <strong>¡Estoy radiante!</strong>
          <span className="cr-hero-label">Vas por debajo de tus límites</span>
        </span>
      </div>
      <div className="cr-lp-float cr-lp-secure">
        <span className="cr-chip cr-chip-brand">
          <Icon name="shield" />
        </span>
        <span>
          <strong>Sesión protegida</strong>
          <span className="cr-hero-label">Verificación en dos pasos</span>
        </span>
      </div>
    </div>
  )
}

function AndroidButton({ className = '' }: { className?: string }) {
  return (
    <a className={`cr-btn cr-btn-primary cr-lp-cta ${className}`} href={ANDROID_URL} download>
      <Icon name="download" />
      Descargar para Android
    </a>
  )
}

/** Página pública: qué es Alvea, descarga para Android y acceso a la versión web. */
export function LandingPage() {
  return (
    <Backdrop>
      <div className="cr-lp">
        <header className="cr-glass cr-topbar cr-lp-nav">
          <Link to="/" className="cr-brand" aria-label={`${APP_NAME}, inicio`}>
            <BrandLogo />
            {APP_NAME}
          </Link>
          <nav className="cr-lp-links" aria-label="Secciones">
            <a href="#funciones">Funciones</a>
            <a href="#android">Android</a>
            <a href="#seguridad">Seguridad</a>
          </nav>
          <span className="cr-spacer" />
          <Link className="cr-btn cr-btn-ghost cr-btn-sm" to="/login">
            Iniciar sesión
          </Link>
          <Link className="cr-btn cr-btn-primary cr-btn-sm cr-lp-hide-xs" to="/register">
            Crear cuenta
          </Link>
        </header>

        <main>
          <section className="cr-lp-hero">
            <div className="cr-lp-hero-copy">
              <span className="cr-page-tag">finanzas personales</span>
              <h1 className="cr-hero-title">
                Tu dinero, <em>claro</em> como el cristal.
              </h1>
              <p className="cr-lp-lead">
                {APP_NAME} reúne tus cuentas, gastos, presupuestos y metas en un solo lugar, con un
                diseño tranquilo que te dice cómo vas sin agobiarte.
              </p>
              <div className="cr-lp-actions">
                <AndroidButton />
                <Link className="cr-btn cr-btn-glass cr-lp-cta" to="/login">
                  Usar en la web
                  <Icon name="arrow" />
                </Link>
              </div>
              <ul className="cr-lp-trust">
                <li>
                  <Icon name="check" /> Gratis
                </li>
                <li>
                  <Icon name="check" /> Sin anuncios
                </li>
                <li>
                  <Icon name="check" /> Web y Android sincronizados
                </li>
              </ul>
            </div>
            <HeroStage />
          </section>

          <section id="funciones" className="cr-lp-section" aria-labelledby="lp-funciones">
            <span className="cr-page-tag">funciones</span>
            <h2 id="lp-funciones" className="cr-lp-h2">
              Todo lo que necesitas, <em>nada que sobre</em>.
            </h2>
            <ul className="cr-lp-grid">
              {FEATURES.map((f) => (
                <li key={f.title} className="cr-glass cr-glass-md cr-lp-card">
                  <span className="cr-chip cr-chip-brand">
                    <Icon name={f.icon} />
                  </span>
                  <h3>{f.title}</h3>
                  <p>{f.text}</p>
                </li>
              ))}
            </ul>
          </section>

          <section id="android" className="cr-lp-section" aria-labelledby="lp-android">
            <div className="cr-glass cr-glass-strong cr-lp-android">
              <div>
                <span className="cr-page-tag">android</span>
                <h2 id="lp-android" className="cr-lp-h2">
                  Lleva {APP_NAME} <em>en el bolsillo</em>.
                </h2>
                <p className="cr-lp-lead">
                  Anota un gasto en tres toques desde el botón rápido o los widgets del escritorio,
                  recibe avisos antes de cada cobro y sigue usándola sin conexión.
                </p>
                <AndroidButton />
                <p className="cr-lp-note">APK para Android 8 o superior · versión de prueba</p>
              </div>
              <ol className="cr-lp-steps">
                {STEPS.map(([title, text], i) => (
                  <li key={title}>
                    <span className="cr-lp-step-n">{i + 1}</span>
                    <span>
                      <strong>{title}</strong>
                      <span className="cr-hero-label">{text}</span>
                    </span>
                  </li>
                ))}
              </ol>
            </div>
          </section>

          <section id="seguridad" className="cr-lp-section" aria-labelledby="lp-seguridad">
            <span className="cr-page-tag">seguridad</span>
            <h2 id="lp-seguridad" className="cr-lp-h2">
              Privado <em>por diseño</em>.
            </h2>
            <ul className="cr-lp-grid cr-lp-grid-3">
              {SAFETY.map((f) => (
                <li key={f.title} className="cr-glass cr-glass-md cr-lp-card">
                  <span className="cr-chip">
                    <Icon name={f.icon} />
                  </span>
                  <h3>{f.title}</h3>
                  <p>{f.text}</p>
                </li>
              ))}
            </ul>
          </section>

          <section className="cr-lp-section">
            <div className="cr-glass cr-lp-final">
              <h2 className="cr-lp-h2">
                Empieza hoy, <em>es gratis</em>.
              </h2>
              <p className="cr-lp-lead">Crea tu cuenta en la web y úsala también en tu teléfono.</p>
              <div className="cr-lp-actions">
                <Link className="cr-btn cr-btn-primary cr-lp-cta" to="/register">
                  Crear cuenta gratis
                </Link>
                <Link className="cr-btn cr-btn-glass cr-lp-cta" to="/login">
                  Ya tengo cuenta
                </Link>
              </div>
            </div>
          </section>
        </main>

        <footer className="cr-lp-footer">
          <span className="cr-brand">
            <BrandLogo size={24} />
            {APP_NAME}
          </span>
          <nav aria-label="Legal">
            <Link to="/terminos">Términos</Link>
            <Link to="/privacidad">Privacidad</Link>
            <a href={ANDROID_URL} download>
              Android
            </a>
          </nav>
          <span className="cr-hero-label">
            © {YEAR} {APP_NAME}
          </span>
        </footer>
      </div>
    </Backdrop>
  )
}
