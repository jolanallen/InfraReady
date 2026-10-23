# InfraReady

Projet fil rouge (2026) — standardisation des configurations, automatisation de l'administration et supervision de serveurs Linux/Windows.

Laboratoire : 3 VM sur Proxmox VE, réseau isolé `192.168.50.0/24`.

| Machine | IP | Rôle |
| --- | --- | --- |
| WIN-DC01 | 192.168.50.10 | Windows Server 2025 — AD DS, DNS (`infraready.test`), windows_exporter |
| LINUX01 | 192.168.50.20 | Ubuntu 24.04 — nginx, stockage de test `/data`, node_exporter |
| OPS01 | 192.168.50.30 | Ubuntu 24.04 — Ansible, Prometheus, Grafana |

## Documents

- **Dossier technique** : [InfraReady - Dossier technique.md](InfraReady%20-%20Dossier%20technique.md) (phases A à H, TP de la séance 4 en section 11, TP de la séance 6 en section 12, preuves, écarts)
- **Séance 6, note de synthèse illustrée** : [InfraReady - Séance 6.md](InfraReady%20-%20S%C3%A9ance%206.md) (bilan par use case et captures)
- **Procédure de maintenance** : [docs/procedure-maintenance.md](docs/procedure-maintenance.md)
- **Rapports d'incident** (phase H, séance 6) : [docs/rapport-incident.md](docs/rapport-incident.md)
- **Preuves** : `docs/preuves/` (sorties de commandes horodatées et captures, numérotées par phase)

## Arborescence

```
ansible/      inventaire, group_vars (vault chiffré), playbooks, templates
lab/          modèles d'installation automatique (Ubuntu autoinstall, Windows autounattend) et réseau Proxmox
monitoring/   configuration Prometheus (cibles, règles d'alerte) et provisioning Grafana (source, dashboard)
scripts/      scripts d'amorçage, de vérification et de diagnostic (bash, PowerShell)
docs/         procédure de maintenance, rapport d'incident, preuves
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
ansible-playbook playbooks/controle_sante.yml      # séance 6 : contrôle de santé des 3 serveurs, lecture seule
ansible-playbook playbooks/linux_quotas.yml        # séance 6 (défi) : quotas sur le disque de test /data de LINUX01

# Vérification de l'idempotence d'un playbook (2e passage doit afficher changed=0)
../scripts/verif-idempotence.sh playbooks/linux_base.yml
```

Les mots de passe sont dans des fichiers Ansible Vault chiffrés (`group_vars/*/vault.yml`) ; le mot de passe du vault n'est pas dans le dépôt (`~/.vault_pass_infraready` sur OPS01).

## Séance 4 — scripts de vérification et scénarios de panne

**Prérequis** : laboratoire démarré, accès SSH par clé depuis OPS01, nginx installé sur LINUX01 (`linux_base.yml`), snapshot Proxmox pris avant toute panne volontaire.

```bash
# Sur LINUX01 (sans sudo) — 0 = OK, 1 = contrôle négatif, 2 = erreur / prérequis absent
./scripts/check-nginx.sh [service] [url] [texte attendu]      # défauts : nginx http://127.0.0.1/ InfraReady

# Sur WIN-DC01 — 0 = démarré, 1 = arrêté, 2 = introuvable
powershell -NoProfile -File scripts\Check-DnsClient.ps1 -Name Dnscache ; $LASTEXITCODE

# Sur OPS01 (ansible) — contrôles avant toute correction (procédure 7.5 du support)
ansible-playbook playbooks/linux_base.yml --syntax-check
ansible-playbook playbooks/linux_base.yml --list-hosts      # doit afficher linux01 uniquement
ansible-playbook playbooks/linux_base.yml --check --diff
ansible-playbook playbooks/linux_base.yml                   # 2e passage attendu : changed=0
```

**Limites** : `check-nginx.sh` contrôle l'hôte local (pas le DNS ni le pare-feu) ; `Check-DnsClient.ps1` vérifie l'état du service, pas la résolution d'un nom ; lancé via le module `script` d'Ansible, tout code non nul devient 1 ; en `--check`, l'assertion de contenu compare la nouvelle valeur à la page encore en place.

## Séance 6 — maintenance opérationnelle et supervision

**Prérequis** : laboratoire démarré (les VM ne démarrent pas seules avec l'hôte), snapshot Proxmox `s09_avant_seance6`, copie du projet sur OPS01 identique au dépôt (`~/infraready`).

```bash
# Sur OPS01 (ansible, dossier ansible/) — contrôle de santé, lecture seule (changed=0)
ansible-playbook playbooks/controle_sante.yml                       # tableau OK / ATTENTION / ECHEC / NON APPLICABLE / INACCESSIBLE
ansible-playbook playbooks/controle_sante.yml -e sante_rapport=true # + rapport daté dans ~/infraready-logs/
ansible-playbook playbooks/controle_sante.yml --limit linux01,localhost   # un seul hôte (localhost = synthèse)
# code retour 2 si un contrôle est en ECHEC ou un hôte INACCESSIBLE

# Sur LINUX01 — contrôle planifié du site (timer systemd déployé par linux_base.yml)
systemctl list-timers infraready-controle-site.timer
journalctl -u infraready-controle-site -n 5
cat /var/lib/prometheus/node-exporter/infraready_controle.prom       # métriques lues par node_exporter
```

- **Alertes ajoutées** : `SiteWebIndisponible` (contrôle du site en échec pendant 2 min) et `ControlePlanifieEnRetard` (contrôle non exécuté depuis 5 min). Pas d'Alertmanager : l'état se lit dans Prometheus (`/classic/alerts`) et Grafana.
- **Dashboard v3** : unités et descriptions sur chaque panneau, « NON COLLECTÉ » / « Aucune donnée » au lieu d'un faux zéro, panneaux « Contrôle planifié du site web », « Maintenance Linux » et « Stockage utilisé (%) — évolution ».
- **Validation et déploiement** : la CI GitHub Actions valide les fichiers (lint, syntaxe, `promtool`, JSON, secrets) mais ne déploie rien ; le déploiement se fait depuis OPS01, seul à joindre le réseau privé du labo.
- **Limites** : le contrôle planifié ne teste que le site de LINUX01 ; root n'est pas soumis aux quotas de `/data` ; la correction de l'arrêt non propre de WIN-DC01 (incident INC-2026-10-23-01) est préparée mais pas encore appliquée.

## Où trouver les preuves

| Exigence | Preuves (`docs/preuves/`) |
| --- | --- |
| Installation, réseau, snapshots (A) | P-01 à P-05 |
| Windows : AD DS, DNS, journaux, services et processus (B, séance 4) | P-10 à P-14 |
| Linux : comptes, nginx, disque `/data` par UUID, mises à jour, journaux, script de vérification, processus (C, séance 4) | P-20 à P-26 |
| Ansible : inventaire, playbooks rejoués deux fois, simulation `--check` (D, séance 4) | P-30 à P-39 |
| Maintenance (E) | P-40 à P-43 |
| Supervision Prometheus / Grafana (F) | P-50 à P-55 |
| GitHub Actions (G) | P-60a, P-60 |
| Incident (H) et six scénarios de panne contrôlée (séance 4, 7.4) | P-70 à P-79, `docs/rapport-incident.md` |
| Séance 6 : état initial, collecte, contrôle de santé, tâche planifiée, alerte, dashboard v3, incident du DC, maintenance avant / après, tendance, quotas | P-80 à P-89, P-64 |

Une preuve suffixée `a` (ex. P-39a) est un premier essai en échec, conservé et expliqué dans le dossier.

