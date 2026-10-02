# Ironhaven

Infrastructure AWS sécurisée et reproductible, provisionnée avec Terraform et administrée sans exposition publique de SSH.

## Objectif du projet

Ironhaven est un projet pratique consacré au cycle de vie complet d’une infrastructure cloud sécurisée : provisionnement, configuration, validation, supervision et destruction contrôlée.

L’objectif est de construire une architecture AWS segmentée et reproductible, puis d’automatiser sa configuration avec Ansible. Une attention particulière est portée au principe du moindre privilège, à la traçabilité, à la maintenabilité et à la maîtrise des coûts.

## Architecture

L’infrastructure est déployée dans la région AWS `eu-west-3` et comprend actuellement :

- un VPC dédié `10.42.0.0/16` ;
- un sous-réseau public et deux sous-réseaux privés ;
- une Internet Gateway et une table de routage publique ;
- trois groupes de sécurité représentant les couches management, application et données ;
- un rôle IAM et un instance profile dédiés à AWS Systems Manager ;
- une instance EC2 Amazon Linux 2023 administrée exclusivement avec Session Manager.

L’instance de management ne possède aucune règle entrante. Aucun port SSH n’est exposé et aucune clé privée n’est nécessaire pour son administration.

La documentation détaillée est disponible dans [docs/architecture.md](docs/architecture.md).

## Sécurité

Les principaux contrôles actuellement appliqués sont :

- authentification MFA pour l’utilisateur AWS du projet ;
- politique IAM dédiée et limitée aux ressources Ironhaven ;
- segmentation réseau en plusieurs couches ;
- groupes de sécurité restrictifs ;
- absence de règle entrante ouverte sur Internet ;
- administration par AWS Systems Manager Session Manager ;
- métadonnées EC2 limitées à IMDSv2 ;
- volume système chiffré ;
- exclusion du state Terraform et des informations sensibles du dépôt Git.

## Technologies

### Actuellement utilisées

- AWS
- Terraform
- AWS IAM
- AWS Systems Manager
- Amazon EC2
- Amazon Linux 2023
- Git et GitHub
- WSL2 Ubuntu

### Prévues

- Ansible
- Docker
- Nginx
- Amazon CloudWatch
- Amazon S3
- GitHub Actions
- composant de sécurité pour agent IA

## État du projet

### Terminé

- [x] Configuration sécurisée de l’accès AWS avec MFA
- [x] Mise en place du socle Terraform
- [x] Création du VPC et des trois sous-réseaux
- [x] Configuration du routage public
- [x] Création des groupes et règles de sécurité
- [x] Création du rôle IAM et de l’instance profile SSM
- [x] Déploiement d’une instance EC2 Amazon Linux 2023
- [x] Validation de l’administration sans SSH avec Session Manager
- [x] Documentation de l’architecture réseau

### Prochaines étapes

- [ ] Automatiser la configuration Linux avec Ansible
- [ ] Déployer la couche applicative
- [ ] Déployer ou simuler la couche de données
- [ ] Ajouter la journalisation et la supervision
- [ ] Mettre en place les contrôles de sécurité pour agent IA
- [ ] Ajouter les validations CI avec GitHub Actions
- [ ] Tester la reconstruction et la destruction complète de l’environnement

## Structure du dépôt

```text
.
├── docs/
│   ├── architecture.md
│   ├── decisions.md
│   ├── troubleshooting.md
│   └── screenshots/
└── terraform/
    ├── compute.tf
    ├── iam.tf
    ├── network.tf
    ├── outputs.tf
    ├── provider.tf
    ├── routing.tf
    ├── security.tf
    ├── variables.tf
    └── versions.tf
```

## Avertissement

Ce dépôt correspond à un environnement de laboratoire et de démonstration. Les ressources AWS sont temporaires et doivent être arrêtées ou détruites lorsqu’elles ne sont pas utilisées afin de limiter les coûts.
