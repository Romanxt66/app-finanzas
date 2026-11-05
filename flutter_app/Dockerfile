# syntax=docker/dockerfile:1
# Compila Flutter web y lo sirve con nginx. La versión de Flutter se fija por tag de git
# (reproducible); debe coincidir con la usada en desarrollo y en CI.
FROM debian:12-slim AS build
ARG FLUTTER_VERSION=3.47.5
ENV FLUTTER_ROOT=/opt/flutter \
    PATH=/opt/flutter/bin:$PATH \
    PUB_CACHE=/root/.pub-cache
RUN apt-get update \
    && apt-get install -y --no-install-recommends git curl ca-certificates unzip xz-utils \
    && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch "${FLUTTER_VERSION}" https://github.com/flutter/flutter.git "${FLUTTER_ROOT}" \
    && flutter config --no-analytics --enable-web \
    && flutter precache --web

WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .
# Sin API_URL: la app usa el mismo origen y nginx reenvía /api al backend (sin CORS).
# --no-web-resources-cdn: CanvasKit y fuentes salen del propio origen (cumple la CSP).
# --wasm: los navegadores con WasmGC (Chrome/Edge 119+, Firefox 120+, Safari 18.2+) cargan la versión
# WebAssembly con el motor Skwasm (más rápida al arrancar y al desplazarse); el resto usa JavaScript.
# Después se quitan los símbolos de depuración y se precomprime con gzip -9 (nginx: gzip_static).
# SUPPORT_EMAIL: correo de soporte que muestran los textos legales (opcional, --build-arg).
ARG SUPPORT_EMAIL=""
RUN flutter build web --release --wasm --no-web-resources-cdn --dart-define=SUPPORT_EMAIL="${SUPPORT_EMAIL}" \
    && find build/web -name '*.symbols' -delete \
    && find build/web -type f \( -name '*.js' -o -name '*.mjs' -o -name '*.wasm' -o -name '*.json' \
        -o -name '*.html' -o -name '*.ttf' -o -name '*.otf' -o -name 'NOTICES' \) -exec gzip -9 -k {} +

FROM nginx:1.27-alpine
ENV API_UPSTREAM=http://alvea-api:8000
COPY nginx.conf /etc/nginx/templates/default.conf.template
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80
HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=5 \
    CMD wget -q -O /dev/null http://127.0.0.1/healthz || exit 1
