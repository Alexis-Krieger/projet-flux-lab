# Runbook : le service ne reçoit plus de messages

## Symptôme

- Les clients reçoivent `503 {"detail":"stockage indisponible"}` sur `POST /messages`.
- `GET /ready` renvoie `503`.
- `GET /health` répond `200` : le service est vivant mais pas prêt.

## Ce qu'il ne faut pas faire

- Ne pas redémarrer le service en premier réflexe : si la cause est un droit ou un chemin, le redémarrage ne répare rien.
- Ne pas copier le contenu des messages dans un ticket : ils peuvent contenir des données sensibles.

## Diagnostic

1. Chercher l'événement dans les logs JSON du service :

   ```bash
   grep '"evenement": "erreur_stockage"' <fichier-de-logs>
   ```

   Le champ `detail` donne la cause (`attempt to write a readonly database`, `unable to open database file`).

2. Vérifier le fichier de base de l'environnement concerné :

   ```bash
   ls -la .deploy/<env>/data/flux_lab.db
   ```

   - `-r--r--r--` : fichier en lecture seule (droits).
   - `No such file or directory` sur le dossier : le chemin `FLUX_LAB_DB` est faux.

3. Vérifier la variable de configuration utilisée :

   ```bash
   cat config/<env>.env
   ```

## Actions

| Cause | Action |
|---|---|
| Fichier en lecture seule | rétablir les droits d'écriture pour l'utilisateur du service, puis vérifier `/ready` |
| Dossier de la base absent | créer le dossier, ou corriger `FLUX_LAB_DB` |
| Cause inconnue après 15 minutes | revenir à la version précédente (voir ci-dessous) |

## Retour arrière

```bash
bash scripts/deploy.sh <env> <version-précédente>
bash scripts/start.sh <env>
```

Les données ne sont pas perdues : la base vit hors des versions (`.deploy/<env>/data/`).

## Vérification de la résolution

```bash
curl -s -w "  -> %{http_code}\n" http://127.0.0.1:<port>/ready
```

Attendu : `{"status":"ready"}  -> 200`.

