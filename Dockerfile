# Use Debian Bullseye Slim as a Base Image
FROM debian:bullseye-slim

# Set Metadata for the Image
LABEL maintainer="Codehornets Inc. <codehornets@gmail.com>"

# Configure Shell
SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

# Set Environment Variables & Generate locale C.UTF-8 for postgres and general locale data
ENV LANG=C.UTF-8

# Install core dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        dirmngr \
        fonts-noto-cjk \
        gnupg \
        libssl-dev && \
    rm -rf /var/lib/apt/lists/

# Install Node and Python packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        node-less \
        npm \
        python3-magic \
        python3-num2words \
        python3-odf \
        python3-pdfminer \
        python3-pip \
        python3-phonenumbers \
        python3-pyldap \
        python3-qrcode \
        python3-renderpm \
        python3-setuptools \
        python3-slugify \
        python3-vobject \
        python3-watchdog \
        python3-xlrd \
        python3-xlwt \
        xz-utils \
        libpq-dev \
        gcc \
        python3-dev \
        libldap2-dev \
        libsasl2-dev \
        ldap-utils && \
    rm -rf /var/lib/apt/lists/*

# Install Python dependencies
RUN pip3 install openai paramiko docker psycopg2-binary

# Install wkhtmltopdf
RUN curl -o wkhtmltox.deb -sSL https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.buster_amd64.deb && \
    echo 'ea8277df4297afc507c61122f3c349af142f31e5 wkhtmltox.deb' | sha1sum -c - && \
    apt-get update && \
    apt-get install -y --no-install-recommends ./wkhtmltox.deb && \
    rm -rf /var/lib/apt/lists/* wkhtmltox.deb

# install latest postgresql-client
RUN echo 'deb http://apt.postgresql.org/pub/repos/apt/ bullseye-pgdg main' > /etc/apt/sources.list.d/pgdg.list \
    && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8 \
    && apt-get update \
    && apt-get install -y --no-install-recommends postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Install rtlcss (on Debian buster)
RUN npm install -g rtlcss

# Install Odoo
ENV ODOO_VERSION 16.0
ARG ODOO_RELEASE=20230825
ARG ODOO_SHA=12ce0c5d56051d71ec3d9d474b3f4694fdcae45a
RUN curl -o odoo.deb -sSL http://nightly.odoo.com/${ODOO_VERSION}/nightly/deb/odoo_${ODOO_VERSION}.${ODOO_RELEASE}_all.deb \
    && echo "${ODOO_SHA} odoo.deb" | sha1sum -c - \
    && apt-get update \
    && apt-get -y install --no-install-recommends ./odoo.deb \
    && rm -rf /var/lib/apt/lists/* odoo.deb
# COPY ./odoo /opt/openerp/odoo

# Create the directory for the Odoo logs and set permissions
RUN mkdir -p /var/log/odoo && \
    chown odoo:odoo /var/log/odoo && \
    chmod 755 /var/log/odoo && \
    touch /var/log/odoo/openerp-server.log && \
    chown odoo:odoo /var/log/odoo/openerp-server.log

# Add the Odoo User to the Docker Group
RUN groupadd docker && \
    usermod -aG docker odoo

# Copy entrypoint script and Odoo configuration file
COPY ./entrypoint.sh /
COPY ./config/odoo.conf /etc/odoo/

# Set permissions and Mount /var/lib/odoo to allow restoring filestore and /mnt/extra-addons for users addons
RUN chmod +x /entrypoint.sh \
    && chown odoo /etc/odoo/odoo.conf \
    && chown odoo:odoo /etc/odoo/odoo.conf \
    && chmod 600 /etc/odoo/odoo.conf \
    && mkdir -p /mnt/extra-addons \
    && chown -R odoo /mnt/extra-addons

# Declare Volumes
VOLUME ["/var/lib/odoo", "/mnt/extra-addons"]
# VOLUME ["/var/lib/odoo", "/mnt/extra-addons", "/opt/openerp/odoo"]

# Expose Odoo services
EXPOSE 8069 8071 8072

# Set the default config file
ENV ODOO_RC=/etc/odoo/odoo.conf

# Copy wait-for script
COPY wait-for-psql.py /usr/local/bin/wait-for-psql.py
RUN chmod +x /usr/local/bin/wait-for-psql.py

# Set default user when running the container
USER odoo

# Define entrypoint and command
ENTRYPOINT ["/entrypoint.sh"]
CMD ["odoo"]
