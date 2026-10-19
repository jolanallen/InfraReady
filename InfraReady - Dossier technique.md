---
title: InfraReady — Modèle de dossier technique
type: livrable à compléter
status: en cours
version: v0.1
tags:
  - infraready
  - projet-fil-rouge
  - dossier-technique
---

# InfraReady — Dossier technique

> [!info] À propos de ce modèle
> Modèle fondé sur le sujet officiel du projet fil rouge (2026). À remplir avec les configurations et preuves **réellement obtenues**. Les questions théoriques non notées sont volontairement exclues.

| Champ | Valeur |
| --- | --- |
| **Binôme** | [Nom 1] / [Nom 2] |
| **Classe** | [Groupe] |
| **Lien GitHub** | [URL] |
| **Date / version** | [JJ/MM/AAAA] — v0.1 |
| **Statut du projet** | [En cours / Livré] |

---

## 1. Présentation et périmètre

- **Contexte :** InfraReady souhaite standardiser ses configurations, automatiser l'administration et superviser ses serveurs Linux/Windows.
- **Besoin / contraintes :** [À compléter]
- **Répartition du binôme :** [À compléter]
- **Conventions de preuves :** P-01, P-02, etc. ; pas de secrets dans les captures ou le dépôt.

---

## 2. Architecture et inventaire

**Schéma :** [Insérer image / lien]

| Machine | OS | Rôle | Ressources proposées | IP (à confirmer) |
| --- | --- | --- | --- | --- |
| WIN-DC01 | Windows Server 2025 | AD DS / DNS | 2 vCPU · 4–6 Go · 50 Go | 192.168.50.10 |
| LINUX01 | Ubuntu Server 24.04 LTS | Services Linux, stockage | 2 vCPU · 2–4 Go · 30 Go | 192.168.50.20 |
| OPS01 | Ubuntu Server 24.04 LTS | Ansible, Git, Prometheus, Grafana | 2–4 vCPU · 4–8 Go · 50 Go | 192.168.50.30 |

| Paramètre | Valeur |
| --- | --- |
| **Réseau VMware** | [Host-only / Custom / NAT] |
| **Sous-réseau validé** | [À renseigner] |
| **Domaine / DNS** | [infraready.test / 192.168.50.10 — à valider] |
| **Flux autorisés / pare-feu** | [Ports, source, destination, justification] |
| **Adaptations matérielles** | [À compléter] |

---

## 3. Phase A — Installation et réseau

> [!abstract] Objectif
> Mettre en service les VM, les noms, les adresses et la connectivité du laboratoire.

**Responsable :** [Nom] · **Dates :** [Date(s)] · **Statut :** [À faire / En cours / Fait / Bloqué]

### Travaux réalisés / checklist

- [ ] Créer WIN-DC01, LINUX01 et OPS01 dans VMware Workstation.
- [ ] Installer Windows Server 2025 et Ubuntu Server 24.04 LTS.
- [ ] Configurer les noms d'hôtes et les adresses IP fixes.
- [ ] Configurer le réseau virtuel et vérifier l'isolation.
- [ ] Tester les communications IP entre VM.
- [ ] Configurer et tester la résolution DNS du domaine.
- [ ] Actualiser le schéma d'architecture selon le déploiement réel.

### Procédure et configuration

