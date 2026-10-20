# Rapport d'incident — INC-2026-10-19-01 : site web LINUX01 en erreur 404

| Champ | Valeur |
| --- | --- |
| Référence | INC-2026-10-19-01 |
| Date / heure du constat | 19/10/2026 19:27 (CEST) |
| Système concerné | LINUX01 (192.168.50.20) — service nginx, site `http://linux01.infraready.test/` |
| Impact | Site web indisponible (HTTP 404 sur toutes les pages) ; aucun autre service touché (SSH, node_exporter, AD/DNS OK) |
| Gravité | Moyenne (service applicatif du labo, pas de perte de données) |
| Type | Erreur de configuration lors d'un changement (mise en production simulée) |
| Reproduit volontairement | Oui — incident contrôlé et réversible (sauvegarde préalable, configuration de référence dans Ansible) |
| Responsable | MIR Mahan / Jolan Allen |

## 1. Symptôme

Depuis le poste d'administration OPS01, le site répond **404 Not Found** par adresse IP et par nom DNS, alors que la VM répond au ping et que le port 80 accepte les connexions (preuve P-70). Avant le changement, le site répondait 200.

## 2. Chronologie

| Heure (CEST) | Événement | Preuve |
| --- | --- | --- |
| 19:27:22 | Modification de `/etc/nginx/sites-available/infraready` (`root /var/www/infraready` → `/var/www/infraready-v2`), `nginx -t` OK, `systemctl reload nginx` | P-70 |
| 19:27:27 | Constat : 404 depuis OPS01 (IP et nom) | P-70 |
| 19:27:51 | Diagnostic sur LINUX01 : cause confirmée | P-71 |
| 19:28:20 | 1ʳᵉ correction : `linux_base.yml --limit linux01` → fichier restauré mais **toujours 404** (handler de rechargement non exécuté) | P-72a |
| 19:30 | Correction du playbook (`meta: flush_handlers` avant les vérifications) | P-72 |
| 19:30:34 | Reproduction n°2 de l'incident (pour valider la correction en un seul passage) | P-72 |
| 19:30:39 → 19:30:51 | Correction : playbook corrigé → fichier restauré **et** nginx rechargé → 200 | P-72 |
| 19:30:53 → 19:31:09 | Retour à la normale vérifié ; 2ᵉ passage `changed=0` | P-73 |

## 3. Diagnostic

Hypothèses testées dans l'ordre, sur LINUX01 (P-71) :

1. **Service planté ?** Non — `systemctl is-active nginx` = `active`, rechargement à 19:27:22 réussi.
2. **Port fermé / pare-feu ?** Non — `ss -ltnp` montre nginx en écoute sur `0.0.0.0:80`, règle UFW `80/tcp ALLOW 192.168.50.0/24` présente.
3. **Contenu supprimé ?** Non — `/var/www/infraready/index.html` toujours présent (279 octets, `root:webadmins`).
4. **Configuration ?** **Oui** — `nginx -T` montre `root /var/www/infraready-v2;` ; ce répertoire n'existe pas ; `stat` date le changement à 19:27:22 ; `diff` avec la sauvegarde montre la seule ligne modifiée ; le journal `sudo` identifie la session qui a fait le changement.

**Cause confirmée :** la directive `root` du virtual host pointe vers un répertoire inexistant. `nginx -t` ne vérifie pas l'existence du répertoire, le rechargement a donc réussi et la configuration erronée a été appliquée sans avertissement.

Point d'attention : `infraready_error.log` est resté vide, car `try_files $uri $uri/ =404` renvoie 404 sans journaliser. Le bon réflexe est de lire la **configuration réellement chargée** (`nginx -T`), pas seulement les journaux.

## 4. Correction

Correction ciblée : **rejouer la configuration de référence** avec Ansible plutôt que corriger le fichier à la main (le dépôt Git est la source de vérité).

```bash
ansible-playbook playbooks/linux_base.yml --limit linux01
```

- **1ʳᵉ tentative (P-72a) : échec partiel.** La tâche « Virtual host nginx » restaure bien le fichier (`changed`), mais la vérification « Le site répond en HTTP 200 » échoue (nginx n'a pas encore rechargé) et interrompt le play **avant** l'exécution des handlers : le rechargement notifié n'a jamais lieu, nginx garde l'ancienne configuration en mémoire. Au 2ᵉ passage, le fichier est déjà bon (`changed=0`), la notification est perdue : toujours 404.
- **Correction du playbook :** ajout de `ansible.builtin.meta: flush_handlers` juste avant les vérifications, pour que les rechargements en attente soient appliqués avant de tester le service.
- **2ᵉ tentative (P-72) : succès.** Après reproduction n°2 de l'incident, un seul passage du playbook corrigé restaure le fichier, exécute le handler « Recharger nginx » et passe les tests HTTP 200 (`failed=0`).

En production, la mitigation immédiate aurait été un `systemctl reload nginx` manuel après la 1ʳᵉ tentative ; ici, l'incident a été reproduit pour démontrer que la correction du playbook suffit à elle seule.

## 5. Retour à la normale (P-73)

- `systemctl is-active nginx` = `active` ; `curl -I http://127.0.0.1/` = **200** ; `nginx -T` → `root /var/www/infraready;` ; configuration identique à la sauvegarde d'avant incident ; rechargement tracé dans `journalctl -u nginx` à 19:30:51.
- Depuis OPS01 : **200** par IP et par nom DNS ; 2ᵉ passage du playbook `changed=0 failed=0`.

## 6. Retour arrière disponible

- Sauvegarde du fichier : `/root/infraready.nginx.bak-incident-h` sur LINUX01 (`cp` puis `systemctl reload nginx`).
- Configuration de référence : `ansible/playbooks/templates/nginx-infraready.conf.j2` dans le dépôt.

## 7. Leçons et actions de prévention

| Leçon | Action |
| --- | --- |
| `nginx -t` ne garantit pas qu'un site fonctionne | Tester en HTTP après chaque rechargement (le playbook le fait, désormais au bon moment) |
| Un test en échec dans un playbook peut masquer un handler non exécuté | `flush_handlers` avant les vérifications (corrigé) ; lire le RECAP (`changed=1 failed=1` est un signal) |
| Un changement manuel sur un serveur géré par Ansible dérive de la référence | Passer par le dépôt + playbook pour tout changement ; rejouer le playbook pour détecter la dérive |
| Le site n'est pas supervisé en HTTP (seul `up` du node_exporter l'est) | Piste : sonde HTTP (`blackbox_exporter`) et alerte `SiteWebHS` dans Prometheus |
