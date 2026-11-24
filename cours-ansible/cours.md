# Cours Ansible — Premiers pas

Ce dépôt contient les exercices réalisés pour découvrir Ansible sur la machine locale. Nous avons vu les commandes ad hoc, les playbooks, les variables, les facts, les modèles Jinja2, les handlers, la gestion des erreurs, les tags et les rôles.

En gros, voilà le truc expliqué simplement, sans jargon inutile.

---

## I. Comprendre Ansible (Vulgarisation & Concepts)

### C'est quoi Ansible, pour de vrai ?

Imagine que tu es assis devant ton PC. En face de toi, tu as **une machine virtuelle vide** (sur Scaleway, le Cloud, ou autre).

* **À l'ancienne (en Bash) :**  
  Tu te connectes en SSH, tu tapes `sudo apt update`, puis `sudo apt install docker`, tu crées les dossiers à la main, tu copies tes fichiers un par un, tu lances `docker compose up`, etc. Si tu as 5 serveurs, tu dois te taper tout ça 5 fois. Et si ton script plante au milieu, t'es coincé.
* **Avec Ansible :**  
  Tu écris une **"liste de courses"** dans un fichier (le *playbook*).  
  Tu lances **une seule commande** depuis ton PC d'école :
  ```bash
  ansible-playbook -i inventories/hosts.ini playbook.yml
  ```
  Ansible se connecte en SSH à ta place, il fait tout le boulot tout seul, et quand il a fini, ton site est en ligne.

### Les 3 principes

1. **Il n'installe rien sur le serveur distant** : Pas de logiciel lourd. Ansible a juste besoin d'une connexion **SSH** et de **Python** sur la machine distante pour faire son travail.
2. **L'Idempotence** :  
   Ça veut juste dire : **« Il ne refait pas ce qui est déjà fait »**.  
   Si tu relances Ansible :
   * Docker est déjà installé ? Il l'ignore (il affiche `ok` en vert).
   * Ton dossier existe déjà ? Il ne le recrée pas.
   * Il n'applique que ce qui a changé. Rien ne casse si tu relances la commande 10 fois.
3. **C'est déclaratif** :  
   Tu ne lui dis pas *« tape la commande pour installer Docker »*.  
   Tu lui dis : *« Je veux que Docker soit installé »*. C'est Ansible qui se débrouille avec les commandes du système pour que ce soit fait.

### Dans le projet Cloud-1, il fait quoi concrètement ?

Quand on va lancer le playbook, Ansible va découper le travail en **3 rôles** (3 étapes) :

1. **Rôle 1 : Le videur de boîte de nuit (Firewall / UFW)**  
   Il bloque tous les ports de ta machine Scaleway, sauf **22** (pour que tu puisses continuer à te connecter en SSH), **80** (HTTP) et **443** (HTTPS pour ton site).
2. **Rôle 2 : Le mécano (Docker)**  
   Il installe Docker et le plugin Docker Compose tout neufs sur la machine distante.
3. **Rôle 3 : Le livreur (Inception / App)**  
   * Il prend ton dossier `docker/` qui est sur ton PC d'école et l'envoie sur le serveur.
   * Il injecte tes mots de passe proprement dans un fichier `.env`.
   * Il lance la commande magique : `docker compose up -d --build`.

**Résultat :** En 2 minutes chrono, ton WordPress / Nginx / MariaDB tourne sur Internet, sans que tu aies tapé une seule commande directement sur le serveur.

---

## II. Fiche de synthèse technique

### 1. Les composants d’Ansible : rôles et interactions

Dans l'écosystème Ansible, la logique d'automatisation est découpée en quatre concepts distincts :

#### A. Les `tasks` (Tâches)
* **Définition :** La séquence d'instructions exécutée de manière séquentielle, du haut vers le bas.
* **Fonctionnement :** Chaque tâche appelle un *module* Ansible pour garantir un état souhaité (*state: present, started, etc.*). Si l'état est déjà atteint, la tâche renvoie le statut `ok` ; s'il y a eu action, elle renvoie `changed`.

#### B. Les `templates` (Modèles de configuration)
* **Définition :** Fichiers textes traités par le moteur de rendu **Jinja2** (extension `.j2`).
* **Fonctionnement :** Ils permettent d'injecter dynamiquement des variables (mots de passe, adresses IP, noms de domaine) dans des fichiers de configuration statiques (`.env`, `nginx.conf`, etc.) au moment de leur déploiement sur la machine cible.

