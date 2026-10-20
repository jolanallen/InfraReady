# CLAUDE.md — instructions pour l'agent de code

Projet **InfraReady** : projet fil rouge B3 Cybersécurité. Labo de 3 VM Proxmox
(`192.168.50.0/24`) standardisées, automatisées avec Ansible et supervisées avec
Prometheus/Grafana. Ce dépôt est la **remise notée** du projet : chaque changement
doit rester traçable, validé et documenté.

## Repères

- `ansible/` — inventaire, `group_vars` (vaults chiffrés), playbooks (phases B à F), templates
- `lab/` — modèles d'installation automatique (Ubuntu autoinstall, Windows autounattend) et réseau Proxmox
- `monitoring/` — Prometheus (cibles, règles d'alerte) et Grafana (source + dashboard provisionnés)
- `scripts/` — amorçage, vérification, diagnostic (bash, PowerShell)
- `docs/` — procédure de maintenance, rapport d'incident, preuves numérotées par phase
- `InfraReady - Dossier technique.md` — livrable principal (phases A à H, matrice des preuves, écarts)
- `.github/workflows/validation.yml` — CI : yamllint, ansible-lint, syntax-check, promtool, jq, gitleaks

## Règles git — obligatoires

1. **Jamais de push direct sur `main`.** `main` n'évolue que par merge de PR.
2. **1 modification = 1 commit**, clair et documenté. Un commit ne mélange pas
   deux sujets (un fix Ansible n'entre pas dans le même commit qu'une mise à
   jour de documentation d'une autre phase).
3. **Une branche dédiée par sujet**, créée depuis `main` :
   `fix/…` (correction), `feat/…` (fonctionnalité), `docs/…` (documentation),
   `ci/…` (workflow), `chore/…` (ménage). Nom court en kebab-case.
4. **Tout passe par une pull request** créée avec `gh pr create` (base `main`).
   Une PR regroupe un **groupe de modifications cohérent** (un sujet).
   Ne **jamais** merger soi-même : l'étudiant relit, ajuste éventuellement, puis merge.
5. **Message de commit en français**, dans le style du dépôt (voir `git log`) :
   - sujet d'une ligne au présent, qui dit *quoi* (et *pourquoi* si ce n'est pas évident) ;
   - corps détaillant le constat et le correctif, lignes à ~72 caractères.
6. **Titre et corps de PR en français**, structurés : Contexte / Apport (ou Correction) / Validation.
7. Vérifier `git status` avant chaque commit : n'ajouter que les fichiers du sujet
   (pas de `git add -A` aveugle). Ne jamais réécrire l'historique déjà poussé.
8. Les vaults chiffrés (`vault*.yml`) ne sont **jamais** modifiés ni régénérés sans
   demande explicite.

## Règles de documentation — la doc suit le code

Le dossier technique est le livrable noté : **toute modification du code, des
playbooks, de la supervision ou de l'état des VM doit être répercutée dans la
documentation**, qui doit rester claire, en français et à jour.

| Ce qui change | À mettre à jour |
| --- | --- |
| Arborescence, commandes d'utilisation | `README.md` |
| Playbook, inventaire, group_vars, templates | `InfraReady - Dossier technique.md` (phase concernée) |
| Maintenance (playbooks de phase E, procédure) | `docs/procedure-maintenance.md` + dossier technique |
| Monitoring (Prometheus, règles, dashboard) | Dossier technique (phase F) ; signaler les captures à rafraîchir (`docs/preuves/P-51`, `P-53`, `P-55…`) |
| Incident ou diagnostic | `docs/rapport-incident.md` |
| Nouvelle preuve | `docs/preuves/P-xx-description.txt|.png` + matrice des preuves du dossier technique |

- **Ajouter une preuve ne doit jamais supprimer ni réécrire une preuve existante** :
  ce sont des traces horodatées qui font foi.
- **Modification faite à la main sur une VM ?** La rejouer en Ansible (le lab est
  décrit par le dépôt, pas l'inverse), documenter le changement et ajouter la preuve.
- Tenir à jour la **matrice des preuves** du dossier technique dès qu'une preuve s'ajoute.
- Même présentation que le reste du dossier : titres, tableaux, commentaires en français.

## Règles de validation — avant toute PR

La CI bloque les PR qui échouent ; refaire les mêmes contrôles en local :

```bash
yamllint --strict .                                    # YAML (playbooks, inventaire, CI)
cd ansible
[ -f ~/.vault_pass_infraready ] || echo "ci-dummy" > ~/.vault_pass_infraready   # syntax-check seulement
for p in playbooks/*.yml; do ansible-playbook --syntax-check -i localhost, "$p"; done
ansible-lint playbooks/
cd ..
jq -e '.title and (.panels | length > 0)' monitoring/grafana/dashboards/infraready.json
docker run --rm -v "$PWD/monitoring/prometheus:/cfg:ro" --entrypoint promtool \
  prom/prometheus:v2.53.4 check config /cfg/prometheus.yml
```

**Idempotence** : un second passage d'un playbook doit afficher `changed=0`. Vérifier
avec le script du dépôt (à lancer depuis `ansible/`) :

```bash
../scripts/verif-idempotence.sh playbooks/<nom>.yml
```

## Règles spécifiques au projet

- **Secrets** : aucun mot de passe en clair, jamais. Ils vivent dans les vaults
  chiffrés (`ansible/inventory/group_vars/*/vault.yml`, entête `$ANSIBLE_VAULT;`).
  Ne jamais commiter `~/.vault_pass_infraready` ni une version déchiffrée d'un vault
  (gitleaks + contrôle CI sur les vaults).
- **Ne pas exécuter de playbook contre le lab sans demande explicite** : les VM
  (WIN-DC01, LINUX01, OPS01) sont partagées et suivies par snapshots Proxmox.
- Les fichiers de supervision (`monitoring/`) sont versionnés puis déployés par
  `ops01_monitoring.yml` : modifier le dépôt, pas le fichier en place sur OPS01.
- Préserver l'idempotence : aucune tâche ne doit signaler `changed` au second passage.
- Ne pas ajouter de dépendance (collection Ansible, paquet, action GitHub) sans
  justifier et sans mettre `requirements.yml` / la CI à jour.

## Langue

Tout en français : commits, PR, documentation, commentaires de code.
