#!/usr/bin/env bash
# Séance 4 — contrôle en lecture seule du site web local (aucune correction automatique).
# Usage : ./check-nginx.sh [service] [url] [texte attendu]
#   défauts : nginx  http://127.0.0.1/  "InfraReady"
# Codes de sortie :
#   0 = contrôle positif (service actif, HTTP 200, texte présent)
#   1 = contrôle négatif (service inactif, site injoignable, HTTP != 200 ou texte absent)
#   2 = erreur d'exécution (commande absente, service inconnu sur cet hôte)
# Prérequis : systemd, curl. Limites : contrôle l'hôte local seulement, pas la résolution DNS ni le pare-feu.
set -u
SERVICE="${1:-nginx}"
URL="${2:-http://127.0.0.1/}"
EXPECTED="${3:-InfraReady}"

for cmd in systemctl curl; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "ERREUR : commande $cmd introuvable"; exit 2; }
done

# Un service absent est un prérequis manquant, pas une panne
if ! systemctl list-unit-files --no-legend "$SERVICE.service" 2>/dev/null | grep -q .; then
  echo "ERREUR : service $SERVICE inconnu sur $(hostname) (prérequis absent)"
  exit 2
fi

if ! systemctl is-active --quiet "$SERVICE"; then
  echo "ECHEC : le service $SERVICE n'est pas actif ($(systemctl is-active "$SERVICE"))"
  exit 1
fi

# Corps de la page + code HTTP sur la dernière ligne
if ! body=$(curl -sS --max-time 5 -w '\n%{http_code}' "$URL" 2>&1); then
  echo "ECHEC : $URL injoignable (${body%%$'\n'*})"
  exit 1
fi
code=${body##*$'\n'}
if [ "$code" != "200" ]; then
  echo "ECHEC : $URL répond HTTP $code"
  exit 1
fi
if ! grep -qF -- "$EXPECTED" <<<"$body"; then
  echo "ECHEC : HTTP 200 mais le texte « $EXPECTED » est absent de la page"
  exit 1
fi

echo "OK : $SERVICE actif, $URL répond 200 et contient « $EXPECTED »"
exit 0
