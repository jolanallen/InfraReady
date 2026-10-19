#!/bin/bash
# Crée le compte de service "ansible" (clé SSH, sudo sans mot de passe) — à lancer en root.
#   Sur OPS01   : ./bootstrap-ansible-user.sh control          -> crée l'utilisateur + sa paire de clés
#   Sur LINUX01 : ./bootstrap-ansible-user.sh managed "<clé publique de ansible@ops01>"
set -euo pipefail
role=${1:?control|managed}

id ansible &>/dev/null || useradd --create-home --shell /bin/bash --comment "Compte de service Ansible" ansible
install -d -m 700 -o ansible -g ansible /home/ansible/.ssh

echo 'ansible ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/ansible
chmod 440 /etc/sudoers.d/ansible
visudo -cf /etc/sudoers.d/ansible

if [ "$role" = control ]; then
  [ -f /home/ansible/.ssh/id_ed25519 ] || sudo -u ansible ssh-keygen -q -t ed25519 -N "" -C "ansible@ops01" -f /home/ansible/.ssh/id_ed25519
  cat /home/ansible/.ssh/id_ed25519.pub
else
  key=${2:?clé publique requise}
  grep -qxF "$key" /home/ansible/.ssh/authorized_keys 2>/dev/null || echo "$key" >> /home/ansible/.ssh/authorized_keys
  chown ansible:ansible /home/ansible/.ssh/authorized_keys
  chmod 600 /home/ansible/.ssh/authorized_keys
fi
