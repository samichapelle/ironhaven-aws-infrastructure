# Troubleshooting — Ironhaven

Ce document recense uniquement les incidents techniques ayant bloqué le déploiement ou affecté directement l’architecture d’Ironhaven.

Les erreurs mineures liées au poste de travail, à l’interface ou à la saisie ne sont pas conservées.

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