[À compléter : hyperviseur, versions, paramètres réseau, méthode de configuration IP, difficultés d'installation.]

[Commandes utiles réellement exécutées : `ip address`, `ping`, `ipconfig /all`, `Resolve-DnsName`, etc.]

### Tests et preuves

| Vérification | Attendu | Résultat observé | Preuve |
| --- | --- | --- | --- |
| Démarrage des trois VM | Trois VM fonctionnelles | [Résultat réel] | [P-..] |
| Adressage IP | IP conforme au plan validé | [Résultat réel] | [P-..] |
| Connectivité croisée | Communication autorisée fonctionnelle | [Résultat réel] | [P-..] |
| Résolution DNS | Enregistrements / domaine résolus | [Résultat réel] | [P-..] |

### Difficultés / décision / retour arrière

[À compléter : problème, cause supposée ou confirmée, correction, résultat et lien de preuve.]

---

## 4. Phase B — Administration Windows

> [!abstract] Objectif
> Rendre l'annuaire et le DNS opérationnels, documenter comptes, groupes et journaux.

**Responsable :** [Nom] · **Dates :** [Date(s)] · **Statut :** [À faire / En cours / Fait / Bloqué]

### Travaux réalisés / checklist

- [ ] Installer AD DS sur WIN-DC01.
- [ ] Créer le domaine de laboratoire et configurer DNS.
- [ ] Créer au moins deux groupes de test.
- [ ] Créer plusieurs comptes de test et les affecter aux groupes.
- [ ] Décrire les droits et accès attribués.
- [ ] Vérifier les journaux et événements Windows pertinents.
- [ ] Démontrer l'état du domaine et les tests DNS.

### Procédure et configuration

[À compléter : domaine retenu, OU si créées, tableau des groupes/comptes fictifs, droits accordés, journaux consultés.]

[Commandes / outils réellement utilisés : Server Manager, PowerShell, `Get-ADDomain`, `Get-ADGroup`, `Resolve-DnsName`, observateur d'événements…]

### Tests et preuves

| Vérification | Attendu | Résultat observé | Preuve |
| --- | --- | --- | --- |
| Domaine AD | Domaine créé et accessible | [Résultat réel] | [P-..] |
| Comptes et groupes | Au moins 2 groupes + plusieurs comptes présents | [Résultat réel] | [P-..] |
| DNS interne | Résolution du domaine validée | [Résultat réel] | [P-..] |
| Journaux Windows | Événements vérifiés et interprétés | [Résultat réel] | [P-..] |

### Difficultés / décision / retour arrière

[À compléter : problème, cause supposée ou confirmée, correction, résultat et lien de preuve.]

---

## 5. Phase C — Administration Linux

> [!abstract] Objectif
> Gérer identités, permissions, services, stockage, mises à jour et journaux sur Ubuntu.

**Responsable :** [Nom] · **Dates :** [Date(s)] · **Statut :** [À faire / En cours / Fait / Bloqué]

### Travaux réalisés / checklist

- [ ] Créer et configurer des utilisateurs et groupes Linux.
- [ ] Attribuer et vérifier les permissions.
- [ ] Installer un service applicatif simple (ex. serveur web).
- [ ] Administrer et contrôler les processus et services.
- [ ] Ajouter un disque virtuel de test, créer un système de fichiers.
- [ ] Configurer et documenter le montage du disque.
- [ ] Mettre Ubuntu à jour selon une procédure contrôlée.
- [ ] Lire et analyser des journaux système.

### Procédure et configuration

[À compléter : service choisi, utilisateurs/groupes créés, dossier concerné, système de fichiers, UUID/montage, données de test.]

[Commandes réellement utilisées : `id`, `groups`, `ls -l`, `chmod`, `systemctl`, `curl`, `lsblk`, `blkid`, `findmnt`, `journalctl`…]

### Tests et preuves

| Vérification | Attendu | Résultat observé | Preuve |
| --- | --- | --- | --- |
| Comptes / permissions | Droits conformes au besoin | [Résultat réel] | [P-..] |
| Service applicatif | Service accessible et fonctionnel | [Résultat réel] | [P-..] |
| Stockage de test | Disque formaté sur la bonne cible et monté | [Résultat réel] | [P-..] |
| Maintenance et logs | Mises à jour et journaux vérifiés | [Résultat réel] | [P-..] |

### Difficultés / décision / retour arrière

[À compléter : problème, cause supposée ou confirmée, correction, résultat et lien de preuve.]

---

## 6. Phase D — Automatisation avec Ansible

> [!abstract] Objectif
> Fournir des playbooks Linux et Windows reproductibles et idéalement idempotents.

**Responsable :** [Nom] · **Dates :** [Date(s)] · **Statut :** [À faire / En cours / Fait / Bloqué]

### Travaux réalisés / checklist

- [ ] Installer et préparer Ansible sur OPS01.
- [ ] Créer l'inventaire et les variables nécessaires.
- [ ] Configurer/tester SSH pour Linux et WinRM/PSRP pour Windows.
- [ ] Créer au moins un playbook Linux.
- [ ] Créer au moins un playbook Windows.
- [ ] Automatiser plusieurs tâches de configuration.
- [ ] Contrôler la bonne exécution et traiter les erreurs.
- [ ] Rejouer les playbooks et évaluer l'idempotence.
- [ ] Documenter commandes, prérequis, dépendances et résultats.

### Procédure et configuration

[À compléter : fichiers hosts, variables sans secrets, nom des playbooks, actions automatisées et logique de vérification.]

[Commandes réellement utilisées : `ansible --version`, `ansible-inventory`, `ansible … -m ping`, `ansible-playbook …`, résultats du 2e lancement.]

### Tests et preuves

| Vérification | Attendu | Résultat observé | Preuve |
| --- | --- | --- | --- |
| Inventaire Ansible | Hôtes Linux et Windows décrits | [Résultat réel] | [P-..] |
| Connexions | Linux SSH et Windows transport validés | [Résultat réel] | [P-..] |
| Playbook Linux | Exécution sans erreur bloquante | [Résultat réel] | [P-..] |
| Playbook Windows | Exécution sans erreur bloquante | [Résultat réel] | [P-..] |
| Second passage | État stable / changements expliqués | [Résultat réel] | [P-..] |

### Difficultés / décision / retour arrière

[À compléter : problème, cause supposée ou confirmée, correction, résultat et lien de preuve.]

---

## 7. Phase E — Maintenance et mises à jour

> [!abstract] Objectif
> Formaliser et tester une maintenance sûre et traçable sur les deux OS.

**Responsable :** [Nom] · **Dates :** [Date(s)] · **Statut :** [À faire / En cours / Fait / Bloqué]

### Travaux réalisés / checklist

- [ ] Écrire une procédure de maintenance standard.
- [ ] Automatiser les mises à jour Linux.
- [ ] Documenter et tester les mises à jour Windows.
- [ ] Vérifier l'espace disque et l'état des services.
- [ ] Documenter les précautions avant redémarrage et changement majeur.
- [ ] Conserver une trace des exécutions et résultats.

### Procédure et configuration

[À compléter : pré-contrôles, snapshot, procédure et fenêtre de maintenance, ordre des opérations, retour arrière.]

[Commandes et interfaces réellement utilisées : `apt`, PowerShell/Windows Update, `df -h`, `Get-Volume`, `systemctl`, `Get-Service`…]

### Tests et preuves

| Vérification | Attendu | Résultat observé | Preuve |
| --- | --- | --- | --- |
| Mise à jour Linux | Procédure automatisée vérifiable | [Résultat réel] | [P-..] |
| Mise à jour Windows | Procédure exécutée et documentée | [Résultat réel] | [P-..] |
| Capacité disque | État relevé et interprété | [Résultat réel] | [P-..] |
| État des services | Services critiques contrôlés | [Résultat réel] | [P-..] |

### Difficultés / décision / retour arrière

[À compléter : problème, cause supposée ou confirmée, correction, résultat et lien de preuve.]

---

## 8. Phase F — Supervision Prometheus et Grafana

> [!abstract] Objectif
> Collecter et visualiser les métriques réelles des serveurs et présenter une alerte.

**Responsable :** [Nom] · **Dates :** [Date(s)] · **Statut :** [À faire / En cours / Fait / Bloqué]

### Travaux réalisés / checklist

- [ ] Installer et configurer Prometheus sur OPS01.
- [ ] Configurer Node Exporter pour LINUX01.
- [ ] Configurer Windows Exporter ou collecteur équivalent pour WIN-DC01.
- [ ] Vérifier les cibles et données reçues par Prometheus.
- [ ] Installer/configurer Grafana avec Prometheus comme source.
- [ ] Créer un dashboard avec CPU, mémoire, stockage, disponibilité.
- [ ] Démontrer un seuil ou une alerte simple.
- [ ] Documenter origine, ports et cheminement des métriques.

### Procédure et configuration

[À compléter : targets, ports réellement utilisés, nom du dashboard, captures, règle et condition d'alerte.]

[Commandes / points de contrôle réellement utilisés : `/targets`, métriques exporters, Grafana datasource, dashboards, journaux services.]

### Tests et preuves

| Vérification | Attendu | Résultat observé | Preuve |
| --- | --- | --- | --- |
| Collecte Linux | Métriques de LINUX01 disponibles | [Résultat réel] | [P-..] |
| Collecte Windows | Métriques de WIN-DC01 disponibles | [Résultat réel] | [P-..] |
| Source Grafana | Prometheus connecté | [Résultat réel] | [P-..] |
| Dashboard | CPU, RAM, disque et disponibilité visibles | [Résultat réel] | [P-..] |
| Seuil / alerte | Démonstration vérifiable | [Résultat réel] | [P-..] |

### Difficultés / décision / retour arrière

[À compléter : problème, cause supposée ou confirmée, correction, résultat et lien de preuve.]

---

## 9. Phase G — GitHub et intégration continue

> [!abstract] Objectif
> Versionner les livrables et valider le dépôt automatiquement via GitHub Actions.

**Responsable :** [Nom] · **Dates :** [Date(s)] · **Statut :** [À faire / En cours / Fait / Bloqué]

### Travaux réalisés / checklist

- [ ] Créer un dépôt GitHub adapté au binôme.
- [ ] Organiser playbooks, scripts, variables, monitoring et docs.
- [ ] Utiliser des commits descriptifs des deux membres.
- [ ] Créer `.github/workflows/validation.yml`.
- [ ] Déclencher des validations à chaque push ou pull request.
- [ ] Inclure des contrôles pertinents (ex. syntax-check / lint / fichiers).
- [ ] Fournir une preuve d'exécution réussie du workflow.
- [ ] Contrôler l'absence de secrets en clair.

### Procédure et configuration

[À compléter : URL du dépôt, structure réelle, branche, déclencheurs, jobs et règles de validation.]

[À compléter : commandes Git / contrôles de validation, lien du run GitHub Actions.]

### Tests et preuves

| Vérification | Attendu | Résultat observé | Preuve |
| --- | --- | --- | --- |
| Dépôt et arborescence | Fichiers attendus présents | [Résultat réel] | [Lien] |
| Contributions | Contributions du binôme traçables | [Résultat réel] | [Lien] |
| Workflow automatique | Push / PR déclenche la validation | [Résultat réel] | [P-..] |
| Pipeline vert | Exécution terminée avec succès | [Résultat réel] | [P-..] |

### Difficultés / décision / retour arrière

[À compléter : problème, cause supposée ou confirmée, correction, résultat et lien de preuve.]

---

## 10. Phase H — Diagnostic d'incident

> [!abstract] Objectif
> Reproduire un incident simple, contrôlé, réversible et justifier le retour à la normale.

**Responsable :** [Nom] · **Dates :** [Date(s)] · **Statut :** [À faire / En cours / Fait / Bloqué]

### Travaux réalisés / checklist

- [ ] Choisir un incident du labo (service, DNS, stockage, exporter, playbook…).
- [ ] Décrire le symptôme initial et l'heure du constat.
- [ ] Consigner les tests effectués et les journaux consultés.
- [ ] Identifier une cause confirmée ou une hypothèse explicitement signalée.
- [ ] Appliquer et documenter une correction ciblée.
- [ ] Rejouer les tests pour confirmer le retour à la normale.
- [ ] Joindre les preuves et préparer un rapport d'incident distinct.

### Procédure et configuration

[À compléter : date, incident choisi, systèmes concernés, impact, chronologie et cause / hypothèse.]

[À compléter : commandes, journaux, captures avant et après, changement réalisé.]

### Tests et preuves

| Vérification | Attendu | Résultat observé | Preuve |
| --- | --- | --- | --- |
| Reproduction | Symptôme observé et documenté | [Résultat réel] | [P-..] |
| Diagnostic | Hypothèse vérifiée / cause expliquée | [Résultat réel] | [P-..] |
| Correction | Modification clairement décrite | [Résultat réel] | [P-..] |
| Retour à la normale | Test identique à nouveau réussi | [Résultat réel] | [P-..] |

### Difficultés / décision / retour arrière

[À compléter : problème, cause supposée ou confirmée, correction, résultat et lien de preuve.]

---

## 11. Sécurité et limites d'intervention

- [ ] VM du laboratoire uniquement, aucun système externe
- [ ] Cibles contrôlées avant formatage / partitionnement
- [ ] Snapshots avant changements majeurs
- [ ] Moindre privilège
- [ ] Ports limités au strict besoin
- [ ] Aucun secret en clair dans Git ou dans ce dossier
- [ ] Playbooks testés avant exécution large
- [ ] Changements perturbateurs documentés
- [ ] Fonctionnalités non réalisées signalées

**Mesures concrètes et preuves :** [À compléter]

---

## 12. Recette finale et matrice des preuves

### Recette finale

| Phase | Validation finale | État | Preuve |
| --- | --- | --- | --- |
| A | VM / IP / réseau / DNS | [À valider] | [P-..] |
| B | AD DS / groupes / comptes / DNS | [À valider] | [P-..] |
| C | Permissions / service / stockage / logs | [À valider] | [P-..] |
| D | Playbooks Linux & Windows / idempotence | [À valider] | [P-..] |
| E | Mises à jour / maintenance | [À valider] | [P-..] |
| F | Exporters / dashboard / alerte | [À valider] | [P-..] |
| G | Workflow GitHub Actions réussi | [À valider] | [P-..] |
| H | Incident corrigé / retour normal | [À valider] | [P-..] |

### Matrice des preuves

| ID | Date | Test ou capture | Fichier / lien |
| --- | --- | --- | --- |
| P-01 | [Date] | [Description] | [Chemin ou URL] |
| P-02 | [Date] | [Description] | [Chemin ou URL] |
| P-03 | [Date] | [Description] | [Chemin ou URL] |
| P-04 | [Date] | [Description] | [Chemin ou URL] |

---

## 13. Difficultés, limites et bilan

- **Blocages et corrections :** [À compléter]
- **Écarts à l'architecture :** [À compléter]
- **Fonctionnalités inachevées :** [À compléter]
- **Bilan du binôme :** [À compléter]

---

## 14. Annexes et journal de changements

### Arborescence GitHub

```text
[Coller ici l'arbre réellement retenu]
```

### Journal de changements

| Date | Auteur | Modification | Validation | Preuve / rollback |
| --- | --- | --- | --- | --- |
| [Date] | [Nom] | [Étape] | [Résultat] | [P-..] |

### Annexes

[Liens captures, journaux expurgés, extraits de configurations, exports dashboards]

---

## 15. Checklist de remise

- [ ] Dépôt GitHub prêt, avec contributions du binôme
- [ ] Dossier technique exporté en PDF + lien du dépôt
- [ ] Captures et sorties de commandes classées
- [ ] Rapport d'incident distinct rédigé
- [ ] PowerPoint final préparé selon modalités du formateur
- [ ] Aucun secret présent dans les livrables
- [ ] Tous les écarts et limites sont mentionnés

**Date et plateforme de remise :** [À compléter]
