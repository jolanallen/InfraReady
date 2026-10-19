# Procédure de maintenance standard — InfraReady

Version 1.0 — 19/10/2026. S'applique aux trois serveurs du laboratoire (WIN-DC01, LINUX01, OPS01).

## 1. Fenêtre et périmètre

| Point | Règle |
| --- | --- |
| Fenêtre | En dehors des démonstrations ; durée prévue 1 h, un serveur à la fois |
| Ordre | 1. LINUX01 (service web) → 2. OPS01 (outils) → 3. WIN-DC01 en dernier (annuaire + DNS : tout le labo en dépend) |
| Exécution | Depuis OPS01, utilisateur `ansible`, dans `~/infraready/ansible` |
| Trace | `~/infraready-logs/ansible.log` (toutes les tâches) + un rapport par serveur `~/infraready-logs/maintenance-<hôte>-<date>.txt` |

## 2. Avant (pré-contrôles)

1. **Snapshot Proxmox** du serveur concerné : `qm snapshot <vmid> s0x_avant_maj --description "Avant maintenance <date>"`. Le snapshot est le retour arrière.
2. Les playbooks vérifient automatiquement et **s'arrêtent** si une condition n'est pas remplie :
   - espace disque < 85 % sur chaque volume ;
   - services attendus actifs (`ssh`, `nginx`, exporters, `prometheus`, `grafana-server` / `NTDS`, `DNS`, `Netlogon`, `kdc`, `windows_exporter`).
3. Regarder Grafana (dashboard « InfraReady — Serveurs ») : aucune alerte active avant de commencer.

## 3. Pendant

### Linux (LINUX01, OPS01)

```bash
ansible-playbook playbooks/linux_maintenance.yml                      # MAJ sans redémarrage
ansible-playbook playbooks/linux_maintenance.yml -e allow_reboot=true # si /var/run/reboot-required existe
```

- `apt upgrade` uniquement (jamais `dist-upgrade` / suppression de paquets en automatique), puis `autoremove`.
- Les **mises à jour de sécurité** sont par ailleurs installées **chaque jour automatiquement** par `unattended-upgrades` (configuré par le playbook, sans redémarrage automatique).

### Windows (WIN-DC01)

```bash
ansible-playbook playbooks/windows_maintenance.yml                                           # recherche seulement
ansible-playbook playbooks/windows_maintenance.yml -e maintenance_apply=true                  # installation, pas de reboot
ansible-playbook playbooks/windows_maintenance.yml -e maintenance_apply=true -e allow_reboot=true
```

- Catégories : mises à jour de sécurité, critiques, cumulatives, définitions.
- Journal détaillé côté Windows : `C:\Windows\Temp\infraready-windowsupdate.log`.

## 4. Précautions avant redémarrage ou changement majeur

- Snapshot pris et nommé (vérifier avec `qm listsnapshot <vmid>`).
- **WIN-DC01** : jamais de redémarrage pendant qu'un playbook ou qu'une démonstration utilise l'annuaire ; prévenir le binôme ; vérifier `dcdiag /q` après redémarrage.
- **LINUX01** : le site web est indisponible pendant le redémarrage (~1 min) ; vérifier HTTP 200 après.
- **OPS01** : Prometheus perd les points de mesure pendant le redémarrage ; les alertes `InstanceDown` ne sont pas évaluées pendant ce temps.
- Changement majeur (nouvelle version, nouveau rôle, modification réseau) : d'abord sur une seule machine, snapshot, test, puis généralisation.

## 5. Après (post-contrôles)

Les playbooks revérifient les services et, pour LINUX01, le site web. Compléter par :

- Grafana : les trois serveurs « EN LIGNE », aucune alerte active ;
- WIN-DC01 : `Get-ADDomain` et résolution DNS OK (fait par le playbook) ;
- lecture du rapport `~/infraready-logs/maintenance-<hôte>-<date>.txt` et archivage dans `docs/preuves/` si la maintenance fait partie d'une phase du projet.

## 6. Retour arrière

| Situation | Action |
| --- | --- |
| Service en échec après mise à jour | `journalctl -u <service>` / observateur d'événements ; correction ciblée ; sinon ci-dessous |
| Serveur instable | `qm rollback <vmid> s0x_avant_maj` puis `qm start <vmid>` ; rejouer les tests de la phase |
| Mise à jour Windows problématique | `Get-HotFix` / `wusa /uninstall /kb:<n>` ; sinon rollback snapshot |

Les snapshots de maintenance sont supprimés une semaine après une maintenance validée (`qm delsnapshot`).
