# Configuration

## Généralités

La configuration du projet est centralisée dans le fichier `config/config.env` généré au premier démarrage ou lors de l'exécution du script de configuration.

Le fichier `config/config.env.example` sert de modèle et doit être adapté selon l'environnement.

## Fichier de configuration

Le fichier principal contient les variables suivantes :

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

## Exemple de configuration

```bash
HOSTNAME=serveur-pedagogique
TIMEZONE=Europe/Paris
IP_ADDRESS=192.168.10.10
GATEWAY=192.168.10.1
DNS_SERVERS="8.8.8.8 1.1.1.1"
LDAP_DOMAIN=example.local
LDAP_BASE_DN=dc=example,dc=local
LDAP_ADMIN_PASSWORD=admin
SAMBA_WORKGROUP=WORKGROUP
USER_PASSWORD=user
RADIUS_SHARED_SECRET=admin
SHARES_BASE=/srv/partages
```

## Rôle des principales variables

### `HOSTNAME`
Nom du serveur sur le réseau.

### `TIMEZONE`
Fuseau horaire du système.

### `IP_ADDRESS`
Adresse IP du serveur.

### `GATEWAY`
Passerelle réseau principale.

### `DNS_SERVERS`
Serveurs DNS à utiliser pour la résolution.

### `LDAP_DOMAIN`
Nom du domaine LDAP utilisé par le système.

### `LDAP_BASE_DN`
Base DN pour l'annuaire LDAP.

### `LDAP_ADMIN_PASSWORD`
Mot de passe de l'administrateur LDAP.

### `SAMBA_WORKGROUP`
Nom du groupe de travail Samba.

### `USER_PASSWORD`
Mot de passe initial des comptes utilisateurs de démonstration.

### `RADIUS_SHARED_SECRET`
Clé partagée utilisée pour FreeRADIUS.

### `SHARES_BASE`
Dossier racine des partages pédagogiques.

## Sécurité des variables

Le projet est une maquette et utilise des valeurs de démonstration très simples, notamment :

- `LDAP_ADMIN_PASSWORD=admin`
- `USER_PASSWORD=user`
- `RADIUS_SHARED_SECRET=admin`

Dans un environnement réel, il faut impérativement :
- remplacer ces valeurs
- utiliser un gestionnaire de secrets
- limiter l'accès au fichier de configuration
- chiffrer les données sensibles si nécessaire

## Modifications à effectuer avant utilisation réelle

Avant toute exploitation hors laboratoire :

1. modifier les mots de passe par défaut
2. choisir une vraie base DN
3. sécuriser les accès UFW
4. vérifier les ACL Samba et LDAP
5. contrôler les ports ouverts

## Génération ou mise à jour

Le script de configuration permet de régénérer ou de mettre à jour les paramètres du système. En cas d'erreur, il est conseillé de vérifier le fichier de configuration et de relancer les scripts dans l'ordre recommandé.

## Conclusion

La configuration est volontairement simple pour faciliter la compréhension et la démonstration. Elle constitue néanmoins une base solide pour une validation technique d'architecture pédagogique sur Ubuntu.
