#!/usr/bin/env bash
set -Eeuo pipefail

ODOO_HOME="${ODOO_HOME:-/opt/odoo/odoo-19.0+e.20260223}"
SOURCE_CONFIG="${ODOO_HOME}/odoo.conf"
RUNTIME_CONFIG="/tmp/odoo-runtime.conf"

mkdir -p /var/lib/odoo/sessions
chown -R odoo:odoo /var/lib/odoo
chmod 750 /var/lib/odoo
chmod 700 /var/lib/odoo/sessions

# Support both the explicit PaaS names and Odoo's conventional names.
export HOST="${POSTGRES_HOST:-${HOST:-db}}"
export PORT="${POSTGRES_PORT:-${PORT:-5432}}"
export USER="${POSTGRES_USER:-${USER:-odoo}}"
export PASSWORD="${POSTGRES_PASSWORD:-${PASSWORD:-}}"

: "${ODOO_ADMIN_PASSWD:=change-me-before-production}"
: "${ODOO_LIST_DB:=False}"
: "${ODOO_WORKERS:=2}"
: "${ODOO_MAX_CRON_THREADS:=1}"
: "${ODOO_DB_FILTER:=}"
: "${ODOO_LOG_LEVEL:=warn}"

cp "$SOURCE_CONFIG" "$RUNTIME_CONFIG"

escape_sed() {
  printf '%s' "$1" | sed 's/[&|\\]/\\&/g'
}

AP=$(escape_sed "$ODOO_ADMIN_PASSWD")
LD=$(escape_sed "$ODOO_LIST_DB")
WK=$(escape_sed "$ODOO_WORKERS")
CR=$(escape_sed "$ODOO_MAX_CRON_THREADS")
LF=$(escape_sed "$ODOO_LOG_LEVEL")
DF=$(escape_sed "$ODOO_DB_FILTER")
DH=$(escape_sed "$HOST")
DP=$(escape_sed "$PORT")
DU=$(escape_sed "$USER")
DW=$(escape_sed "$PASSWORD")

sed -i \
  -e "s|__ODOO_ADMIN_PASSWD__|${AP}|g" \
  -e "s|__ODOO_LIST_DB__|${LD}|g" \
  -e "s|__ODOO_WORKERS__|${WK}|g" \
  -e "s|__ODOO_MAX_CRON_THREADS__|${CR}|g" \
  -e "s|__ODOO_LOG_LEVEL__|${LF}|g" \
  -e "s|__ODOO_DB_FILTER__|${DF}|g" \
  -e "s|__DB_HOST__|${DH}|g" \
  -e "s|__DB_PORT__|${DP}|g" \
  -e "s|__DB_USER__|${DU}|g" \
  -e "s|__DB_PASSWORD__|${DW}|g" \
  "$RUNTIME_CONFIG"

chown odoo:odoo "$RUNTIME_CONFIG"
chmod 640 "$RUNTIME_CONFIG"

if [[ "${1:-}" == "odoo" ]]; then
  shift
  set -- python "$ODOO_HOME/setup/odoo" "$@"
fi

args=()
for arg in "$@"; do
  if [[ "$arg" == --config=* ]]; then
    args+=("--config=$RUNTIME_CONFIG")
  else
    args+=("$arg")
  fi
done

export ODOO_RC="$RUNTIME_CONFIG"
exec gosu odoo "${args[@]}"
