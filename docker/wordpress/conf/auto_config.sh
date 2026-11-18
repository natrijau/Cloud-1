#!/bin/bash
set -e

# Utiliser les variables d'env injectees par docker-compose (.env)
# SQL_USER, SQL_PASSWORD, SQL_DATABASE, WP_URL, etc.

while ! mysqladmin ping -h mariadb -u "${SQL_USER}" -p"${SQL_PASSWORD}" --silent; do
    sleep 2
done

cd /var/www/wordpress

# 1. Telecharger WordPress core si pas present
if [ ! -f wp-includes/version.php ]; then
    echo "Downloading WordPress core..."
    wp core download --allow-root --path=/var/www/wordpress
fi

if [ ! -f wp-config.php ]; then
    wp config create --allow-root \
        --dbname="${SQL_DATABASE}" \
        --dbuser="${SQL_USER}" \
        --dbpass="${SQL_PASSWORD}" \
        --dbhost=mariadb:3306 \
        --path=/var/www/wordpress

    wp core install --allow-root \
        --url="${WP_URL}" \
        --title="${WP_TITLE}" \
        --admin_user="${WP_ADMIN_LOGIN}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --path=/var/www/wordpress

    wp user create --allow-root "${WP_USER_LOGIN}" "${WP_USER_EMAIL}" \
        --user_pass="${WP_USER_PASSWORD}" \
        --role=editor \
        --path=/var/www/wordpress
fi

# Permissions
chown -R www-data:www-data /var/www/wordpress

# Demarrer PHP-FPM
exec php-fpm8.1 -F