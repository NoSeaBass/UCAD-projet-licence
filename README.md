# Serveur pédagogique - Projet de soutenance

## Description

Ce projet automatise le déploiement d'un serveur pédagogique pour un centre
de formation. À partir d'une machine vierge, une ISO personnalisée installe
Ubuntu Server 24.04 LTS et configure automatiquement :

- **OpenLDAP** : annuaire central des identités (utilisateurs, groupes)
- **Samba** : partage de ressources pédagogiques avec ACL par groupe
- **SSSD** : résolution des identités LDAP côté Linux
- **FreeRADIUS** : authentification réseau par email (AAA)
- **TLS** : certificats internes pour LDAPS et FreeRADIUS
- **UFW + SSH** : sécurité de base

## Objectifs

- Fournir un média d'installation automatisé, reproductible et documenté.
- Centraliser la gestion des comptes utilisateurs.
- Permettre l'accès aux ressources pédagogiques depuis Windows et Linux.
- Offrir une authentification unifiée (LDAP, RADIUS, SMB).
- Sécuriser les échanges avec TLS.

## Prérequis

### Machine cible (serveur)

- Processeur x86_64
- 4 Go RAM minimum (8 Go recommandé)
- 20 Go disque minimum
- Réseau NAT ou Host-Only
- Accès à Internet pendant l'installation (pour `apt`)

### Machine de build (pour créer l'ISO)

