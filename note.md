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