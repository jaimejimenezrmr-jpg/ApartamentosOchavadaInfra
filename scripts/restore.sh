#!/bin/sh
# =====================================================================================
# Restaura una copia hecha por backup.sh SOBRE la base de datos actual (borra lo que haya).
#
#   docker compose stop backend frontend
#   docker compose run --rm -e RESTORE_CONFIRM=si --entrypoint /bin/sh db-backup \
#     /scripts/restore.sh /backups/ochavada-AAAAMMDD-HHMM.dump
#   docker compose start backend frontend
# =====================================================================================
set -eu

dump="${1:-}"
if [ -z "$dump" ] || [ ! -f "$dump" ]; then
  echo "Uso: restore.sh /backups/<fichero>.dump   (copias disponibles:)" >&2
  ls -1t /backups/*.dump 2>/dev/null >&2 || echo "  (ninguna)" >&2
  exit 1
fi
if [ "${RESTORE_CONFIRM:-}" != "si" ]; then
  echo "Esto sustituye TODOS los datos de '$PGDATABASE' por los de $dump." >&2
  echo "Repita la orden con -e RESTORE_CONFIRM=si para continuar." >&2
  exit 1
fi

until pg_isready --quiet; do
  echo "Esperando a PostgreSQL..."
  sleep 3
done

echo "Restaurando $dump en $PGDATABASE..."
pg_restore --clean --if-exists --no-owner --single-transaction --dbname="$PGDATABASE" "$dump"
echo "Restauración completada."
