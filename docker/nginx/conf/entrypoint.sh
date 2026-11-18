#!/bin/bash
set -e

# Variables (remplacées par Ansible en prod, valeurs test ici)
DOMAIN_NAME="${DOMAIN_NAME:-localhost}"

echo "=== Nginx Entrypoint ==="
echo "Domain: $DOMAIN_NAME"

# 1. Si certificats Let's Encrypt existent, les utiliser
if [ -f "/etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem" ]; then
    echo "Certificats Let's Encrypt trouvés -> copie vers /etc/nginx/ssl/"
    cp /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem /etc/nginx/ssl/fullchain.pem
    cp /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem /etc/nginx/ssl/privkey.pem
fi

# 2. Sinon générer auto-signé pour démarrage
if [ ! -f "/etc/nginx/ssl/fullchain.pem" ]; then
    echo "Pas de certificats -> génération auto-signé pour $DOMAIN_NAME"
    openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
        -keyout /etc/nginx/ssl/privkey.pem \
        -out /etc/nginx/ssl/fullchain.pem \
        -subj "/CN=$DOMAIN_NAME" \
        -addext "subjectAltName=DNS:$DOMAIN_NAME,DNS:pma.$DOMAIN_NAME"
fi

# 3. Vérifier config nginx
nginx -t

# 4. Démarrer nginx (foreground)
echo "=== Starting Nginx ==="
exec nginx -g "daemon off;"