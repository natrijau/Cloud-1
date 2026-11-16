# Glossaire Cloud-1

> Maintenu au fil du projet. Format Markdown pour versioning Git optimal.

---

## A

### Ansible
**Outil d'automatisation IT** (Configuration Management, Application Deployment, Orchestration). Approche **déclarative** : on décrit l'état *désiré*, Ansible converge vers cet état.

#### Pourquoi Ansible pour Cloud-1 ?
| Besoin Cloud-1 | Solution Ansible |
|----------------|------------------|
| Déploiement **automatisé** complet | Playbooks + rôles |
| **Multi-serveurs** en parallèle | Inventaire + `strategy: free` / `serial` |
| **Idempotence** (relançable sans casser) | Modules natifs idempotents |
| **Pas de secrets en dur** | Ansible Vault (AES-256) |
| **Portable** (instance fraîche Ubuntu 22.04) | Roles réutilisables, pas de state local |
| **Ordre des opérations** | Dependencies entre rôles, handlers |
| **Audit / Reproductibilité** | Code versionné dans Git |

#### Architecture — *Agentless, Push-based*
```
┌──────────────────┐     SSH (Python)      ┌──────────────────┐
│  CONTROL NODE    │ ────────────────────► │  MANAGED NODES   │
│  (votre machine  │                       │  (serveurs cloud │
│   ou CI/CD)      │  Modules s'exécutent  │   Ubuntu 22.04)  │
│                  │  côté cible, puis     │                  │
│  - Playbooks     │  supprimés            │  - Python3 only  │
│  - Inventaire    │                       │  - SSH daemon    │
│  - Rôles         │  Pas d'agent permanent│  - sudo/root     │
│  - Vault         │                       │                  │
└──────────────────┘                       └──────────────────┘
```

#### Concepts clés

| Concept | Description | Fichier/Exemple |
|---------|-------------|-----------------|
| **Control Node** | Machine qui lance Ansible | Votre laptop / GitHub Actions |
| **Managed Nodes** | Serveurs cibles (inventaire) | `hosts.yml` → `web1`, `web2` |
| **Inventory** | Liste des hôtes + groupes + variables | YAML/INI : `all:`, `children:`, `vars:` |
| **Playbook** | Fichier YAML : série de *plays* | `deploy.yml` |
| **Play** | Cible (hosts/groups) + rôles/tasks | `- hosts: all`<br>`  roles: [docker, nginx]` |
| **Task** | Action unitaire (module + params) | `- name: Install nginx`<br>`  apt: name=nginx state=present` |
| **Module** | Unité de code réutilisable (Python) | `apt`, `copy`, `template`, `systemd`, `ufw`, `docker_container`, `community.docker.docker_compose_v2` |
| **Role** | Structure réutilisable (tasks, handlers, templates, vars, files) | `roles/nginx/` |
| **Handler** | Task déclenchée par `notify` (ex: restart service) | `handlers/main.yml` |
| **Template** | Fichier Jinja2 (`.j2`) → rendu avec variables | `nginx.conf.j2` → `/etc/nginx/nginx.conf` |
| **Facts** | Infos auto-collectées sur le nœud (OS, IP, disks...) | `ansible_facts['distribution']` → `"Ubuntu"` |
| **Variables** | Priorité : extra vars > play > role > inventory > defaults | `group_vars/all/vars.yml`, `host_vars/web1.yml` |

#### Flux d'exécution typique
```
ansible-playbook -i inventories/production/hosts.yml playbooks/deploy.yml
        │
        ▼
┌───────────────────┐
│ 1. Parse playbook │
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ 2. Load inventory │  → groupes, hosts, variables
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ 3. Gather facts   │  → setup module (auto) sur chaque hôte
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ 4. Pour chaque play, pour chaque hôte :     │
│    - Exécute tasks dans l'ordre              │
│    - Modules s'exécutent SUR le nœud géré    │
│    - Idempotence : check → change si besoin  │
│    - Handlers notifiés → flush à la fin      │
└───────────────────┘
```

#### Modes d'exécution parallèle (Cloud-1 : multi-serveurs)
| Stratégie | Comportement | Usage Cloud-1 |
|-----------|--------------|---------------|
| `linear` (défaut) | Un hôte à la fois, toutes tasks | Simple, séquentiel |
| `free` | Chaque hôte à son rythme, max forks | **Déploiement parallèle rapide** |
| `serial: N` | Par batch de N hôtes | Rolling update (ex: `serial: 1`) |
| `strategy: debug` | Pause interactive sur erreur | Debug |

