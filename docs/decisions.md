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
- Séparation : GitHub Actions utilisera à terme un rôle IAM via OIDC, indépendant de cette connexion humaine.
- État : identité `ironhaven-cli` vérifiée avec STS ; intégration Terraform et permissions de déploiement encore à configurer.

## 003 — Détruire l'environnement pendant les pauses

- Contexte : budget cible de 15–20 € et travail par sessions espacées.
- Décision : rendre les ressources du lab reproductibles et les détruire hors utilisation prolongée.
- Justification : maîtriser les coûts et démontrer la capacité de reconstruction.
- Compromis : temps de redéploiement ; le stockage persistant éventuel doit être inventorié et son coût évalué.
- État : procédure de destruction et contrôle des ressources résiduelles à construire et tester.