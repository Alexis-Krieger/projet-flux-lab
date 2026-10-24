# Vérifier une release avant de l'installer

Chaque release publie trois choses : le paquet (`.whl`), son inventaire (`sbom.cdx.json`)
et une **attestation de provenance** signée. Avant d'installer une version, on vérifie
que le fichier vient bien du workflow du dépôt.

## Ce que la vérification prouve

- le fichier a été produit par `.github/workflows/release.yml` de ce dépôt ;
- à partir du commit indiqué par le tag ;
- et il n'a pas été modifié depuis.

## Ce qu'elle ne prouve pas

- que le code est correct ou sans faille ;
- que le commit a été relu ;
- que GitHub n'est pas compromis.

## Procédure

Prérequis : la CLI GitHub (`gh`), connectée avec `gh auth login`.

```bash
curl -sL -O https://github.com/Alexis-Krieger/projet-flux-lab/releases/download/<tag>/flux_lab-<version>-py3-none-any.whl
gh attestation verify flux_lab-<version>-py3-none-any.whl --repo Alexis-Krieger/projet-flux-lab
```

Résultat attendu : code de sortie `0`. Tout autre résultat signifie **ne pas installer**.

## Règle

Aucune release n'est déployée sans vérification réussie. Un fichier qui échoue
à la vérification est signalé et n'est jamais installé.

## Déconnexion

Une fois la vérification faite, `gh auth logout` retire le jeton de la machine.

