#!/usr/bin/env bash
# Séance 6 (UC-C4) — contrôle planifié du site web de LINUX01, lancé chaque minute par
# infraready-controle-site.timer (déployé par ansible/playbooks/linux_base.yml).
# Exécute check-nginx.sh (lecture seule) puis publie le résultat pour Prometheus via le collecteur
# « textfile » de node_exporter ; la sortie du contrôle part dans le journal :
#   journalctl -u infraready-controle-site
# Codes de sortie : ceux de check-nginx.sh (0 = OK, 1 = contrôle négatif, 2 = erreur d'exécution),
#   3 = résultat non publié (dossier textfile absent ou non inscriptible).
set -u
CHECK=/usr/local/lib/infraready/check-nginx.sh
DIR=/var/lib/prometheus/node-exporter
PROM="$DIR/infraready_controle.prom"

debut=$(date +%s.%N)
"$CHECK"
rc=$?
fin=$(date +%s.%N)
succes=0
[ "$rc" -eq 0 ] && succes=1
duree=$(awk -v d="$debut" -v f="$fin" 'BEGIN { printf "%.3f", f - d }')

# Écriture atomique (fichier temporaire puis mv) : node_exporter ne lit jamais un fichier à moitié écrit
tmp=$(mktemp "$DIR/.infraready_controle.XXXXXX") || { echo "ERREUR : $DIR non inscriptible"; exit 3; }
cat > "$tmp" <<EOF
# HELP infraready_controle_succes 1 si le dernier contrôle a réussi, 0 sinon.
# TYPE infraready_controle_succes gauge
infraready_controle_succes{controle="site_web"} $succes
# HELP infraready_controle_code_retour Code de retour du dernier contrôle (0 OK, 1 négatif, 2 erreur).
# TYPE infraready_controle_code_retour gauge
infraready_controle_code_retour{controle="site_web"} $rc
# HELP infraready_controle_derniere_execution_secondes Horodatage Unix de la fin de la dernière exécution.
# TYPE infraready_controle_derniere_execution_secondes gauge
infraready_controle_derniere_execution_secondes{controle="site_web"} ${fin%.*}
# HELP infraready_controle_duree_secondes Durée de la dernière exécution.
# TYPE infraready_controle_duree_secondes gauge
infraready_controle_duree_secondes{controle="site_web"} $duree
EOF
chmod 0644 "$tmp" && mv -f "$tmp" "$PROM" || { rm -f "$tmp"; echo "ERREUR : publication de $PROM impossible"; exit 3; }
exit "$rc"