- Linux Mint, Ubuntu ou Debian
- [Cubic](https://github.com/PJ-Singh-001/Cubic) installé
- 10 Go d'espace libre
- Le fichier ISO Ubuntu Server 24.04 LTS

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
        ├── 01-architecture.md
        ├── 02-installation.md
        ├── 03-configuration.md
        ├── 04-tests.md
        ├── 05-securite.md
        ├── 06-depannage.md
        └── schemas/

## Installation

### 1. Créer l'ISO personnalisée

Suivre la procédure détaillée dans `docs/02-installation.md`.

Résumé :
- Ouvrir le projet Cubic.
- Copier le projet dans `/cdrom/projet-soutenance/`.
- Copier `user-data` et `meta-data` dans `/cdrom/autoinstall/`.
- Modifier `grub.cfg` pour ajouter l'option `autoinstall`.
- Générer l'ISO.

### 2. Déployer sur une machine vierge

- Démarrer la VM ou la machine physique sur l'ISO.
- Suivre les étapes interactives (langue, réseau, partitionnement, compte).
- Attendre la fin de l'installation.
- Au premier démarrage, répondre aux questions de `configure.sh`.

### 3. Vérifier

    sudo bash /opt/projet-soutenance/tests/run-tests.sh

Résultat attendu : **35 tests réussis, 0 échec**.

## Configuration

Toutes les valeurs modifiables sont dans `config/config.env`, généré au
premier démarrage par `configure.sh`. Le modèle `config/config.env.example`
sert de documentation.

### Variables principales

| Variable              | Description                      | Valeur par défaut       |
|-----------------------|----------------------------------|-------------------------|
| `HOSTNAME`            | Nom du serveur                   | serveur-peda            |
| `TIMEZONE`            | Fuseau horaire                   | Africa/Dakar            |
| `IP_ADDRESS`          | Adresse IP (CIDR)                | (DHCP si vide)          |
| `GATEWAY`             | Passerelle                       | 192.168.122.1           |
| `DNS_SERVERS`         | Serveurs DNS                     | 127.0.0.1 8.8.8.8       |
| `LDAP_DOMAIN`         | Domaine DNS                      | etablissement.local     |
| `LDAP_BASE_DN`        | Base DN                          | dc=etablissement,dc=local |
| `LDAP_ADMIN_PASSWORD` | Mot de passe admin LDAP          | admin                   |
| `SAMBA_WORKGROUP`     | Workgroup Samba                  | ETABLISSEMENT           |
| `USER_PASSWORD`       | Mot de passe des utilisateurs    | user                    |
| `RADIUS_SHARED_SECRET`| Secret partagé RADIUS            | admin                   |
| `SHARES_BASE`         | Répertoire de base des partages  | /srv/partages           |

### Configuration réseau

`config.env.example` propose `DNS_SERVERS="127.0.0.1 8.8.8.8"`.

- Le premier (127.0.0.1) suppose que le serveur fait aussi office de resolver.
- Le second (8.8.8.8) est un DNS public de secours.

Adaptez selon votre environnement :
- DNS d'entreprise : mettez son adresse en premier.
- Pas de resolver local : retirez 127.0.0.1.
- Hors ligne : mettez l'adresse de votre passerelle.

## Sécurité

### Mesures appliquées

- **Pare-feu UFW** : deny par défaut, ports 22, 139, 445, 389, 636, 1812, 1813.
- **SSH durci** : `PermitRootLogin no`, `MaxAuthTries 3`, `X11Forwarding no`.
- **Permissions** : `sssd.conf` en 600, `smb.conf` en 640.
- **TLS** : CA interne, LDAPS sur slapd, certificats FreeRADIUS.
- **Sauvegardes** : chaque fichier de configuration écrasé est sauvegardé en `.bak.<timestamp>`.

### Important : changer les mots de passe par défaut

Après la configuration, **changez le mot de passe administrateur LDAP** :

    ldappasswd -x -H ldaps://localhost \
        -D "cn=admin,dc=etablissement,dc=local" \
        -W -S "cn=admin,dc=etablissement,dc=local"

Les mots de passe par défaut sont `admin` (LDAP, RADIUS) et `user`
(utilisateurs de test). Ces valeurs sont volontairement simples pour
faciliter les tests. **Un administrateur compétent les changera avant
tout déploiement en production.**

`config/config.env` contient les secrets en clair, protégé en `600 root:root`.
Pour un déploiement réel, utilisez un gestionnaire de secrets.

Voir `docs/05-securite.md` pour les limites et recommandations.

## Tests

La suite `tests/run-tests.sh` exécute **35 tests** :

- **Système** (8) : hostname, timezone, paquets installés
- **LDAP** (13) : service, DIT, groupes, utilisateurs, attributs Samba, SSSD
- **Samba** (11) : services, smb.conf, pdbedit, partages, ACL
- **RADIUS** (3) : service, Access-Accept, Access-Reject

Lancer :

    sudo bash /opt/projet-soutenance/tests/run-tests.sh

Voir `docs/04-tests.md` pour la liste détaillée.

## Relancer les scripts manuellement

Si vous avez modifié `config/config.env` et souhaitez réappliquer la
configuration, relancez les scripts dans l'ordre :

    sudo bash /opt/projet-soutenance/scripts/system.sh
    sudo bash /opt/projet-soutenance/scripts/openldap.sh
    sudo bash /opt/projet-soutenance/scripts/samba.sh
    sudo bash /opt/projet-soutenance/scripts/freeradius.sh
    sudo bash /opt/projet-soutenance/scripts/integration.sh
    sudo bash /opt/projet-soutenance/scripts/security.sh

Pour repasser par l'interface interactive (`configure.sh`), supprimez
d'abord le marqueur :

    sudo rm /etc/projet-soutenance/configured
    sudo systemctl start projet-soutenance.service

## Clients

### Client Windows

Monter un lecteur réseau :

    net use Z: \\<ip-serveur>\cours /user:ETABLISSEMENT\enseignant01 user

**Important** : utiliser une invite de commandes **normale**, pas
administrateur. Windows isole les sessions.

### Client Linux

Monter un partage CIFS :

    sudo mkdir -p /mnt/cours
    sudo mount -t cifs //<ip-serveur>/cours /mnt/cours \
        -o username=enseignant01,password=user,domain=ETABLISSEMENT

### Application Java (bonus)

Une application Java permet de s'authentifier via RADIUS (email + mot de
passe) et de monter automatiquement le partage correspondant au groupe.

## Dépannage

Voir `docs/06-depannage.md` pour les problèmes courants et leurs solutions.

En cas de blocage :

1. Noter le message d'erreur exact.
2. Consulter les logs :

       sudo journalctl -u <service> --no-pager | tail -50
       sudo tail -50 /var/log/samba/log.smbd
       sudo tail -50 /var/log/freeradius/radius.log

3. Vérifier la cohérence avec `config/config.env`.

## Documentation

- `docs/01-architecture.md` : schémas et flux
- `docs/02-installation.md` : Cubic, Autoinstall, déploiement
- `docs/03-configuration.md` : variables et scripts
- `docs/04-tests.md` : 35 tests détaillés
- `docs/05-securite.md` : mesures, limites, recommandations
- `docs/06-depannage.md` : problèmes et solutions

## Auteur

Papa Ibrahima DIOP
Université Cheikh Anta Diop
Année académique 2025-2026
Encadreur : Dr Malaw Ndiaye
