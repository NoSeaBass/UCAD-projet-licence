# ============================================================
# Serveur pédagogique - Projet de soutenance
# ============================================================
# README du projet
#
# Ce dépôt contient une maquette fonctionnelle d'infrastructure
# pédagogique locale basée sur Ubuntu Server, OpenLDAP, Samba,
# SSSD, FreeRADIUS et des scripts Bash d'automatisation.
#
# Il est conçu comme un environnement de laboratoire / démonstrateur,
# et non comme un environnement de production prêt à l'emploi.
# ============================================================

# Serveur pédagogique - Projet de soutenance

## Description

Ce projet automatise le déploiement d'un serveur pédagogique pour un centre de formation.
À partir d'une machine vierge, une ISO personnalisée installe Ubuntu Server 24.04 LTS et configure automatiquement :

- OpenLDAP : annuaire central des identités (utilisateurs, groupes)
- Samba : partage de ressources pédagogiques avec ACL par groupe
- SSSD : résolution des identités LDAP côté Linux
- FreeRADIUS : authentification réseau par email (AAA)
- TLS : certificats internes pour LDAPS et FreeRADIUS
- UFW + SSH : sécurité de base

## État du projet

Ce dépôt correspond à une maquette de laboratoire fonctionnelle, destinée à valider une architecture et à démontrer un flux de déploiement automatisé.

Il est adapté à :
- un environnement de cours / de démonstration
- une petite infrastructure pédagogique locale
- une validation de concept technique

Il n'est pas conçu comme :
- une plateforme de production sans revue de sécurité
- un environnement complet avec gestion des secrets en production
- un remplacement de solutions telles que Samba AD DC / FreeIPA pour des parcs Windows complexes

## Objectifs

- Fournir un média d'installation automatisé, reproductible et documenté.
- Centraliser la gestion des comptes utilisateurs.
- Permettre l'accès aux ressources pédagogiques depuis Windows et Linux.
- Offrir une authentification unifiée (LDAP, RADIUS, SMB).
- Sécuriser les échanges avec TLS.
- Préparer un environnement de démonstration pédagogique réaliste.

## Prérequis

### Machine cible (serveur)

- Processeur x86_64
- 4 Go RAM minimum (8 Go recommandé)
- 20 Go disque minimum
- Réseau NAT ou Host-Only
- Accès à Internet pendant l'installation (pour `apt`)

### Machine de build (pour créer l'ISO)

- Linux Mint, Ubuntu ou Debian
- Cubic installé
- 10 Go d'espace libre
- ISO Ubuntu Server 24.04 LTS

## Arborescence

    projet-soutenance/
    ├── README.md
    ├── config/
    │   └── config.env.example
    ├── scripts/
    │   ├── system.sh
    │   ├── openldap.sh
    │   ├── samba.sh
    │   ├── freeradius.sh
    │   ├── integration.sh
    │   ├── security.sh
    │   ├── configure.sh
    │   └── lib.sh
    ├── tests/
    │   ├── lib-test.sh
    │   ├── test-system.sh
    │   ├── test-ldap.sh
    │   ├── test-samba.sh
    │   ├── test-radius.sh
    │   └── run-tests.sh
    ├── autoinstall/
    │   ├── user-data
    │   ├── meta-data
    │   └── projet-soutenance.service
    └── docs/
        ├── architecture.md
        ├── installation.md
        ├── configuration.md
        ├── tests.md
        ├── securite.md
        └── dépannage.md

## Installation rapide

### 1. Préparer l'ISO

- Copier les fichiers du projet dans un dossier de build compatible avec Cubic.
- Ajouter le fichier `autoinstall/user-data` et les fichiers associés.
- Démarrer l'installation Ubuntu Server 24.04 LTS avec Autoinstall.

### 2. Déployer sur une machine vierge

- Démarrer la VM ou la machine physique sur l'ISO.
- Suivre les étapes interactives de l'installateur.
- Attendre la fin de l'installation.
- Au premier démarrage, lancer la configuration interactive ou relancer les scripts manuellement.