#### C. Les `handlers` (Gestionnaires d'événements)
* **Définition :** Tâches conditionnelles passives exécutées uniquement en fin de playbook.
* **Fonctionnement :**
  * Un handler n'est exécuté que s'il est notifié via la directive `notify:` par une tâche ayant renvoyé l'état `changed`.
  * Même si 5 tâches notifient le même handler, il ne s'exécutera qu'une seule fois à la fin du flux d'exécution.
  * Cas d'usage type : redémarrer un service système (`systemctl restart docker`) ou recharger une configuration de proxy inverse.

#### D. Les `vars` (Variables)
* **Définition :** Données stockées de façon centralisée (`vars.yml`, `group_vars/`).
* **Fonctionnement :** Séparent le code (les playbooks) de la configuration (noms d'utilisateurs, chemins, secrets), évitant d'écrire des valeurs en dur.

---

### 2. Analyse détaillée des modules de base

Tous les modules du cœur d'Ansible appartiennent à la collection `ansible.builtin`. Voici l'analyse des modules les plus fréquents :

#### `ansible.builtin.debug`
**Rôle :** Affiche des informations ou la valeur d'une variable dans la console standard lors de l'exécution.
```yaml
- name: Afficher l'adresse IP de la machine cible
  ansible.builtin.debug:
    var: ansible_default_ipv4.address
```
* **`msg`** : Affiche une chaîne de caractères brute ou formatée.
* **`var`** : Affiche la structure d'une variable spécifique.

#### `ansible.builtin.file`
**Rôle :** Gestion du système de fichiers (fichiers, répertoires, liens symboliques) et de leurs permissions.
```yaml
- name: Creer le repertoire de destination
  ansible.builtin.file:
    path: /home/ubuntu/app
    state: directory
    owner: ubuntu
    group: ubuntu
    mode: '0755'
```
* **`path`** : Chemin absolu de la cible sur le serveur distant.
* **`state`** : Type d'élément attendu :
  * `directory` : Répertoire (équivalent de `mkdir -p`).
  * `absent` : Supprime le fichier ou le dossier (équivalent de `rm -rf`).
  * `touch` : Crée un fichier vide s'il n'existe pas.
* **`mode`** : Permissions POSIX en notation octale (ex: `'0755'`, `'0644'`).
* **`owner` / `group`** : Propriétaire et groupe système assignés à la ressource.

#### `ansible.builtin.copy`
**Rôle :** Transfert de fichiers ou de répertoires statiques depuis la machine locale vers la machine distante (sans traitement de variables).
```yaml
- name: Deployer les sources Docker sur l'hote
  ansible.builtin.copy:
    src: ../docker/
    dest: /home/ubuntu/app/
    mode: '0755'
```
* **`src`** : Chemin source sur la machine qui exécute Ansible (local).  
  *(Attention : un `/` à la fin copie le contenu du dossier, sans `/` il copie le dossier lui-même).*
* **`dest`** : Chemin de destination sur le serveur distant.
* **`mode`** : Permissions appliquées aux fichiers copiés.

#### `ansible.builtin.template`
**Rôle :** Traitement d'un gabarit Jinja2 en local, substitution des variables, puis transfert du fichier généré sur la machine distante.
```yaml
- name: Generer le fichier d'environnement .env
  ansible.builtin.template:
    src: env.j2
    dest: /home/ubuntu/app/.env
    mode: '0600'
  notify: Redemarrer la stack Docker
```
* **`src`** : Fichier source local contenant la syntaxe Jinja2 (ex: `{{ db_password }}`).
* **`dest`** : Fichier final généré sur la machine cible.
* **`mode: '0600'`** : Droits stricts en lecture/écriture réservés au seul propriétaire (recommandé pour les secrets).
* **`notify`** : Émet un signal vers le handler nommé uniquement si le contenu du fichier généré diffère de celui déjà présent sur le serveur.

#### `ansible.builtin.command`
**Rôle :** Exécute une commande binaire directement sur l'hôte distant, sans passer par un interpréteur shell (plus rapide et plus sûr qu'`ansible.builtin.shell`).
```yaml
- name: Executer la stack applicative via Docker Compose
  ansible.builtin.command:
    cmd: docker compose up -d --build
    chdir: /home/ubuntu/app
```
* **`cmd`** : La commande exacte à exécuter.
* **`chdir`** (*change directory*) : Répertoire de travail dans lequel la commande doit être exécutée avant son lancement.

