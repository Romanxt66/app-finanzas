#!/bin/sh
# Copia de seguridad de la base de datos de Alvea con pg_dump (formato custom, comprimido).
#
# Uso:   DATABASE_URL=postgresql+asyncpg://usuario:clave@host:5432/bd ./ops/backup_db.sh [carpeta]
# Deja  alvea-AAAAMMDD-HHMMSS.dump  en la carpeta (por defecto ./backups) y borra las de más de
# KEEP_DAYS días (por defecto 14). Restaurar:  pg_restore --clean --no-owner -d "$URL" archivo.dump
#
# Lo ideal es programarlo con las copias automáticas de Coolify (ver README) o con cron en el
# servidor. Necesita pg_dump de la misma versión mayor que el servidor de Postgres, o superior.
set -eu

: "${DATABASE_URL:?Define DATABASE_URL}"
OUT_DIR="${1:-./backups}"
KEEP_DAYS="${KEEP_DAYS:-14}"

# SQLAlchemy usa «postgresql+asyncpg://»; pg_dump entiende «postgresql://»
URL=$(printf '%s' "$DATABASE_URL" | sed 's#^postgresql+[a-z0-9]*://#postgresql://#')

mkdir -p "$OUT_DIR"
FILE="$OUT_DIR/alvea-$(date -u +%Y%m%d-%H%M%S).dump"
pg_dump --format=custom --no-owner --no-privileges --file="$FILE.part" "$URL"
mv "$FILE.part" "$FILE"
echo "Copia creada: $FILE ($(du -h "$FILE" | cut -f1))"

find "$OUT_DIR" -name 'alvea-*.dump' -type f -mtime +"$KEEP_DAYS" -print -delete
