#!/bin/bash
set -e

# درست کردن دسترسی‌ها در زمان اجرا (مهم برای Volumeهای PaaS)
if [ "$(id -u)" = "0" ]; then
    mkdir -p /var/lib/odoo /mnt/extra-addons
    chown -R odoo:odoo /var/lib/odoo /mnt/extra-addons
    exec gosu odoo /entrypoint.sh "$@"
fi

exec /entrypoint.sh "$@"