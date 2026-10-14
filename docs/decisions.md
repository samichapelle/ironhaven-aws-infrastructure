# Décisions techniques

## 001 — Utiliser Ubuntu sous WSL2

- Contexte : poste Windows, avec Terraform, AWS CLI et Ansible à utiliser ensemble.
- Décision : regrouper les outils dans Ubuntu sous WSL2 et conserver le dépôt dans le système de fichiers Linux.
- Justification : Ansible nécessite un environnement compatible Linux/Unix pour son nœud de contrôle. WSL2 permet de conserver Windows comme poste principal.
- Alternative : une VM Linux dédiée aurait également convenu.
- État : environnement installé et commandes vérifiées.

## 002 — Authentifier l'accès humain sans clé AWS permanente

- Contexte : Terraform sera exécuté depuis le poste de travail.
- Décision : utilisateur IAM dédié, passkey déverrouillée par biométrie et connexion par navigateur avec `aws login`.
- Justification : obtenir des identifiants temporaires sans conserver de clé d'accès IAM permanente sur le poste.
- Compromis : AWS CLI 2.32.0 minimum, reconnexion à expiration et présence d'un cache local d'identifiants temporaires.
- Séparation : GitHub Actions utilise désormais un rôle IAM dédié via OIDC, indépendant de cette connexion humaine.
- État : identité `ironhaven-cli` vérifiée avec STS ; intégration Terraform opérationnelle et politique IAM adaptée aux ressources actuellement gérées.

## 003 — Détruire l'environnement pendant les pauses

- Contexte : budget cible de 15–20 € et travail par sessions espacées.
- Décision : rendre les ressources du lab reproductibles et les détruire hors utilisation prolongée.
- Justification : maîtriser les coûts et démontrer la capacité de reconstruction.
- Compromis : temps de redéploiement ; le stockage persistant éventuel doit être inventorié et son coût évalué.
- État : procédure de destruction et contrôle des ressources résiduelles à construire et tester.

## 004 — Utiliser une NAT Gateway pour la couche application

- Contexte : une EC2 privée doit accéder aux API AWS et aux dépôts.
- Décision : NAT Gateway publique et routage privé applicatif.
- Justification : sortie Internet sans IP publique sur l'EC2.
- Compromis : coûts horaires et trafic NAT.
- État : déployé le 13 octobre 2026.

## 005 — Séparer management et application

- Décision : deux EC2 et deux rôles IAM distincts.
- Justification : isolation des fonctions et des permissions.
- État : EC2 privée déployée le 14 octobre 2026.

## 006 — Authentification PostgreSQL IAM et moindre privilège

- Historique : le premier test utilisait provisoirement `GetSecretValue` avec le compte maître RDS.
- Décision actuelle : IAM DB authentication (`rds-db:connect`) uniquement pour `ironhaven_reader`.
- Permissions SQL : `SELECT` sur `public.ironhaven_components`, écriture refusée.
- TLS : `sslmode=verify-full` avec certificat CA RDS validé.
- État : lecture réussie, écriture refusée et accès au secret maître refusé depuis l'EC2 applicative.

## 007 — Permissions temporaires du déploiement

- Contexte : refus IAM répétés pendant le provisionnement.
- Décision : PowerUserAccess temporaire pour ironhaven-cli.
- Distinction : les rôles EC2 conservent leurs droits propres.
- Compromis : droits de déploiement plus larges pendant le lab.
- Suite : supprimer cet accès après finalisation.

## 008 — Stabiliser l'instance management

- Contexte : une nouvelle AMI provoquait un remplacement Terraform.
- Décision : figer son AMI et ignorer les écarts de user_data.
- Justification : préserver la configuration Ansible existante.
- Limite : ces évolutions devront être gérées explicitement.
- État : plan validé sans remplacement de management.
