# Commandes Docker Essentielles - Cloud-1

Fichier de reference pour le projet. A garder sous la main.

---

## SOMMAIRE

1. [Build - Construction des images](#build---construction-des-images)
2. [Run - Lancer des conteneurs](#run---lancer-des-conteneurs)
3. [Docker Compose - Stack complete](#docker-compose---stack-complete)
4. [Inspect & Debug](#inspect--debug)
5. [Volumes - Persistance des donnees](#volumes---persistance-des-donnees)
6. [Reseau](#reseau)
7. [Nettoyage](#nettoyage)
8. [Secrets & ENV](#secrets--env)
9. [Tags & Registry](#tags--registry)
10. [Commandes specifiques Cloud-1](#commandes-specifiques-cloud-1)
11. [Raccourcis utiles (Aliases)](#raccourcis-utiles-aliases)
12. [Erreurs frequentes & Solutions](#erreurs-frequentes--solutions)
13. [References officielles](#references-officielles)

---

## BUILD - Construction des images

```bash
# Build une image depuis un Dockerfile
docker build -t cloud1-mariadb ./docker/mariadb
docker build -t cloud1-wordpress ./docker/wordpress
docker build -t cloud1-nginx ./docker/nginx
docker build -t cloud1-phpmyadmin ./docker/phpmyadmin

# Build sans cache (force re-telechargement packages)
docker build --no-cache -t cloud1-wordpress ./docker/wordpress

# Build avec build args (ex: version PHP)
docker build --build-arg PHP_VERSION=8.1 -t cloud1-wordpress ./docker/wordpress

# Voir les layers d'une image
docker history cloud1-wordpress
```

---

## RUN - Lancer des conteneurs

### Mode detache (production-like)

```bash
# MariaDB seul
docker run -d --name mariadb \
  -e SQL_DATABASE=wordpress \
  -e SQL_USER=wp_user \
  -e SQL_PASSWORD=testpass \
  -e SQL_ROOT_PASSWORD=rootpass \
  -v mariadb_data:/var/lib/mysql \
  cloud1-mariadb

# WordPress (necessite MariaDB running)
docker run -d --name wordpress \
  -e SQL_DATABASE=wordpress \
  -e SQL_USER=wp_user \
  -e SQL_PASSWORD=testpass \
  -e WP_URL=http://localhost \
  -e WP_TITLE="Test" \
  -e WP_ADMIN_LOGIN=admin \
  -e WP_ADMIN_PASSWORD=adminpass \
  -e WP_ADMIN_EMAIL=admin@test.local \
  -e WP_USER_LOGIN=editor \
  -e WP_USER_EMAIL=editor@test.local \
  -e WP_USER_PASSWORD=editorpass \
  -v wp_data:/var/www/wordpress \
  --link mariadb:mariadb \
  cloud1-wordpress
```

### Mode interactif (debug)

```bash
# Shell dans l'image (pour inspecter)
docker run --rm -it cloud1-wordpress bash

# Shell dans un conteneur running
docker exec -it wordpress bash

# One-shot command
docker exec wordpress wp --allow-root core version --path=/var/www/wordpress
```

---

## DOCKER COMPOSE - Stack complete (RECOMMANDE)

```bash
# Depuis le dossier docker/
cd /home/alamizan/Projects/42-school/Cloud_1/docker

# Demarrer toute la stack (build + up)
docker compose up -d --build

# Demarrer sans rebuild
docker compose up -d

# Voir les logs (suivi temps reel)
docker compose logs -f
docker compose logs -f wordpress
docker compose logs -f mariadb

# Arreter (garde volumes, reseaux, conteneurs)
docker compose down

# Arreter + supprimer volumes (DATA PERDUE !)
docker compose down -v

# Rebuild un service specifique
docker compose up -d --build wordpress

# Scale (pas pour Cloud-1, mais bon a savoir)
docker compose up -d --scale wordpress=3
```

---

## INSPECT & DEBUG

```bash
# Lister conteneurs (running + stopped)
docker ps -a

# Lister images
docker images

# Inspecter un conteneur (JSON complet)
docker inspect wordpress

# Inspecter une image
docker inspect cloud1-wordpress

# Voir les variables d'env d'un conteneur
docker inspect wordpress | jq '.[0].Config.Env'

# Voir les mounts/volumes
docker inspect wordpress | jq '.[0].Mounts'

# Logs depuis le debut
docker logs wordpress
docker logs --tail 100 wordpress
docker logs -f wordpress  # follow

# Stats ressources (CPU, RAM, NET, I/O)
docker stats
docker stats wordpress mariadb nginx

# Processus dans le conteneur
docker top wordpress

# Port mapping
docker port wordpress
```

---

## VOLUMES - Persistance des donnees

```bash
# Lister volumes
docker volume ls

# Inspecter un volume
docker volume inspect wp_data

# Supprimer volumes orphelins (non utilises)
docker volume prune

# Supprimer TOUS les volumes non utilises
docker volume prune -a

# Backup volume (ex: wp_data)
docker run --rm -v wp_data:/data -v $(pwd):/backup alpine tar czf /backup/wp_backup.tar.gz -C /data .

# Restore volume
docker run --rm -v wp_data:/data -v $(pwd):/backup alpine tar xzf /backup/wp_backup.tar.gz -C /data
```

---

## RESEAU

```bash
# Lister reseaux
docker network ls

# Inspecter reseau inception
docker network inspect inception

# Creer reseau manuellement (si pas compose)
docker network create inception
```

---

## NETTOYAGE (Nettoyer l'espace disque)

```bash
# Supprimer conteneurs arretes
docker container prune

# Supprimer images non utilisees (dangling)
docker image prune

# Supprimer TOUTES les images non utilisees par un conteneur
docker image prune -a

# Nettoyage complet (conteneurs + images + volumes + reseaux + cache build)
docker system prune -a --volumes

# Voir l'espace utilise
docker system df
docker system df -v
```

---

## SECRETS & ENV (Bonnes pratiques)

```bash
# Passer secrets via fichier (pas en CLI visible dans ps)
echo "motdepasse" | docker secret create sql_password -

# Dans compose : utiliser env_file
# docker-compose.yml :
#   env_file: .env

# Fichier .env (JAMAIS commit dans Git)
cat > .env << 'EOF'
SQL_PASSWORD=supersecret
SQL_ROOT_PASSWORD=rootsecret
WP_ADMIN_PASSWORD=adminsecret
PMA_BLOWFISH_SECRET=32charsrandomstring123456789012
EOF
chmod 600 .env
```

---

## TAGS & REGISTRY (Pour CI/CD plus tard)

```bash
# Tagger une image
docker tag cloud1-wordpress ghcr.io/tonuser/cloud1-wordpress:v1.0.0

# Login registry
docker login ghcr.io

# Push
docker push ghcr.io/tonuser/cloud1-wordpress:v1.0.0

# Multi-arch build (pour Arm64 + AMD64)
docker buildx create --use
docker buildx build --platform linux/amd64,linux/arm64 -t ghcr.io/tonuser/cloud1-wordpress:v1.0.0 --push .
```

---

## COMMANDES SPECIFIQUES CLOUD-1

### Test stack local complete

```bash
cd /home/alamizan/Projects/42-school/Cloud_1/docker

# 1. Build + up
docker compose up -d --build

# 2. Verifier sante
docker compose ps
# NAME                STATUS
# mariadb             Up (healthy)
# wordpress           Up
# phpmyadmin          Up
# nginx               Up

# 3. Test WordPress
curl -I http://localhost
# HTTP/1.1 301 Moved Permanently -> redirect HTTPS

curl -k -I https://localhost
# HTTP/1.1 200 OK

# 4. Test phpMyAdmin
curl -k -I https://pma.localhost
# HTTP/1.1 200 OK

# 5. Logs WordPress install
docker compose logs -f wordpress | grep -E "(wp config|wp core|wp user)"

# 6. Nettoyage test
docker compose down -v
```

### Debug MariaDB connexion

```bash
# Depuis conteneur WordPress
docker exec -it wordpress mysqladmin ping -h mariadb -u wp_user -ptestpass

# Depuis hote (si port expose temporairement)
mysql -h 127.0.0.1 -P 3306 -u wp_user -p

# Verifier grants
docker exec -it mariadb mysql -u root -prootpass -e "SHOW GRANTS FOR 'wp_user'@'%';"
```

### Debug PHP-FPM

```bash
# Verifier processus
docker exec wordpress ps aux | grep php-fpm

# Test FastCGI depuis Nginx (dans conteneur nginx)
docker exec nginx cgi-fcgi -bind -connect wordpress:9000

# Config PHP-FPM active
docker exec wordpress php-fpm8.1 -i | grep -E "(listen|pm\.)"
```

---

## RACCOURCIS UTILES (Aliases a mettre dans ~/.bashrc)

```bash
# Aliases Docker
alias d='docker'
alias dc='docker compose'
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dlogs='docker compose logs -f'
alias dexec='docker exec -it'
alias dclean='docker system prune -a --volumes'
alias dvol='docker volume ls'
alias dnet='docker network ls'

# Cloud-1 specific
alias c1up='cd ~/Projects/42-school/Cloud_1/docker && docker compose up -d --build'
alias c1down='cd ~/Projects/42-school/Cloud_1/docker && docker compose down -v'
alias c1logs='cd ~/Projects/42-school/Cloud_1/docker && docker compose logs -f'
alias c1ps='cd ~/Projects/42-school/Cloud_1/docker && docker compose ps'
```

---

## ERREURS FREQUENTES & SOLUTIONS

| Erreur | Cause | Solution |
|--------|-------|----------|
| Cannot connect to the Docker daemon | Docker daemon pas demarre | sudo systemctl start docker |
| Permission denied sur /var/run/docker.sock | User pas dans groupe docker | sudo usermod -aG docker $USER + reconnexion |
| port is already allocated | Port 80/443/9000 deja utilise | sudo lsof -i :80 -> kill processus |
| no space left on device | Disque plein (images/volumes) | docker system prune -a --volumes |
| wp config create: Error: Database connection failed | MariaDB pas pret / mauvais creds | Verifier mysqladmin ping, variables d'env |
| chown: changing ownership: Operation not permitted | Volume mount avec user mapping | chown -R 1000:1000 /host/path sur l'hote |
| php-fpm: error while loading shared libraries | Extension manquante | Verifier php8.1-xml, php8.1-gd etc. installees |

---

## REFERENCES OFFICIELLES

| Sujet | Lien |
|-------|------|
| Dockerfile reference | https://docs.docker.com/engine/reference/builder/ |
| docker-compose.yml reference | https://docs.docker.com/compose/compose-file/ |
| PHP-FPM configuration | https://www.php.net/manual/en/install.fpm.configuration.php |
| WP-CLI commands | https://developer.wordpress.org/cli/commands/ |
| MariaDB Docker | https://hub.docker.com/_/mariadb |
| Nginx Docker | https://hub.docker.com/_/nginx |

---

Derniere MAJ : 2026-11-16 - Projet Cloud-1 42 School