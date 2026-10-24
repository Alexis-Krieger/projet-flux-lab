# flux-lab

Petit service HTTP qui reçoit des messages d'intégration, les valide et refuse les doublons.
Projet fil rouge d'apprentissage : API Python, CI/CD sécurisée, exploitation.

## Ce que fait le service

| Route | Rôle |
|---|---|
| `GET /health` | le processus est vivant (liveness) |
| `GET /ready` | le stockage est utilisable (readiness) |
| `POST /messages` | reçoit un message `{id, type, payload}` |

Réponses de `POST /messages` :

| Code | Sens |
|---|---|
| `202` | message accepté |
| `409` | `id` déjà reçu (doublon) |
| `422` | message invalide (champ manquant ou vide) |
| `503` | stockage indisponible : réessayer plus tard |

## Prérequis

- Python 3.12
- [uv](https://docs.astral.sh/uv/)
- Git Bash (Windows) ou un shell POSIX

## Démarrer en local

```bash
uv sync
bash scripts/run.sh test
```

Puis, dans un autre terminal :

```bash
curl -s http://127.0.0.1:8001/health
curl -s -X POST http://127.0.0.1:8001/messages \
  -H "Content-Type: application/json" \
  -d '{"id":"abc-1","type":"commande","payload":{"montant":42}}'
```

## Vérifier la qualité

```bash
uv run ruff check . && uv run ruff format --check . && uv run mypy
uv run pytest --cov=flux_lab --cov-fail-under=90
uv audit --locked --preview-features audit-command
```

La CI exécute les mêmes contrôles à chaque pull request.

## Déployer

Une version est un tag Git (`vX.Y.Z`). Le workflow `Release` construit le paquet,
lance un test de fumée, puis publie une release GitHub après approbation.

Déploiement local d'une version dans un environnement :

```bash
bash scripts/deploy.sh <test|prod> <tag>
bash scripts/start.sh <test|prod>
```

Retour arrière : redéployer la version précédente avec la même commande.

## Configuration

Un fichier par environnement dans `config/` (`test.env`, `prod.env`).
Aucun secret n'y figure.

| Variable | Rôle |
|---|---|
| `PORT` | port d'écoute |
| `FLUX_LAB_DB` | chemin du fichier SQLite |

## Logs

Une ligne JSON par événement : `message_recu`, `message_doublon`,
`erreur_stockage`, `stockage_indisponible`. Le contenu (`payload`) n'est jamais journalisé.

## En cas d'incident

Voir [docs/runbook.md](docs/runbook.md).