---

### 3. Synthèse du flux d'exécution standard

1. **Préparation :** Définition de l'environnement avec `ansible.builtin.file` pour garantir l'existence de l'arborescence.
2. **Déploiement statique :** Synchronisation des fichiers de code ou Dockerfiles via `ansible.builtin.copy`.
3. **Déploiement dynamique :** Injection des variables d'environnement via `ansible.builtin.template`.
4. **Déclenchement :** Si le template génère un changement, la directive `notify` déclenche le `handler`.
5. **Finalisation :** Le `handler` exécute la commande de reload/restart (`ansible.builtin.command` ou `ansible.builtin.service`) une fois l'ensemble des tâches validé.

---

## III. Environnement et structure du projet

### Prérequis

- Ubuntu
- Ansible installé
- Un terminal ouvert dans le dossier `cours-ansible`

### Organisation du projet

```text
cours-ansible/
├── ansible.cfg
├── inventory.ini
├── cours.md
├── premier-playbook.yml
├── premier-playbook copy.yml
├── group_vars/
│   └── all.yml
├── roles/
│   └── bienvenue/
│       ├── handlers/
│       │   └── main.yml
│       ├── tasks/
│       │   └── main.yml
│       └── templates/
│           └── bienvenue.txt.j2
├── templates/
│   └── bienvenue.txt.j2
└── vars.yml
```

- `ansible.cfg` : configuration du projet et chemin de l’inventaire par défaut.
- `inventory.ini` : indique à Ansible quelles machines gérer.
- `group_vars/all.yml` : variables applicables à tous les hôtes de l’inventaire.
- `premier-playbook.yml` : playbook actif, qui appelle le rôle `bienvenue`.
- `premier-playbook copy.yml` : ancienne copie du playbook, conservée comme archive.
- `roles/bienvenue/tasks/main.yml` : tâches du rôle.
- `roles/bienvenue/handlers/main.yml` : handler du rôle.
- `roles/bienvenue/templates/bienvenue.txt.j2` : modèle utilisé par le rôle.
- `templates/bienvenue.txt.j2` : ancien emplacement du modèle, conservé dans le projet.
- `vars.yml` : ancien fichier de variables utilisé pendant les exercices. Les variables sont maintenant chargées depuis `group_vars/all.yml`.

---

## IV. Exercices pratiques pas à pas

### 1. Tester la connexion à l’hôte local

La commande suivante demande à Ansible d’exécuter son module `ping` sur l’hôte `local` défini dans l’inventaire :

```bash
ansible local -i inventory.ini -m ansible.builtin.ping
```

Résultat attendu :

```text
localhost | SUCCESS => {
    ...
    "ping": "pong"
}
```

Le module Ansible `ping` vérifie que la connexion et l’exécution fonctionnent. Il ne s’agit pas d’une commande réseau comme le ping ICMP.

### 2. Exécuter une commande sur la machine

La commande `hostname` affiche le nom de la machine :

```bash
ansible local -i inventory.ini -m ansible.builtin.command -a "hostname"
```

Exemple de résultat :

```text
localhost | CHANGED | rc=0 >>
1C3.42angouleme.fr
```

- `rc=0` signifie que la commande s’est terminée sans erreur.
- `CHANGED` peut apparaître parce que le module `command` ne sait pas toujours si la commande a modifié la machine. Pour `hostname`, aucune modification n’a été effectuée.

### 3. Configurer Ansible pour le projet

Le fichier `ansible.cfg` se trouve à la racine du projet :

```ini
[defaults]
inventory = ./inventory.ini
```

Cette configuration indique à Ansible d’utiliser `inventory.ini` par défaut. L’inventaire contient notamment :

```ini
[local]
localhost ansible_connection=local
```

Vérifier la version et le fichier de configuration chargé :

```bash
ansible --version
```

La ligne `config file` doit indiquer le chemin vers `cours-ansible/ansible.cfg`.

Pour afficher les paramètres qui diffèrent des valeurs par défaut :

```bash
ansible-config dump --only-changed
```

Grâce à l’inventaire défini dans `ansible.cfg`, il est possible de lancer le playbook sans préciser `-i inventory.ini`.

