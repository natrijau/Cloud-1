================================================================================
                  DÉROULEMENT DU PROJET CLOUD-1 (ÉTAPES CLÉS)
================================================================================

[ÉTAPE 1 : CHOIX DE LA PLATEFORME & INFRASTRUCTURE] (Chapitre III & V)
   │
   ├──► Sélectionner un fournisseur cloud (AWS, GCP, Azure, crédits étudiants)[cite: 7]
   ├──► Dimensionner les instances (éligibles aux niveaux gratuits)[cite: 10]
   ├──► Provisionner 1 ou plusieurs serveurs vierges (Ubuntu 22.04 LTS + SSH + Python)[cite: 8]
   └──► (Optionnel) Configurer un nom de domaine gratuit (ex: DuckDNS, .tk)[cite: 11]
          │
          ▼
[ÉTAPE 2 : ARCHITECTURE APPLICATIVE & CONTENEURISATION] (Chapitre I & IV)
   │
   ├──► Séparer les services : 1 processus = 1 conteneur (images officielles acceptées)[cite: 4, 8, 9]
   │      ├── Serveur Web / Reverse Proxy (routage URL + TLS/HTTPS)[cite: 8]
   │      ├── WordPress[cite: 4, 8]
   │      ├── Base de données SQL (MySQL/MariaDB)[cite: 4, 8]
   │      └── phpMyAdmin[cite: 4, 8]
   ├──► Orchestrer via un fichier docker-compose.yml[cite: 8]
   └──► Configurer la persistance des données (volumes) et le redémarrage auto[cite: 8]
          │
          ▼
[ÉTAPE 3 : AUTOMATISATION & SÉCURISATION] (Chapitre I, IV & V)
   │
   ├──► Structurer le code d'automatisation (ex: Ansible organisé en rôles)[cite: 4, 8]
   ├──► Garantir l'idempotence (rejouable à l'infini) et la portabilité[cite: 8, 9]
   ├──► Assurer le déploiement simultané sur plusieurs serveurs en parallèle[cite: 8]
   ├──► Sécuriser les accès réseau : ouvrir uniquement les ports 22, 80, 443[cite: 8]
   │      (bloquer tout accès externe direct à la base de données)[cite: 8]
   └──► Protéger les secrets (aucun mot de passe/clé en dur dans le code ou Git)[cite: 9, 10]
          │
          ▼
[ÉTAPE 4 : TESTS, GESTION DES COÛTS & REMISE] (Chapitre V & VI)
   │
   ├──► Tester le redémarrage du serveur (vérifier relance auto & maintien des données)[cite: 8]
   ├──► Tester le déploiement depuis zéro sur une nouvelle instance vierge[cite: 9]
   ├──► Pousser le code propre sur le dépôt Git (vérifier noms de fichiers/dossiers)[cite: 11]
   ├──► Surveiller/arrêter les instances cloud inutilisées pour éviter la facturation
   └──► Soutenance : connexion en tant que root (obligatoire) et démonstration[cite: 11]