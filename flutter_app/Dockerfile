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
RUN flutter build web --release --no-web-resources-cdn --no-wasm-dry-run

FROM nginx:1.27-alpine
ENV API_UPSTREAM=http://alvea-api:8000
COPY nginx.conf /etc/nginx/templates/default.conf.template
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80
HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=5 \
    CMD wget -q -O /dev/null http://127.0.0.1/healthz || exit 1
