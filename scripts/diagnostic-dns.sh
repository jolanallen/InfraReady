#!/bin/bash
# Phase H — diagnostic DNS depuis un serveur Linux du labo (lecture seule, aucune modification).
# usage : ./diagnostic-dns.sh [nom à résoudre]   (défaut : linux01.infraready.test)
nom=${1:-linux01.infraready.test}; dc=192.168.50.10
echo "== $(hostname) — $(date '+%F %T %Z')"
echo "== 1. Symptôme : accès par le nom";        curl -s -m 5 -o /dev/null -w "   curl http://$nom/ -> HTTP %{http_code}\n" "http://$nom/" || echo "   curl : échec ($?) — résolution impossible ?"
echo "== 2. Le même service par IP (isole le DNS)"; curl -s -m 5 -o /dev/null -w "   curl http://192.168.50.20/ -> HTTP %{http_code}\n" http://192.168.50.20/
echo "== 3. Serveur DNS configuré";              resolvectl dns ens18
echo "== 4. Résolution via le résolveur local";  resolvectl query "$nom" 2>&1 | head -2 | sed 's/^/   /'
echo "== 5. Le serveur DNS répond-il ? (ping IP, port 53 TCP/UDP)"
ping -c1 -W1 $dc >/dev/null && echo "   ping $dc : OK (réseau et hôte joignables)" || echo "   ping $dc : ECHEC"
timeout 3 bash -c "</dev/tcp/$dc/53" 2>/dev/null && echo "   port 53/tcp : ouvert" || echo "   port 53/tcp : FERME ou filtré"
echo "== 6. Interrogation directe du DC (contourne le cache local)"
resolvectl query --cache=no "$nom" 2>&1 | head -1 | sed 's/^/   /'
command -v dig >/dev/null && dig +time=2 +tries=1 @$dc "$nom" A 2>&1 | grep -E "status:|^;; connection|ANSWER SECTION" -A1 | sed 's/^/   /'
echo "== 7. Autres services du DC (WinRM 5985, LDAP 389) : le serveur est-il globalement en panne ?"
for p in 5985 389; do timeout 3 bash -c "</dev/tcp/$dc/$p" 2>/dev/null && echo "   port $p/tcp : ouvert" || echo "   port $p/tcp : fermé"; done