```yaml
# Exemple deploy.yml avec parallélisme
- hosts: all
  strategy: free
  max_fail_percentage: 0
  roles:
    - mariadb
    - wordpress
    - nginx
    - phpmyadmin
```

#### Modules Cloud-1 essentiels
| Module | Usage |
|--------|-------|
| `apt` | Installer paquets (docker, nginx, certbot, python3-pip...) |
| `copy` | Déployer fichiers statiques (configs, scripts) |
| `template` | Rendre fichiers `.j2` avec variables (configs dynamiques) |
| `file` | Créer répertoires, liens, permissions |
| `systemd` | Gérer services (docker, nginx) — `enabled: yes`, `state: started` |
| `ufw` | Configurer firewall — `rule: allow`, `port: 443`, `proto: tcp` |
| `community.docker.docker_image` | Build/pull images Docker |
| `community.docker.docker_container` | Gérer conteneurs (alternative à compose) |
| `community.docker.docker_compose_v2` | **Déployer stack complète** via `docker-compose.yml` |
| `ansible.builtin.shell` / `command` | Dernier recours (non idempotent) |
| `set_fact` | Créer variables dynamiques pendant l'exécution |
| `include_tasks` / `import_tasks` | Modulariser les tâches |

#### Bonnes pratiques Cloud-1
```yaml
# ✅ Bon : idempotent, déclaratif
- name: Ensure docker service started and enabled
  systemd:
    name: docker
    state: started
    enabled: yes

# ❌ Mauvais : non idempotent, shell
- name: Start docker
  shell: systemctl start docker

# ✅ Bon : template pour config dynamique
- name: Deploy nginx config
  template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
    mode: '0644'
  notify: Reload nginx

# ✅ Bon : handler pour restart conditionnel
# handlers/main.yml
- name: Reload nginx
  systemd:
    name: nginx
    state: reloaded
```

#### Commandes utiles
```bash
# Syntaxe check
ansible-playbook --syntax-check playbooks/deploy.yml

# Dry-run (check mode) — ne modifie rien, rapporte ce qui changerait
ansible-playbook -i inventories/production/hosts.yml playbooks/deploy.yml --check

# Diff mode — montre les différences exactes
ansible-playbook -i inventories/production/hosts.yml playbooks/deploy.yml --diff

# Limiter à un hôte/groupe
ansible-playbook -i inventories/production/hosts.yml playbooks/deploy.yml --limit web1

# Démarrer à une task précise (--start-at-task)
ansible-playbook ... --start-at-task "Deploy nginx config"

# Vault
ansible-vault create inventories/production/group_vars/all/vault.yml
ansible-vault edit inventories/production/group_vars/all/vault.yml
ansible-vault encrypt_string 'mon_secret' --name 'sql_password'

# Exécuter avec vault (demande mot de passe)
ansible-playbook -i ... playbooks/deploy.yml --ask-vault-pass

# Ou fichier de mot de passe vault (CI/CD)
ansible-playbook -i ... playbooks/deploy.yml --vault-password-file .vault_pass
```

---

### Ansible Vault
Chiffrement **AES-256** des variables sensibles. Fichiers `vault.yml` illisibles sans mot de passe.

#### Structure recommandée Cloud-1
```
inventories/production/
├── hosts.yml
└── group_vars/
    └── all/
        ├── vars.yml      # Variables NON sensibles (domaine, paths, versions...)
        └── vault.yml     # Variables SENSIBLES (chiffrées)
```

#### Variables dans `vault.yml` (exemple)
```yaml
# Chiffré avec: ansible-vault create inventories/production/group_vars/all/vault.yml
sql_root_password: "Tr0ub4dor&3"
sql_password: "W0rdPr3ss$ecure"
wp_admin_password: "Adm1nP@ss"
wp_user_password: "Us3rP@ss"
pma_blowfish_secret: "r4nd0m_l0ng_str1ng_32_chars_min"
letsencrypt_email: "admin@alamizan.42.fr"
```

