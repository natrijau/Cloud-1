###########################################################
# Dockerfile MariaDB - Ubuntu 22.04 (Arm64 compatible)
# Construire une image Docker qui lance MariaDB (base de données)
# automatiquement, avec la bonne config, et qui initialise la 
# base WordPress au premier démarrage.
###########################################################

# Définir l'image de base sur l'avant derniere version de d'Ubuntu 22.04 (Jammy Jellyfish) pour assurer la compatibilité avec les architectures ARM64:
FROM ubuntu:22.04

# Éviter prompts interactifs :
ENV DEBIAN_FRONTEND=noninteractive

# Mettre à niveau les paquets et installer MariaDB et nettoyer le cache d'installation pour réduire la taille de l'image :
RUN apt-get update -y && apt-get upgrade -y \
    && apt-get install -y mariadb-server \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Config MariaDB (bind 0.0.0.0 pour accès réseau Docker) :
COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/

# Donne les droits d'acces au script de lancement:
COPY conf/entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

# Expose le port:
EXPOSE 3306

# Définit la commande par défaut à exécuter: 
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]