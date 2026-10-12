# Base de données PostgreSQL — Ironhaven

## Objectif

La couche de données d’Ironhaven repose sur une instance Amazon RDS for PostgreSQL déployée avec Terraform. Elle complète l’architecture en trois tiers et fournit un service relationnel administré, privé et chiffré.

La base n’est pas exposée à Internet. Seules les ressources associées au groupe de sécurité de la couche application peuvent initier une connexion PostgreSQL.

## Architecture

La couche de données comprend :

- deux sous-réseaux privés répartis dans deux zones de disponibilité ;
- un groupe de sous-réseaux RDS multi-AZ ;
- une instance PostgreSQL Single-AZ adaptée à l’environnement de laboratoire ;
- un groupe de sécurité dédié à la couche données ;
- un secret géré automatiquement par Amazon RDS dans AWS Secrets Manager ;
- l’export des journaux PostgreSQL et de mise à niveau vers Amazon CloudWatch Logs.

| Élément | Configuration |
|---|---|
| Moteur | Amazon RDS for PostgreSQL |
| Classe | `db.t4g.micro` |
| Base initiale | `ironhaven` |
| Port | `5432/TCP` |
| Stockage | `20 GiB` GP3, extensible jusqu’à `30 GiB` |
| Chiffrement | Activé au repos avec AWS KMS |
| Accès public | Désactivé |
| Déploiement | Single-AZ |
| Sauvegardes automatiques | Conservation pendant un jour |
| Authentification IAM | Activée |
| Identifiants principaux | Générés et gérés par AWS Secrets Manager |

Le déploiement Single-AZ limite les coûts pendant la phase de laboratoire. Les deux sous-réseaux privés restent néanmoins nécessaires au groupe de sous-réseaux RDS et préparent une éventuelle évolution vers un déploiement Multi-AZ.

## Segmentation réseau

L’instance RDS utilise le groupe de sécurité `ironhaven-data-sg`. Sa seule règle entrante applicative autorise PostgreSQL sur le port TCP `5432` depuis `ironhaven-application-sg`.

Cette règle s’appuie sur une référence entre groupes de sécurité et non sur une adresse IP fixe. Une ressource doit donc appartenir explicitement à la couche application pour joindre la base.

Les conséquences sont les suivantes :

- aucun accès depuis Internet ;
- aucun accès direct depuis la couche management ;
- aucun port PostgreSQL ouvert sur `0.0.0.0/0` ;
- trafic limité au chemin application vers données.

## Gestion des identifiants

Terraform ne contient aucun mot de passe de base de données. L’option `manage_master_user_password` demande à Amazon RDS de :

1. générer un mot de passe aléatoire ;
2. l’enregistrer dans AWS Secrets Manager ;
3. chiffrer le secret avec AWS KMS ;
4. gérer sa rotation automatiquement.

Terraform expose uniquement l’ARN du secret afin que les composants autorisés puissent le référencer. L’ARN n’est pas un secret, mais la valeur retournée par `secretsmanager:GetSecretValue` ne doit jamais être enregistrée dans le dépôt, une capture d’écran ou les journaux CI.

## Configuration Terraform

La brique est principalement définie dans :

- `terraform/database.tf` pour le groupe de sous-réseaux et l’instance RDS ;
- `terraform/network.tf` pour le second sous-réseau privé de données ;
- `terraform/security.tf` pour le flux application vers PostgreSQL ;
- `terraform/variables.tf` pour les paramètres configurables ;
- `terraform/outputs.tf` pour les métadonnées non sensibles.

Les paramètres de laboratoire facilitent également une destruction contrôlée :

- protection contre la suppression désactivée ;
- snapshot final désactivé ;
- suppression des sauvegardes automatisées lors de la destruction.

Ces choix sont adaptés à une infrastructure temporaire. Ils devraient être renforcés dans un environnement de production avec une protection contre la suppression, une politique de sauvegarde plus longue et un snapshot final obligatoire.

## Validation

Après le déploiement, les contrôles ont confirmé :

- le statut `available` de l’instance ;
- le chiffrement du stockage ;
- l’absence d’exposition publique ;
- le statut `active` du secret géré par RDS ;
- l’activation de la rotation du secret ;
- l’absence de divergence entre l’infrastructure AWS et le code Terraform.

![Validation de l’instance RDS PostgreSQL](screenshots/rds-postgresql-validation.png)

La commande `terraform plan` retourne :

```text
No changes. Your infrastructure matches the configuration.
```

## Exploitation temporaire

L’instance peut être arrêtée entre deux sessions afin d’éviter la facturation des heures de calcul :

```bash
AWS_PROFILE=ironhaven aws rds stop-db-instance \
  --db-instance-identifier ironhaven-postgresql
```

Elle peut ensuite être redémarrée avec :

```bash
AWS_PROFILE=ironhaven aws rds start-db-instance \
  --db-instance-identifier ironhaven-postgresql

AWS_PROFILE=ironhaven aws rds wait db-instance-available \
  --db-instance-identifier ironhaven-postgresql
```

L’arrêt conserve le stockage, les données, la configuration et l’endpoint. Le stockage et les sauvegardes restent facturés, et AWS redémarre automatiquement une instance arrêtée après sept jours consécutifs.

## Limites et évolution

Cette implémentation constitue une base de démonstration sécurisée, mais plusieurs améliorations seraient nécessaires en production :

- déploiement Multi-AZ ;
- conservation plus longue des sauvegardes ;
- protection contre la suppression ;
- clé KMS gérée par le client ;
- surveillance et alarmes dédiées à RDS ;
- accès au secret limité au rôle IAM de l’application ;
- authentification TLS vérifiée côté client ;
- tests réguliers de restauration.

La prochaine étape du projet consiste à déployer une ressource dans la couche application, lui accorder un accès minimal au secret, puis valider une connexion réelle à PostgreSQL sans identifiants codés en dur.
