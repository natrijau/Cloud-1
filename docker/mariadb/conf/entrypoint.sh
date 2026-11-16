#!/bin/bash
set -e


# Créer le dossier pour le socket
mkdir -p /var/run/mysqld
chown mysql:mysql /var/run/mysqld

# Init DB si pas déjà fait :
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Initializing MariaDB..."
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql
fi

# Start MariaDB en background pour init :
mariadbd --user=mysql --datadir=/var/lib/mysql &
PID=$!

# Attendre que le socket soit prêt :
while ! mysqladmin ping --silent; do sleep 1; done

# Exécuter scripts d'init :
for f in /docker-entrypoint-initdb.d/*.sql; do
    echo "Running $f"
    mysql < "$f"
done

# Arrêt propre :
mysqladmin shutdown
wait $PID

# Démarrage final
exec mariadbd --user=mysql --datadir=/var/lib/mysql