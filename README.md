# Ironhaven

Infrastructure AWS sécurisée et reproductible, provisionnée avec Terraform, configurée avec Ansible et administrée sans exposition publique de SSH.

## Objectif du projet

Ironhaven est un projet pratique consacré au cycle de vie complet d’une infrastructure cloud sécurisée : provisionnement, configuration, durcissement, validation, supervision et destruction contrôlée.

L’objectif est de construire une architecture AWS segmentée et reproductible, puis d’automatiser sa configuration et ses contrôles de sécurité. Une attention particulière est portée au principe du moindre privilège, à la traçabilité, à la maintenabilité et à la maîtrise des coûts.

## Architecture

L’infrastructure est déployée dans la région AWS `eu-west-3` et comprend actuellement :

- un VPC dédié `10.42.0.0/16` ;
- un sous-réseau public, un sous-réseau applicatif privé et deux sous-réseaux de données privés ;
- une Internet Gateway et une table de routage publique ;
- trois groupes de sécurité représentant les couches management, application et données ;
- une instance EC2 Amazon Linux 2023 administrée avec AWS Systems Manager ;
- un rôle IAM et un instance profile dédiés à Systems Manager et CloudWatch ;
- un bucket S3 privé et chiffré pour les transferts temporaires Ansible ;
- une configuration Linux de base et plusieurs contrôles de durcissement ;
- un service Nginx conteneurisé, déployé et validé avec Ansible ;
- une centralisation des journaux et des métriques avec Amazon CloudWatch ;
- une instance Amazon RDS for PostgreSQL privée et chiffrée ;
- des identifiants de base de données générés et gérés par AWS Secrets Manager ;
- une image Nginx corrigée et analysée avec Trivy ;
- un contrôle de sécurité automatisé avec GitHub Actions.

L’instance de management ne possède aucune règle entrante. Aucun port SSH n’est exposé et aucune clé privée n’est nécessaire pour son administration.

La base PostgreSQL n’est pas accessible depuis Internet ni directement depuis la couche management. Son port `5432` est autorisé uniquement depuis le groupe de sécurité de la couche application.

Le service Nginx de démonstration écoute uniquement sur `127.0.0.1:8080` à l’intérieur de l’instance. Il peut être consulté depuis le poste local avec un tunnel Systems Manager, sans ouvrir de port entrant supplémentaire.

![Page Ironhaven servie par Nginx](docs/screenshots/docker-nginx-page.png)

La documentation détaillée est disponible dans :

- [Architecture AWS](docs/architecture.md)
- [Administration avec Ansible](docs/ansible.md)
- [Service conteneurisé Nginx](docs/container.md)
- [Supervision avec Amazon CloudWatch](docs/monitoring.md)
- [Base de données PostgreSQL](docs/database.md)
- [Analyse de sécurité des conteneurs](docs/security-scanning.md)
- [Décisions techniques](docs/decisions.md)
- [Troubleshooting](docs/troubleshooting.md)

## Sécurité

Les principaux contrôles actuellement appliqués sont :

- authentification MFA pour l’utilisateur AWS du projet ;
- politiques IAM dédiées aux opérations du projet ;
- segmentation réseau en couches management, application et données ;
- groupes de sécurité restrictifs utilisant des références entre groupes ;
- absence de règle entrante ouverte sur Internet ;
- administration par AWS Systems Manager Session Manager ;
- métadonnées EC2 limitées à IMDSv2 ;
- volume système chiffré ;
- bucket de transfert Ansible chiffré, privé et nettoyé automatiquement ;
- synchronisation temporelle avec `chronyd` ;
- journalisation système avec `auditd` ;
- authentification SSH par mot de passe et connexion directe de `root` désactivées ;
- service Nginx lié uniquement à l’interface locale ;
- contenu web monté en lecture seule dans le conteneur ;
- validation automatique de la réponse HTTP ;
- analyse des vulnérabilités de l’image avec Trivy ;
- blocage du pipeline sur les vulnérabilités corrigibles `HIGH` ou `CRITICAL` ;
- dépendances CI externes épinglées par SHA ou digest ;
- centralisation des journaux système, d’audit et Docker dans CloudWatch ;
- rétention des journaux CloudWatch limitée à sept jours ;
- instance RDS privée avec stockage chiffré ;
- identifiants PostgreSQL absents du code et gérés par Secrets Manager ;
- rotation automatique du secret RDS ;
- exclusion du state Terraform et des informations sensibles du dépôt Git.

## Automatisation Ansible

Trois playbooks sont actuellement disponibles :

| Playbook | Fonction |
|---|---|
| `baseline.yml` | Mise à jour, outils d’administration, synchronisation temporelle, audit et durcissement SSH |
| `container.yml` | Installation de Docker, construction et déploiement du service Nginx conteneurisé |
| `monitoring.yml` | Installation et configuration de l’agent Amazon CloudWatch |

Les trois playbooks ont été exécutés une seconde fois avec :

```text
changed=0
unreachable=0
failed=0
```

Ce résultat confirme leur idempotence sur l’environnement déployé. Les collections nécessaires sont versionnées dans `ansible/requirements.yml`.

## Supervision

L’agent Amazon CloudWatch collecte :

- les journaux d’initialisation de l’instance ;
- les événements produits par `auditd` ;
- les journaux du conteneur Docker ;
- le pourcentage de mémoire utilisée ;
- le pourcentage d’espace utilisé sur la partition racine.

Les journaux sont répartis dans trois groupes CloudWatch gérés par Terraform. Les métriques sont publiées dans l’espace de noms `Ironhaven/Management`.

