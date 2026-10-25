# Sécurité

## Vue d'ensemble

Ce projet est une maquette de laboratoire destinée à démontrer une architecture locale de serveur pédagogique. Il a été conçu pour être fonctionnel et compréhensible, mais pas pour remplacer une solution de production.

## Risques et limites

### 1. Mots de passe de démonstration

Les valeurs par défaut sont volontairement simples :

- `LDAP_ADMIN_PASSWORD=admin`
- `USER_PASSWORD=user`
- `RADIUS_SHARED_SECRET=admin`

Ces valeurs sont adaptées à un environnement de test, mais insuffisantes pour une exploitation réelle.

### 2. Secrets et configuration

Le dépôt n'est pas conçu pour gérer des secrets de production dans des conditions sécurisées. Il est recommandé d'utiliser un moyen de stockage chiffré ou un gestionnaire de secrets dédié.

### 3. Ouverture des services

L'environnement doit être protégé :
- limiter les ports ouverts
- filtrer l'accès réseau
- ne pas exposer le serveur sur un réseau non maîtrisé

### 4. Services internes et certificats

Les certificats internes sont utiles pour la démonstration, mais ne doivent pas être considérés comme équivalents à une PKI de production.

## Mesures déjà mises en place

- pare-feu UFW activé
- SSH durci
- permissions restreintes sur les fichiers de configuration
- génération d'une CA interne
- activation de LDAPS
- activation du certificat FreeRADIUS

## Recommandations minimales

Avant toute utilisation autre que pédagogique :

- modifier les mots de passe par défaut
- utiliser des secrets robustes
- activer des règles UFW minimales et explicites
- limiter les comptes et les groupes à ce qui est strictement nécessaire
- vérifier régulièrement les logs et les autorisations

## Bonnes pratiques de déploiement

- préférer un réseau isolé pour le laboratoire
- ne pas exposer les services au grand public
- documenter les accès autorisés
- surveiller les journaux `journalctl` et les logs Samba
- revoir la configuration avant chaque démonstration

## Conclusion

La sécurisation de la maquette est volontairement réduite pour faciliter l'enseignement et la démonstration. Toutefois, l'architecture reste un bon support pour comprendre les mécanismes de centralisation d'identité et d'authentification en environnement Linux.
