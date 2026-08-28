FROM odoo:19.0

USER root


RUN mkdir -p /mnt/extra-addons /var/lib/odoo/sessions \
    && chown -R odoo:odoo /mnt/extra-addons /var/lib/odoo \
    && chmod -R 755 /mnt/extra-addons \
    && chmod -R 700 /var/lib/odoo


COPY --chown=odoo:odoo odoo.conf /etc/odoo/odoo.conf


COPY --chown=odoo:odoo addons/ /mnt/extra-addons/


COPY entrypoint.sh /custom-entrypoint.sh
RUN chmod +x /custom-entrypoint.sh

USER odoo

EXPOSE 8069 8071 8072

ENTRYPOINT ["/custom-entrypoint.sh"]
CMD ["odoo"]