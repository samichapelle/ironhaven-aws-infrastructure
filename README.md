# Ironhaven

Infrastructure AWS sécurisée et reproductible, provisionnée avec Terraform, configurée avec Ansible et validée par GitHub Actions.

## Objectif du projet

Ironhaven est un projet pratique consacré au cycle de vie complet d’une infrastructure cloud sécurisée : provisionnement, configuration, validation, supervision et destruction contrôlée.

L’infrastructure sera entièrement reproductible à partir du code, avec une attention particulière portée à la sécurité, à la maintenabilité et à la maîtrise des coûts.

## Architecture prévue

- Infrastructure AWS déployée dans la région `eu-west-3`
- VPC dédié, sous-réseaux, routage et groupes de sécurité restrictifs
- Instance EC2 Linux administrée sans exposition publique de SSH
- État Terraform distant, chiffré et stocké dans Amazon S3
- Rôles IAM appliquant le principe du moindre privilège
- Configuration et durcissement Linux automatisés avec Ansible
- Service de démonstration Nginx conteneurisé
- Centralisation des journaux et métriques avec Amazon CloudWatch
- Validation continue avec GitHub Actions
- Environnements temporaires détruits lorsqu’ils ne sont pas utilisés

## Technologies

- AWS
- Terraform
- Ansible
- Docker
- Nginx
- GitHub Actions
- Linux

## État du projet

🚧 Cadrage initial et préparation de l’environnement de travail.