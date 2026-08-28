#!/bin/bash
set -e

echo "Fixing permissions..."
mkdir -p /var/lib/odoo/sessions /mnt/extra-addons
chown -R odoo:odoo /var/lib/odoo /mnt/extra-addons
chmod -R 700 /var/lib/odoo
chmod -R 755 /mnt/extra-addons

echo "Permissions fixed. Starting Odoo as user odoo..."
exec su -s /bin/bash odoo -c "/entrypoint.sh $*"