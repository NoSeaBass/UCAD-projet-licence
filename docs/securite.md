# Tests

## Objectif

La suite de tests du projet vérifie que les composants principaux du système sont bien installés, configurés et fonctionnels.

## Script principal

Le lancement se fait via :

```bash
sudo bash /opt/projet-soutenance/tests/run-tests.sh
```

## Tests disponibles

La suite couvre plusieurs catégories :

- système
- OpenLDAP
- Samba
- SSSD
- FreeRADIUS
- permissions et accès

## Déroulement attendu

Les tests vérifient en particulier :
- la présence des services système
- le bon fonctionnement des paquets installés
- les accès LDAP et les comptes utilisateur
- la cohérence des permissions de partage Samba
- la disponibilité des services réseau
- le refus d'accès en cas de configuration invalide ou d'identifiants inadaptés

## Cas de validation importants

Le projet met un accent particulier sur :
- la vérification d'authentification
- le refus d'accès non autorisé
- la cohérence des ACL et permissions
- la validation des composants couplés entre eux

## Utilisation

Lors d'un déploiement ou d'une modification, il est recommandé de lancer la suite de tests :

```bash
sudo bash /opt/projet-soutenance/tests/run-tests.sh
```

## Diagnostic en cas d'échec

En cas d'erreur :

1. lire le message de test exact
2. vérifier les journaux du service concerné
3. contrôler `config/config.env`
4. relancer les scripts dans le bon ordre
5. tester les composants individuellement

## Conclusion

Les tests permettent d'objectiver le bon fonctionnement de la maquette et de valider que les services interagissent correctement entre eux.
