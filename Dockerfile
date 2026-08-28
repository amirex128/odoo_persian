FROM odoo:19.0

USER root

# ایجاد پوشه extra-addons
RUN mkdir -p /mnt/extra-addons \
    && chown -R odoo:odoo /mnt/extra-addons

# کپی فایل کانفیگ
COPY --chown=odoo:odoo odoo.conf /etc/odoo/odoo.conf

# کپی تمام محتویات پوشه addons محلی به داخل کانتینر
COPY --chown=odoo:odoo addons/ /mnt/extra-addons/

USER odoo

EXPOSE 8069 8071 8072

CMD ["odoo"]