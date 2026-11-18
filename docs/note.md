# Démarches effectuées

## 1. Choix de l’hébergeur

Après quelques recherches, nous avons retenu **Azure** comme solution la plus adaptée à nos besoins, avec un nom de domaine si possible.

Le lancement d’une instance s’étant révélé compliqué, nous avons poursuivi avec les étapes suivantes.

## 2. Téléchargement de l’image Ubuntu 22.04 LTS

Sous Linux, ouvrir un terminal et télécharger l’image Ubuntu Server :

```bash
wget https://releases.ubuntu.com/22.04.5/ubuntu-22.04.5-live-server-amd64.iso
```

Pour vérifier l’intégrité du fichier avec la somme officielle :

```bash
wget https://releases.ubuntu.com/22.04.5/SHA256SUMS
grep ubuntu-22.04.5-live-server-amd64.iso SHA256SUMS | sha256sum --check
```

## 3. Configuration et installation

1. Démarrer la machine virtuelle dans **VirtualBox** avec l’ISO `ubuntu-22.04.5-live-server-amd64.iso`.
2. Choisir la langue, le clavier et les options réseau proposées par l’installateur.
3. Configurer le stockage en utilisant le disque virtuel de la VM. **Attention : son contenu sera effacé.**
4. Créer un profil utilisateur et noter le nom d’utilisateur ainsi que le mot de passe : ils seront nécessaires pour se connecter.
5. À l’étape SSH, cocher **« Installer le serveur OpenSSH »** à l’aide de la barre d’espace, puis continuer.
6. À l’écran des snaps serveur, ne rien sélectionner et choisir **« Terminé »**.
7. Attendre la fin de l’installation, puis redémarrer la VM.

## 4. Connexion SSH

### Trouver l’adresse IP de la VM

Dans un terminal de la VM, exécuter :

```bash
ip a
```

### Générer une clé SSH

Sur la machine cliente, créer le répertoire `.ssh` et générer une clé :

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
ssh-keygen -t ed25519 -f ~/.ssh/cloud1_vm
```

### Copier la clé publique sur la VM

Configurer l’accès à la VM avec la clé publique :

```bash
ssh-copy-id -i ~/.ssh/cloud1_vm.pub -p 2222 bob@127.0.0.1
```

### Se connecter à la VM

Depuis un terminal de la machine cliente, exécuter :

```bash
ssh -i ~/.ssh/cloud1_vm -p 2222 bob@127.0.0.1
```

Lors de la première connexion, répondre `yes` à la demande de confirmation, puis saisir le mot de passe Ubuntu.

## 5. Ressources Ansible

### Documentation et guides

- [Installer Ansible et déployer une application avec Docker Compose](https://colinfo.fr/installation-dansible-et-deploiement-de-docker-compose/)
- [Déployer Docker Compose avec Ansible et GitHub Actions](https://medium.com/swlh/deploying-docker-compose-applications-with-ansible-and-github-actions-7f1740392507) — exemple d’utilisation du module `template` et d’Ansible Vault pour gérer les variables sensibles.
- [Documentation du module `community.docker.docker_compose_v2`](https://docs.ansible.com/projects/ansible/latest/collections/community/docker/docker_compose_v2_module.html)

### Exemple minimal de playbook

```yaml
- name: Déployer une application avec Docker Compose
  hosts: app_servers
  become: true

  tasks:
    - name: Créer le répertoire du projet
      ansible.builtin.file:
        path: /opt/mon-app
        state: directory
        mode: "0755"

    - name: Copier le fichier Compose
      ansible.builtin.copy:
        src: compose.yml
        dest: /opt/mon-app/compose.yml
        mode: "0644"

    - name: Démarrer la stack Docker Compose
      community.docker.docker_compose_v2:
        project_src: /opt/mon-app
        state: present
        pull: policy
```

> **Prérequis :** la collection `community.docker` doit être installée sur la machine de contrôle, et le plugin Docker Compose v2 doit être disponible sur l’hôte cible.

### Comprendre le playbook

#### 1. Définir le contexte d’exécution

```yaml
- name: Déployer une application avec Docker Compose
  hosts: app_servers
  become: true
```

- `name` décrit le playbook. Ansible l’affiche pendant l’exécution.
- `hosts` désigne le groupe de machines ciblé, défini dans l’inventaire, par exemple `inventory.ini` ou `hosts.yml`.
- `become: true` exécute les tâches avec des privilèges élevés. C’est nécessaire ici pour écrire dans `/opt` et piloter Docker.

#### 2. Créer le répertoire du projet

```yaml
- name: Créer le répertoire du projet
  ansible.builtin.file:
    path: /opt/mon-app
    state: directory
    mode: "0755"
```

- `ansible.builtin.file` gère les fichiers et répertoires sur l’hôte cible.
- `path` indique le chemin à créer.
- `state: directory` garantit que le chemin existe en tant que répertoire.
- `mode: "0755"` accorde les droits de lecture, écriture et exécution au propriétaire, et les droits de lecture et d’exécution aux autres utilisateurs.

#### 3. Copier le fichier Compose

```yaml
- name: Copier le fichier Compose
  ansible.builtin.copy:
    src: compose.yml
    dest: /opt/mon-app/compose.yml
    mode: "0644"
```

- `ansible.builtin.copy` transfère un fichier depuis la machine de contrôle vers l’hôte cible.
- `src` désigne le fichier source sur la machine de contrôle. Pour un projet structuré, placez-le de préférence dans un répertoire `files/`.
- `dest` indique son emplacement sur l’hôte cible.
- `mode: "0644"` autorise le propriétaire à modifier le fichier et les autres utilisateurs à le lire.

Si le fichier Compose contient des variables à interpoler, utilisez plutôt `ansible.builtin.template`. Les valeurs sensibles devraient être protégées avec Ansible Vault.

#### 4. Démarrer les services

```yaml
- name: Démarrer la stack Docker Compose
  community.docker.docker_compose_v2:
    project_src: /opt/mon-app
    state: present
    pull: policy
```

- `community.docker.docker_compose_v2` pilote Docker Compose v2.
- `project_src` désigne le répertoire contenant le fichier Compose.
- `state: present` démarre le projet et crée ou met à jour les services selon la configuration. Les conteneurs sont recréés si nécessaire.
- `pull: policy` laisse Docker Compose appliquer la stratégie `pull_policy` définie pour chaque service dans le fichier Compose. ([docs.ansible.com](https://docs.ansible.com/projects/ansible/latest/collections/community/docker/docker_compose_v2_module.html?utm_source=openai))
