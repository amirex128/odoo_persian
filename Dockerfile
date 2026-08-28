FROM odoo:19.0

USER root

RUN mkdir -p /mnt/extra-addons \
    && chown -R odoo:odoo /mnt/extra-addons

COPY odoo.conf /etc/odoo/odoo.conf
RUN chown odoo:odoo /etc/odoo/odoo.conf

USER odoo

EXPOSE 8069

CMD ["odoo"]