###########################################################
# Dockerfile WordPress - Ubuntu 22.04 + PHP 8.1-fpm
###########################################################
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# 1. SYSTEM DEPS + PHP 8.1-fpm + EXTENSIONS WP REQUIS
RUN apt-get update -y && apt-get upgrade -y \
    && apt-get install -y \
    php8.1 \
    php8.1-fpm \        
    php8.1-mysql \
    php8.1-curl \
    php8.1-gd \
    php8.1-mbstring \
    php8.1-xml \
    php8.1-zip \
    php8.1-intl \
    mariadb-client \
    wget \
    ca-certificates \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 2. WP-CLI (outil CLI officiel WordPress)
RUN wget -O /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x /usr/local/bin/wp

# 3. CONFIG PHP-FPM (pool www)
COPY conf/www.conf /etc/php/8.1/fpm/pool.d/www.conf

# 4. AUTO-CONFIG SCRIPT (le cerveau - templaté par Ansible)
COPY conf/auto_config.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/auto_config.sh

# 5. DOSSIERS RUNTIME
RUN mkdir -p /var/www/wordpress /run/php

EXPOSE 9000
ENTRYPOINT ["/usr/local/bin/auto_config.sh"]