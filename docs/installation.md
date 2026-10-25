# Installation

## Objectif

Ce document décrit la procédure de déploiement du projet sur une machine vierge ou une machine virtuelle.

## Prérequis

### Machine cible

- Ubuntu Server 24.04 LTS ou une base compatible
- 4 Go de RAM minimum (8 Go recommandé)
- 20 Go de disque minimum
- accès réseau local ou NAT
- accès internet pendant l'installation pour récupérer les paquets Debian/Ubuntu

### Machine de build

- Ubuntu, Debian ou Linux Mint
- Cubic installé
- 10 Go d'espace libre
- ISO Ubuntu Server 24.04 LTS

## Préparation du support d'installation

1. Copier le dépôt dans un dossier de travail dédié.
2. Préparer l'arborescence du projet dans le dossier de build.
3. Ajouter les fichiers de configuration nécessaires pour l'autoinstall.
4. Vérifier que le fichier `autoinstall/user-data` est bien présent.
5. Démarrer l'ISO personnalisée avec Cubic.

## Installation automatique

### Étape 1 : créer l'ISO personnalisée

Utiliser Cubic pour intégrer les éléments suivants :
- le système Ubuntu Server 24.04 LTS
- les fichiers du projet
- la configuration d'autoinstall

### Étape 2 : démarrer la machine cible

- boot sur l'ISO personnalisée
- suivre les étapes de l'installateur
- laisser l'autoinstall conduire la configuration initiale

### Étape 3 : vérifier la fin d'installation

Après le premier démarrage, vérifier :
- le système est opérationnel
- le service système du projet est présent
- le script de configuration est accessible

## Déploiement manuel des scripts

En cas de besoin, les scripts peuvent être lancés manuellement dans l'ordre suivant :

```bash
sudo bash /opt/projet-soutenance/scripts/system.sh
sudo bash /opt/projet-soutenance/scripts/openldap.sh
sudo bash /opt/projet-soutenance/scripts/samba.sh
sudo bash /opt/projet-soutenance/scripts/freeradius.sh
sudo bash /opt/projet-soutenance/scripts/integration.sh
sudo bash /opt/projet-soutenance/scripts/security.sh
```

## Réinitialisation de la configuration

Si l'on souhaite refaire la configuration interactive :

```bash
sudo rm /etc/projet-soutenance/configured
sudo systemctl start projet-soutenance.service
```

## Vérification initiale

À la fin du déploiement, vérifier que les services principaux répondent correctement :

```bash
sudo systemctl status slapd
sudo systemctl status smbd
sudo systemctl status freeradius
sudo systemctl status ssh
```

## Validation rapide

La validation globale du projet est réalisée par la suite de tests :

```bash
sudo bash /opt/projet-soutenance/tests/run-tests.sh
```

## Bonnes pratiques

- utiliser un réseau dédié pour la démonstration
- conserver les mots de passe de démonstration internes
- ne pas exposer le service au grand public
- enregistrer les logs système lors des premiers tests

## Conclusion

L'installation est pensée pour être reproductible et compatible avec un cadre pédagogique local. La maquette est conçue pour être déployée facilement sur une machine virtuelle ou une machine physique, puis validée par les scripts et tests intégrés.
