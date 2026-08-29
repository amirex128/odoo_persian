FROM odoo:19.0

USER root

# OCA/web module web_widget_bokeh_chart declares bokeh==3.9.0.
RUN pip3 install --no-cache-dir --break-system-packages 'bokeh==3.9.0'

COPY addons/ /mnt/extra-addons/
COPY config/odoo.conf /etc/odoo/odoo.conf
COPY entrypoint.sh /usr/local/bin/project-entrypoint.sh

RUN chown -R odoo:odoo /mnt/extra-addons /etc/odoo/odoo.conf \
    && chmod -R a+rX /mnt/extra-addons \
    && chmod 755 /usr/local/bin/project-entrypoint.sh

USER odoo
EXPOSE 8069 8072

ENTRYPOINT ["/usr/local/bin/project-entrypoint.sh"]
CMD ["odoo", "--config=/etc/odoo/odoo.conf"]