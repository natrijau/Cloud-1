###########################################################
# Dockerfile Nginx - Ubuntu 22.04 + Certbot (Let's Encrypt)
###########################################################
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install nginx + certbot
RUN apt-get update -y && apt-get upgrade -y \
    && apt-get install -y nginx certbot python3-certbot-nginx \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Config nginx (sera templatée par Ansible)
COPY conf/nginx.conf /etc/nginx/nginx.conf

# Dossiers SSL + web roots
RUN mkdir -p /etc/nginx/ssl /var/www/wordpress /var/www/phpmyadmin /var/www/certbot

# Entrypoint pour gestion certificats auto
COPY conf/entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 80 443
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]