#!/usr/bin/env bash
# Le "gardien" : vérifie qu'une image a bien été fabriquée par notre workflow
# de release, puis seulement la lance. Il est installé dans la VM sous
# /usr/local/sbin/flux-deploy, propriété de root.
#
# Codes de sortie : 0 = déployé, 1 = vérification échouée,
#                   2 = argument invalide, 3 = service pas prêt.

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

# Nom du conteneur, et adresse où on teste qu'il est prêt.
NAME="flux-lab"
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
  exit 1       # on s'arrête ICI : rien en dessous ne s'exécute
fi
echo "vérification réussie"

# --- 3. Lancement du conteneur ------------------------------------------------

# Télécharge l'image exacte désignée par l'empreinte.
docker pull "$ref" > /dev/null

# Supprime l'ancien conteneur s'il existe. "|| true" évite que "set -e" arrête le
# script quand il n'y en a pas (premier déploiement).
# LIMITE CONNUE : l'ancien est supprimé avant de savoir si le nouveau démarre ;
# le retour arrière automatique sera ajouté dans une étape suivante.
docker rm -f "$NAME" > /dev/null 2>&1 || true

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

# Essaie jusqu'à 30 fois, une fois par seconde. "_" : variable dont on n'a pas besoin.
for _ in $(seq 1 30); do
  # curl -s : silencieux ; -f : échoue si la réponse est une erreur HTTP (ex. 503),
  # donc /ready qui répond 503 compte comme "pas prêt".
  if curl -sf "$URL/ready" > /dev/null; then
    echo "déployé : $ref"
    exit 0
  fi
  sleep 1
done

echo "le service n'est pas prêt après 30 s" >&2
exit 3
