#!/usr/bin/env bash
# Prépare la VM. Lancé par Vagrant, en root, à la création (vagrant up)
# et à chaque "vagrant provision". Doit donc pouvoir être relancé sans casser.

# -e : stop à la première erreur ; -u : variable non définie = erreur ;
# -o pipefail : un enchaînement échoue si l'une de ses commandes échoue.
set -euo pipefail

# Évite que apt pose des questions interactives (personne ne peut répondre).
export DEBIAN_FRONTEND=noninteractive

# Version de cosign et SON EMPREINTE, lue sur la page de la release officielle.
# On vérifie l'empreinte avant d'installer : un binaire modifié serait refusé.
COSIGN_VERSION="v3.1.4"
COSIGN_SHA256="424e2c97d0b45fd7a6b608a87f090f35633f4c23ece5f092d48bba11aaf4bbfa"

# --- Système et Docker -------------------------------------------------------

apt-get update -y      # rafraîchit la liste des paquets
apt-get upgrade -y     # applique les mises à jour (dont celles de sécurité)

# docker.io : le paquet Docker d'Ubuntu (pas de dépôt tiers à faire confiance).
# curl : télécharger ; ca-certificates : vérifier les certificats HTTPS.
apt-get install -y docker.io curl ca-certificates

# --- Utilisateur de déploiement ----------------------------------------------

# Crée "deploy" seulement s'il n'existe pas déjà (rend le script relançable).
# Volontairement PAS dans le groupe "docker" : ce groupe donnerait un accès
# équivalent à root. Il n'aura que le droit d'appeler le gardien (voir plus bas).
id deploy >/dev/null 2>&1 || useradd --create-home --shell /bin/bash deploy

# --- Installation de cosign (outil de vérification des signatures) -----------

# N'installe que si "cosign" n'est pas déjà là.
if ! command -v cosign >/dev/null 2>&1; then
  # -s silencieux, -f échoue sur erreur HTTP, -L suit les redirections.
  curl -sfL -o /tmp/cosign "https://github.com/sigstore/cosign/releases/download/${COSIGN_VERSION}/cosign-linux-amd64"

  # Contrôle l'empreinte. Format attendu : "empreinte" + DEUX espaces + "fichier".
  # En cas de différence, la commande échoue et "set -e" arrête tout.
  echo "${COSIGN_SHA256}  /tmp/cosign" | sha256sum -c -

  # Copie le binaire dans /usr/local/bin : droits 0755, propriétaire root.
  install -m 0755 -o root -g root /tmp/cosign /usr/local/bin/cosign
  rm -f /tmp/cosign
fi

# --- Installation du gardien -------------------------------------------------

# Le script a été copié dans /tmp par Vagrant (ligne "file" du Vagrantfile).
# On l'installe dans /usr/local/sbin, propriété de root : "deploy" peut
# l'exécuter (0755) mais PAS le modifier.
install -m 0755 -o root -g root /tmp/flux-deploy.sh /usr/local/sbin/flux-deploy

# --- Droit d'appeler le gardien ----------------------------------------------

# Règle sudo : l'utilisateur "deploy", sur n'importe quelle machine (ALL), peut
# lancer EN ROOT (root) cette seule commande, sans mot de passe (NOPASSWD).
# Les arguments ne sont pas limités ici : c'est le script qui les valide.
echo 'deploy ALL=(root) NOPASSWD: /usr/local/sbin/flux-deploy' > /etc/sudoers.d/flux-deploy

# sudo exige 0440 sur ces fichiers, sinon il les ignore.
chmod 0440 /etc/sudoers.d/flux-deploy

# Vérifie la syntaxe. Une règle sudo cassée peut bloquer sudo pour tout le monde.
visudo -cf /etc/sudoers.d/flux-deploy
