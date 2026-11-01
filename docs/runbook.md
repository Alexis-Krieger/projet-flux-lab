# Runbook : le service ne reçoit plus de messages

Le service tourne dans la VM `flux-deploy` (voir le README). Les commandes ci-dessous se lancent
depuis le dossier `infra/vm/` du dépôt.

## Symptôme

- Les clients reçoivent `503 {"detail":"stockage indisponible"}` sur `POST /messages`.
- `GET http://192.168.56.20:8000/ready` renvoie `503`.
- `GET /health` répond `200` : le service est vivant mais pas prêt.

## Ce qu'il ne faut pas faire

- Ne pas redémarrer le service en premier réflexe : si la cause est un droit ou un chemin, le redémarrage ne répare rien.
- Ne pas copier le contenu des messages dans un ticket : ils peuvent contenir des données sensibles.

## Diagnostic

1. Chercher l'événement dans les logs JSON du conteneur :

   ```bash
   vagrant ssh -c "sudo docker logs flux-lab 2>&1 | grep erreur_stockage"
   ```

   Le champ `detail` donne la cause (`attempt to write a readonly database`, `unable to open database file`).

2. Vérifier le fichier de base, qui vit dans le volume `flux-data` :

   ```bash
   vagrant ssh -c "sudo ls -la /var/lib/docker/volumes/flux-data/_data"
   ```

   - `-r--r--r--` ou un propriétaire autre que `10001` : droits incorrects. Le service tourne sous
     l'identifiant `10001` (`appuser`).
   - dossier ou fichier absent : le volume a été supprimé ou recréé.

3. Vérifier que le conteneur tourne bien avec les options attendues :

   ```bash
   vagrant ssh -c "sudo docker ps -a --format '{{.Names}} | {{.Status}}'"
   vagrant ssh -c "sudo docker inspect flux-lab --format '{{.Config.Image}}'"
   ```

   L'image doit être désignée par une empreinte `ghcr.io/…@sha256:…`.

## Actions

| Cause | Action |
|---|---|
| Fichier en lecture seule ou mauvais propriétaire | rétablir les droits : `sudo chown 10001 /var/lib/docker/volumes/flux-data/_data/flux_lab.db` et `sudo chmod 644` sur le fichier, puis vérifier `/ready` |
| Volume absent | le redéploiement le recrée vide : **les messages déjà reçus sont alors perdus** ; restaurer une sauvegarde s'il en existe une |
| Conteneur arrêté | `sudo docker start flux-lab`, puis vérifier `/ready` |
| Cause inconnue après 15 minutes | revenir à la version précédente (voir ci-dessous) |

## Retour arrière

Le gardien revient seul en arrière quand un nouveau conteneur n'est pas prêt en 30 secondes.
Pour revenir volontairement à une version précédente, relancer le gardien avec l'empreinte de
cette version :

```bash
vagrant ssh -c "sudo -u deploy sudo /usr/local/sbin/flux-deploy sha256:<empreinte-précédente>"
```

Le gardien vérifie l'attestation avant de lancer l'image. Les données ne sont pas perdues : la
base vit dans le volume `flux-data`, hors de l'image. Le README explique comment lire l'empreinte
d'une version publiée.

## Vérification de la résolution

```bash
curl -s -w "  -> %{http_code}\n" http://192.168.56.20:8000/ready
```

Attendu : `{"status":"ready"}  -> 200`.