#### Variables dans `vars.yml` (clair)
```yaml
domain_name: "alamizan.42.fr"
wp_url: "https://alamizan.42.fr"
wp_title: "Mon Blog Cloud-1"
sql_database: "wordpress"
sql_user: "wp_user"
wp_admin_login: "admin"
wp_admin_email: "admin@alamizan.42.fr"
wp_user_login: "editor"
wp_user_email: "editor@alamizan.42.fr"
data_path: "/home/ubuntu/data"
docker_compose_path: "/home/ubuntu/inception"
docker_compose_version: "2.24.0"
```

#### Accès dans les templates/tasks
```jinja2
# Dans template .j2 — variables vault accessibles normalement
MYSQL_ROOT_PASSWORD: "{{ sql_root_password }}"
MYSQL_PASSWORD: "{{ sql_password }}"
```

```yaml
# Dans task — pas de syntaxe spéciale
- name: Create .env file for docker-compose
  template:
    src: dotenv.j2
    dest: "{{ docker_compose_path }}/.env"
    mode: '0600'  # Restreint car contient secrets
  vars:
    # Les variables vault sont déjà dans le scope
```

> ⚠️ **Jamais** de `vault.yml` en clair dans Git. Seule la version chiffrée est committée. Le mot de passe vault = secret partagé hors Git (1Password, Bitwarden, fichier `.vault_pass` ignoré par .gitignore).

---

## C

### Cloud Provider
Fournisseur d'infrastructure cloud (AWS, GCP, Azure, Scaleway, OVH, DigitalOcean, etc.). Fournit des instances VM, stockage, réseau, services managés.
- **Crédits étudiants** : souvent gratuits pour commencer (AWS Academy, GitHub Student Pack, Azure for Students, GCP Free Tier)
- **Responsabilité** : l'étudiant gère les coûts, l'arrêt des ressources, la sécurité

### Cloud-1 : Choix Fournisseur Recommandé
| Rang | Fournisseur | Offre | Pourquoi |
|------|-------------|-------|----------|
| **1** | **Azure for Students** | $100/an, **sans CB**, renouvelable | Meilleur équilibre simplicité/specs/coût 0€ |
| **2** | **Oracle Always Free** | 4 vCPU Arm / 24 GB RAM **à vie** | Specs max, mais Arm + CB requise + dispo aléatoire |
| **3** | **OVHcloud VPS** | €3.50-7/mois (2-8 GB RAM) | Budget prévisible, EU/RGPD, pas de crédit qui expire |

> Voir `docs/COMPARATIF_CLOUD.md` pour analyse complète (8 fournisseurs, decision matrix, checklists).

### Conteneur (Docker)
Unité d'exécution légère, isolée, portable. Un processus = un conteneur (règle Cloud-1).
- **Image** : template immuable (layers read-only)
- **Conteneur** : instance runtime avec layer writable
- **Volume** : persistance données hors cycle de vie conteneur

---

## D

### Docker
Plateforme de conteneurisation. Moteur : `dockerd` + CLI `docker`.
- **Docker Compose** : orchestration multi-conteneurs via `docker-compose.yml` (v2 = plugin `docker compose`)
- **Réseau Docker** : bridge par défaut, isolation inter-conteneurs
- **Registre** : Docker Hub (public), GHCR, registres privés

- Permet d'afficher l'arborescence des couches :
```bash
Cloud_1 tree docker
docker
├── mariadb
├── nginx
├── phpadmin
└── wordpress
```

