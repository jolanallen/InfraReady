#!/bin/bash
# Vérification d'idempotence d'un playbook : deux exécutions consécutives ;
# le second passage doit afficher changed=0 (aucune modification), comme dans
# les preuves P-32 et P-34 du dossier technique.
#
# usage (depuis le dossier ansible/, utilisateur ansible sur OPS01) :
#   ../scripts/verif-idempotence.sh playbooks/linux_base.yml
#   ../scripts/verif-idempotence.sh playbooks/windows_base.yml --limit win-dc01
#
# options supplémentaires : transmises telles quelles à ansible-playbook
# (par exemple -e allow_reboot=true pour la maintenance).
set -euo pipefail

playbook=${1:?usage : verif-idempotence.sh playbooks/<nom>.yml [options ansible-playbook]}
shift

# Les playbooks utilisent ansible.cfg (inventaire, vault) du dossier ansible/.
racine=$(cd "$(dirname "$0")/.." && pwd)
cd "$racine/ansible"

# Somme d'un champ du RECAP (changed, failed, ...) sur tous les hôtes.
somme_recap() {
  awk -v champ="$1=" '
    /^PLAY RECAP/ {recap=1; next}
    recap {for (i=1; i<=NF; i++) if ($i ~ "^" champ) {split($i, a, "="); total += a[2]}}
    END {print total + 0}'
}

echo "== 1er passage : mise à jour de l'état si nécessaire"
if ! ansible-playbook "$playbook" "$@"; then
  echo "ECHEC : le 1er passage a échoué — corriger avant de parler d'idempotence" >&2
  exit 2
fi

echo
echo "== 2e passage : doit afficher changed=0"
if ! sortie=$(ansible-playbook "$playbook" "$@" 2>&1); then
  echo "$sortie"
  echo "ECHEC : le 2e passage a échoué" >&2
  exit 2
fi
echo "$sortie"

changed=$(echo "$sortie" | somme_recap changed)
failed=$(echo "$sortie" | somme_recap failed)
unreachable=$(echo "$sortie" | somme_recap unreachable)

echo
if [ "$failed" -eq 0 ] && [ "$unreachable" -eq 0 ] && [ "$changed" -eq 0 ]; then
  echo "IDEMPOTENT : 2e passage sans changement (changed=0, failed=0, unreachable=0)"
else
  echo "NON IDEMPOTENT : changed=$changed failed=$failed unreachable=$unreachable sur le 2e passage" >&2
  exit 1
fi
