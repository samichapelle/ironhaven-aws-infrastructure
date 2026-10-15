# Cycle de vie, sauvegarde et fermeture AWS — Ironhaven

## Périmètre

Ironhaven est un laboratoire AWS temporaire dans la région
`eu-west-3`, destiné à être intégralement supprimé après
validation de ses fonctionnalités.

Le code Terraform et Ansible, la documentation et les captures
restent dans GitHub. Le state Terraform réel et les secrets
ne doivent pas être publiés.

## Validation du 15 octobre 2026

Contrôles effectivement réalisés :

- `terraform validate` : configuration valide ;
- `terraform plan -detailed-exitcode` : code de sortie `0`,
  aucune différence entre infrastructure et configuration ;
- state téléchargé depuis le backend S3, analysé comme JSON
  et conservé localement hors dépôt ;
- bucket de state S3 vérifié avec `head-object` ;
- deux EC2 `t3.micro` observées à l'état `running` ;
- une NAT Gateway observée à l'état `available` ;
- RDS PostgreSQL `db.t4g.micro`, 20 Gio, observé `available` ;
- bucket S3 de transfert Ansible et bucket de state recensés ;
- trois alarmes CloudWatch observées à l'état `OK` ;
- GitHub Actions : audit IaC Trivy et Ansible-lint
  bloquants validés, avec quatre risques IaC acceptés.

La validation du bootstrap PostgreSQL sur base existante,
les contrôles IAM/TLS et la simulation d'alarme sont décrits
dans les autres documents du projet.

Une reconstruction intégrale depuis zéro n'a pas été validée.

## Sauvegarde locale

Le state a été conservé sur le poste WSL dans :

`~/ironhaven-state-backup/terraform-final-2026-10-15.tfstate`

Ce chemin est local au poste de développement et n'est
pas un artefact GitHub.

Le fichier peut contenir des valeurs sensibles et doit
rester privé. Une copie chiffrée sur un support indépendant
est recommandée avant la fermeture définitive du compte.

## Destruction : à exécuter après les dernières démonstrations

1. Conserver captures, logs de validation et commits GitHub.
2. Examiner `terraform plan -destroy` avant toute action.
3. Vérifier les conséquences sur PostgreSQL :
   absence possible de snapshot final selon la configuration.
4. N'exécuter `terraform destroy` qu'après accord explicite.
5. Contrôler les ressources résiduelles hors Terraform :
   bucket S3 du state et toutes ses versions,
   objets temporaires, identités et politiques IAM manuelles,
   intégration OIDC, éventuels snapshots et secrets.
6. Vérifier les autres régions AWS éventuellement utilisées.
7. Contrôler Billing/Cost Explorer et l'état du forfait.
8. Envisager ensuite la fermeture du compte via AWS Console.

Cette liste décrit une procédure prévue. Elle ne prétend
pas que la destruction ou la fermeture est déjà effectuée.

**Important :** le backend S3 est indépendant du Terraform
principal. Ne supprimer son bucket qu'après la destruction
et les vérifications finales ; la sauvegarde locale doit
être conservée en lieu sûr.

## Limites

Le verrouillage natif S3 `use_lockfile = true` est configuré,
mais aucun test concurrent explicite n'a été réalisé.

Le state sauvegardé n'est pas une sauvegarde complète des
données d'une instance RDS ni des ressources AWS détruites.

La reprise d'un environnement dans un nouveau compte cloud
nécessiterait notamment de recréer les dépendances IAM,
les données SQL et le backend Terraform.