![Validation des journaux et métriques CloudWatch](docs/screenshots/cloudwatch-monitoring-validation.png)

## Sécurité des conteneurs

L’image Nginx initiale contenait des vulnérabilités corrigibles de sévérité `HIGH` ou `CRITICAL`. Après mise à jour de l’image de base et application des correctifs Alpine pendant le build, Trivy ne détecte plus aucune vulnérabilité correspondant à cette politique.

Le workflow GitHub Actions reconstruit et analyse l’image à chaque push et pull request vers `main`. Le job échoue automatiquement si une vulnérabilité corrigible `HIGH` ou `CRITICAL` est détectée.

## Base de données

Amazon RDS héberge une instance PostgreSQL dans deux sous-réseaux privés répartis sur deux zones de disponibilité. L’instance n’est pas publiquement accessible, son stockage est chiffré et ses journaux PostgreSQL sont exportés vers CloudWatch.

Le mot de passe principal n’est ni défini dans Terraform ni stocké dans le dépôt. RDS le génère et le conserve dans Secrets Manager. La rotation automatique doit encore être vérifiée.

![Validation de l’instance RDS PostgreSQL](docs/screenshots/rds-postgresql-validation.png)

## Technologies

### Actuellement utilisées

- AWS
- Terraform
- Ansible
- Docker
- Nginx
- PostgreSQL
- Trivy
- GitHub Actions
- Amazon CloudWatch
- Amazon RDS
- AWS Secrets Manager
- AWS IAM
- AWS Systems Manager
- Amazon EC2
- Amazon S3
- Amazon Linux 2023
- Git et GitHub
- WSL2 Ubuntu

### Prévue

- composant de sécurité pour agent IA

## État du projet

### Terminé

- [x] Configuration sécurisée de l’accès AWS avec MFA
- [x] Mise en place du socle Terraform
- [x] Création du VPC et des sous-réseaux segmentés
- [x] Configuration du routage public
- [x] Création des groupes et règles de sécurité
- [x] Création du rôle IAM et de l’instance profile SSM
- [x] Déploiement d’une instance EC2 Amazon Linux 2023
- [x] Validation de l’administration sans SSH avec Session Manager
- [x] Création du bucket de transfert temporaire Ansible
- [x] Validation de la connexion Ansible via SSM
- [x] Automatisation de la configuration de base avec Ansible
- [x] Application de contrôles de durcissement Linux
- [x] Vérification de l’idempotence des playbooks
- [x] Installation et activation de Docker
- [x] Déploiement d’un service Nginx conteneurisé
- [x] Validation du service avec un tunnel SSM
- [x] Création des groupes de journaux CloudWatch avec Terraform
- [x] Centralisation des journaux système, d’audit et Docker
- [x] Collecte des métriques mémoire et disque
- [x] Validation de la supervision CloudWatch
- [x] Analyse de l’image Nginx avec Trivy
- [x] Remédiation des vulnérabilités `HIGH` et `CRITICAL`
- [x] Ajout d’un contrôle de sécurité bloquant avec GitHub Actions
- [x] Création de deux sous-réseaux privés pour la couche données
- [x] Déploiement d’Amazon RDS for PostgreSQL
- [x] Gestion des identifiants RDS avec Secrets Manager
- [x] Validation du chiffrement et de l’isolation réseau de RDS
- [x] Documentation des briques déployées

### Prochaines étapes

- [ ] Déployer une ressource dans la couche application privée
- [ ] Valider une connexion applicative réelle à PostgreSQL
- [ ] Limiter l’accès au secret au rôle IAM de l’application
- [ ] Mettre en place les contrôles de sécurité pour agent IA
- [ ] Tester la reconstruction et la destruction complète de l’environnement
- [ ] Finaliser la documentation du projet

## Structure du dépôt

```text
.
├── .github/
│   └── workflows/
│       └── container-security.yml
├── ansible/
│   ├── ansible.cfg
│   ├── files/
│   │   └── nginx/
│   │       └── Dockerfile
│   ├── inventory/
│   │   └── hosts.yml
│   ├── playbooks/
│   │   ├── baseline.yml
│   │   ├── container.yml
│   │   └── monitoring.yml
│   └── requirements.yml
├── docs/
│   ├── ansible.md
│   ├── architecture.md
│   ├── container.md
│   ├── database.md
│   ├── decisions.md
│   ├── monitoring.md
│   ├── security-scanning.md
│   ├── troubleshooting.md
│   └── screenshots/
└── terraform/
    ├── compute.tf
    ├── database.tf
    ├── iam.tf
    ├── monitoring.tf
    ├── network.tf
    ├── outputs.tf
    ├── provider.tf
    ├── routing.tf
    ├── security.tf
    ├── storage.tf
    ├── variables.tf
    └── versions.tf
```

## Maîtrise des coûts

L’instance EC2 et l’instance RDS sont arrêtées lorsqu’elles ne sont pas utilisées. Le bucket S3 applique une expiration automatique aux objets temporaires, les journaux CloudWatch sont conservés pendant sept jours et aucune NAT Gateway n’est actuellement déployée.

L’arrêt de RDS supprime la facturation des heures d’instance, mais le stockage et les sauvegardes restent facturés. Les ressources restent provisionnées par Terraform afin de permettre leur redémarrage et leur validation avant la destruction finale.

## Avertissement

Ce dépôt correspond à un environnement de laboratoire et de démonstration. Les ressources AWS sont temporaires et doivent être arrêtées ou détruites lorsqu’elles ne sont pas utilisées afin de limiter les coûts.
