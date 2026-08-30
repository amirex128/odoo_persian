FROM python:3.12-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PYTHONPATH=/opt/odoo/odoo-19.0+e.20260223 \
    ODOO_HOME=/opt/odoo/odoo-19.0+e.20260223

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        fonts-dejavu \
        fonts-freefont-ttf \
        git \
        gosu \
        libfreetype6-dev \
        libfribidi-dev \
        libgeos-dev \
        libharfbuzz-dev \
        libjpeg62-turbo-dev \
        libldap2-dev \
        libopenjp2-7-dev \
        libpq-dev \
        libssl-dev \
        libtiff-dev \
        libwebp-dev \
        libxml2-dev \
        libxslt1-dev \
        libz-dev \
        node-less \
        postgresql-client \
        libsasl2-dev \
        wkhtmltopdf \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --system odoo \
    && useradd --system --gid odoo --home-dir /var/lib/odoo --create-home odoo

WORKDIR /opt/odoo
COPY odoo-19.0+e.20260223/ /opt/odoo/odoo-19.0+e.20260223/

RUN python -m pip install --upgrade pip setuptools wheel \
    && python -m pip install --no-cache-dir -r "$ODOO_HOME/requirements.txt" \
    && python -m pip install --no-cache-dir 'bokeh==3.9.0' \
    && mkdir -p /mnt/extra-addons /var/lib/odoo/sessions \
    && chown -R odoo:odoo /var/lib/odoo /mnt/extra-addons

COPY addons/ /mnt/extra-addons/
COPY entrypoint.sh /usr/local/bin/project-entrypoint.sh

RUN chmod 755 /usr/local/bin/project-entrypoint.sh \
    && chmod -R a+rX /mnt/extra-addons

EXPOSE 8069 8072

USER root
ENTRYPOINT ["/usr/local/bin/project-entrypoint.sh"]
CMD ["python", "/opt/odoo/odoo-19.0+e.20260223/setup/odoo", "--config=/opt/odoo/odoo-19.0+e.20260223/odoo.conf"]