### 4. Organiser les variables avec `group_vars`

Le fichier `group_vars/all.yml` contient les variables utilisées dans le playbook :

```yaml
---
message_accueil: "Bonjour depuis group_vars/all.yml !"
affichage_bonus: true
```

Le fichier `all.yml` s’applique au groupe spécial `all`, c’est-à-dire à tous les hôtes de l’inventaire. Les variables peuvent ensuite être utilisées dans un playbook, par exemple avec `{{ message_accueil }}`.

Il n’est pas nécessaire d’ajouter `vars_files` au playbook pour charger les variables de `group_vars/all.yml`.

### 5. Le playbook actif

Le fichier `premier-playbook.yml` appelle maintenant le rôle `bienvenue`. Les tâches de fichiers et leur handler sont donc placés dans le rôle plutôt que directement dans ce playbook.

Voici la structure générale du playbook actif :

```yaml
---
- name: Mon premier playbook
  hosts: local
  connection: local
  gather_facts: true

  roles:
    - bienvenue

  tasks:
    - name: Afficher le système d'exploitation
      ansible.builtin.debug:
        var: ansible_facts.distribution

    - name: Afficher la version du système
      ansible.builtin.debug:
        var: ansible_facts.distribution_version

    - name: Afficher le nom de la machine vu par Ansible
      ansible.builtin.debug:
        var: ansible_facts.hostname

    - name: Afficher le message bonus si activé
      ansible.builtin.debug:
        msg: "La condition est vraie : le bonus est activé"
      when: affichage_bonus

    - name: Afficher un message
      ansible.builtin.debug:
        msg: "{{ message_accueil }}"

    - name: Afficher le nom de la machine
      ansible.builtin.command: hostname
      register: resultat_hostname
      changed_when: false

    - name: Montrer le résultat
      ansible.builtin.debug:
        var: resultat_hostname.stdout

    - name: Afficher plusieurs éléments
      ansible.builtin.debug:
        msg: "Élément : {{ item }}"
      loop:
        - pomme
        - poire
        - banane

    - name: Démontrer la gestion des erreurs
      block:
        - name: Simuler une opération qui échoue
          ansible.builtin.command: /bin/false

        - name: Cette tâche ne sera pas exécutée
          ansible.builtin.debug:
            msg: "Cette tâche est ignorée après l'échec"

      rescue:
        - name: Récupérer l'erreur
          ansible.builtin.debug:
            msg: "L'opération a échoué, mais le bloc rescue a pris le relais."

      always:
        - name: Exécuter quoi qu'il arrive
          ansible.builtin.debug:
            msg: "Le bloc always s'exécute dans tous les cas."
```

Pour lancer le playbook :

```bash
ansible-playbook premier-playbook.yml
```

### 6. Organiser les tâches avec un rôle

Un **rôle** regroupe des éléments réutilisables : tâches, handlers, modèles, variables et autres fichiers. Dans notre projet, le rôle s’appelle `bienvenue`.

#### Tâches du rôle

Le fichier `roles/bienvenue/tasks/main.yml` contient les tâches qui créent les fichiers :

```yaml
---
- name: Créer un fichier de bienvenue
  ansible.builtin.copy:
    content: "Bonjour ! Fichier mis à jour par Ansible.\n"
    dest: /tmp/bienvenue-ansible.txt
    mode: '0644'
  notify: Confirmer la mise a jour
  tags:
    - fichier

- name: Générer un fichier depuis un modèle Jinja2
  ansible.builtin.template:
    src: bienvenue.txt.j2
    dest: /tmp/bienvenue-modele.txt
    mode: '0644'
  tags:
    - modele
```

#### Handler du rôle

Le fichier `roles/bienvenue/handlers/main.yml` contient le handler :

```yaml
---
- name: Confirmer la mise a jour
  ansible.builtin.debug:
    msg: "Le fichier a changé : le handler a été déclenché."
```

Le rôle trouve automatiquement ses tâches dans `tasks/main.yml`, ses handlers dans `handlers/main.yml` et ses modèles dans `templates/`.

Dans le playbook, le rôle est appelé avec :

```yaml
roles:
  - bienvenue
```

Dans la sortie d’Ansible, le préfixe `bienvenue :` indique qu’une tâche appartient à ce rôle.

### 7. Comprendre les éléments du playbook

