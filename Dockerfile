FROM odoo:19.0

USER root

# ساخت پوشه‌ها
RUN mkdir -p /mnt/extra-addons /var/lib/odoo/sessions \
    && chown -R odoo:odoo /mnt/extra-addons /var/lib/odoo

# کپی کانفیگ و ماژول‌ها
COPY odoo.conf /etc/odoo/odoo.conf
COPY addons/ /mnt/extra-addons/

RUN chown -R odoo:odoo /etc/odoo /mnt/extra-addons

# کپی entrypoint
COPY entrypoint.sh /custom-entrypoint.sh
RUN chmod +x /custom-entrypoint.sh

# مهم: با root اجرا شود تا بتواند chown کند
USER root

EXPOSE 8069 8071 8072

ENTRYPOINT ["/custom-entrypoint.sh"]
CMD ["odoo"]