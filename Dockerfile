FROM odoo:19.0

USER root

RUN mkdir -p /mnt/extra-addons \
    && chown -R odoo:odoo /mnt/extra-addons \
    && chmod 755 /mnt/extra-addons


COPY --chown=odoo:odoo odoo.conf /etc/odoo/odoo.conf

COPY --chown=odoo:odoo addons/ /mnt/extra-addons/

USER odoo

EXPOSE 8069 8071 8072

CMD ["odoo"]