- `name` donne un nom descriptif au play ou à la tâche.
- `hosts: local` cible l’hôte ou le groupe `local` de l’inventaire.
- `connection: local` indique qu’Ansible travaille directement sur la machine locale.
- `gather_facts: true` demande à Ansible de collecter des informations sur la machine au début du play.
- `roles` indique les rôles à exécuter.
- `tasks` contient les tâches définies directement dans le playbook.
- `ansible.builtin.debug` affiche un message ou une valeur.
- `when` exécute une tâche uniquement si la condition est vraie.
- `register` enregistre le résultat d’une tâche dans une variable.
- `resultat_hostname.stdout` contient la sortie texte de la commande.
- `changed_when: false` indique à Ansible que la tâche n’a pas modifié la machine.
- `loop` répète une tâche pour chaque élément de la liste.
- Dans une boucle, `item` représente l’élément traité.

### 8. Collecter et afficher les facts

Avec `gather_facts: true`, Ansible collecte des informations sur l’hôte au début du play. Ces informations sont accessibles dans la variable `ansible_facts`.

Dans notre résultat, Ansible a notamment affiché :

```text
ansible_facts.distribution: Ubuntu
ansible_facts.distribution_version: 22.04
ansible_facts.hostname: 1C3
```

Les facts sont des informations détectées par Ansible sur la machine. Ils sont différents des variables personnalisées définies dans `group_vars/all.yml`.

### 9. Créer un fichier avec `copy`

Le module `ansible.builtin.copy` crée ou met à jour un fichier à partir du contenu indiqué dans la tâche du rôle :

```yaml
- name: Créer un fichier de bienvenue
  ansible.builtin.copy:
    content: "Bonjour ! Fichier mis à jour par Ansible.\n"
    dest: /tmp/bienvenue-ansible.txt
    mode: '0644'
  notify: Confirmer la mise a jour
  tags:
    - fichier
```

Ansible est **idempotent** : si le fichier existe déjà avec le bon contenu et les bonnes permissions, la tâche ne le modifie pas et affiche `ok`. Si le contenu ou les permissions doivent changer, elle affiche `changed`.

### 10. Utiliser un modèle Jinja2

Le module `ansible.builtin.template` crée un fichier à partir d’un modèle Jinja2. Le modèle du rôle se trouve ici :

```text
roles/bienvenue/templates/bienvenue.txt.j2
```

Par exemple, il peut contenir :

```jinja2
Bienvenue sur {{ inventory_hostname }} !
```

`inventory_hostname` est une variable fournie par Ansible. Elle correspond au nom de l’hôte tel qu’il apparaît dans l’inventaire. Ce nom n’est pas nécessairement le nom retourné par la commande `hostname`.

Le résultat est écrit dans :

```text
/tmp/bienvenue-modele.txt
```

### 11. Réagir à un changement avec un handler

Un **handler** est une tâche spéciale déclenchée par une autre tâche qui a signalé un changement. La directive `notify` associe la tâche `copy` au handler :

```yaml
notify: Confirmer la mise a jour
```

Le handler du rôle affiche un message. Il s’exécute si la tâche `copy` a réellement modifié le fichier. Si la tâche affiche `ok`, le handler ne se déclenche pas.

### 12. Sélectionner des tâches avec les tags

Les tags permettent de sélectionner certaines tâches. Dans le rôle `bienvenue`, la tâche `template` porte le tag `modele` et la tâche `copy` porte le tag `fichier`.

Afficher la liste des tâches et des tags :

```bash
ansible-playbook premier-playbook.yml --list-tasks --list-tags
```

Exécuter uniquement la tâche du modèle :

```bash
ansible-playbook premier-playbook.yml --tags modele
```

Exécuter uniquement la tâche de création du fichier :

```bash
ansible-playbook premier-playbook.yml --tags fichier
```

Exécuter les tâches portant l’un ou l’autre tag :

```bash
ansible-playbook premier-playbook.yml --tags "modele,fichier"
```

Exécuter toutes les tâches sauf celles portant le tag `modele` :

```bash
ansible-playbook premier-playbook.yml --skip-tags modele
```

La collecte des facts peut également apparaître lors d’une exécution avec `--tags`, car elle utilise par défaut le tag spécial `always`.

### 13. Gérer une erreur avec `block`, `rescue` et `always`

Les blocs permettent d’organiser des tâches et de gérer certains échecs :

