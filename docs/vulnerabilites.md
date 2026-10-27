# Gestion des vulnérabilités

## D'où viennent les alertes

| Source | Ce qu'elle signale | Où la voir |
|---|---|---|
| `uv audit` (CI) | une dépendance a une faille connue | échec du job `quality` |
| Dependabot alerts | idem, en continu | onglet Security du dépôt |
| Dependabot version updates | nouvelle version d'une dépendance ou d'une action | pull requests ouvertes par `dependabot[bot]` |
| gitleaks | un secret a été committé | à lancer sur l'historique avant toute publication |
| Trivy (CI, workflow `Container`) | une faille connue dans le système de base ou l'interpréteur de l'image | échec de l'étape « Analyser l'image » |


## Délais de traitement

| Gravité | Exemple | Délai pour corriger |
|---|---|---|
| Critique | exécution de code à distance dans une dépendance de production | 24 heures |
| Haute | fuite d'information, contournement d'authentification | 7 jours |
| Moyenne ou basse | déni de service limité, dépendance de développement uniquement | prochain cycle de mise à jour |

Une faille dans une dépendance de **production** passe avant une faille dans un outil de
développement (`pytest`, `ruff`, `mypy`). Vérifier avec `uv audit --no-dev`.

## Procédure

1. Lire l'avis : paquet concerné, versions touchées, version corrigée.
2. Vérifier si le code du projet utilise la fonction concernée.
3. Corriger sur une branche en montant la version : `uv lock --upgrade-package <paquet>`.
4. La CI doit être verte (tests, couverture, `uv audit`), puis fusion en squash.
5. Publier une nouvelle version si la dépendance est en production (voir le README).

## Ignorer une alerte

Interdit par défaut. Accepté seulement si la faille ne s'applique pas à l'usage du projet,
avec une trace écrite (date, identifiant `GHSA-` ou `CVE-`, justification, date de réexamen)
dans ce fichier. Jamais pour faire passer la CI.

## Secret committé

Un secret publié est compromis, même supprimé ensuite :

1. révoquer le secret chez le fournisseur ;
2. vérifier ses usages dans les journaux du fournisseur ;
3. nettoyer l'historique du dépôt si nécessaire.

