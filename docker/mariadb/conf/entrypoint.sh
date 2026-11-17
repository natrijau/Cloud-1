#!/bin/bash
set -e


# Creer le dossier pour le socket
mkdir -p /var/run/mysqld
chown mysql:mysql /var/run/mysqld

# Init DB si pas deja fait :
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Initializing MariaDB data directory..."
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql
fi

# Demarrer MariaDB en background (SANS password root au debut, sans networking pour securite)
mariadbd --user=mysql --datadir=/var/lib/mysql --skip-networking=1 &
PID=$!

# Attendre que le socket soit pret :
while ! mysqladmin ping --silent; do sleep 1; done

# DEFINIR ROOT PASSWORD (critique pour healthcheck + securite)
if [ -n "${SQL_ROOT_PASSWORD}" ]; then
    echo "Setting root password..."
    mysqladmin -u root password "${SQL_ROOT_PASSWORD}"
fi

# CREER BASE ET USER WORDPRESS via variables d'env
if [ -n "${SQL_DATABASE}" ] && [ -n "${SQL_USER}" ] && [ -n "${SQL_PASSWORD}" ]; then
    echo "Creating WordPress database and user..."
    
    # Utiliser mysql -e avec variables expansion correcte
    mysql -u root -p"${SQL_ROOT_PASSWORD}" -e "CREATE DATABASE IF NOT EXISTS \`${SQL_DATABASE}\`;"
    mysql -u root -p"${SQL_ROOT_PASSWORD}" -e "CREATE USER IF NOT EXISTS '${SQL_USER}'@'%' IDENTIFIED BY '${SQL_PASSWORD}';"
    mysql -u root -p"${SQL_ROOT_PASSWORD}" -e "CREATE USER IF NOT EXISTS '${SQL_USER}'@'localhost' IDENTIFIED BY '${SQL_PASSWORD}';"
    mysql -u root -p"${SQL_ROOT_PASSWORD}" -e "GRANT ALL PRIVILEGES ON \`${SQL_DATABASE}\`.* TO '${SQL_USER}'@'%';"
    mysql -u root -p"${SQL_ROOT_PASSWORD}" -e "GRANT ALL PRIVILEGES ON \`${SQL_DATABASE}\`.* TO '${SQL_USER}'@'localhost';"
    mysql -u root -p"${SQL_ROOT_PASSWORD}" -e "FLUSH PRIVILEGES;"
fi

# Arret propre
mysqladmin -u root -p"${SQL_ROOT_PASSWORD}" shutdown
wait $PID

# Demarrage final (avec networking, password root actif)
exec mariadbd --user=mysql --datadir=/var/lib/mysql