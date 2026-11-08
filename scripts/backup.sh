#!/bin/sh
# =====================================================================================
# Copia de seguridad diaria de PostgreSQL (pg_dump en formato custom, comprimido).
#   - Se ejecuta cada día a BACKUP_HOUR (hora de Madrid) y una vez al arrancar si no hay copia de hoy.
#   - Conserva BACKUP_RETENTION_DAYS días.
#   - Escribe primero a un fichero temporal: una copia a medias nunca sustituye a una buena.
# Restaurar:  ver README (pg_restore --clean --if-exists).
# =====================================================================================
set -eu

BACKUP_DIR=/backups
HOUR="${BACKUP_HOUR:-4}"
RETENTION="${BACKUP_RETENTION_DAYS:-14}"

log() {
  echo "$(date '+%Y-%m-%dT%H:%M:%S%z') [backup] $*"
}

run_backup() {
  stamp=$(date '+%Y%m%d-%H%M')
  target="$BACKUP_DIR/${PGDATABASE}-${stamp}.dump"
  tmp="$target.partial"
  log "Copiando la base de datos $PGDATABASE en $target"
  if pg_dump --format=custom --compress=9 --no-owner --file="$tmp"; then
    mv "$tmp" "$target"
    log "Copia terminada ($(du -h "$target" | cut -f1))"
  else
    rm -f "$tmp"
    log "ERROR: la copia ha fallado; se reintentará en la próxima ejecución"
    return 1
  fi
  find "$BACKUP_DIR" -name "${PGDATABASE}-*.dump" -type f -mtime +"$RETENTION" -print -delete \
    | while read -r old; do log "Eliminada copia antigua $old"; done
}

seconds_until_next_run() {
  now=$(date +%s)
  today_run=$(date -d "$(date '+%Y-%m-%d') ${HOUR}:00:00" +%s 2>/dev/null \
    || date -D '%Y-%m-%d %H:%M:%S' -d "$(date '+%Y-%m-%d') ${HOUR}:00:00" +%s)
  if [ "$today_run" -le "$now" ]; then
    today_run=$((today_run + 86400))
  fi
  echo $((today_run - now))
}

mkdir -p "$BACKUP_DIR"
until pg_isready --quiet; do
  log "Esperando a PostgreSQL..."
  sleep 5
done

if ! ls "$BACKUP_DIR/${PGDATABASE}-$(date '+%Y%m%d')"-*.dump >/dev/null 2>&1; then
  run_backup || true
fi

while true; do
  wait_for=$(seconds_until_next_run)
  log "Próxima copia en $((wait_for / 3600)) h $(((wait_for % 3600) / 60)) min"
  sleep "$wait_for"
  run_backup || true
done
