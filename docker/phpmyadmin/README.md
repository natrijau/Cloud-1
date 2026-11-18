# phpMyAdmin - Interface d'Administration MariaDB

[![phpMyAdmin](https://img.shields.io/badge/phpMyAdmin-5.2+-blue?logo=phpmyadmin)](https://www.phpmyadmin.net/)
[![Docker](https://img.shields.io/badge/Image-Official-blue?logo=docker)](https://hub.docker.com/r/phpmyadmin/phpmyadmin)
[![Arch](https://img.shields.io/badge/Arch-amd64%20%7C%20arm64-lightgrey)](https://hub.docker.com/r/phpmyadmin/phpmyadmin)
[![Apache](https://img.shields.io/badge/Server-Apache_2.4-green?logo=apache)](https://httpd.apache.org/)

> **Image officielle phpMyAdmin** (multi-arch ARM64/AMD64) avec configuration via variables d'environnement PMA_*. Accessible via Nginx reverse proxy sur `https://pma.localhost:8443`.

---

## Architecture

```mermaid
graph TB
    subgraph Container["Conteneur phpmyadmin"]
        direction TB
        
        Apache["Apache 2.4\nPort 80\nPHP 8.2+ module"]
        PHP["PHP 8.2+\nextensions: mysqli, mbstring, zip, gd..."]
        Config["Config via variables PMA_*\nCookie auth + blowfish secret"]
        Session["/var/www/html/\nSessions + config persistée"]
    end
    
    Apache --> PHP
    Config --> PHP
    Session -.-> Apache
    
    Nginx["Nginx Proxy\nHTTPS :443"] -->|Proxy HTTP :80| Apache
    MariaDB["MariaDB\nTCP:3306"] <--->|MySQL Protocol| PHP
    
    User["Utilisateur"] -->|HTTPS pma.localhost| Nginx
    
    Volumes["Volume: pma_data"] -.-> Session
    
    style Apache fill:#D22128,color:#fff
    style PHP fill:#777BB4,color:#fff
    style Config fill:#FF6B35,color:#fff
```

### Flux Connexion

```mermaid
sequenceDiagram
    participant U as Utilisateur
    participant N as Nginx (HTTPS)
    participant P as phpMyAdmin (Apache:80)
    participant D as MariaDB (3306)
    
    U->>N: GET https://pma.localhost/
    N->>P: Proxy HTTP (headers X-Forwarded-*)
    P->>U: Page login (cookie auth)
    
    U->>N: POST login (user/pass)
    N->>P: Forward
    P->>D: Connexion MySQL (credentials)
    D-->>P: OK / Échec
    P-->>N: Session cookie + redirect
    N-->>U: Interface phpMyAdmin
    
    Note over P,D: Connexion persistée via cookie chiffré (blowfish_secret)
```

---

## Configuration

### Variables d'Environnement (via `.env`)

| Variable | Source | Description |
|----------|--------|-------------|
| `SQL_USER` | `.env` | Utilisateur MariaDB (ex: `wp_user`) |
| `SQL_PASSWORD` | `.env` | Mot de passe utilisateur |
| `PMA_BLOWFISH_SECRET` | `.env` | Clé 32 chars pour chiffrement cookies |

### Variables PMA_* (injectées dans le conteneur)

| Variable | Valeur | Description |
|----------|--------|-------------|
| `PMA_HOST` | `mariadb` | Host MariaDB (nom service Docker) |
| `PMA_PORT` | `3306` | Port MariaDB |
| `PMA_USER` | `${SQL_USER}` | User DB (depuis .env) |
| `PMA_PASSWORD` | `${SQL_PASSWORD}` | Password DB (depuis .env) |
| `PMA_BLOWFISH_SECRET` | `${PMA_BLOWFISH_SECRET}` | Clé chiffrement cookies (32 chars) |

### Fichier de Configuration

| Fichier | Rôle | Montage |
|---------|------|---------|
| `conf/config.inc.php` | Config phpMyAdmin (générée auto par image officielle) | Non monté (générée au démarrage) |

> **Note** : L'image officielle `phpmyadmin/phpmyadmin` génère automatiquement `config.inc.php` depuis les variables d'environnement `PMA_*`. Pas besoin de fichier de config manuel.

---

## Docker

### Dockerfile — Analyse

```dockerfile
###########################################################
# phpMyAdmin - Image officielle (multi-arch Arm64 OK)
###########################################################
FROM phpmyadmin/phpmyadmin:latest

# Configuration via variables d'environnement PMA_*
# Pas de COPY de config.inc.php - l'image officielle la génère depuis les variables PMA_*
```

**C'est tout !** L'image officielle gère :
- Apache + PHP + extensions requises
- Entrypoint natif (apache2-foreground)
- Healthcheck natif
- Multi-arch (amd64, arm64, ppc64le, s390x)
- Génération auto de `config.inc.php` depuis variables `PMA_*`

### Build & Run

```bash
# Build (trivial, juste image de base)
docker build -t phpmyadmin-wp:local ./phpmyadmin

# Via docker-compose (recommandé)
docker compose up -d phpmyadmin
```

---

## Intégration docker-compose

```yaml
phpmyadmin:
  container_name: phpmyadmin
  build: ./phpmyadmin
  env_file: .env
  environment:
    - PMA_HOST=mariadb
    - PMA_PORT=3306
    - PMA_USER=${SQL_USER}
    - PMA_PASSWORD=${SQL_PASSWORD}
    - PMA_BLOWFISH_SECRET=${PMA_BLOWFISH_SECRET}
  volumes:
    - pma_data:/var/www/html
  networks:
    - inception
  depends_on:
    mariadb:
      condition: service_healthy
  restart: unless-stopped
```

### Dépendances

- **MariaDB** : `depends_on: mariadb (condition: service_healthy)` — phpMyAdmin ne démarre que si DB prête

### Réseau

- Réseau `inception` (bridge)
- Accessible via `mariadb:3306` (MySQL protocol)
- **Port 80 (Apache) non exposé sur l'hôte** — uniquement via Nginx proxy

### Volume

- `pma_data` → `/var/www/html` (persistance sessions, config utilisateur)

---

## Accès via Nginx

### Configuration Nginx (extrait)

```nginx
# phpMyAdmin HTTPS (proxy vers Apache sur port 80)
server {
    listen 443 ssl http2;
    server_name pma.localhost;
    
    ssl_certificate /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;
    
    root /var/www/phpmyadmin;
    index index.php;
    
    location / {
        proxy_pass http://phpmyadmin:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;
    }
    
    # Sécurité
    location ~ /\. { deny all; }
    location ~ /(libraries|setup|templates)/ { deny all; }
}
```

### Accès Local

1. Ajouter dans `/etc/hosts` :
   ```
   127.0.0.1 pma.localhost
   ```

2. Accéder : `https://pma.localhost:8443`

3. Login avec :
   - **Serveur** : `mariadb` (pré-rempli)
   - **Utilisateur** : `wp_user` (depuis `SQL_USER`)
   - **Mot de passe** : `SQL_PASSWORD`

---

## Commandes Utiles

### Administration

```bash
# Shell dans le conteneur
docker compose exec phpmyadmin bash

# Logs Apache
docker compose exec phpmyadmin tail -f /var/log/apache2/access.log
docker compose exec phpmyadmin tail -f /var/log/apache2/error.log

# Vérifier config PHP
docker compose exec phpmyadmin php -m | grep -E 'mysqli|mbstring|gd|zip'

# Test connexion MariaDB
docker compose exec phpmyadmin mysql -h mariadb -u ${SQL_USER} -p${SQL_PASSWORD} -e "SELECT VERSION();"
```

### Debug

```bash
# Logs démarrage
docker compose logs phpmyadmin

# Suivi temps réel
docker compose logs -f phpmyadmin

# Vérifier config effective (générée auto)
docker compose exec phpmyadmin cat /etc/phpmyadmin/config.inc.php

# Inspect conteneur
docker inspect phpmyadmin
```

### Session / Config Persistée

```bash
# Voir volume pma_data
docker volume inspect docker_pma_data

# Backup config utilisateur
docker run --rm -v docker_pma_data:/data -v $(pwd):/backup alpine tar czf /backup/pma_backup.tar.gz -C /data .

# Restore
docker run --rm -v docker_pma_data:/data -v $(pwd):/backup alpine tar xzf /backup/pma_backup.tar.gz -C /data
```

---

## Sécurité

### Implémenté

- ✅ **Auth cookie** : Pas de credentials en clair dans URL
- ✅ **Blowfish secret** : 32 chars pour chiffrement cookies
- ✅ **Nginx deny rules** : Bloque `libraries/`, `setup/`, `templates/`, dotfiles
- ✅ **Réseau isolé** : Pas d'exposition port 80 sur hôte
- ✅ **Image officielle** : Mises à jour sécurité régulières
- ✅ **Non-root** : Apache/PHP run as `www-data` (uid 33)

### Recommandations Prod

```yaml
# docker-compose.override.yml
services:
  phpmyadmin:
    # Variables d'env supplémentaires (image officielle)
    environment:
      - PMA_ARBITRARY=0           # Interdire serveur arbitraire
      - PMA_ABSOLUTE_URI=https://pma.monsite.com/
      - UPLOAD_LIMIT=16M
    
    # Sécurité conteneur
    cap_drop: [ALL]
    cap_add: [CHOWN, DAC_OVERRIDE, SETGID, SETUID]
    read_only: true
    tmpfs:
      - /var/www/html/tmp
      - /var/run/apache2
      - /tmp
    security_opt:
      - no-new-privileges:true
```

### Génération Blowfish Secret

```bash
# 32 caractères requis
openssl rand -base64 32 | tr -d '\n' | head -c 32

# Ou PHP
php -r 'echo bin2hex(random_bytes(16));'
```

> **Attention** : Si secret change → toutes sessions invalidées (reconnexion requise).

---

## Dépannage

| Symptôme | Cause | Solution |
|----------|-------|----------|
| `Cannot connect to MySQL server` | MariaDB pas ready | Attendre `service_healthy` (healthcheck mariadb) |
| `Access denied for user` | Mauvais credentials | Vérifier `SQL_USER`/`SQL_PASSWORD` dans `.env` |
| `blowfish_secret too short` | Secret < 32 chars | Générer nouveau : `openssl rand -base64 32` |
| `Session expired` / redirect loop | Secret changé / cookies | Vider cookies navigateur, vérifier secret constant |
| `500 Error` / Page blanche | Extension PHP manquante | Vérifier `docker compose exec phpmyadmin php -m` |
| `Forbidden` / 403 sur / | Nginx deny rules | Vérifier `location ~ /\.` et `libraries/` dans nginx.conf |
| `phpMyAdmin ne charge pas` | Nginx proxy down | Vérifier `docker compose logs nginx`, `phpmyadmin` up |

### Reset Complet

```bash
docker compose down phpmyadmin
docker volume rm docker_pma_data
docker compose up -d --build phpmyadmin
```

---

## Structure

```
phpmyadmin/
├── Dockerfile
└── README.md                # Ce fichier
```

---

## Conventions GitHub

### Commits Spécifiques phpMyAdmin

```bash
# Config
git commit -m "feat(phpmyadmin): add PMA_ARBITRARY=0 for security"

# Blowfish secret
git commit -m "chore(phpmyadmin): update blowfish_secret in .env.example"

# Sécurité
git commit -m "security(phpmyadmin): disable UploadDir/SaveDir in config"

# Version image
git commit -m "chore(phpmyadmin): bump base image to phpmyadmin/phpmyadmin:5.2.1"
```

### Labels Issues

- `phpmyadmin` - Interface d'administration
- `database` - Connexion MariaDB, permissions
- `security` - Auth, cookies, headers
- `ui` - Interface, thèmes, extensions

### PR Checklist phpMyAdmin

- [ ] `config.inc.php` syntaxe PHP valide (générée auto)
- [ ] `blowfish_secret` 32 chars dans `.env.example`
- [ ] Test login avec `wp_user` / `SQL_PASSWORD` fonctionne
- [ ] Accès via Nginx `https://pma.localhost:8443` OK
- [ ] Pas de credentials en dur dans config
- [ ] Image officielle version pinée (pas `latest` en prod)

---

## Références

| Ressource | Lien |
|-----------|------|
| phpMyAdmin Docker Official | https://hub.docker.com/r/phpmyadmin/phpmyadmin |
| phpMyAdmin Configuration | https://docs.phpmyadmin.net/en/latest/config.html |
| phpMyAdmin Config Reference | https://docs.phpmyadmin.net/en/latest/config.html#cfg_Servers |
| Blowfish Secret | https://docs.phpmyadmin.net/en/latest/config.html#cfg_blowfish_secret |
| Auth Types | https://docs.phpmyadmin.net/en/latest/config.html#cfg_Servers_auth_type |

---

## Licence

MIT — Voir [LICENSE](../../LICENSE).

*Note : phpMyAdmin est sous licence GPL v2+, l'image Docker officielle respecte cette licence.*

---

*Dernière mise à jour : 2026-11-18 — Partie de la stack Docker WordPress.*