### 3. Vérifier le déploiement

    sudo bash /opt/projet-soutenance/tests/run-tests.sh

Résultat attendu : validation des composants principaux, avec une attention particulière portée aux tests de refus d'accès et à la cohérence des permissions.

## Configuration

Les paramètres modifiables sont stockés dans `config/config.env` généré au premier démarrage par `configure.sh`. Le fichier `config/config.env.example` sert de modèle.

### Variables principales

- `HOSTNAME`
- `TIMEZONE`
- `IP_ADDRESS`
- `GATEWAY`
- `DNS_SERVERS`
- `LDAP_DOMAIN`
- `LDAP_BASE_DN`
- `LDAP_ADMIN_PASSWORD`
- `SAMBA_WORKGROUP`
- `USER_PASSWORD`
- `RADIUS_SHARED_SECRET`
- `SHARES_BASE`

## Sécurité et bonnes pratiques

### Attention importante

Les valeurs par défaut suivantes sont volontairement simples pour faciliter la démonstration dans un environnement de test :

- `LDAP_ADMIN_PASSWORD=admin`
- `USER_PASSWORD=user`
- `RADIUS_SHARED_SECRET=admin`

Ceci est acceptable pour une maquette, mais ne doit pas être considéré comme un usage sûr en production.

### Recommandations minimales

- Modifier les mots de passe avant toute utilisation autre qu'un laboratoire.
- Utiliser un gestionnaire de secrets ou au moins un fichier de configuration chiffré.
- Limiter les ports ouverts avec UFW.
- Vérifier les ACL LDAP et les permissions Samba.
- Ne pas exposer le service directement sur un réseau non maîtrisé.

### Mesures déjà appliquées

- Pare-feu UFW par défaut
- SSH durci
- permissions restreintes sur les fichiers de configuration
- génération d'une CA interne
- activation de LDAPS et d'un certificat FreeRADIUS

## Scripts

L'ordre recommandé de lancement des scripts est le suivant :

    sudo bash /opt/projet-soutenance/scripts/system.sh
    sudo bash /opt/projet-soutenance/scripts/openldap.sh
    sudo bash /opt/projet-soutenance/scripts/samba.sh
    sudo bash /opt/projet-soutenance/scripts/freeradius.sh
    sudo bash /opt/projet-soutenance/scripts/integration.sh
    sudo bash /opt/projet-soutenance/scripts/security.sh

### Relancer l'interface interactive

Si vous souhaitez refaire la configuration interactive :

    sudo rm /etc/projet-soutenance/configured
    sudo systemctl start projet-soutenance.service

## Tests

La suite `tests/run-tests.sh` vérifie les composants principaux du système :

- système
- OpenLDAP
- Samba
- SSSD
- FreeRADIUS
- permissions et accès

## Dépannage

En cas de blocage :

1. Identifier précisément le message d'erreur.
2. Consulter les logs du service concerné.
3. Vérifier la cohérence des variables dans `config/config.env`.
4. Relancer les scripts dans l'ordre recommandé.

Exemples utiles :

    sudo journalctl -u slapd --no-pager -n 50
    sudo journalctl -u smbd --no-pager -n 50
    sudo journalctl -u freeradius --no-pager -n 50
    sudo tail -50 /var/log/samba/log.smbd

## Documentation

- `docs/architecture.md` : architecture globale
- `docs/installation.md` : procédure de déploiement
- `docs/configuration.md` : configuration et variables
- `docs/tests.md` : validation fonctionnelle
- `docs/securite.md` : sécurité et limites
- `docs/dépannage.md` : aide pour corriger les erreurs

## Auteur

Papa Ibrahima DIOP  
Université Cheikh Anta Diop  
Année académique 2025-2026  
Encadreur : Dr Malaw Ndiaye

## Contribution et amélioration

Les améliorations à prioriser sont :

- sécuriser davantage les secrets
- utiliser des comptes de service dédiés plus strictement
- renforcer les tests de refus d'accès
- mesurer le temps de déploiement
- documenter explicitement les limites de la solution
