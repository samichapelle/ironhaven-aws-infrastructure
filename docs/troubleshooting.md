# Troubleshooting — Ironhaven

Ce document recense uniquement les incidents techniques ayant bloqué le déploiement ou affecté directement l’architecture d’Ironhaven.

Les erreurs mineures liées au poste de travail, à l’interface ou à la saisie ne sont pas conservées.

## Index des incidents

| Domaine | Incident | Section |
|---|---|---|
| IAM / Terraform | Création des Security Groups refusée | [Diagnostic IAM initial](#politique-iam-insuffisante-pour-le-déploiement-réseau) |
| AWS / Réseau | Elastic IP refusée | [Incidents des 13–14 octobre](#incidents-du-1314-octobre-2026) |
| Terraform | Remplacement inattendu d'EC2 | [Incidents des 13–14 octobre](#incidents-du-1314-octobre-2026) |
| Terraform / IAM | Rafraîchissement du state bloqué | [Incidents des 13–14 octobre](#incidents-du-1314-octobre-2026) |
| IAM | Tagging de l'instance profile refusé | [Incidents des 13–14 octobre](#incidents-du-1314-octobre-2026) |
| SSM | Accès CLI refusé | [Incidents des 13–14 octobre](#incidents-du-1314-octobre-2026) |
| PostgreSQL | Premier contrôle de connexion TLS | [Incidents des 13–14 octobre](#incidents-du-1314-octobre-2026) |
| PostgreSQL / SSM | Bootstrap et permissions SQL | [Bootstrap](#bootstrap-postgresql-et-séparation-des-privilèges) |
| CI / Ansible | Contrôle Ansible-lint bloquant | [Ansible-lint](#échec-ansible-lint-sur-le-playbook-de-récupération) |
| CI / Réseau | Délai d'attente Ansible Galaxy | [Galaxy](#échec-de-téléchargement-de-collections-ansible-galaxy) |
| IaC / Sécurité | Gestion des exceptions Trivy | [Trivy](#gestion-des-alertes-trivy-iac) |

Pour la panne applicative provoquée et sa récupération, voir
[Incident Recovery](incident-recovery.md).

## Politique IAM insuffisante pour le déploiement réseau

### Contexte

L’infrastructure est déployée avec l’utilisateur IAM `ironhaven-cli` et une politique personnalisée limitée aux besoins du projet.

Cette approche applique le principe du moindre privilège, mais nécessite d’adapter progressivement les permissions à mesure que le périmètre Terraform évolue.

### Symptôme principal

Après l’ajout des groupes de sécurité, `terraform apply` a échoué avec une erreur HTTP `403 UnauthorizedOperation`.

L’action refusée était :

```text
ec2:CreateSecurityGroup
```

Les trois créations suivantes ont été bloquées :

```text
ironhaven-management-sg
ironhaven-application-sg
ironhaven-data-sg
```

### Cause

La politique IAM autorisait la gestion des éléments réseau déjà déployés :

- VPC ;
- sous-réseaux ;
- Internet Gateway ;
- tables de routage ;
- routes et associations.

Elle ne contenait cependant pas encore les permissions nécessaires à la création et à la gestion des groupes de sécurité.

### Diagnostic

Le diagnostic s’est appuyé sur trois éléments :

1. le code HTTP `403`, indiquant un refus d’autorisation ;
2. l’identité IAM mentionnée dans l’erreur ;
3. l’action AWS précisément refusée : `ec2:CreateSecurityGroup`.

L’échec ne provenait donc ni de la syntaxe Terraform ni de la configuration du VPC.

### Correction

La politique IAM personnalisée a été étendue avec les actions nécessaires :

```text
ec2:CreateSecurityGroup
ec2:DeleteSecurityGroup
ec2:AuthorizeSecurityGroupIngress
ec2:RevokeSecurityGroupIngress
ec2:AuthorizeSecurityGroupEgress
ec2:RevokeSecurityGroupEgress
```

Les opérations de lecture EC2 ont également été regroupées sous :

```text
ec2:Describe*
```

Cette seconde modification permet à Terraform et à la console AWS de consulter les métadonnées nécessaires, notamment pour afficher le mappage complet du VPC.

Les opérations d’écriture restent explicitement limitées aux besoins du projet et à la région `eu-west-3`.

### Validation

La configuration a d’abord été contrôlée sans modifier l’infrastructure :

```bash
terraform -chdir=terraform fmt -check -recursive
terraform -chdir=terraform validate
AWS_PROFILE=ironhaven terraform -chdir=terraform plan
```

Le plan attendu indiquait :

```text
Plan: 12 to add, 0 to change, 0 to destroy.
```

Après vérification du plan, l’application a été relancée :

```bash
AWS_PROFILE=ironhaven terraform -chdir=terraform apply
```

Les trois groupes de sécurité et leurs neuf règles ont alors été créés avec succès.

La console AWS a également pu afficher le mappage complet des ressources du VPC.

### Résultat

La correction a permis de poursuivre le déploiement sans attribuer de droits administrateur généraux à l’utilisateur Terraform.

L’incident a confirmé le fonctionnement attendu du modèle retenu :

- permissions IAM accordées selon les besoins ;
- séparation des droits de lecture et d’écriture ;
- analyse de l’action explicitement refusée ;
- validation avec `terraform plan` avant application ;
- absence d’utilisation du compte root pour les opérations courantes.

### Enseignement

Une erreur IAM ne doit pas être corrigée en accordant immédiatement des permissions globales.

La méthode retenue consiste à :

1. identifier l’action AWS refusée ;
2. vérifier si elle est légitime pour le projet ;
3. ajouter uniquement les permissions nécessaires ;
4. contrôler le nouveau plan Terraform ;
5. valider le fonctionnement après application.

## Incidents du 13–14 octobre 2026

### 1. Allocation Elastic IP refusée

**Erreur :** `ec2:AllocateAddress` — AccessDenied.

**Cause :** permission manquante sur l'utilisateur Terraform.

**Correction :** extension des permissions EC2 nécessaires
à l'allocation d'Elastic IP et à la création de la NAT Gateway.

**Résultat :** quatre ressources réseau créées avec succès.

### 2. Remplacement inattendu de l'EC2 management

**Symptôme :** `aws_instance.management must be replaced`.

**Cause :** nouvelle AMI sélectionnée avec `most_recent = true`.

**Correction :** AMI management figée, puis différences
de `user_data` ignorées pour l'instance existante.

**Résultat :** plan sans modification ni destruction.

### 3. Rafraîchissement Terraform bloqué par IAM

**Erreurs rencontrées :**

- `iam:ListRolePolicies`
- `logs:ListTagsForResource`
- `s3:GetBucketPolicy`
- `s3:GetBucketAcl`
- `s3:GetBucketCORS`
- `s3:GetAccelerateConfiguration`

**Cause :** droits de lecture incomplets pour le rafraîchissement
des ressources déjà présentes dans le state Terraform.

**Correction :** politique complémentaire IAM et
autorisations S3 de lecture pour le bucket Ironhaven.

**Résultat :** plan Terraform complet obtenu.

### 4. Création de l'instance profile

**Erreur :** `iam:TagInstanceProfile` — AccessDenied.

**Cause :** Terraform devait taguer la nouvelle ressource.

**Correction :** autorisation IAM de tagging de l'instance profile.

**Résultat :** profil et EC2 applicative déployés avec succès.

### 5. Accès Systems Manager refusé depuis le CLI

**Erreur :** `ssm:DescribeInstanceInformation` — AccessDenied.

**Contexte :** PowerUserAccess venait d'être attachée.

**Action effectuée :**

```bash
aws logout --profile ironhaven
aws login --profile ironhaven
```

**Résultat :** les deux instances ont été vues `Online`.

Ce résultat ne permet pas de distinguer avec certitude
une propagation IAM tardive d'un problème de session.

### 6. Connexion SQL depuis EC2 privée

Une session SSM a permis de tester le rôle IAM,
la résolution DNS, le port TCP 5432 et la lecture du secret.

Une requête PostgreSQL réelle a réussi.

**Preuve :** `docs/screenshots/application-rds-postgresql-success.png`

Le premier test présentait un avertissement
`sslmode=require` lié à un argument psql mal placé.
Le second test a utilisé une chaîne de connexion valide.

**Résultat :** connexion PostgreSQL confirmée,
avec chiffrement TLS demandé.

## Bootstrap PostgreSQL et séparation des privilèges

### Contexte

L'application Flask/Gunicorn est hébergée sur une EC2 privée.
Elle utilise une instance RDS PostgreSQL privée, sans accès
direct depuis Internet.

Le compte SQL applicatif `ironhaven_reader` doit disposer
de la lecture seule, sans accès au secret administrateur.

### Difficulté technique

Le provisionnement initial du schéma SQL et du lecteur
nécessite des privilèges différents de ceux accordés à
l'application en exploitation.

Une simple création de ressources Terraform ne suffit pas
à créer ces objets à l'intérieur de PostgreSQL.

### Solution retenue

Le script local `ansible/scripts/bootstrap_database.py` :

1. récupère les métadonnées via les outputs Terraform ;
2. lit le secret administrateur RDS via les autorisations du
   profil AWS utilisé sur le poste de contrôle ;
3. établit un tunnel Systems Manager vers RDS en passant
   par l'instance applicative privée ;
4. vérifie le certificat TLS avec `sslmode=verify-full` ;
5. crée si nécessaire la table et les trois données de
   démonstration ;
6. crée si nécessaire `ironhaven_reader` et lui attribue
   les permissions SQL limitées à la lecture ;
7. vérifie explicitement les droits `SELECT`, `INSERT`,
   `UPDATE` et `DELETE`.

Le rôle IAM de l'instance applicative autorise uniquement
la connexion à RDS sous l'identité `ironhaven_reader`.
Il ne détient plus de permission de lecture du secret maître.

### Validation et limites

Le bootstrap a été exécuté deux fois avec succès sur
l'environnement existant. Les contrôles ont confirmé
la présence des trois enregistrements et les restrictions
SQL du lecteur.

Le fonctionnement applicatif a également été validé
avec authentification IAM et TLS `verify-full`.

Ces tests établissent l'idempotence observée du bootstrap
dans cet environnement, mais ne constituent pas une preuve
de reconstruction intégrale depuis un compte AWS vierge.

**Documentation :** [PostgreSQL](database.md),
[Architecture](architecture.md).

## Échec Ansible-lint sur le playbook de récupération

### Contexte

Après l'exercice de récupération applicative du
15 octobre 2026, le playbook
`ansible/playbooks/incident-recovery.yml`
a été ajouté à l'analyse de qualité GitHub Actions.

### Symptôme

Le job `Ansible | Quality Audit` a échoué sur la règle
`command-instead-of-module`.

La première version utilisait une commande
`systemctl is-active` pour inspecter le service.

### Diagnostic et correction

La commande était fonctionnelle dans le laboratoire,
mais Ansible-lint recommandait d'utiliser un module Ansible
approprié plutôt qu'une commande système directe.

Le contrôle a été remplacé par `ansible.builtin.service_facts`.
L'action de démarrage reste assurée par
`ansible.builtin.systemd_service`.

### Validation

Le workflow `Infrastructure Security Audit` du commit
`06bd90e` a terminé ses deux jobs avec succès.

La version corrigée du playbook a également été exécutée
contre le service déjà actif :

- état initial : `running` ;
- service maintenu sans redémarrage ;
- `/health` sain et PostgreSQL connecté ;
- trois enregistrements accessibles ;
- `changed=0`, `failed=0`, `unreachable=0`.

**Limite importante :** la récupération réelle d'un service
arrêté a été démontrée avec la version précédente du
playbook. La version corrigée a été validée en idempotence
sur un service déjà actif.

**Rapport complet :**
[Incident Recovery](incident-recovery.md).

## Échec de téléchargement de collections Ansible Galaxy

### Contexte

Lors de l'exécution GitHub Actions du commit `3eb9f74`,
le job de contrôle qualité Ansible a échoué pendant
l'installation des collections.

### Symptôme

Le journal affichait notamment :

```text
Failed to download collection tar from 'default'
<urlopen error _ssl.c:983: The handshake operation timed out>
```

Les collections `amazon.aws` et `community.docker` avaient
été installées avec succès avant l'échec du téléchargement
de `community.general`.

### Diagnostic

L'échec s'est produit dans l'étape
`Install Ansible collections`, avant le lancement
d'Ansible-lint.

Il ne constitue donc pas la preuve d'une erreur dans
les playbooks ni d'un échec de validation Ansible-lint.

### Remédiation appliquée

L'étape d'installation Ansible Galaxy a été renforcée
dans `.github/workflows/infrastructure-security.yml` :

- trois tentatives au maximum ;
- délai réseau porté à 120 secondes par tentative ;
- attente de 15 secondes entre les tentatives ;
- échec du job si aucune tentative ne réussit.

Le contrôle Ansible-lint reste obligatoire : la correction
ne supprime ni le scan ni son caractère bloquant.

### Validation

Le commit `c27d905` a été exécuté avec succès dans
GitHub Actions :

- `Trivy | Terraform IaC Audit` : succès ;
- `Ansible | Quality Audit` : succès ;
- durée totale du workflow : 3 min 44 s.

La capture GitHub Actions confirme la réussite du workflow.
Elle ne démontre pas à elle seule qu'une nouvelle tentative
a été nécessaire pendant cette exécution.

Ne pas présenter cette panne réseau comme un défaut
du code applicatif.

## Gestion des alertes Trivy IaC

### Contexte

Le workflow `Infrastructure Security Audit` analyse
les fichiers Terraform avec Trivy en sévérité
`HIGH` et `CRITICAL`.

### Constats documentés

Quatre alertes connues sont conservées dans le périmètre
de laboratoire :

- `AWS-0164`, une occurrence dans `network.tf` ;
- `AWS-0104`, deux occurrences dans `security.tf` ;
- `AWS-0132`, une occurrence dans `storage.tf`.

Elles correspondent respectivement à l'attribution
automatique d'IP publiques, à certaines règles de
sortie réseau et au mode de chiffrement d'un bucket S3.

### Décision

Les risques n'ont pas été silencieusement ignorés.
Une politique explicite compare les alertes détectées
à une liste de référence documentée.

Le commit `3eb9f74` renforce cette politique en exigeant
les cardinalités exactes : une, deux et une occurrences.

Le contrôle échoue si une alerte inattendue apparaît
ou si le nombre d'occurrences attendues change.

### Limites

La comparaison repose sur l'identifiant de règle, le
fichier et le nombre d'occurrences. Elle ne vérifie
pas l'emplacement exact de chaque règle Terraform.

Une alerte identique pourrait remplacer une ancienne
occurrence sans être distinguée par le contrôle.

Le scan ne constitue pas non plus un audit complet
de sécurité cloud. Les exceptions restent spécifiques
à ce laboratoire et ne sont pas des recommandations
pour un environnement de production.

**Détail de chaque exception :**
[Analyses de sécurité](security-scanning.md).
