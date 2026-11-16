Voici la version corrigée et mise à jour avec ce que tu as ajouté : `ansible.cfg`, `group_vars/all.yml` et la collecte des facts. Copie-colle le contenu entre les quatre accents graves dans ton fichier Markdown.

````markdown
# Cours Ansible — Premiers pas

Ce dépôt contient les exercices réalisés pour découvrir Ansible en exécutant des commandes sur la machine locale. Nous avons vu les commandes ad hoc, les playbooks, les variables, les facts, les modèles Jinja2, les handlers, la gestion des erreurs et la configuration du projet.

## Prérequis

- Ubuntu
- Ansible installé
- Un terminal ouvert dans le dossier `cours-ansible`

## Organisation du projet

```text
cours-ansible/
├── ansible.cfg
├── inventory.ini
├── premier-playbook.yml
├── group_vars/
│   └── all.yml
└── templates/
    └── bienvenue.txt.j2
```

- `ansible.cfg` : contient les paramètres Ansible du projet.
- `inventory.ini` : indique à Ansible quelles machines gérer.
- `group_vars/all.yml` : contient des variables applicables à tous les hôtes de l’inventaire.
- `premier-playbook.yml` : contient les tâches à exécuter.
- `templates/bienvenue.txt.j2` : modèle Jinja2 utilisé pour générer un fichier.

## 1. Tester la connexion à l’hôte local

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

## 2. Exécuter une commande sur la machine

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
- `CHANGED` peut apparaître parce que le module `command` ne sait pas toujours si la commande a modifié la machine. Pour `hostname`, il n’y a pas eu de modification.

## 3. Configurer Ansible pour le projet

Le fichier `ansible.cfg` se trouve à la racine du projet. Il indique à Ansible d’utiliser `inventory.ini` par défaut :

```ini
[defaults]
inventory = ./inventory.ini
```

Nous avons vérifié la configuration avec :

```bash
ansible --version
```

La ligne `config file` indique le fichier de configuration chargé. Avant la création de `ansible.cfg`, elle affichait :

```text
config file = None
```

Après sa création, elle doit indiquer le chemin vers `cours-ansible/ansible.cfg`.

Pour afficher les paramètres qui diffèrent des valeurs par défaut :

```bash
ansible-config dump --only-changed
```

Grâce à l’inventaire défini dans `ansible.cfg`, il est possible de lancer le playbook sans préciser `-i inventory.ini` :

```bash
ansible-playbook premier-playbook.yml
```

## 4. Organiser les variables avec `group_vars`

Le fichier `group_vars/all.yml` contient les variables utilisées dans le playbook :

```yaml
---
message_accueil: "Bonjour depuis group_vars/all.yml !"
affichage_bonus: true
```

Le dossier `group_vars` permet de charger des variables associées aux groupes de l’inventaire. Le fichier `all.yml` s’applique au groupe spécial `all`, c’est-à-dire à tous les hôtes de l’inventaire.

Les variables sont ensuite utilisables dans le playbook, par exemple avec `{{ message_accueil }}`. Il n’est pas nécessaire d’ajouter `vars_files` dans ce playbook pour charger ce fichier `group_vars/all.yml`.

## 5. Exécuter un playbook

Un **playbook** est un fichier YAML qui décrit les machines ciblées et les tâches à exécuter.

Voici le playbook utilisé pendant les exercices :

```yaml
---
- name: Mon premier playbook
  hosts: local
  connection: local
  gather_facts: true

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

    - name: Créer un fichier de bienvenue
      ansible.builtin.copy:
        content: "Bonjour ! Ce fichier a été créé par Ansible.\n"
        dest: /tmp/bienvenue-ansible.txt
        mode: '0644'
      notify: Confirmer la mise a jour

    - name: Générer un fichier depuis un modèle Jinja2
      ansible.builtin.template:
        src: templates/bienvenue.txt.j2
        dest: /tmp/bienvenue-modele.txt
        mode: '0644'

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

  handlers:
    - name: Confirmer la mise a jour
      ansible.builtin.debug:
        msg: "Le fichier a changé : le handler a été déclenché."
```

Pour lancer le playbook avec la configuration du projet :

```bash
ansible-playbook premier-playbook.yml
```

## 6. Comprendre les éléments du playbook

- `name` donne un nom descriptif au play ou à la tâche.
- `hosts: local` cible le groupe ou l’hôte `local` de l’inventaire.
- `connection: local` indique qu’Ansible travaille directement sur la machine locale.
- `gather_facts: true` demande à Ansible de collecter des informations sur la machine au début du play.
- `tasks` contient la liste des tâches à exécuter.
- `ansible.builtin.debug` affiche un message ou une valeur.
- `when` exécute une tâche uniquement si la condition est vraie. Ici, le message bonus s’affiche si `affichage_bonus` est vrai.
- `register` enregistre le résultat d’une tâche dans une variable.
- `resultat_hostname.stdout` contient la sortie texte de la commande.
- `changed_when: false` indique à Ansible que la tâche n’a pas modifié la machine.
- `loop` répète une tâche pour chaque élément de la liste.
- Dans une boucle, `item` représente l’élément traité.

