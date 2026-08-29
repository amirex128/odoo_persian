#!/bin/bash
set -e

# A PaaS persistent disk is commonly mounted as root:root and hides the
# ownership baked into the image. Prepare the mounted data directory first.
mkdir -p /var/lib/odoo/sessions
chown -R odoo:odoo /var/lib/odoo
chmod 750 /var/lib/odoo
chmod 700 /var/lib/odoo/sessions

# Accept both the official Odoo image names and the more explicit
# POSTGRES_* names commonly exposed by PaaS database services.
if [ -n "${POSTGRES_HOST:-}" ]; then export HOST="$POSTGRES_HOST"; fi
if [ -n "${POSTGRES_PORT:-}" ]; then export PORT="$POSTGRES_PORT"; fi
if [ -n "${POSTGRES_USER:-}" ]; then export USER="$POSTGRES_USER"; fi
if [ -n "${POSTGRES_PASSWORD:-}" ]; then export PASSWORD="$POSTGRES_PASSWORD"; fi

# The image config is owned by odoo and may be mounted read-only by a PaaS.
# Render secrets into a writable runtime copy, then delegate DB readiness and
# PostgreSQL argument handling to the official Odoo entrypoint.
runtime_config=/tmp/odoo-runtime.conf
cp /etc/odoo/odoo.conf "$runtime_config"
ODOO_ADMIN_PASSWD=${ODOO_ADMIN_PASSWD:-change-me-before-production}
ODOO_LIST_DB=${ODOO_LIST_DB:-True}
escaped_passwd=$(printf '%s' "$ODOO_ADMIN_PASSWD" | sed 's/[&|\\]/\\&/g')
escaped_list_db=$(printf '%s' "$ODOO_LIST_DB" | sed 's/[&|\\]/\\&/g')
sed -i "s|__ODOO_ADMIN_PASSWD__|${escaped_passwd}|g; s|__ODOO_LIST_DB__|${escaped_list_db}|g" "$runtime_config"

# Odoo imports its config module before processing CLI arguments, so point the
# environment variable at the rendered file as well as replacing --config.
export ODOO_RC="$runtime_config"
args=()
for arg in "$@"; do
    if [ "$arg" = "--config=/etc/odoo/odoo.conf" ]; then
        args+=("--config=$runtime_config")
    else
        args+=("$arg")
    fi
done

# Keep the application process non-root after preparing the mounted volume.
exec su -s /bin/bash odoo -c 'exec /entrypoint.sh "$@"' -- "${args[@]}"
