# Architecture du projet

## Vue d'ensemble

Le projet met en place un serveur pédagogique autonome, basé sur Ubuntu Server 24.04 LTS, avec des services d'annuaire, de partage, d'authentification et de sécurisation.

L'objectif est de démontrer une architecture cohérente, automatisable et reproductible, sans dépendre d'une infrastructure complexe ou d'un environnement de production.

## Composants principaux

### 1. Ubuntu Server

Le serveur de base fournit :
- le système d'exploitation
- les services réseau de base
- la gestion locale des paquets
- la sécurisation SSH et UFW
- la prise en charge des scripts de configuration

### 2. OpenLDAP

OpenLDAP est utilisé comme source d'identité centrale.

Rôles :
- stocker les comptes utilisateurs et groupes
- fournir un schéma d'organisation pédagogique
- centraliser les identités utilisées par Linux et les services applicatifs

### 3. Samba

Samba sert à exposer les ressources pédagogiques aux clients Windows et Linux.

Rôles :
- partage de répertoires pédagogiques
- gestion des permissions et ACL
- intégration avec l'annuaire LDAP

### 4. SSSD

SSSD permet de résoudre les identités LDAP côté Linux.

Rôles :
- authentification locale via LDAP
- mapping des utilisateurs et groupes du domaine
- cohérence entre le système Linux et l'annuaire central

### 5. FreeRADIUS

FreeRADIUS sert à l'authentification réseau et à la validation des accès selon des besoins AAA.

Rôles :
- authentification via email ou identifiants centralisés
- support d'un usage pédagogique sur le réseau
- démonstration d'un service d'authentification réseau

### 6. TLS / certificats internes

Le projet génère des certificats et met en place un usage TLS interne pour sécuriser les services LDAP et RADIUS.

Cela permet de :
- chiffrer les échanges
- préparer une base de démonstration crédible
- montrer les bonnes pratiques de sécurisation

## Flux fonctionnel

1. L'installation Ubuntu est automatisée via une ISO personnalisée.
2. Les scripts de configuration créent les services requis.
3. OpenLDAP reçoit les utilisateurs et groupes.
4. Samba et SSSD utilisent ces identités pour l'accès aux ressources.
5. FreeRADIUS apporte une authentification réseau complémentaire.
6. La validation du système se fait via la suite de tests automatisés.

## Topologie logique

Le schéma peut être représenté comme suit :

- Clients Windows/Linux
  - accès aux partages Samba
  - authentification via LDAP / SSSD / RADIUS
- Serveur pédagogique
  - OpenLDAP
  - Samba
  - SSSD
  - FreeRADIUS
  - UFW / SSH / TLS

## Limites de la maquette

Ce projet est une maquette de laboratoire et non une architecture de production.

Ses limites incluent :
- mots de passe de démonstration
- sécurisation minimale
- absence de gestion de secrets avancée
- tolérance limitée pour des cas d'usage complexes

## Points d'amélioration

- centraliser les secrets dans un gestionnaire dédié
- renforcer l'audit et la journalisation
- utiliser des comptes de service distincts
- ajouter des tests de robustesse et de refus d'accès
- valider avec des scénarios plus réalistes de partage et d'authentification

## Conclusion

L'architecture vise à démontrer un environnement pédagogique complet sur une unique machine ou un petit parc local, avec des services interconnectés et automatiques. Elle offre une base idéale pour la validation d'un concept technique, de la formation et de la démonstration.