## 7. Collecter et afficher les facts

Avec `gather_facts: true`, Ansible collecte des informations sur l’hôte au début du play. Ces informations sont accessibles dans la variable `ansible_facts`.

Dans notre résultat, Ansible a notamment affiché :

```text
ansible_facts.distribution: Ubuntu
ansible_facts.distribution_version: 22.04
ansible_facts.hostname: 1C3
```

Les facts sont des informations détectées par Ansible sur la machine. Ils sont différents des variables personnalisées que nous avons définies dans `group_vars/all.yml`.

## 8. Créer un fichier avec `copy`

Le module `ansible.builtin.copy` crée ou met à jour un fichier à partir d’un contenu indiqué dans le playbook :

```yaml
- name: Créer un fichier de bienvenue
  ansible.builtin.copy:
    content: "Bonjour ! Ce fichier a été créé par Ansible.\n"
    dest: /tmp/bienvenue-ansible.txt
    mode: '0644'
```

Ansible est **idempotent** : si le fichier existe déjà avec le bon contenu et les bonnes permissions, il ne le modifie pas et la tâche affiche `ok`. Si le contenu ou les permissions doivent changer, la tâche affiche `changed`.

## 9. Utiliser un modèle Jinja2

Le module `ansible.builtin.template` crée un fichier à partir d’un modèle. Le fichier source se trouve ici :

```text
templates/bienvenue.txt.j2
```

Par exemple, le modèle peut contenir :

```jinja2
Bienvenue sur {{ inventory_hostname }} !
```

La variable spéciale `inventory_hostname` est fournie automatiquement par Ansible. Elle correspond au nom de l’hôte tel qu’il apparaît dans l’inventaire. Ce nom n’est pas nécessairement le nom réel de la machine retourné par la commande `hostname`.

Le résultat est écrit dans :

```text
/tmp/bienvenue-modele.txt
```

## 10. Réagir à un changement avec un handler

Un **handler** est une tâche spéciale déclenchée par une tâche qui a signalé un changement. La directive `notify` associe une tâche à un handler :

```yaml
notify: Confirmer la mise a jour
```

Dans cet exercice, le handler affiche un message. Il s’exécute à la fin du play seulement si la tâche `copy` a réellement modifié le fichier.

Si la tâche affiche `ok`, le handler ne se déclenche pas. Pour le tester, change temporairement le contenu de `content`, puis relance le playbook.

## 11. Gérer une erreur avec `block`, `rescue` et `always`

Les blocs permettent d’organiser des tâches et de gérer certains échecs :

- `block` contient les tâches à exécuter.
- `rescue` s’exécute si une tâche de `block` échoue.
- `always` s’exécute après le bloc, qu’il ait réussi ou échoué.

Dans l’exercice, `/bin/false` échoue volontairement et renvoie le code `rc=1`. La tâche suivante dans `block` est alors ignorée. `rescue` prend le relais, puis `always` s’exécute.

> `/bin/false` sert uniquement à démontrer la gestion des erreurs. Ne l’utilise pas comme commande dans un playbook destiné à effectuer un vrai travail.

Quand les tâches de `rescue` réussissent, Ansible considère généralement l’erreur comme récupérée et peut poursuivre le playbook.

## 12. Lire le récapitulatif

À la fin du playbook, Ansible affiche un récapitulatif, par exemple :

```text
localhost : ok=13 changed=0 unreachable=0 failed=0 skipped=0 rescued=1 ignored=0
```

- `ok` : tâches exécutées sans erreur.
- `changed` : tâches ayant signalé une modification.
- `unreachable` : hôtes qu’Ansible n’a pas pu joindre.
- `failed` : tâches ayant terminé en échec sans être récupérées.
- `skipped` : tâches ignorées, par exemple parce qu’une condition `when` est fausse.
- `rescued` : échecs récupérés grâce à un bloc `rescue`.
- `ignored` : échecs ignorés avec une directive comme `ignore_errors`.

Le résultat de `/bin/false` apparaît comme un échec dans la sortie, mais il est ensuite récupéré par `rescue`. Le récapitulatif peut donc afficher `failed=0` et `rescued=1`.

## À propos de l’avertissement Python

Ansible peut afficher un avertissement indiquant qu’il a détecté Python à `/usr/bin/python3.10`. Dans notre exercice, cet avertissement n’a pas empêché l’exécution du playbook : Ansible prévient simplement que la découverte de l’interpréteur Python pourrait changer si un autre interpréteur est installé.

## Commandes récapitulatives

```bash
# Vérifier la version et le fichier de configuration utilisé
ansible --version

# Afficher les paramètres Ansible modifiés
ansible-config dump --only-changed

# Tester l’hôte local
ansible local -i inventory.ini -m ansible.builtin.ping

# Exécuter la commande hostname
ansible local -i inventory.ini -m ansible.builtin.command -a "hostname"

# Exécuter le playbook avec l'inventaire défini dans ansible.cfg
ansible-playbook premier-playbook.yml
```
````