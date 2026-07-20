# Progression par rapport au projet

## Plannification

Etablissement du dossier de projet de base avec la structure de base qui suit :
UCAD-projet-soutenance-automatisation-infra-Linux/
├── docs
│   ├── progres.log.md
│   ├── Soutenance.drawio
│   └── sujet_soutenance_automatisation_infra_linux_centralise.docx
├── README.md
└── scripts
    ├── client
    └── server

Avec :
- docs : Contenant les fichiers de redaction du projet
    - le fichier .docx qui est le fichier de base dans lequel se trouve la problematique, les objectifs, le plan en détail et une conclusion temporaire
    - le fichier .drawio qui en faite le diagramme d'activités et les diagrammes de cas d'utilisation (je convertirais plus tard en fichiers .png)
    - et ce fichier
- scripts : Qui contiendras les scripts de configuration automatique
- README : Je ne vois pas pourquoi expliquez ce fichier...

## Conception

[08-06-2026 11h30]Création du dossier script et envoi du dossier du projet dans [Github](https://github.com/NoSeaBass/UCAD-projet-soutenance-automatisation-infra-Linux/). Le dossier script contient les scripts d'installation et de configurations des différents élements necessaire au projet côte serveur et côté client. Elle sert aussi de reférence par rapport a mon progrès sur les configurations (sachant que celles-ci seront faites manuellement).

Pour l'instant les scripts côté serveur sont mis en place avec :
- vérification de présence des packages necessaires
- configuration de base de radius à LDAP/MySQL

[14-07-2026 22h40]Finalisation du couplage de LDAP et FreeRADIUS.
J'ai recommencé la configuration de FreeRADIUS pour le couplage avec LDAP car je me perdais dans mes vieux scripts du coups j'ai décider de reconfigurer le serveur en commençant par une configuration vide et en ajoutant les éléments nécessaires étape par étape :

- Configuration de base de FreeRADIUS
- Configuration de l'authentification LDAP
- Configuration des groupes et des autorisations

Une fois la configuration terminée, je me suis assuré que le serveur fonctionne correctement en testant l'authentification avec un utilisateur LDAP. Et puis je couplerais FreeRADIUS avec Samba pour les répertoires.

J'ai aussi ajouer un flake.nix pour obternir pour utiliser Cubic via ma machine NixOS. Les détails seront inclus prochainement dans la documentation dans la partie des problèmes rencontrés.

Prochainement je retournerai sur la documentation car beaucoup d'information nécessaire manque.

[20-07-2026]Pré-soutenance.
Je dois revoir le titre et tout le projet
J'aimerais aussi revoir mes documentation, le plan mais surtout le cahier de charge
