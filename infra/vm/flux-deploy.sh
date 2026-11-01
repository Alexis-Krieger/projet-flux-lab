#!/usr/bin/env bash
# Le "gardien" : vérifie qu'une image a bien été fabriquée par notre workflow
# de release, puis seulement la lance. Si le nouveau conteneur ne devient pas
# prêt, il remet l'ancien en service. Il est installé dans la VM sous
# /usr/local/sbin/flux-deploy, propriété de root.
#
# Codes de sortie : 0 = déployé, 1 = vérification échouée,
#                   2 = argument invalide,
#                   3 = nouveau service pas prêt (retour arrière tenté).

# -e : s'arrêter dès qu'une commande échoue
# -u : une variable non définie est une erreur (évite les fautes de frappe)
# -o pipefail : un enchaînement "a | b" échoue si l'une des commandes échoue
set -euo pipefail

# --- Réglages (ce qu'on accepte de lancer) -----------------------------------

# Le seul dépôt d'images autorisé.
IMAGE_REPO="ghcr.io/alexis-krieger/projet-flux-lab"

# Qui a signé : l'identité GitHub Actions (jetons OIDC émis par GitHub).
ISSUER="https://token.actions.githubusercontent.com"

# Quel workflow : uniquement release.yml de notre dépôt, déclenché par un tag vX.Y.Z.
# Un autre workflow, un autre dépôt ou une branche ne passent pas cette expression.
IDENTITY='^https://github.com/Alexis-Krieger/projet-flux-lab/\.github/workflows/release\.yml@refs/tags/v.*$'

# Nom du conteneur, nom sous lequel on garde l'ancien, et adresse du test de disponibilité.
NAME="flux-lab"
PREVIOUS="${NAME}-precedent"
URL="http://192.168.56.20:8000"

# --- 1. Contrôle de l'argument ------------------------------------------------

# $1 est le premier argument ; ":-" donne une valeur vide s'il manque.
digest="${1:-}"

# Ce script tourne en root via sudo : on n'accepte QUE "sha256:" suivi de
# 64 caractères hexadécimaux. Tout le reste (espaces, ";", "&&"...) est refusé,
# donc aucune commande ne peut être glissée dans l'argument.
if ! [[ "$digest" =~ ^sha256:[0-9a-f]{64}$ ]]; then
  echo "usage : flux-deploy sha256:<empreinte>" >&2   # >&2 : message sur la sortie d'erreur
  exit 2
fi

# On désigne l'image par son EMPREINTE (immuable), jamais par un tag qui peut bouger.
ref="${IMAGE_REPO}@${digest}"

# --- 2. Vérification de l'attestation (le "badge") ---------------------------

echo "vérification de l'attestation de $ref"

# cosign contrôle la signature de l'attestation de provenance SLSA, et que
# l'identité du certificat correspond à ISSUER et IDENTITY.
# "> /dev/null 2>&1" cache la sortie détaillée ; seul le code de sortie compte.
if ! cosign verify-attestation --type slsaprovenance1 \
      --certificate-oidc-issuer "$ISSUER" \
      --certificate-identity-regexp "$IDENTITY" \
      "$ref" > /dev/null 2>&1; then
  echo "VÉRIFICATION ÉCHOUÉE : rien n'est déployé" >&2
  exit 1       # on s'arrête ICI : rien en dessous ne s'exécute, le service en place n'est pas touché
fi
echo "vérification réussie"

# --- 3. Lancement du conteneur, avec possibilité de retour arrière -----------

# Télécharge l'image exacte désignée par l'empreinte. Fait AVANT de toucher à
# l'ancien conteneur : si le téléchargement échoue, le service en place continue.
docker pull "$ref" > /dev/null

# Nettoie un ancien "précédent" laissé par un essai antérieur : sinon le
# renommage ci-dessous échouerait. "|| true" : ne pas s'arrêter s'il n'existe pas.
docker rm -f "$PREVIOUS" > /dev/null 2>&1 || true

# Si un conteneur tourne déjà, on NE LE SUPPRIME PAS : on l'arrête et on le renomme.
# Il reste sur la machine, prêt à être relancé sans réseau ni registre : un retour
# arrière ne doit pas dépendre de ce qui peut justement être en panne.
had_previous=0
if docker inspect "$NAME" > /dev/null 2>&1; then
  docker stop "$NAME" > /dev/null          # libère le port 8000
  docker rename "$NAME" "$PREVIOUS"        # libère le nom pour le nouveau
  had_previous=1
fi

# Options de sécurité fixées ICI, pas par celui qui appelle :
#   -d                              : en arrière-plan
#   --name                          : nom du conteneur
#   --restart unless-stopped        : redémarre après un redémarrage de la VM
#   --read-only                     : le système de fichiers du conteneur est en lecture seule
#   --tmpfs /tmp                    : sauf /tmp, en mémoire, effacé à l'arrêt
#   --cap-drop ALL                  : retire toutes les capacités Linux spéciales
#   --security-opt no-new-privileges: aucun processus ne peut gagner de droits
#   -v flux-data:/data              : volume nommé pour la base SQLite (survit aux déploiements)
#   -p IP:8000:8000                 : exposé uniquement sur le réseau privé de la VM
docker run -d --name "$NAME" --restart unless-stopped \
  --read-only --tmpfs /tmp \
  --cap-drop ALL --security-opt no-new-privileges \
  -v flux-data:/data \
  -p 192.168.56.20:8000:8000 \
  "$ref" > /dev/null

# --- 4. Attente que le service soit prêt -------------------------------------

ready=0
# Essaie jusqu'à 30 fois, une fois par seconde. "_" : variable dont on n'a pas besoin.
for _ in $(seq 1 30); do
  # curl -s : silencieux ; -f : échoue si la réponse est une erreur HTTP (ex. 503),
  # donc /ready qui répond 503 compte comme "pas prêt".
  if curl -sf "$URL/ready" > /dev/null; then
    ready=1
    break
  fi
  sleep 1
done

if [ "$ready" -eq 1 ]; then
  # Succès : l'ancien conteneur n'est plus utile, on le supprime.
  docker rm -f "$PREVIOUS" > /dev/null 2>&1 || true
  echo "déployé : $ref"
  exit 0
fi

# --- 5. Échec : retour arrière -----------------------------------------------

echo "le service n'est pas prêt après 30 s : retour arrière" >&2

# Supprime le nouveau conteneur défaillant.
docker rm -f "$NAME" > /dev/null 2>&1 || true

# Remet l'ancien en service, s'il y en avait un (pas au tout premier déploiement).
if [ "$had_previous" -eq 1 ]; then
  docker rename "$PREVIOUS" "$NAME"
  docker start "$NAME" > /dev/null
  echo "ancien conteneur relancé" >&2
fi

# Le script signale l'échec même s'il a restauré le service.
exit 3
