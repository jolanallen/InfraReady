#!/bin/bash
# Commands run on the Proxmox host (corsair1) to prepare the three lab VMs.
# VMs 100-102 were created beforehand in the Proxmox UI; this script only adapts them.
# Seed/answer ISOs are built from lab/*.tpl with real values filled in locally (never committed).
set -euo pipefail
ISO=ISOs:iso

# Windows Server 2025 — e1000e NIC (inbox driver), lab bridge, answer file on a 2nd CD
qm set 100 --net0 e1000e=BC:24:11:EA:70:74,bridge=vmbr1,firewall=1 \
           --ide3 $ISO/infraready-win-dc01-unattend.iso,media=cdrom

# Ubuntu 24.04.5 — autoinstall seed (cloud-init NoCloud, label CIDATA) on a 2nd CD
qm set 101 --ide2 $ISO/ubuntu-24.04.5-live-server-amd64.iso,media=cdrom \
           --ide3 $ISO/infraready-linux01-seed.iso,media=cdrom \
           --net0 virtio=BC:24:11:7A:CA:61,bridge=vmbr1,firewall=1 --agent enabled=1
qm set 102 --ide2 $ISO/ubuntu-24.04.5-live-server-amd64.iso,media=cdrom \
           --ide3 $ISO/infraready-ops01-seed.iso,media=cdrom \
           --net0 virtio=BC:24:11:A1:B4:22,bridge=vmbr1,firewall=1 --agent enabled=1

for id in 100 101 102; do qm start $id; done
# Ubuntu asks "Continue with autoinstall? (yes|no)" (no 'autoinstall' on the kernel cmdline):
#   qm sendkey <id> y; qm sendkey <id> e; qm sendkey <id> s; qm sendkey <id> ret
# Windows asks "Press any key to boot from CD":  qm sendkey 100 ret