### Dockerfile
Fichier de recette pour builder une image. Instructions principales :
- `FROM` : image de base (ex: `ubuntu:22.04`)
- `RUN` : commandes à l'image build (layers)
- `COPY/ADD` : fichiers hôte → image
- `EXPOSE` : documentation port (n'ouvre pas le port)
- `ENTRYPOINT` / `CMD` : processus par défaut au démarrage

---

## F

### Firewall (UFW)
**Uncomplicated Firewall** — frontend iptables/nftables sur Ubuntu.
- Règle Cloud-1 : **Seuls ports 22 (SSH), 80 (HTTP), 443 (HTTPS) ouverts**
- `ufw default deny incoming` + `ufw allow 22,80,443/tcp`

---

## I

### Idempotence
Propriété : appliquer une opération plusieurs fois = même résultat qu'une fois.
- **Ansible** : modules idempotents par défaut (`apt`, `copy`, `template`, `systemd`, `ufw`, `docker_container`)
- **Test** : relancer le playbook 2x → 0 changed

### Inception (projet 42)
Projet prérequis : déploiement WordPress + MariaDB + Nginx en Docker Compose **local**. Cloud-1 = version **automatisée, distante, multi-serveurs, sécurisée**.

---

## L

### Let's Encrypt
Autorité de certification gratuite, automatisée, ouverte (ACME). Certificats TLS valides 90j, renouvellement auto via `certbot`.
- **Challenge HTTP-01** : nécessite port 80 accessible
- **Wildcard** : challenge DNS-01 requis

---

## M

### MariaDB
Fork communautaire de MySQL. Base de données relationnelle pour WordPress.
- Port par défaut : **3306**
- Stockage : volume Docker `/var/lib/mysql` (persistance)
- Utilisateur root + utilisateur applicatif (WP) + privilèges limités

---

## N

### Nginx
Serveur web / reverse proxy haute performance.
- **Rôle Cloud-1** : Terminaison TLS (port 443), redirect HTTP→HTTPS (port 80), proxy vers PHP-FPM (WordPress:9000) et phpMyAdmin
- **Config** : `nginx.conf` + vhosts dans `sites-enabled/`
- **PHP-FPM** : FastCGI Process Manager pour PHP (socket TCP port 9000 ou unix socket)

---

## P

### PHP-FPM
Gestionnaire de processus PHP pour Nginx. Écoute sur port **9000** (TCP) ou socket Unix.
- Pool `www` : `pm = dynamic`, `max_children`, `start_servers`, etc.
- User/Groupe : `www-data`

### phpMyAdmin
Interface web d'administration MySQL/MariaDB. Déployé en conteneur séparé (image officielle `phpmyadmin/phpmyadmin`).
- Accès via sous-domaine (`pma.domain.tld`) ou path (`/phpmyadmin`) derrière Nginx
- Config : `config.inc.php` (serveur, auth, blowfish_secret)

### Playbook Ansible
Fichier YAML décrivant une série de **plays** (cible + rôles/tasks) à exécuter sur l'inventaire.
- Ex: `setup-server.yml`, `deploy.yml`, `renew-ssl.yml`

---

## R

### Rôle Ansible
Unité de réutilisation : structure standardisée (`tasks/`, `handlers/`, `templates/`, `files/`, `vars/`, `defaults/`, `meta/`).
- Rôles Cloud-1 : `common`, `docker`, `firewall`, `nginx`, `mariadb`, `wordpress`, `phpmyadmin`, `ssl`

---

## S

### Serveur Cloud (Instance / VM)
Machine virtuelle louée chez un cloud provider. Spécs minimales Cloud-1 : **Ubuntu 22.04 LTS**, SSH daemon, Python3.
- Accès : `ssh ubuntu@<IP>` (ou root selon config)
- Stockage persistant : disque attaché ou volume bind-mounted

### SSL / TLS
**Transport Layer Security** — chiffrement du trafic HTTP → HTTPS.
- Certificat + clé privée (`.crt` + `.key`)
- Terminaison au niveau Nginx (reverse proxy)
- Protocoles : **TLSv1.2**, **TLSv1.3** uniquement

---

## W

### WordPress
CMS PHP/MySQL. Installation via **WP-CLI** (`wp-cli.phar`) en mode non-interactif.
- Config : `wp-config.php` (généré au premier démarrage)
- Tables : `wp_*` en base `wordpress`
- Utilisateurs : admin + user standard (exigence sujet)

### WP-CLI
Outil en ligne de commande pour gérer WordPress (install, config, users, plugins, etc.).
- `--allow-root` : requis dans conteneur (exécution as root)
- `--path` : chemin installation WP (`/var/www/wordpress`)

---

## V

### Volume Docker
Mécanisme de persistance données. Types :
- **Named volume** : géré par Docker (`docker volume create`)
- **Bind mount** : chemin hôte → conteneur (ex: `/home/ubuntu/data/wp:/var/www/wordpress`)
- **Cloud-1** : bind mounts pour sauvegarde facile et inspection hôte

---

*Dernière MAJ : {{ date }} — Prochaines entrées : termes spécifiques aux rôles Ansible, variables Vault, commandes déploiement*