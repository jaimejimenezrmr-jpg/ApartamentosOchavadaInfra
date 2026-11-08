#!/usr/bin/env bash
# =====================================================================================
# Despliegue en el servidor: actualiza el código, compila las imágenes de UNA EN UNA y sustituye
# los contenedores esperando a que estén sanos.
#
#   bash scripts/deploy.sh             # git pull de los tres repositorios + compilar + arrancar
#   bash scripts/deploy.sh --no-pull   # solo compilar y arrancar el código que ya hay (primera vez)
#
# Por qué de una en una: en un VPS de 4 GB, compilar Java (Maven), Angular y Caddy (Go) a la vez agota
# la memoria. Mientras compila, la versión anterior sigue atendiendo; el corte es solo el reinicio final.
#
# Todo va dentro de main() y la última línea es `main "$@"; exit`: bash ya ha leído todo el código
# antes de ejecutarlo, así que el `git pull` del repositorio de infraestructura puede cambiar este
# script sin romper la ejecución en curso.
# =====================================================================================
set -euo pipefail

main() {
  local pull=true
  for arg in "$@"; do
    case "$arg" in
      --no-pull) pull=false ;;
      -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
      *) echo "Opción desconocida: $arg (use --help)" >&2; exit 2 ;;
    esac
  done

  local infra_dir root_dir
  infra_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  root_dir="$(dirname "$infra_dir")"
  cd "$infra_dir"

  local repos=("$root_dir/ApartamentosOchavadaBackend" "$root_dir/ApartamentosOchavadaFront" "$infra_dir")

  step "Comprobaciones previas"
  for f in .env backend.env; do
    [[ -f "$f" ]] || fail "Falta $infra_dir/$f (cópielo de $f.example y rellénelo)"
  done
  for repo in "${repos[@]}"; do
    [[ -d "$repo/.git" ]] || fail "No existe el repositorio $repo"
  done
  command -v docker >/dev/null || fail "Docker no está instalado"
  docker compose version >/dev/null || fail "Falta el plugin docker compose"
  check_disk 5

  if $pull; then
    step "Actualizando el código"
    for repo in "${repos[@]}"; do
      echo "· $(basename "$repo")"
      git -C "$repo" pull --ff-only || fail "No se pudo actualizar $repo (¿cambios locales o sin conexión con GitHub?)"
    done
  fi

  for service in backend frontend caddy; do
    step "Compilando $service"
    docker compose build "$service"
  done

  step "Sustituyendo contenedores (espera a que estén sanos, máx. 5 min)"
  if ! docker compose up -d --remove-orphans --wait --wait-timeout 300; then
    docker compose ps
    fail "Algún servicio no ha quedado sano. Revise: docker compose logs --tail=100 backend frontend caddy"
  fi

  step "Limpiando imágenes sin uso"
  docker image prune -f >/dev/null

  docker compose ps
  echo
  echo "Despliegue terminado. Disco libre: $(free_disk_gb) GB."
}

step() {
  printf '\n==> %s\n' "$1"
}

fail() {
  printf '\nERROR: %s\n' "$1" >&2
  exit 1
}

free_disk_gb() {
  df -Pk / | awk 'NR==2 { printf "%d", $4 / 1024 / 1024 }'
}

# Para antes de compilar si queda poco disco: las compilaciones y su caché ocupan varios GB.
check_disk() {
  local min_gb=$1 free_gb
  free_gb=$(free_disk_gb)
  if (( free_gb < min_gb )); then
    fail "Solo quedan ${free_gb} GB libres en disco. Libere espacio: docker builder prune -f && docker image prune -f"
  fi
  echo "· Disco libre: ${free_gb} GB"
}

main "$@"; exit
