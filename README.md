# InfraReady

Projet fil rouge (2026) — standardisation des configurations, automatisation de l'administration et supervision de serveurs Linux/Windows.

Laboratoire : 3 VM sur Proxmox VE, réseau isolé `192.168.50.0/24`.

| Machine | IP | Rôle |
| --- | --- | --- |
| WIN-DC01 | 192.168.50.10 | Windows Server 2025 — AD DS, DNS (`infraready.test`), windows_exporter |
| LINUX01 | 192.168.50.20 | Ubuntu 24.04 — nginx, stockage de test `/data`, node_exporter |
| OPS01 | 192.168.50.30 | Ubuntu 24.04 — Ansible, Prometheus, Grafana |

## Documents

- **Dossier technique** : [InfraReady - Dossier technique.md](InfraReady%20-%20Dossier%20technique.md) (phases A à H, preuves, écarts)
- **Procédure de maintenance** : [docs/procedure-maintenance.md](docs/procedure-maintenance.md)
- **Preuves** : `docs/preuves/` (sorties de commandes horodatées et captures, numérotées par phase)

## Arborescence

```
ansible/      inventaire, group_vars (vault chiffré), playbooks, templates
lab/          modèles d'installation automatique (Ubuntu autoinstall, Windows autounattend) et réseau Proxmox
monitoring/   configuration Prometheus (cibles, règles d'alerte) et provisioning Grafana (source, dashboard)
scripts/      scripts d'amorçage, de vérification et de diagnostic (bash, PowerShell)
docs/         procédure de maintenance, preuves
.github/      workflow de validation (yamllint, ansible-lint, syntax-check, promtool, gitleaks, vault chiffré)
```

## Utilisation (depuis OPS01, utilisateur `ansible`, dossier `ansible/`)

```bash
ansible-inventory --graph
ansible linux -m ping ; ansible windows -m win_ping

ansible-playbook playbooks/windows_adds.yml        # phase B : AD DS + forêt
ansible-playbook playbooks/linux_base.yml          # phase C/D : LINUX01
ansible-playbook playbooks/windows_base.yml        # phase B/D : objets AD, partage, DNS, exporter
ansible-playbook playbooks/ops01_monitoring.yml    # phase F : Prometheus + Grafana
ansible-playbook playbooks/linux_maintenance.yml   # phase E (voir docs/procedure-maintenance.md)
ansible-playbook playbooks/windows_maintenance.yml # phase E (recherche ; -e maintenance_apply=true pour installer)
```

Les mots de passe sont dans des fichiers Ansible Vault chiffrés (`group_vars/*/vault.yml`) ; le mot de passe du vault n'est pas dans le dépôt (`~/.vault_pass_infraready` sur OPS01).
