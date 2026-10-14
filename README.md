# Ironhaven

Infrastructure AWS sécurisée et reproductible, provisionnée avec Terraform, configurée avec Ansible et administrée sans exposition publique de SSH.

## Objectif du projet

Ironhaven est un projet pratique consacré au cycle de vie complet d’une infrastructure cloud sécurisée : provisionnement, configuration, durcissement, validation, supervision et destruction contrôlée.

L’objectif est de construire une architecture AWS segmentée et reproductible, puis d’automatiser sa configuration et ses contrôles de sécurité. Une attention particulière est portée au principe du moindre privilège, à la traçabilité, à la maintenabilité et à la maîtrise des coûts.

## Architecture

Ironhaven est déployé en région AWS `eu-west-3` dans un
VPC `10.42.0.0/16` segmenté en trois couches.

| Couche | Ressource | Réseau |
|---|---|---|
| Management | EC2 Amazon Linux 2023 | 10.42.10.21 |
| Application | EC2 Amazon Linux 2023 | 10.42.20.104 |
| Données | RDS PostgreSQL | Sous-réseaux privés |

L'infrastructure comprend :

- quatre subnets : public, application et deux subnets de données ;
- une Internet Gateway et une NAT Gateway ;
- des tables de routage publique et privée ;
- trois Security Groups aux flux restrictifs ;
- deux instances EC2 administrées sans SSH via Systems Manager ;
- des rôles IAM distincts pour management et application ;
- un bucket S3 privé pour les transferts Ansible ;
- un service Nginx conteneurisé sur management ;
- une base PostgreSQL RDS privée et chiffrée ;
- un secret RDS géré par AWS Secrets Manager ;
- des journaux et métriques CloudWatch ;
- une analyse Trivy automatisée avec GitHub Actions.

L'EC2 applicative n'a aucune adresse IPv4 publique.
Le port PostgreSQL `5432` est autorisé depuis le
Security Group applicatif uniquement.

Le 14 octobre 2026, une session SSM a permis de vérifier
le rôle IAM applicatif, de récupérer le secret RDS et
d'exécuter une requête SQL réelle avec TLS demandé.

![Connexion PostgreSQL validée](docs/screenshots/application-rds-postgresql-success.png)

Le service HTTP de la couche applicative reste à déployer.
Le Nginx existant sur management fonctionne déjà.

### Documentation technique

- [Architecture AWS](docs/architecture.md)
- [Administration Ansible](docs/ansible.md)
- [Conteneur Nginx](docs/container.md)
- [CloudWatch](docs/monitoring.md)
- [PostgreSQL et validation RDS](docs/database.md)
- [Analyse Trivy et CI](docs/security-scanning.md)
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
- gestion du secret maître RDS par Secrets Manager ; rotation périodique à vérifier ;
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

### Réalisé et validé

- [x] Authentification AWS avec identifiants temporaires et MFA
- [x] Provisionnement Terraform du VPC et des quatre subnets
- [x] Internet Gateway, NAT Gateway et routage privé
- [x] Security Groups restrictifs
- [x] EC2 management et administration SSM
- [x] Automatisation Ansible via SSM et bucket S3
- [x] Durcissement Linux et configuration de base
- [x] Docker et Nginx sur management
- [x] Tests HTTP du service Nginx
- [x] CloudWatch Logs et métriques système
- [x] Analyse Trivy et remédiation des vulnérabilités
- [x] Pipeline GitHub Actions de sécurité
- [x] RDS PostgreSQL privée avec stockage chiffré
- [x] Gestion du secret maître avec Secrets Manager
- [x] EC2 applicative privée sans IP publique
- [x] Rôle IAM applicatif dédié
- [x] Connexion SSM sur l'EC2 applicative
- [x] Résolution DNS et connectivité PostgreSQL TCP 5432
- [x] Lecture du secret RDS depuis le rôle IAM applicatif
- [x] Connexion PostgreSQL et requête SQL réelle
- [x] Capture de validation SQL publiée sur GitHub

### À terminer

- [ ] Déployer le service HTTP dans la couche applicative
- [ ] Automatiser son déploiement avec Ansible
- [ ] Tester HTTP depuis management vers application
- [ ] Tester l'intégration HTTP vers PostgreSQL
- [ ] Collecter les preuves visuelles finales
- [ ] Vérifier la reproductibilité et l'état Terraform final
- [ ] Contrôler les coûts et nettoyer les ressources AWS

L'extension expérimentale de sécurité pour agent IA
reste hors du périmètre de livraison de cette V1.

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
    ├── application.tf
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

L'environnement est temporaire et son coût est surveillé.

- Les instances EC2 peuvent être arrêtées entre les sessions.
- RDS peut être arrêtée temporairement, mais son stockage
  et ses sauvegardes peuvent rester facturés.
- La NAT Gateway est facturée tant qu'elle reste provisionnée,
  même lorsque les instances sont arrêtées.
- Les journaux CloudWatch sont conservés sept jours.
- Les objets temporaires du bucket S3 expirent automatiquement.
- Les fichiers `.tfstate`, `.tfvars` et `.tfplan`
  sont exclus du dépôt Git.

Une destruction contrôlée est prévue après les validations
finales, sous réserve de sauvegarder les livrables utiles.

## Avertissement

Ce dépôt correspond à un environnement de laboratoire et de démonstration. Les ressources AWS sont temporaires et doivent être arrêtées ou détruites lorsqu’elles ne sont pas utilisées afin de limiter les coûts.