- `block` contient les tâches à exécuter.
- `rescue` s’exécute si une tâche de `block` échoue.
- `always` s’exécute après le bloc, qu’il ait réussi ou échoué.

Dans notre exercice, `/bin/false` échoue volontairement et renvoie le code `rc=1`. La tâche suivante dans `block` est alors ignorée. `rescue` prend le relais, puis `always` s’exécute.

> `/bin/false` sert uniquement à démontrer la gestion des erreurs. Ne l’utilise pas comme commande dans un playbook destiné à effectuer un vrai travail.

Lorsque les tâches de `rescue` réussissent, Ansible considère généralement l’erreur comme récupérée et peut poursuivre le playbook.

### 14. Tester la syntaxe et lire le récapitulatif

Vérifier la syntaxe du playbook sans exécuter ses tâches :

```bash
ansible-playbook premier-playbook.yml --syntax-check
```

La sortie suivante indique que le contrôle de syntaxe a réussi :

```text
playbook: premier-playbook.yml
```

À la fin d’une exécution, Ansible affiche un récapitulatif, par exemple :

```text
localhost : ok=14 changed=1 unreachable=0 failed=0 skipped=0 rescued=1 ignored=0
```

- `ok` : tâches exécutées sans erreur.
- `changed` : tâches ayant signalé une modification.
- `unreachable` : hôtes qu’Ansible n’a pas pu joindre.
- `failed` : tâches en échec non récupérées.
- `skipped` : tâches ignorées.
- `rescued` : échecs récupérés par un bloc `rescue`.
- `ignored` : échecs ignorés avec une directive comme `ignore_errors`.

Dans notre résultat, `/bin/false` échoue, puis `rescue` récupère l’erreur. Le récapitulatif affiche donc `rescued=1` et `failed=0`.

### 15. Vérifier l’idempotence et le déclenchement du handler

Pour vérifier le comportement du playbook, exécuter deux fois la même commande :

```bash
ansible-playbook premier-playbook.yml
ansible-playbook premier-playbook.yml
```

Lors de ces deux exécutions, les tâches `copy` et `template` ont affiché `ok`. Cela signifie que les fichiers existaient déjà avec le contenu et les permissions attendus : Ansible n’a rien eu à modifier.

Le handler **« Confirmer la mise a jour »** ne s’est donc pas déclenché. C’est le comportement attendu : une tâche ne déclenche son handler que si elle signale un changement (`changed`).

Pour tester le handler, modifier temporairement le contenu défini par `ansible.builtin.copy` dans `roles/bienvenue/tasks/main.yml`, puis relancer le playbook :

```bash
ansible-playbook premier-playbook.yml
```

La tâche `copy` devrait alors afficher `changed`, et le handler devrait s’exécuter. Après le test, remettre le contenu d’origine et relancer le playbook : la tâche devrait de nouveau afficher `ok`.

Dans la sortie observée, le playbook a également exécuté le bloc de gestion d’erreur : `/bin/false` a échoué, `rescue` a récupéré l’échec et `always` s’est exécuté. Le récapitulatif indiquait `rescued=1` et `failed=0`, car l’échec a été récupéré.

---

## V. Notes & Aide-mémoire

### À propos de l’avertissement Python

Ansible peut afficher un avertissement indiquant qu’il a détecté Python à `/usr/bin/python3.10`. Dans notre exercice, cet avertissement n’a pas empêché l’exécution : le playbook s’est terminé correctement. Ansible signale simplement que la découverte de l’interpréteur pourrait changer si un autre interpréteur est installé.

### Commandes récapitulatives

```bash
# Vérifier la version et le fichier de configuration utilisé
ansible --version

# Afficher les paramètres Ansible modifiés
ansible-config dump --only-changed

# Tester l’hôte local
ansible local -i inventory.ini -m ansible.builtin.ping

# Exécuter la commande hostname
ansible local -i inventory.ini -m ansible.builtin.command -a "hostname"

# Vérifier la syntaxe du playbook
ansible-playbook premier-playbook.yml --syntax-check

# Lister les tâches et les tags
ansible-playbook premier-playbook.yml --list-tasks --list-tags

# Exécuter uniquement une tâche du rôle par tag
ansible-playbook premier-playbook.yml --tags modele
ansible-playbook premier-playbook.yml --tags fichier

# Exécuter le playbook complet
ansible-playbook premier-playbook.yml
```