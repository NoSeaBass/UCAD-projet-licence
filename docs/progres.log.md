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
