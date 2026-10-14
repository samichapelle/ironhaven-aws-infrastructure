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

Terraform utilise `manage_master_user_password = true`.

Amazon RDS génère et stocke le secret maître dans
AWS Secrets Manager. Terraform expose uniquement son ARN.

Lors du test initial, l'instance applicative pouvait lire ce secret grâce à une
permission temporaire `secretsmanager:GetSecretValue` limitée à
la ressource concernée.

Les identifiants ne sont pas codés en dur dans Terraform
et n'ont pas été affichés lors de la validation SQL.

La gestion du mot de passe par RDS ne suffit pas,
à elle seule, à démontrer que la rotation périodique
est actuellement activée. Ce point reste à confirmer.

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

### Validation de l'instance RDS

Les contrôles initiaux ont porté sur le statut RDS,
le chiffrement, l'absence d'accès public et le secret maître.

![Validation RDS](screenshots/rds-postgresql-validation.png)

### Validation applicative du 14 octobre 2026

Une EC2 Amazon Linux 2023 a été créée dans
le subnet `10.42.20.0/24` avec l'adresse `10.42.20.104`.

Les contrôles suivants ont été réalisés :

| Vérification | Résultat |
|---|---|
| Absence d'IPv4 publique | PASS |
| Administration SSM | PASS |
| Rôle IAM dédié | PASS |
| DNS privé RDS | PASS |
| TCP 5432 vers RDS | PASS |
| Lecture du secret via le rôle IAM | PASS |
| Authentification PostgreSQL | PASS |
| Exécution réelle d'une requête SQL | PASS |

La connexion utilise le compte `ironhaven_admin`
et l'option `sslmode=require`.

La requête exécutée a été :

```sql
SELECT
  current_database(),
  current_user,
  inet_server_addr(),
  now();
```

Le résultat a confirmé :

- la base `ironhaven` ;
- l'utilisateur `ironhaven_admin` ;
- l'adresse privée RDS `10.42.30.44`.

Une seconde validation a confirmé PostgreSQL 18.3.

![Connexion PostgreSQL depuis EC2 privée](screenshots/application-rds-postgresql-success.png)

Le secret a été récupéré grâce au rôle IAM de l'EC2,
sans affichage du mot de passe.

Le mode TLS `require` chiffre la connexion, mais ne
vérifie pas intégralement le certificat du serveur.
Le mode `verify-full` serait préférable en production.

Ce test utilise le compte maître RDS. Un utilisateur
SQL applicatif dédié, avec des droits limités,
a depuis été créé ; le service HTTP Flask utilise `ironhaven_reader` avec IAM.

Cette validation prouve une connexion SQL effective,
pas encore un service applicatif HTTP intégré.

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
- rôle IAM applicatif limité à `rds-db:connect` (validé) ;
- authentification TLS vérifiée côté client (`verify-full`, validée) ;
- tests réguliers de restauration.

La prochaine étape est le déploiement automatisé du service HTTP applicatif, puis la validation d'une requête SQL réalisée par ce service.

## Durcissement final : authentification IAM et lecture seule

La première validation PostgreSQL a utilisé le compte maître
RDS pour confirmer la connectivité. L'application a ensuite
été migrée vers une authentification IAM avec un compte dédié.

### Identité et autorisations

- Compte PostgreSQL : `ironhaven_reader`.
- Authentification : rôle `rds_iam` et jeton IAM temporaire.
- Autorisation IAM : `rds-db:connect` limitée à ce compte.
- Autorisations SQL : `CONNECT`, `USAGE` sur `public`
  et `SELECT` sur `public.ironhaven_components`.
- Écritures `INSERT`, `UPDATE` et `DELETE` : refusées.
- Secret maître : inaccessible depuis le rôle applicatif.

Le compte maître `ironhaven_admin` reste nécessaire aux
opérations d'administration de RDS, mais n'est plus utilisé
par Flask. Le secret administrateur continue d'être géré
par Secrets Manager.

### Chiffrement et validation

La connexion utilise le point de terminaison DNS RDS,
`sslmode=verify-full` et le bundle CA officiel Amazon RDS.
Un test réel a confirmé la négociation TLS 1.3,
l'authentification IAM et la lecture des trois enregistrements.

Une tentative réelle d'écriture a été refusée.
La récupération du secret administrateur depuis l'EC2
applicative a également renvoyé `AccessDeniedException`.

![Connexion IAM et requêtes HTTP depuis management](screenshots/application-iam-tls-validation.png)

![PostgreSQL : IAM, TLS 1.3, lecture autorisée, écriture refusée](screenshots/application-rds-readonly-validation.png)

![IAM : lecture du secret maître refusée](screenshots/application-secret-access-denied.png)

### Séparation provisionnement / exploitation

Le script `ansible/files/database/create_reader.py` documente
le provisionnement initial du rôle SQL, effectué avant la
révocation de l'accès au secret administrateur.

Le playbook `database-reader.yml` est un outil de
*bootstrap administrateur*, et non un playbook à lancer
régulièrement avec les permissions applicatives actuelles.

Le playbook `test-database-iam.yml` vérifie séparément
la connexion IAM, le certificat TLS et le refus d'écriture.

Le déploiement courant de Flask est piloté par
`ansible/playbooks/application.yml` et ne requiert plus
l'accès au secret maître.

### Limites résiduelles

L'API reste en HTTP sur le réseau privé du VPC.
Une terminaison HTTPS interne, des tests automatisés
supplémentaires et une stratégie de rotation/maintenance
des identités demeurent des axes d'amélioration.
