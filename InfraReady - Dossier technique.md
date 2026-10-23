---
title: InfraReady — Dossier technique
type: livrable
status: en cours
version: v0.5
updated: 2026-10-23
tags:
  - infraready
  - projet-fil-rouge
  - dossier-technique
---

# InfraReady — Dossier technique

> [!info] À propos de ce dossier
> Rempli avec les configurations et preuves **réellement obtenues** sur le laboratoire. Chaque résultat renvoie à une preuve `P-xx` stockée dans `docs/preuves/` (sorties de commandes horodatées, captures). Aucun secret n'apparaît dans ce dossier ni dans le dépôt.

> [!summary] Sommaire
> **Cadre :** [[#1. Présentation et périmètre|1. Présentation]] · [[#2. Architecture et inventaire|2. Architecture]]
> **Phases :** [[#3. Phase A — Installation et réseau|A Installation]] · [[#4. Phase B — Administration Windows|B Windows]] · [[#5. Phase C — Administration Linux|C Linux]] · [[#6. Phase D — Automatisation avec Ansible|D Ansible]] · [[#7. Phase E — Maintenance et mises à jour|E Maintenance]] · [[#8. Phase F — Supervision Prometheus et Grafana|F Supervision]] · [[#9. Phase G — GitHub et intégration continue|G GitHub]] · [[#10. Phase H — Diagnostic d'incident|H Incident]]
> **TP :** [[#11. Séance 4 — Stockage, processus, scripts et scénarios de panne|Séance 4]] · **[[#12. Séance 6 — Maintenance opérationnelle et supervision|Séance 6 — maintenance opérationnelle et supervision]]** (note de synthèse : [[InfraReady - Séance 6]])
> **Clôture :** [[#13. Sécurité et limites d'intervention|13. Sécurité]] · [[#14. Recette finale et matrice des preuves|14. Recette et preuves]] · [[#15. Difficultés, limites et bilan|15. Bilan]] · [[#16. Annexes et journal de changements|16. Annexes]] · [[#17. Checklist de remise|17. Checklist]]

| Champ | Valeur |
| --- | --- |
| **Équipe** | MIR Mahan / Jolan Allen (chef de projet) / Kenzi Bendjelloul |
| **Classe** | B3 Cybersécurité |
| **Lien GitHub** | https://github.com/jolanallen/InfraReady |
| **Date / version** | 23/10/2026 — v0.5 |
| **Statut du projet** | Phases A à H, TP des séances 4 et 6 réalisés (correction de l'incident INC-2026-10-23-01 en attente de validation) — finalisation avant remise (bilans, PDF, oral) |

---

## 1. Présentation et périmètre

- **Contexte :** InfraReady souhaite standardiser ses configurations, automatiser l'administration et superviser ses serveurs Linux/Windows.
- **Besoin / contraintes :**
	- Laboratoire de 3 serveurs (1 Windows Server 2025, 2 Ubuntu Server 24.04 LTS), isolé du réseau personnel.
	- Administration reproductible (Ansible), supervision (Prometheus/Grafana), dépôt versionné et validé par CI.
	- Aucune donnée réelle : comptes, groupes et données sont fictifs.
- **Répartition de l'équipe :** Jolan Allen, chef de projet (planification, coordination, suivi et dépôt de remise) ; Kenzi Bendjelloul, partie Ansible (phase D) ; les autres phases ont été réalisées conjointement par MIR Mahan et Jolan Allen.
- **Conventions de preuves :** numérotation par phase — A = P-0x, B = P-1x, C = P-2x, D = P-3x, E = P-4x, F = P-5x, G = P-6x, H = P-7x ; séance 6 = P-8x. Les images `P-xx-rendu-*.png` sont des **rendus visuels de sorties de commandes réelles**, dont le texte intégral est dans le fichier `.txt` cité ; les autres `.png` sont des captures d'écran de Prometheus, Grafana ou GitHub. Les sorties sont capturées automatiquement avec l'heure et la commande exécutée.

---

## 2. Architecture et inventaire

```mermaid
flowchart LR
    subgraph HOME["Réseau domestique 192.168.0.0/24"]
        PC["Poste d'administration"]
        GW["Box / passerelle<br/>192.168.0.254"]
        subgraph PVE["Hôte Proxmox VE 9.1 — corsair1 — 192.168.0.7 (vmbr0)"]
            NAT{{"vmbr1 192.168.50.1<br/>NAT nftables<br/>LAN domestique bloqué"}}
            subgraph LAB["Labo InfraReady 192.168.50.0/24 (vmbr1)"]
                DC["WIN-DC01<br/>192.168.50.10<br/>AD DS · DNS · windows_exporter"]
                L1["LINUX01<br/>192.168.50.20<br/>nginx · /data · node_exporter"]
                OPS["OPS01<br/>192.168.50.30<br/>Ansible · Git · Prometheus · Grafana"]
            end
        end
    end
    PC -- "SSH (rebond via l'hôte)" --> NAT
    NAT --- DC & L1 & OPS
    OPS -- "SSH 22 / HTTP 80 / 9100" --> L1
    OPS -- "WinRM 5985 / 9182" --> DC
    L1 & OPS -- "DNS 53" --> DC
    NAT -- "Internet (MAJ)" --> GW
```

| Machine | VMID | OS | Rôle | Ressources réelles | IP |
| --- | --- | --- | --- | --- | --- |
| WIN-DC01 | 100 | Windows Server 2025 Standard Evaluation (Desktop Experience) | AD DS / DNS | 4 vCPU (2×2) · 6 Go · 50 Go (IDE), UEFI + TPM 2.0, carte e1000e | 192.168.50.10 |
| LINUX01 | 101 | Ubuntu Server 24.04.5 LTS | Services Linux (nginx), stockage | 4 vCPU (2×2) · 4 Go · 30 Go + **10 Go de test** (`/data`) | 192.168.50.20 |
| OPS01 | 102 | Ubuntu Server 24.04.5 LTS | Ansible, Git, Prometheus, Grafana | 8 vCPU (2×4) · 6 Go · 50 Go | 192.168.50.30 |

| Paramètre | Valeur |
| --- | --- |
| **Hyperviseur / réseau** | Proxmox VE 9.1.1 (au lieu de VMware Workstation — voir écarts). Pont dédié `vmbr1` sans carte physique, NAT vers `vmbr0`. |
| **Sous-réseau validé** | 192.168.50.0/24 — passerelle 192.168.50.1 (hôte Proxmox) |
| **Domaine / DNS** | `infraready.test` (NetBIOS `INFRAREADY`) — DNS = 192.168.50.10, redirecteurs 1.1.1.1 / 9.9.9.9 |
| **Adaptations matérielles** | Hôte 16 cœurs / ~46 Go RAM : pas de réduction nécessaire. Disques sur pool ZFS `pool-ssd`. |

**Flux autorisés / pare-feu**

| Source | Destination | Port | Justification | Contrôle |
| --- | --- | --- | --- | --- |
| Labo 192.168.50.0/24 | Internet | tous (sortant) | Mises à jour, téléchargements | NAT nftables sur l'hôte |
| Labo 192.168.50.0/24 | Réseau domestique 192.168.0.0/24 | — | **Interdit** (isolation) | nftables `forward` : `ct state new drop` |
| Labo (dont rebond hôte .1) | LINUX01 | 22/tcp | Administration SSH | UFW (clé uniquement, mot de passe désactivé) |
| Labo | LINUX01 | 80/tcp | Service web | UFW |
| OPS01 (.30) | LINUX01 | 9100/tcp | node_exporter | UFW (OPS01 seul) |
| Labo | WIN-DC01 | 5985/tcp | WinRM (Ansible) | Pare-feu Windows limité à 192.168.50.0/24 |
| OPS01 (.30) | WIN-DC01 | 9182/tcp | windows_exporter | Pare-feu Windows (OPS01 seul) |
| Labo | WIN-DC01 | 53, 88, 389, 445… | DNS / Kerberos / LDAP / SMB | Règles AD par défaut de Windows |
| Labo | WIN-DC01 | ICMP echo | Tests de connectivité | Pare-feu Windows limité au labo |

---

## 3. Phase A — Installation et réseau

> [!abstract] Objectif
> Mettre en service les VM, les noms, les adresses et la connectivité du laboratoire.

**Responsable :** MIR Mahan / Jolan Allen · **Dates :** 19/10/2026 · **Statut :** Fait

### Travaux réalisés / checklist

- [x] Créer WIN-DC01, LINUX01 et OPS01 (Proxmox VE, VMID 100 à 102).
- [x] Installer Windows Server 2025 et Ubuntu Server 24.04 LTS (installations automatiques).
- [x] Configurer les noms d'hôtes et les adresses IP fixes.
- [x] Configurer le réseau virtuel et vérifier l'isolation.
- [x] Tester les communications IP entre VM.
- [x] Configurer et tester la résolution DNS du domaine.
- [x] Actualiser le schéma d'architecture selon le déploiement réel.

### Procédure et configuration

**Réseau du labo (hôte Proxmox)** — sauvegarde préalable de `/etc/network/interfaces` (`interfaces.bak-infraready`), puis ajout du pont `vmbr1` (fichier `lab/proxmox/vmbr1.interfaces`) et des règles `lab/proxmox/infraready-nat.nft` :
- `masquerade` des adresses 192.168.50.0/24 sortant par `vmbr0` (accès Internet) ;
- `drop` de toute **nouvelle** connexion du labo vers 192.168.0.0/24 (isolation du réseau domestique).

L'hôte n'ayant pas `iptables`, la NAT est écrite en **nftables** dans une table dédiée (`infraready_nat`), chargée/supprimée par `post-up`/`post-down` du pont.

**Installations automatiques** (aucune saisie manuelle) :

| VM | Méthode | Points clés |
| --- | --- | --- |
| LINUX01 / OPS01 | ISO `ubuntu-24.04.5-live-server-amd64.iso` (SHA-256 vérifié) + 2ᵉ lecteur « CIDATA » contenant un fichier **autoinstall** (`lab/autoinstall-user-data.yml.tpl`) | Hostname, IP fixe, LVM sur tout le disque, clavier fr, compte `infraadmin` (mot de passe haché SHA-512), SSH par clé uniquement, `qemu-guest-agent`, MAJ de sécurité pendant l'installation |
| WIN-DC01 | ISO Windows Server 2025 Eval + 2ᵉ lecteur contenant `autounattend.xml` (`lab/autounattend.xml.tpl`) | Image n°2 (Standard, Desktop Experience) identifiée dans `install.wim`, partitionnement UEFI/GPT, nom `WIN-DC01`, IP fixe par adresse MAC, fuseau Romance, clavier fr, WinRM + ping autorisés **depuis le labo uniquement** |

Les fichiers de réponse contenant de vrais mots de passe ont été **supprimés du stockage Proxmox** après installation ; le dépôt ne contient que des modèles avec `__PLACEHOLDERS__`.

**DNS** : après création du domaine (phase B), les VM Linux pointent sur le DC (`/etc/netplan/50-cloud-init.yaml` : `nameservers 192.168.50.10`, `search infraready.test`, sauvegarde dans `/root/`). La configuration réseau de cloud-init est désactivée par l'installeur (`90-installer-network.cfg`) : le changement est persistant.

**Commandes réellement utilisées** : `qm set / qm start / qm sendkey / qm snapshot`, `nft list table`, `ip -br addr`, `ip route`, `ping`, `curl`, `resolvectl dns|domain|query`, `getent ahostsv4`, `Get-NetIPConfiguration`, `Resolve-DnsName`, `Test-Connection`.

![[P-03-win-dc01-installe-server-manager.png|600]]

### Tests et preuves

| Vérification | Attendu | Résultat observé | Preuve |
| --- | --- | --- | --- |
| Démarrage des trois VM | Trois VM fonctionnelles | 3 VM `running`, snapshot `s01_installation_ok` sur chacune ; Windows installé en ~10 min, Ubuntu en ~6 min | [P-01](docs/preuves/P-01-proxmox-vms-et-reseau.txt), [P-03](docs/preuves/P-03-win-dc01-installe-server-manager.png) |
| Adressage IP | IP conforme au plan validé | .10 / .20 / .30, passerelle 192.168.50.1, toutes sur `vmbr1` | [P-02](docs/preuves/P-02-linux01-ip-connectivite-isolation.txt), [P-02b](docs/preuves/P-02b-ops01-ip-connectivite-isolation.txt), [P-04c](docs/preuves/P-04c-win-dc01-ip-dns.txt) |
| Connectivité croisée | Communication autorisée fonctionnelle | Ping OK entre les 3 VM et vers la passerelle ; Internet OK (HTTP 200 archive.ubuntu.com) | [P-02](docs/preuves/P-02-linux01-ip-connectivite-isolation.txt), [P-02b](docs/preuves/P-02b-ops01-ip-connectivite-isolation.txt), [P-04c](docs/preuves/P-04c-win-dc01-ip-dns.txt) |
| Isolation | Labo sans accès au réseau domestique | 192.168.0.254 **bloqué** depuis le labo, mais répond depuis l'hôte → blocage dû à la règle nftables | [P-02](docs/preuves/P-02-linux01-ip-connectivite-isolation.txt) |
| Résolution DNS | Enregistrements / domaine résolus | A, PTR et SRV `_ldap._tcp.dc._msdcs` résolus depuis les 2 VM Linux et le DC ; nom court `win-dc01` résolu grâce au domaine de recherche | [P-04](docs/preuves/P-04-linux01-resolution-dns-domaine.txt), [P-04b](docs/preuves/P-04b-ops01-resolution-dns-domaine.txt), [P-04c](docs/preuves/P-04c-win-dc01-ip-dns.txt) |

### Difficultés / décision / retour arrière

| Problème | Cause | Correction | Résultat |
| --- | --- | --- | --- |
| Les VM Linux avaient l'ISO Ubuntu **26.04** | Mauvaise ISO attachée à la création | Téléchargement d'Ubuntu 24.04.5 sur l'hôte, SHA-256 vérifié, ISO remplacée | Conforme au sujet |
| Carte réseau `e1000` sur WIN-DC01 | Pilote non garanti sur Windows Server 2025 | Passage en `e1000e` (même adresse MAC) | Réseau fonctionnel dès l'installation |
| L'installeur Ubuntu demande « Continue with autoinstall? » | Mot-clé `autoinstall` absent de la ligne de commande du noyau | Réponse `yes` envoyée par `qm sendkey` | Installation sans autre intervention |
| Pas d'`iptables` sur l'hôte Proxmox 9 | Système basé sur nftables | Règles écrites en nftables, table dédiée | NAT + isolation fonctionnelles |
| Le DC n'avait pas d'enregistrement PTR | Zone inverse créée **après** la promotion du DC | `windows_base.yml` déclenche l'enregistrement dynamique du DC (`Register-DnsClient`) si son PTR manque (voir phase D) | PTR .10 résolu ([P-35](docs/preuves/P-35-playbook-windows-correction-ptr-dc.txt), [P-37](docs/preuves/P-37-playbook-windows-ptr-dc-stable.txt)) |
| Mot de passe `sudo` de l'hôte visible dans l'en-tête d'une preuve | Le script de capture recopiait la commande complète | Preuve nettoyée, script corrigé (affiche `sudo`), vérification systématique avant chaque commit | Aucun secret dans le dépôt |

Retour arrière disponible : snapshot `s01_installation_ok` (3 VM) et `interfaces.bak-infraready` sur l'hôte.

---

## 4. Phase B — Administration Windows

> [!abstract] Objectif
> Rendre l'annuaire et le DNS opérationnels, documenter comptes, groupes et journaux.

**Responsable :** MIR Mahan / Jolan Allen · **Dates :** 19/10/2026 · **Statut :** Fait

### Travaux réalisés / checklist

- [x] Installer AD DS sur WIN-DC01.
- [x] Créer le domaine de laboratoire et configurer DNS.
- [x] Créer au moins deux groupes de test.
- [x] Créer plusieurs comptes de test et les affecter aux groupes.
- [x] Décrire les droits et accès attribués.
- [x] Vérifier les journaux et événements Windows pertinents.
- [x] Démontrer l'état du domaine et les tests DNS.

### Procédure et configuration

Snapshot `s02_avant_adds` pris avant toute modification. Les actions sont lancées depuis OPS01 via WinRM (Ansible) :

1. **AD DS + forêt** — playbook `ansible/playbooks/windows_adds.yml` (équivalent PowerShell indiqué en tête du fichier : `Install-WindowsFeature AD-Domain-Services`, `Install-ADDSForest`) :
	- forêt `infraready.test`, NetBIOS `INFRAREADY`, niveau fonctionnel **Windows2025Domain / Windows2025Forest** ;
	- DNS intégré à AD, redirecteurs 1.1.1.1 et 9.9.9.9, le DC utilise son propre DNS ;
	- source de temps NTP `fr.pool.ntp.org` (le DC racine fournit l'heure au domaine — indispensable pour Kerberos) ;
	- mot de passe DSRM fourni depuis le **vault Ansible chiffré**.
2. **Objets de l'annuaire** — script `scripts/ad-objets.ps1` (rejouable, mot de passe initial passé en paramètre depuis le vault) :

| OU | Groupe (global, sécurité) | Membres | Rôle fictif |
| --- | --- | --- | --- |
| `OU=Groupes,OU=InfraReady` | `GG_Support_IT` | j.martin, s.bernard | Support informatique |
| `OU=Groupes,OU=InfraReady` | `GG_Comptabilite` | l.petit, t.moreau | Service comptabilité |

Comptes dans `OU=Utilisateurs,OU=InfraReady`, activés, **changement de mot de passe obligatoire à la première connexion**. OU protégées contre la suppression accidentelle.

**Droits et accès attribués** (appliqués par `windows_base.yml`, phase D) :

| Ressource | GG_Comptabilite | GG_Support_IT | Autres utilisateurs |
| --- | --- | --- | --- |
| Partage SMB `\\WIN-DC01\Compta` | Modification (Change) | Lecture | Aucun accès (partage masqué de l'énumération) |
| NTFS `C:\Partages\Comptabilite` | Modify | ReadAndExecute | `BUILTIN\Users` retiré, héritage désactivé |

Principe : moindre privilège — le support peut consulter pour dépanner, seule la comptabilité modifie.

**Outils réellement utilisés** : `Get-ADDomain`, `Get-ADForest`, `Get-ADUser`, `Get-ADGroupMember`, `Resolve-DnsName`, `Get-DnsServerZone`, `Get-DnsServerForwarder`, `dcdiag`, `w32tm`, `Get-WinEvent`, Server Manager (capture P-03).

### Tests et preuves

| Vérification | Attendu | Résultat observé | Preuve |
| --- | --- | --- | --- |
| Domaine AD | Domaine créé et accessible | `infraready.test` / `INFRAREADY`, DC `WIN-DC01.infraready.test`, catalogue global ; dcdiag : 10 tests fonctionnels réussis (Connectivity, Advertising, SysVolCheck, MachineAccount, NetLogons, RidManager, Services, DNS ×2, FsmoCheck) | [P-10](docs/preuves/P-10-adds-installation-foret.txt), [P-12](docs/preuves/P-12-domaine-dns-verifications.txt), [P-12b](docs/preuves/P-12b-dcdiag-tests-fonctionnels-ntp.txt) |
| Comptes et groupes | Au moins 2 groupes + plusieurs comptes présents | 2 groupes, 4 comptes, appartenances conformes | [P-11](docs/preuves/P-11-ad-ou-groupes-comptes.txt), [P-12](docs/preuves/P-12-domaine-dns-verifications.txt) |
| DNS interne | Résolution du domaine validée | A `infraready.test` et `win-dc01` → .10, SRV LDAP, résolution externe via redirecteurs, zones intégrées AD en mise à jour sécurisée | [P-12](docs/preuves/P-12-domaine-dns-verifications.txt), [P-04c](docs/preuves/P-04c-win-dc01-ip-dns.txt) |
| Journaux Windows | Événements vérifiés et interprétés | voir interprétation ci-dessous | [P-13](docs/preuves/P-13-journaux-windows-ad.txt) |

**Interprétation des journaux (P-13)**

| Journal / ID | Observation | Interprétation |
| --- | --- | --- |
| System 1074 — 15:10:51 | Redémarrage demandé par `shutdown.exe` | Redémarrage de fin de promotion du DC |
| Directory Service 1000 — 15:12:07 | « AD DS startup complete » | Annuaire démarré après promotion |
| DNS Server 2 et 4 — 15:12:38 | Serveur DNS démarré, zones chargées | DNS intégré AD opérationnel |
| Security 4727 / 4720 / 4728 — 15:11:58 | Groupes, comptes et appartenances créés | Comptes et groupes **intégrés** créés avec la forêt |
| Security 4727 / 4720 / 4728 — 15:14:34-35 | 2 groupes, 4 comptes, 4 ajouts aux groupes | Exécution de `ad-objets.ps1` (traçabilité de nos actions) |
| dcdiag `DFSREvent`, `SystemLog` en échec | Erreurs RID pool, SYSVOL non partagé, à 15:12:37 | Événements **transitoires du premier démarrage** d'une nouvelle forêt ; les tests fonctionnels associés (RidManager, SysVolCheck) passent ensuite |

### Difficultés / décision / retour arrière

| Problème | Cause | Correction | Résultat |
| --- | --- | --- | --- |
| 1er lancement de `windows_adds.yml` en échec | Paramètre `reboot_timeout` inexistant dans `microsoft.ad` 1.4.1 (version fournie par Ubuntu) | Paramètre retiré (délai par défaut suffisant) | Forêt créée au 2ᵉ lancement ([P-10a](docs/preuves/P-10a-adds-premier-essai-echec-reboot_timeout.txt) → [P-10](docs/preuves/P-10-adds-installation-foret.txt)) |
| DC synchronisé sur sa propre horloge (« Local CMOS Clock ») | Configuration par défaut | NTP externe configuré dans le playbook | Stratum 2, synchronisé ([P-12b](docs/preuves/P-12b-dcdiag-tests-fonctionnels-ntp.txt)) |
| Événements horodatés **23:52** (dans le futur) | **Hypothèse** : saut d'horloge pendant la promotion, avant toute synchronisation NTP | NTP configuré ; heure du DC vérifiée identique à OPS01 | Plus de dérive observée |
| `win_powershell` refuse le paramètre `path` | Option absente d'`ansible.windows` 2.2.0 | Contenu du script passé par `lookup('file', …)` | Scripts exécutés à distance |
| « Le DC utilise son propre DNS » signale `changed` à chaque exécution de `windows_adds.yml` (constaté le 20/10 lors de la validation des PR) | **Cause confirmée** : `win_dns_client` gère IPv4 et IPv6 ensemble ; avec la seule adresse `127.0.0.1`, il retire `::1` que Windows remet sur un DC. Hypothèse « interface de bouclage » écartée par un test en mode check | `dns_servers: ["127.0.0.1", "::1"]` | 2ᵉ passage `changed=0` ([P-62](docs/preuves/P-62-validation-pr-tests-negatifs.txt) → [P-15](docs/preuves/P-15-windows-adds-dns-idempotence.txt)) |

Retour arrière disponible : snapshots `s02_avant_adds` et `s03_avant_ansible` de WIN-DC01.

---

## 5. Phase C — Administration Linux

> [!abstract] Objectif
> Gérer identités, permissions, services, stockage, mises à jour et journaux sur Ubuntu.

**Responsable :** MIR Mahan / Jolan Allen · **Dates :** 19/10/2026 · **Statut :** Fait

### Travaux réalisés / checklist

- [x] Créer et configurer des utilisateurs et groupes Linux.
- [x] Attribuer et vérifier les permissions.
- [x] Installer un service applicatif simple (nginx).
- [x] Administrer et contrôler les processus et services.
- [x] Ajouter un disque virtuel de test, créer un système de fichiers.
- [x] Configurer et documenter le montage du disque.
- [x] Mettre Ubuntu à jour selon une procédure contrôlée.
- [x] Lire et analyser des journaux système.

### Procédure et configuration

Réalisée **manuellement** sur LINUX01 (commandes conservées dans l'en-tête de chaque preuve), puis reprise dans Ansible en phase D.

**Identités et permissions**

| Compte | Groupes | Usage |
| --- | --- | --- |
| alice, bruno | `webadmins` | Mettent à jour le site web |
| chloe | `auditeurs`, `systemd-journal` | Consulte les journaux et rapports, sans droit d'écriture |
| ansible | — (sudo sans mot de passe, clé SSH) | Compte de service pour l'automatisation |

Les comptes du labo sont **verrouillés** (`passwd -S` → `L`) : aucun mot de passe utilisable, accès via `sudo -u` uniquement.

| Dossier | Propriétaire | Mode | Effet |
| --- | --- | --- | --- |
| `/var/www/infraready` | root:webadmins | `2775` (setgid) | webadmins écrivent, les fichiers héritent du groupe ; les autres lisent |
| `/data/rapports` | root:auditeurs | `2750` | auditeurs lisent, aucun accès pour les autres |

**Service** : nginx 1.24, site `infraready` (vhost dédié, journaux séparés `infraready_access.log` / `infraready_error.log`), site par défaut désactivé, `nginx -t` avant chaque rechargement.

**Stockage** : disque de 10 Go ajouté **à chaud** (`qm set 101 --scsi1 pool-ssd:10,serial=INFRA-DATA01`), identifié par son **numéro de série** (`/dev/disk/by-id/scsi-SQEMU_QEMU_HARDDISK_INFRA-DATA01` → `/dev/sdb`). Formatage uniquement si les 5 contrôles sont conformes (taille 10G, aucune signature, aucune partition, non monté, différent du disque système), sinon arrêt automatique. Système de fichiers ext4 (label `DATA`), montage `/data` **par UUID** avec `nofail` dans `/etc/fstab`.

**Mise à jour contrôlée** : (1) snapshot `s02_avant_maj_c` ; (2) pré-contrôles disque et services ; (3) `apt-get update` + simulation `apt-get -s upgrade` ; (4) `apt-get upgrade` (jamais de suppression de paquet), conservation des fichiers de configuration locaux ; (5) contrôle de `/var/log/apt/history.log` ; (6) vérification de `/var/run/reboot-required`.

**Commandes réellement utilisées** : `groupadd`, `useradd`, `id`, `getent`, `passwd -S`, `chmod`, `chown`, `ls -l`, `sudo -u`, `nginx -t`, `systemctl status|stop|start|restart|is-enabled`, `ss -tlnp`, `ps`, `pgrep`, `curl`, `lsblk`, `wipefs -n`, `mkfs.ext4`, `blkid`, `findmnt`, `mount -a`, `df -hT`, `apt-get`, `journalctl`, `uptime`, `free`.

### Tests et preuves

| Vérification | Attendu | Résultat observé | Preuve |
| --- | --- | --- | --- |
| Comptes / permissions | Droits conformes au besoin | alice écrit dans le site ✔, chloe refusée ✔ ; chloe lit le journal ✔, alice non ✔ ; chloe lit `/data/rapports` ✔, alice refusée ✔ | [P-20](docs/preuves/P-20-linux01-comptes-groupes-permissions.txt), [P-22](docs/preuves/P-22-linux01-disque-test-montage.txt) |
| Service applicatif | Service accessible et fonctionnel | `nginx -t` OK, actif et activé au démarrage, port 80 en écoute, HTTP 200 depuis OPS01 ; stop → HTTP 000, start → 200, restart → nouveau PID maître | [P-21](docs/preuves/P-21-linux01-service-nginx-processus.txt) |
| Stockage de test | Disque formaté sur la bonne cible et monté | Contrôles conformes, `/dev/sdb` ext4 9.8G monté sur `/data` par UUID, remontage via fstab réussi | [P-22](docs/preuves/P-22-linux01-disque-test-montage.txt) |
| Maintenance et logs | Mises à jour et journaux vérifiés | 20 paquets mis à jour (code retour 0), pas de redémarrage requis ; tentative SSH « pirate » et requête 404 retrouvées dans les journaux ; aucune erreur ni unité en échec | [P-23](docs/preuves/P-23-linux01-mise-a-jour-controlee.txt), [P-24](docs/preuves/P-24-linux01-analyse-journaux.txt) |

**Analyse des journaux (P-24)** : `sshd` enregistre `Invalid user pirate from 192.168.50.30` (connexion refusée avant authentification) ; nginx trace `GET /admin.php … 404` depuis OPS01 ; le noyau trace l'arrivée à chaud de `sdb` (10.7 GB) ; `journalctl -p err -b` vide ; `sudo` trace chaque commande privilégiée avec l'utilisateur à l'origine.

### Difficultés / décision / retour arrière

| Problème | Cause | Correction | Résultat |
| --- | --- | --- | --- |
| Premiers contrôles « avant formatage » exécutés sur un chemin inexistant | Nom `/dev/disk/by-id/…` deviné au lieu d'être lu | Aucun formatage n'avait lieu dans ce premier script ; lecture du vrai nom (`ls -l /dev/disk/by-id`) et ajout d'un **arrêt automatique** si un contrôle n'est pas conforme | Formatage sur la bonne cible uniquement |

Retour arrière disponible : snapshot `s02_avant_maj_c` (inclut le disque de test), sauvegarde netplan dans `/root/`.

---

## 6. Phase D — Automatisation avec Ansible

> [!abstract] Objectif
> Fournir des playbooks Linux et Windows reproductibles et idéalement idempotents.

**Responsable :** Kenzi Bendjelloul · **Dates :** 19/10/2026 · **Statut :** Fait

### Travaux réalisés / checklist

- [x] Installer et préparer Ansible sur OPS01.
- [x] Créer l'inventaire et les variables nécessaires.
- [x] Configurer/tester SSH pour Linux et WinRM pour Windows.
- [x] Créer au moins un playbook Linux.
- [x] Créer au moins un playbook Windows.
- [x] Automatiser plusieurs tâches de configuration.
- [x] Contrôler la bonne exécution et traiter les erreurs.
- [x] Rejouer les playbooks et évaluer l'idempotence.
- [x] Documenter commandes, prérequis, dépendances et résultats.

### Procédure et configuration

**Prérequis sur OPS01** : `apt install ansible python3-winrm git jq` → ansible-core 2.16.3 avec les collections `ansible.windows` 2.2.0, `ansible.posix` 1.5.4, `community.general` 8.3.0, `community.windows` 2.1.0, `microsoft.ad` 1.4.1 (liste dans `ansible/requirements.yml`).

**Compte de service** : `scripts/bootstrap-ansible-user.sh` crée l'utilisateur `ansible` (clé ed25519 générée sur OPS01, copiée sur LINUX01, sudo sans mot de passe validé par `visudo -c`).

**Fichiers**

| Fichier | Contenu |
| --- | --- |
| `ansible/ansible.cfg` | Inventaire, journal `~/infraready-logs/ansible.log`, minutage des tâches, fichier de mot de passe du vault (hors dépôt) |
| `inventory/hosts.yml` | Groupes `linux` (linux01, ops01 en connexion locale), `windows` (win-dc01), `monitoring` |
| `group_vars/all.yml` | Sous-réseau, domaine, IP du DC et d'OPS01, fuseau horaire |
| `group_vars/linux/vars.yml` | SSH avec l'utilisateur `ansible` + clé, `become` |
| `group_vars/windows/vars.yml` | WinRM HTTP 5985, NTLM (message chiffré), mot de passe lu dans le vault |
| `group_vars/windows/vault.yml` | **Chiffré AES256** (Ansible Vault) : mots de passe Administrateur, DSRM, initial des comptes AD |

**Playbooks**

| Playbook | Cible | Actions automatisées | Vérifications intégrées |
| --- | --- | --- | --- |
| `windows_adds.yml` | WIN-DC01 | Rôle AD DS, forêt, NTP, redirecteurs et client DNS | Attente des services AD, état du domaine |
| `linux_base.yml` | LINUX01 | Fuseau, paquets, groupes/comptes, droits du site, template nginx + handler de rechargement, montage `/data` par UUID (options `usrquota,grpquota` depuis la séance 6), droits `/data/rapports`, **pare-feu UFW** (22 et 80 depuis le labo, 9100 depuis OPS01, refus par défaut), node_exporter, `openipmi` désactivé, **contrôle planifié du site** (timer systemd, séance 6) | HTTP 200 sur le site, `/metrics` de node_exporter |
| `windows_base.yml` | WIN-DC01 | OU, groupes, comptes (`no_log`), dossier + ACL NTFS + partage SMB, zone inverse, enregistrements A/PTR, windows_exporter **0.31.8** (MSI), règle de pare-feu 9182 réservée à OPS01 | Services NTDS, DNS, Netlogon, kdc, windows_exporter démarrés (`assert`), `/metrics` joignable depuis OPS01 |
| `controle_sante.yml` (séance 6) | les 3 serveurs | **Aucune** : contrôle de santé en lecture seule (identité, heure, disques, services, unités en échec, journaux, DNS, tests fonctionnels) | Tableau OK / ATTENTION / ECHEC / NON APPLICABLE / INACCESSIBLE, échec du play s'il reste un ECHEC (section 12, UC-C2) |
| `linux_quotas.yml` (séance 6, défi) | LINUX01 | Quotas alice / bruno sur le disque de test `/data` | Numéro de série du disque et options de montage vérifiés avant toute modification (section 12, UC-A3) |

**Commandes réellement utilisées** : `ansible --version`, `ansible-inventory --graph`, `ansible linux -m ping`, `ansible windows -m win_ping`, `ansible-playbook playbooks/<nom>.yml [--diff]`, lancées deux fois de suite.

**Contrôles ajoutés le 20/10 (PR #2 et #4, Jolan Allen)** : `windows_adds`, `windows_base` et `ops01_monitoring` commencent par un `assert` (`pre_tasks`) qui vérifie la présence de leur variable du vault avant toute modification ; `scripts/verif-idempotence.sh playbooks/<nom>.yml` (depuis `ansible/`) enchaîne deux exécutions et renvoie 0 si le 2ᵉ passage est à `changed=0`, 1 s'il reste des changements, 2 si une exécution échoue.

### Tests et preuves

| Vérification | Attendu | Résultat observé | Preuve |
| --- | --- | --- | --- |
| Inventaire Ansible | Hôtes Linux et Windows décrits | 3 hôtes dans 3 groupes | [P-30](docs/preuves/P-30-ansible-inventaire-connexions.txt) |
| Connexions | Linux SSH et Windows transport validés | `ping: pong` (linux01, ops01) et `win_ping: pong` (win-dc01) | [P-30](docs/preuves/P-30-ansible-inventaire-connexions.txt) |
| Playbook Linux | Exécution sans erreur bloquante | ok=22 changed=10 failed=0 | [P-31](docs/preuves/P-31-playbook-linux-1er-passage.txt) |
| Playbook Windows | Exécution sans erreur bloquante | ok=21 changed=12 failed=0 | [P-33](docs/preuves/P-33-playbook-windows-1er-passage.txt) |
| Script d'idempotence (PR #4) | Détecte un 2ᵉ passage avec changements ou en échec | `windows_base`, `linux_base`, `ops01_monitoring` : IDEMPOTENT (code 0) ; playbook de test non idempotent → code 1 ; playbook en échec → code 2 | [P-61](docs/preuves/P-61-validation-pr-idempotence-playbooks.txt), [P-62](docs/preuves/P-62-validation-pr-tests-negatifs.txt), [P-56](docs/preuves/P-56-grafana-dashboard-v2-deploiement-idempotence.txt) |
| Contrôle du vault (PR #2) | Arrêt avant toute modification si la variable du vault manque | Inventaire sans `group_vars` : arrêt sur l'assert, aucune tâche exécutée ; mot de passe du vault invalide : Ansible s'arrête avant le play (`ERROR! Invalid vault password`) | [P-62](docs/preuves/P-62-validation-pr-tests-negatifs.txt) |
| Second passage | État stable / changements expliqués | **Linux changed=0**, **Windows changed=0** | [P-32](docs/preuves/P-32-playbook-linux-2e-passage-idempotence.txt), [P-34](docs/preuves/P-34-playbook-windows-2e-passage-idempotence.txt) |

**Changements du 1er passage Linux expliqués** : paquets absents (node_exporter, ufw, acl, htop), description du compte chloe différente de la saisie manuelle, page et vhost remplacés par les templates, ligne fstab réécrite au format Ansible, 4 règles UFW nouvelles, rechargement nginx (handler). **Windows** : partage, ACL, DNS et exporter n'existaient pas ; OU, groupes et comptes déjà créés en phase B → `ok` sans changement.

### Difficultés / décision / retour arrière

| Problème | Cause | Correction | Résultat |
| --- | --- | --- | --- |
| windows_exporter 0.31.9 disponible | Version publiée 9 jours plus tôt | Choix de **0.31.8** (stable depuis 3 mois) | Version figée, surchargeable par variable d'environnement |
| L'option MSI `ADDLOCAL=FirewallException` ouvre 9182 à tout le monde | Comportement de l'installeur | Option retirée, règle dédiée limitée à OPS01 | Port 9182 exposé à OPS01 seulement |
| PTR du DC absent (vu en phase A) | Zone inverse créée après la promotion | 1ʳᵉ correction : PTR du DC ajouté à la liste gérée par le playbook (changed=1 puis 0) | [P-35](docs/preuves/P-35-playbook-windows-correction-ptr-dc.txt) |
| Playbook de nouveau `changed=1` plus tard, sur ce même PTR | **Cause confirmée** : le DC enregistre lui-même son PTR par mise à jour dynamique (TTL 20 min, horodaté) ; le playbook le réécrivait en statique (TTL 1 h) → chacun écrasait l'autre à tour de rôle | Le playbook ne gère plus le PTR du DC : il ne déclenche `Register-DnsClient` que si le PTR manque. Seuls les hôtes Linux (qui ne s'enregistrent pas) restent gérés en statique | `changed=0` sur 2 passages, y compris juste après un réenregistrement forcé du DC ([P-36b](docs/preuves/P-36b-ptr-dc-apres-reenregistrement-dynamique.txt), [P-37](docs/preuves/P-37-playbook-windows-ptr-dc-stable.txt)) |
| Test négatif du vault (20/10) : `windows_adds.yml` exécuté réellement au lieu d'échouer (`changed=1`) | `--vault-password-file` en ligne de commande s'**ajoute** au `vault_password_file` d'`ansible.cfg` au lieu de le remplacer : le vault a été déchiffré | Impact vérifié (seule la tâche DNS du DC rejouée, valeur inchangée, résolution OK) ; test refait avec `ANSIBLE_VAULT_PASSWORD_FILE`, qui remplace la configuration, et en `--check` ; défaut d'idempotence révélé et corrigé (phase B, PR #6) | [P-62](docs/preuves/P-62-validation-pr-tests-negatifs.txt) |
| Message de l'assert du vault (PR #2) : il annonce un vault « non déchiffré » | Dans ce cas Ansible s'arrête lui-même avant la première tâche ; l'assert protège du cas où le fichier vault est absent de l'inventaire | Remarque de relecture : préciser le message ; comportement sûr dans les deux cas | [P-62](docs/preuves/P-62-validation-pr-tests-negatifs.txt) |
| 1ʳᵉ exécution du workflow GitHub Actions en échec | Dashboard Grafana pas encore écrit, une ligne > 160 caractères, 7 remarques `ansible-lint` (chemins relatifs, noms de tâches) | Dashboard créé, playbooks corrigés, mêmes outils installés localement (ansible-core 2.16 + collections aux versions d'OPS01) pour valider avant de pousser | yamllint, syntax-check et ansible-lint (profil `production`) OK en local ; playbooks rejoués : `changed=0` |

Retour arrière disponible : snapshot `s03_avant_ansible` (WIN-DC01 et LINUX01).

---

## 7. Phase E — Maintenance et mises à jour

> [!abstract] Objectif
> Formaliser et tester une maintenance sûre et traçable sur les deux OS.

**Responsable :** MIR Mahan / Jolan Allen · **Dates :** 19/10/2026 · **Statut :** Fait

### Travaux réalisés / checklist

- [x] Écrire une procédure de maintenance standard (`docs/procedure-maintenance.md`).
- [x] Automatiser les mises à jour Linux (`linux_maintenance.yml` + `unattended-upgrades` quotidien).
- [x] Documenter et tester les mises à jour Windows (`windows_maintenance.yml` : recherche, installation, redémarrage, post-contrôles).
- [x] Vérifier l'espace disque et l'état des services (pré- et post-contrôles automatiques).
- [x] Documenter les précautions avant redémarrage et changement majeur.
- [x] Conserver une trace des exécutions et résultats (`ansible.log` + un rapport par serveur).

### Procédure et configuration

La procédure complète est dans **`docs/procedure-maintenance.md`** (fenêtre, ordre LINUX01 → OPS01 → WIN-DC01 en dernier, précautions, retour arrière). Elle est outillée par deux playbooks qui **refusent de continuer** si un pré-contrôle échoue :

| Étape | Linux (`linux_maintenance.yml`, un serveur à la fois) | Windows (`windows_maintenance.yml`) |
| --- | --- | --- |
| 0. Retour arrière | Snapshot Proxmox `s04_avant_maintenance_e` (LINUX01, OPS01) | Snapshot `s04_avant_maj_windows` (WIN-DC01) |
| 1. Pré-contrôles | Chaque système de fichiers < 85 % ; services attendus actifs (`ssh`, `nginx`, exporters, `prometheus`, `grafana-server`) | Volumes fixes < 85 % ; services NTDS, DNS, Netlogon, kdc, windows_exporter démarrés ; **aucun redémarrage déjà en attente** (clés CBS / Windows Update) |
| 2. Mises à jour | `unattended-upgrades` installé et configuré (sécurité quotidienne, pas de redémarrage auto) ; `apt upgrade` (jamais de suppression) ; `autoremove` | Recherche Windows Update (sécurité, critiques, cumulatives, définitions) ; installation **uniquement** avec `-e maintenance_apply=true` |
| 3. Redémarrage | Seulement si `/var/run/reboot-required` existe **et** `-e allow_reboot=true` | Seulement avec `-e allow_reboot=true` (géré par `win_updates`, 30 min max) |
| 4. Post-contrôles | Services de nouveau actifs ; site web HTTP 200 (LINUX01) | Services critiques démarrés ; `Get-ADDomain` + résolution DNS ; historique Windows Update |
| 5. Trace | `~/infraready-logs/maintenance-<hôte>-<date>.txt` sur OPS01 + `ansible.log` | idem + `C:\Windows\Temp\infraready-windowsupdate.log` |

**Commandes et interfaces réellement utilisées** : `ansible-playbook playbooks/linux_maintenance.yml`, `ansible-playbook playbooks/windows_maintenance.yml [-e maintenance_apply=true -e allow_reboot=true]`, `qm snapshot`, modules `apt`, `win_updates`, `service_facts`, `win_service_info`, faits `ansible_mounts`, `Get-Volume`, `Get-Service`, `Get-ADDomain`, `Resolve-DnsName`, `unattended-upgrade --dry-run`, `systemctl list-timers`.

### Tests et preuves

| Vérification | Attendu | Résultat observé | Preuve |
| --- | --- | --- | --- |
| Mise à jour Linux | Procédure automatisée vérifiable | LINUX01 : déjà à jour (phase C) ; OPS01 : paquets mis à jour ; aucun redémarrage requis ; `unattended-upgrades` actif (minuteries `apt-daily` 23:27 et `apt-daily-upgrade` 06:39), dry-run OK | [P-40](docs/preuves/P-40-linux-maintenance-standard.txt), [P-43](docs/preuves/P-43-linux01-mises-a-jour-automatiques-unattended.txt) |
| Mise à jour Windows | Procédure exécutée et documentée | Recherche : **5 mises à jour** ; installation en 1 h 13 avec redémarrage du DC (18:04) : cumulative `KB5126646` (build 26100.33650), .NET `KB5127690`, MSRT, plateforme et signatures Defender ; la tâche échoue sur `KB5007651` (boucle Windows Update, voir Difficultés) ; après exclusion, passage complet `failed=0`, dernière signature Defender installée sans redémarrage, services/AD/DNS OK | [P-41](docs/preuves/P-41-windows-maintenance-recherche-maj.txt), [P-42](docs/preuves/P-42-windows-maintenance-installation-maj.txt), [P-42b](docs/preuves/P-42b-win-dc01-diagnostic-kb5007651-historique-wu.txt), [P-42c](docs/preuves/P-42c-windows-maintenance-installation-complete-apres-exclusion.txt) |
| Capacité disque | État relevé et interprété | LINUX01 `/` 29,1 %, `/boot` 11,4 %, `/data` 5,3 % ; OPS01 `/` 26,1 % ; WIN-DC01 `C:` 24,2 % avant (37,1 Go libres) puis **37,2 %** après la cumulative (30,7 Go libres : WinSxS + fichiers de désinstallation) → tous < 85 %, marge suffisante | [P-40b](docs/preuves/P-40b-rapports-maintenance-generes.txt), [P-42c](docs/preuves/P-42c-windows-maintenance-installation-complete-apres-exclusion.txt) |
| Calcul d'occupation simplifié (PR #1, 20/10) | Même résultat qu'avant la modification | Simulation : mêmes montages (`/`, `/data`, `/boot`), 29,2 % / 26,3 % max contre 29,1 % / 26,1 % le 19/10 ; écart avec `df` dû aux blocs réservés à root, comptés comme occupés (seuil appliqué de façon prudente) | [P-63](docs/preuves/P-63-validation-pr1-maintenance-linux-calcul-disque.txt) |
| État des services | Services critiques contrôlés | Avant et après : ssh/nginx/node_exporter (LINUX01), ssh/prometheus/grafana/node_exporter (OPS01), NTDS/DNS/Netlogon/kdc/windows_exporter (WIN-DC01) tous actifs ; site HTTP 200 | [P-40](docs/preuves/P-40-linux-maintenance-standard.txt), [P-40b](docs/preuves/P-40b-rapports-maintenance-generes.txt) |

### Difficultés / décision / retour arrière

| Problème | Cause | Correction | Résultat |
| --- | --- | --- | --- |
| 1er passage Windows : « un volume dépasse 85 % » alors que `C:` est à 24 % | Le lecteur CD vide (ISO éjectée) apparaît comme un volume `E:` de 0 octet → 100 % | Filtre sur les disques fixes de taille > 0 (`DriveType -eq 'Fixed'`) | Pré-contrôle correct ([P-41a](docs/preuves/P-41a-windows-maintenance-1er-essai-lecteur-cd.txt) → [P-41](docs/preuves/P-41-windows-maintenance-recherche-maj.txt)) |
| Ordre des phases | La maintenance d'OPS01 contrôle `prometheus` et `grafana-server` | Phase F exécutée avant la maintenance d'OPS01 | Pré-contrôles cohérents |
| Installation Windows : `failed=1` après 1 h 13 alors que 5 mises à jour sont installées et que le DC a redémarré | `KB5007651` (plateforme Windows Security) est marquée « Installation Successful » trois fois de suite (17:47, 18:06, 18:07) mais toujours re-proposée par Windows Update ; `win_updates` détecte la boucle et arrête la tâche, donc les post-contrôles n'ont pas tourné | Diagnostic avec `QueryHistory`, le journal Système (`WindowsUpdateClient`) et `Get-MpComputerStatus` (plateforme bien en 4.18.26090.9) ; ajout de `reject_list: [KB5007651]` dans le playbook, à suivre manuellement | Passage complet `failed=0`, post-contrôles OK ([P-42](docs/preuves/P-42-windows-maintenance-installation-maj.txt) → [P-42b](docs/preuves/P-42b-win-dc01-diagnostic-kb5007651-historique-wu.txt) → [P-42c](docs/preuves/P-42c-windows-maintenance-installation-complete-apres-exclusion.txt)) |
| Rapport Windows : l'historique Windows Update est écrit sur une seule ligne avec des `\n` littéraux | `join('\n')` dans un gabarit Jinja ne produit pas de retour à la ligne | Boucle `{% for %}` dans le gabarit du rapport | Rapport lisible au passage suivant |

Retour arrière disponible : snapshots `s04_avant_maintenance_e` (LINUX01, OPS01) et `s04_avant_maj_windows` (WIN-DC01).

---

## 8. Phase F — Supervision Prometheus et Grafana

> [!abstract] Objectif
> Collecter et visualiser les métriques réelles des serveurs et présenter une alerte.

**Responsable :** MIR Mahan / Jolan Allen · **Dates :** 19/10/2026 · **Statut :** Fait

### Travaux réalisés / checklist

- [x] Installer et configurer Prometheus sur OPS01 (playbook `ops01_monitoring.yml`).
- [x] Configurer Node Exporter pour LINUX01 (installé par `linux_base.yml`, port 9100 ouvert pour OPS01).
- [x] Configurer Windows Exporter pour WIN-DC01 (0.31.8, port 9182 ouvert pour OPS01).
- [x] Vérifier les cibles et données reçues par Prometheus.
- [x] Installer/configurer Grafana avec Prometheus comme source.
- [x] Créer un dashboard avec CPU, mémoire, stockage, disponibilité.
- [x] Démontrer un seuil ou une alerte simple.
- [x] Documenter origine, ports et cheminement des métriques.

### Procédure et configuration

Tout est déployé par **`ansible/playbooks/ops01_monitoring.yml`** à partir des fichiers versionnés dans `monitoring/` (snapshot `s02_avant_monitoring` pris avant) :

| Composant | Version | Configuration | Vérification intégrée au playbook |
| --- | --- | --- | --- |
| Prometheus | 2.45.3 (paquet Ubuntu 24.04) | `/etc/prometheus/prometheus.yml` et `rules/infraready.rules.yml` copiés depuis le dépôt ; `promtool check config` **avant** tout redémarrage | `/api/v1/targets` : toutes les cibles `up` (sinon échec) |
| Grafana | 13.2.4 (dépôt officiel `apt.grafana.com`) | Source de données et dashboard **provisionnés** (`/etc/grafana/provisioning/`, JSON dans `/var/lib/grafana/dashboards/infraready/`) ; mot de passe admin dans le vault ; accès anonyme **Viewer** (lecture seule) pour l'affichage | Compte admin testé sur `/api/admin/stats` ; source `prometheus-infraready` présente |
| Pare-feu OPS01 | UFW | 22, 3000, 9090 depuis le labo uniquement, refus par défaut | — |

**Origine, ports et cheminement des métriques**

```mermaid
flowchart LR
    L1["LINUX01<br/>node_exporter :9100<br/>(UFW : OPS01 seulement)"]
    DC["WIN-DC01<br/>windows_exporter 0.31.8 :9182<br/>cpu, memory, logical_disk, os, system, net, service<br/>(pare-feu : OPS01 seulement)"]
    O1["OPS01<br/>node_exporter :9100 (local)"]
    PR["Prometheus :9090<br/>scrape toutes les 15 s<br/>jobs linux / windows / prometheus<br/>règles d'alerte"]
    GR["Grafana :3000<br/>source Prometheus (localhost:9090)<br/>dashboard « InfraReady — Serveurs »"]
    L1 -- "HTTP GET /metrics" --> PR
    DC -- "HTTP GET /metrics" --> PR
    O1 --> PR
    PR -- "PromQL" --> GR
```

Chaque cible porte un label `host` (linux01, ops01, win-dc01) et `os`, utilisés dans les requêtes et la légende du dashboard.

**Dashboard « InfraReady — Serveurs »** (`monitoring/grafana/dashboards/infraready.json`, uid `infraready-serveurs`) — 6 panneaux depuis la version 2 du 20/10 (PR #3, Jolan Allen) : disponibilité (`up`), **uptime** (`time() - node_boot_time_seconds` sous Linux, `windows_system_boot_time_timestamp` sous Windows), CPU %, mémoire %, stockage % par volume, table des alertes Prometheus actives. Variable **Hôte** (`label_values(up, host)`, multi-sélection, « Tous » par défaut) : chaque panneau est filtré par `host=~"$host"`. Requêtes Linux (`node_*`) et Windows (`windows_*`) côte à côte dans chaque panneau.

**Règles d'alerte** (`monitoring/prometheus/rules/infraready.rules.yml`, validées par `promtool` dans la CI) :

| Alerte | Condition | Durée | Sévérité |
| --- | --- | --- | --- |
| `InstanceDown` | `up == 0` (cible Linux ou Windows) | 1 min | critical |
| `ServiceWindowsCritiqueArrete` | service DNS / NTDS / Netlogon / Kdc non `running` (collecteur `service`) | 1 min | critical |
| `CpuEleve` | CPU > 80 % | 2 min | warning |
| `MemoireElevee` | mémoire > 90 % | 5 min | warning |
| `DisquePresquePlein` | volume > 85 % | 5 min | warning |
| `SiteWebIndisponible` (séance 6) | contrôle planifié du site LINUX01 en échec (`infraready_controle_succes == 0`) | 2 min | critical |
| `ControlePlanifieEnRetard` (séance 6) | dernier contrôle planifié plus vieux que 5 min, ou métrique absente | 5 min | warning |

**Démonstration d'alerte** (contrôlée et réversible, rejouée 3 fois avec le même résultat) : arrêt de `prometheus-node-exporter` sur LINUX01 → `InstanceDown[linux01]` passe en `pending` après 10 s, puis **`firing` après 60 s** (durée `for: 1m`) ; dashboard : LINUX01 « HORS LIGNE » et alerte dans la table ; redémarrage du service → alerte disparue 16 s plus tard.

**Points de contrôle réellement utilisés** : `/api/v1/targets`, `/api/v1/rules`, `/api/v1/alerts`, `/api/v1/query`, page `/classic/targets` et `/classic/alerts`, `/metrics` de chaque exporter, API Grafana (`/api/health`, `/api/admin/stats`, `/api/datasources`), `ss -tlnp`, `promtool check config`.

> [!warning] Captures à rafraîchir
> P-53 et P-55 montrent la version 1 du dashboard (5 panneaux, sans filtre Hôte). La version 2 est vérifiée par l'API dans P-56. Depuis la séance 6, le dashboard est en **version 3** (9 panneaux, unités, descriptions, données absentes distinguées de zéro), vérifiée par l'API et capturée dans P-85 (section 12, UC-03). P-53 et P-55 restent des traces de la version 1.

![[P-53-grafana-dashboard-infraready.png|700]]

![[P-55-grafana-dashboard-alerte-linux01-hors-ligne.png|700]]

### Tests et preuves

| Vérification | Attendu | Résultat observé | Preuve |
| --- | --- | --- | --- |
| Collecte Linux | Métriques de LINUX01 disponibles | Cible `192.168.50.20:9100` **up** (scrape 60 ms, 1 709 métriques) ; CPU 0,2 %, mémoire 11,3 %, `/` 29,1 %, `/data` 5,3 % | [P-51](docs/preuves/P-51-prometheus-targets.png), [P-52](docs/preuves/P-52-prometheus-cibles-metriques-regles.txt) |
| Collecte Windows | Métriques de WIN-DC01 disponibles | Cible `192.168.50.10:9182` **up** (3 263 métriques) ; CPU 1,0 %, mémoire 26,7 %, `C:` 24,2 % ; services DNS/NTDS/Netlogon/Kdc `running=1` | [P-51](docs/preuves/P-51-prometheus-targets.png), [P-52](docs/preuves/P-52-prometheus-cibles-metriques-regles.txt) |
| Source Grafana | Prometheus connecté | Source `Prometheus` → `http://localhost:9090` provisionnée ; `/api/admin/stats` : 1 dashboard, 1 source | [P-50](docs/preuves/P-50-ops01-prometheus-grafana-installation.txt) |
| Dashboard | CPU, RAM, disque et disponibilité visibles | 3 serveurs « EN LIGNE », courbes CPU/mémoire des 3 hôtes, 6 volumes, table d'alertes vide | [P-53](docs/preuves/P-53-grafana-dashboard-infraready.png) |
| Dashboard v2 (PR #3) | Filtre Hôte et Uptime opérationnels | Grafana : version 2, variable `host`, 6 panneaux ; Uptime renvoyé pour les 3 hôtes, filtre `host=~"linux01"` OK ; `ops01_monitoring.yml` IDEMPOTENT | [P-56](docs/preuves/P-56-grafana-dashboard-v2-deploiement-idempotence.txt) |
| Seuil / alerte | Démonstration vérifiable | `InstanceDown[linux01]` pending → firing à +60 s, visible dans Prometheus et Grafana, résolue 16 s après retour du service | [P-54](docs/preuves/P-54-alerte-instancedown-demonstration.txt), [P-54 png](docs/preuves/P-54-prometheus-alerte-instancedown.png), [P-55](docs/preuves/P-55-grafana-dashboard-alerte-linux01-hors-ligne.png) |
| Idempotence | Second passage stable | `ops01_monitoring.yml` : changed=0 au 2ᵉ passage | [P-50b](docs/preuves/P-50b-ops01-monitoring-2e-passage-idempotence.txt) |

### Difficultés / décision / retour arrière

| Problème | Cause | Correction | Résultat |
| --- | --- | --- | --- |
| Connexion admin Grafana refusée (401) après le 1er passage | **Cause confirmée** : le mot de passe contenait `#`, lu comme début de commentaire dans `grafana.ini` → mot de passe tronqué (test : la partie avant `#` fonctionnait) | Nouveau mot de passe sans `#`/`;`/guillemets, réinitialisation contrôlée (`grafana-cli admin reset-admin-password`, mot de passe lu sur stdin), contrôle `assert` dans le playbook, vérification sur `/api/admin/stats` (401 si faux, 403 si anonyme) | Admin OK, 2ᵉ passage changed=0 ([P-50a](docs/preuves/P-50a-ops01-grafana-1er-essai-echec-mot-de-passe-ini.txt) → [P-50](docs/preuves/P-50-ops01-prometheus-grafana-installation.txt)) |
| Après modification du fichier et redémarrage, même la valeur tronquée ne fonctionnait plus | **Hypothèse non confirmée** : Grafana 13 réapplique `admin_password` au démarrage ; non vérifiée pour ne pas multiplier les essais | Réinitialisation explicite (ci-dessus) | Mot de passe maîtrisé |
| `/targets` et `/alerts` renvoient 404 | Le paquet Ubuntu de Prometheus 2.45 est construit sans la nouvelle interface React | Utilisation de l'interface classique `/classic/targets`, `/classic/alerts` (l'API est identique) | Captures P-51, P-54 |
| Séries sans label `host` (`job="node"`) dans la fenêtre d'1 h du dashboard | Prometheus a démarré une première fois avec la configuration Debian par défaut avant la copie de la nôtre | Aucune action : séries périmées, hors fenêtre après 1 h ; captures faites sur 10 min | Dashboard propre (P-53) |
| Pics de CPU LINUX01 à 80 % pendant la démonstration | Artefact de `rate()` sur les trous de données (exporter arrêté), pas de charge réelle (`uptime` : charge < 0,4) | Expliqué ; disparaît avec les données | Non bloquant |
| Captures Grafana parfois vides avec Chrome headless | Deux lancements consécutifs partageaient le même profil (verrou) | Profil temporaire unique par capture | Captures fiables |

Retour arrière disponible : snapshot `s02_avant_monitoring` (OPS01).

> [!note] Séance 6
> La vérification des cibles de `ops01_monitoring.yml` pouvait réussir sans aucune cible juste après un redémarrage de Prometheus. Elle attend désormais le premier scrape (P-81a → P-81b). Le playbook désactive aussi `openipmi` (P-80b). Détails en section 12.

---

## 9. Phase G — GitHub et intégration continue

> [!abstract] Objectif
> Versionner les livrables et valider le dépôt automatiquement via GitHub Actions.

**Responsable :** MIR Mahan / Jolan Allen · **Dates :** 19/10/2026 · **Statut :** Fait (pipeline vert) — il manque les commits des autres membres

### Travaux réalisés / checklist

- [x] Créer un dépôt GitHub adapté à l'équipe : `jolanallen/InfraReady`, créé par le chef de projet.
- [x] Organiser playbooks, scripts, variables, monitoring et docs (voir arborescence en annexe).
- [ ] Utiliser des commits descriptifs de tous les membres.
- [x] Créer `.github/workflows/validation.yml`.
- [x] Déclencher des validations à chaque push ou pull request (`on: push, pull_request, workflow_dispatch`).
- [x] Inclure des contrôles pertinents : fichiers attendus, `yamllint`, `ansible-playbook --syntax-check`, `ansible-lint`, `promtool check config`, JSON du dashboard, **gitleaks** sur tout l'historique, vault obligatoirement chiffré.
- [x] Fournir une preuve d'exécution réussie du workflow (P-60).
- [x] Contrôler l'absence de secrets en clair (recherche des vrais mots de passe dans le dépôt avant chaque commit, `.gitignore`, vault chiffré).

### Procédure et configuration

- **Dépôt** : https://github.com/jolanallen/InfraReady — branche `main`.
- **Migration** : le travail a commencé le 19/10/2026 sur un dépôt de travail privé ; l'historique complet a été migré le 20/10/2026 vers le dépôt de l'équipe, où le workflow a été rejoué (P-60). Le 1er run en échec date du dépôt de travail (P-60a).
- **Jobs** : `fichiers`, `yaml-ansible`, `monitoring`, `secrets` (voir `.github/workflows/validation.yml`).

- **Validation locale avant push** : les mêmes outils que la CI (ansible-core 2.16, ansible-lint 24, yamllint, collections aux versions d'OPS01) sont installés sur le poste pour corriger avant de pousser.
- **Run réussi** : https://github.com/jolanallen/InfraReady/actions/runs/39401095014 (4 jobs `success`).

### Tests et preuves

| Vérification | Attendu | Résultat observé | Preuve |
| --- | --- | --- | --- |
| Dépôt et arborescence | Fichiers attendus présents | Voir arborescence (annexe) ; job `Arborescence attendue` : success | [Lien](https://github.com/jolanallen/InfraReady), [P-60](docs/preuves/P-60-github-actions-pipeline-vert.txt) |
| Contributions | Contributions de l'équipe traçables | MIR Mahan (`Nothypaa`) : commits directs jusqu'au 20/10 ; Jolan Allen (`jolan`) : PR #1 à #5 du 20/10, CI verte sur chaque branche et après fusion ; depuis, toute modification passe par une PR (règles de `CLAUDE.md`) ; Kenzi Bendjelloul : **à compléter** | [P-60](docs/preuves/P-60-github-actions-pipeline-vert.txt) |
| Workflow automatique | Push / PR déclenche la validation | Chaque `push` sur `main` a lancé un run (événement `push`) | [P-60](docs/preuves/P-60-github-actions-pipeline-vert.txt) |
| Pipeline vert | Exécution terminée avec succès | Run 39401095014 sur `jolanallen/InfraReady` : `Arborescence attendue`, `YAML + Ansible`, `Prometheus + Grafana`, `Aucun secret en clair` → success | [P-60](docs/preuves/P-60-github-actions-pipeline-vert.txt) |

### Difficultés / décision / retour arrière

| Problème | Cause | Correction | Résultat |
| --- | --- | --- | --- |
| `git push` refusé : « refusing to allow an OAuth App to create or update workflow … without `workflow` scope » | Le jeton GitHub CLI n'a pas le droit `workflow`, obligatoire pour modifier `.github/workflows/` | `gh auth refresh -h github.com -s workflow` | Push accepté, 6 commits publiés |
| 1er run en échec (3 jobs sur 4) | Dashboard Grafana absent, ligne > 160 caractères, 7 remarques `ansible-lint` | Dashboard écrit, playbooks corrigés et rejoués (`changed=0`), validation locale avant push | 2ᵉ run vert ([P-60a](docs/preuves/P-60a-github-actions-depot-de-travail-initial.txt)), puis vert sur le dépôt de l'équipe ([P-60](docs/preuves/P-60-github-actions-pipeline-vert.txt)) |

---

## 10. Phase H — Diagnostic d'incident

> [!abstract] Objectif
> Reproduire un incident simple, contrôlé, réversible et justifier le retour à la normale.

**Responsable :** MIR Mahan / Jolan Allen · **Dates :** 19/10/2026 · **Statut :** Fait

### Travaux réalisés / checklist

- [x] Choisir un incident du labo : **site web LINUX01 en 404 après un changement de configuration nginx** (`root` vers un répertoire inexistant).
- [x] Décrire le symptôme initial et l'heure du constat (19:27, depuis OPS01, par IP et par nom DNS).
- [x] Consigner les tests effectués et les journaux consultés (service, port/pare-feu, contenu, `nginx -T`, journaux nginx/systemd/sudo).
- [x] Identifier une cause confirmée (directive `root` vers `/var/www/infraready-v2`, inexistant).
- [x] Appliquer et documenter une correction ciblée (rejeu de la configuration de référence avec Ansible).
- [x] Rejouer les tests pour confirmer le retour à la normale (HTTP 200, 2ᵉ passage `changed=0`).
- [x] Joindre les preuves et préparer un rapport d'incident distinct (**`docs/rapport-incident.md`**, réf. INC-2026-10-19-01).

### Procédure et configuration

> [!info] Incident INC-2026-10-19-01 — 19/10/2026 19:27 CEST
> **Système :** LINUX01, service nginx. **Impact :** site indisponible (404), aucun autre service touché. **Type :** erreur de configuration lors d'une « mise en production » simulée. **Contrôlé et réversible :** sauvegarde `/root/infraready.nginx.bak-incident-h` + configuration de référence dans le dépôt.

```mermaid
flowchart LR
    A["19:27:22<br/>root → /var/www/infraready-v2<br/>nginx -t OK, reload"] --> B["19:27:27<br/>Constat depuis OPS01<br/>HTTP 404 (IP et DNS)"]
    B --> C["19:27:51<br/>Diagnostic<br/>service ? port ? contenu ? config !"]
    C --> D["19:28:20<br/>1er essai : playbook<br/>fichier OK mais 404<br/>(handler non exécuté)"]
    D --> E["Correction du playbook<br/>meta: flush_handlers"]
    E --> F["19:30:34 → 19:30:51<br/>Incident reproduit, playbook corrigé<br/>HTTP 200 en 1 passage"]
    F --> G["19:31<br/>2e passage changed=0<br/>retour à la normale"]
```

**Chronologie et cause :** la directive `root` du virtual host a été modifiée vers un répertoire jamais créé ; `nginx -t` ne vérifie pas l'existence du répertoire, le rechargement réussit et le site renvoie 404 pour tout. Diagnostic par élimination sur LINUX01 (P-71) : nginx `active`, en écoute sur `0.0.0.0:80`, règle UFW présente, contenu intact dans `/var/www/infraready` ; `nginx -T` montre le mauvais `root`, `ls` confirme l'absence du répertoire, `stat` et `diff` datent et isolent le changement, le journal `sudo` identifie la session. Le journal d'erreur nginx est resté vide (`try_files … =404` ne journalise pas) : la configuration réellement chargée est la bonne source.

**Commandes et journaux utilisés :** `curl -s -o /dev/null -w '%{http_code}'`, `ping`, `systemctl is-active/status nginx`, `ss -ltnp`, `ufw status`, `tail /var/log/nginx/infraready_error.log`, `journalctl -u nginx`, `journalctl _COMM=sudo`, `nginx -T`, `ls`, `stat`, `diff`, `ansible-playbook playbooks/linux_base.yml --limit linux01`.

**Changement réalisé :** rejeu de la configuration de référence (`linux_base.yml`, limité à LINUX01) plutôt qu'une correction manuelle ; le 1ᵉʳ essai a révélé un défaut du playbook (voir Difficultés), corrigé par un `meta: flush_handlers` avant les vérifications ; l'incident a été reproduit une 2ᵉ fois pour prouver que le playbook corrigé le résout en un seul passage.

### Tests et preuves

| Vérification | Attendu | Résultat observé | Preuve |
| --- | --- | --- | --- |
| Reproduction | Symptôme observé et documenté | 404 par IP et par nom depuis OPS01 à 19:27:27, VM joignable, port 80 ouvert ; reproduit à l'identique à 19:30:34 | [P-70](docs/preuves/P-70-incident-nginx-reproduction-et-symptome.txt), [P-72](docs/preuves/P-72-incident-nginx-correction-playbook-corrige.txt) |
| Diagnostic | Hypothèse vérifiée / cause expliquée | 3 hypothèses écartées (service, port/pare-feu, contenu) ; cause confirmée : `root /var/www/infraready-v2` inexistant, modifié à 19:27:22 | [P-71](docs/preuves/P-71-incident-nginx-diagnostic.txt) |
| Correction | Modification clairement décrite | 1ᵉʳ essai : fichier restauré, handler non exécuté → 404 ; playbook corrigé → « Virtual host nginx : changed », « RUNNING HANDLER Recharger nginx : changed », tests HTTP OK, `failed=0` | [P-72a](docs/preuves/P-72a-incident-nginx-correction-1er-essai-handler-non-execute.txt), [P-72](docs/preuves/P-72-incident-nginx-correction-playbook-corrige.txt) |
| Retour à la normale | Test identique à nouveau réussi | nginx actif, `root /var/www/infraready`, configuration identique à la sauvegarde, 200 par IP et par nom, 2ᵉ passage `changed=0 failed=0` | [P-73](docs/preuves/P-73-incident-nginx-retour-normale-et-second-passage.txt) |

### Difficultés / décision / retour arrière

| Problème | Cause | Correction | Résultat |
| --- | --- | --- | --- |
| 1ᵉʳ essai de correction : le playbook restaure le fichier (`changed=1`) mais le site reste en 404, et le 2ᵉ passage (`changed=0`) ne change rien | La vérification « HTTP 200 » échoue avant la fin du play ; Ansible n'exécute les handlers qu'en fin de play, donc le rechargement nginx notifié est perdu | `ansible.builtin.meta: flush_handlers` placé avant les vérifications dans `linux_base.yml` | Un seul passage suffit : fichier + rechargement + tests ([P-72a](docs/preuves/P-72a-incident-nginx-correction-1er-essai-handler-non-execute.txt) → [P-72](docs/preuves/P-72-incident-nginx-correction-playbook-corrige.txt)) |
| Journal d'erreur nginx vide malgré l'incident | `try_files … =404` renvoie 404 sans écrire dans `error.log` | Lire la configuration chargée (`nginx -T`) et le journal systemd | Cause trouvée en moins d'une minute |
| Le site n'est pas supervisé en HTTP (seul `up` du node_exporter l'est) : l'incident n'a déclenché aucune alerte | Pas de sonde HTTP dans Prometheus | Contrôle planifié du site (timer systemd) + alerte `SiteWebIndisponible` | **Réalisé en séance 6** (section 12, P-83, P-84) |

Retour arrière disponible : `/root/infraready.nginx.bak-incident-h` sur LINUX01, et la configuration de référence du dépôt (`templates/nginx-infraready.conf.j2`).

---

## 11. Séance 4 — Stockage, processus, scripts et scénarios de panne

> [!abstract] Objectif
> Appliquer au laboratoire le TP guidé de la séance 4 (support pédagogique n° 4 « Stockage et processus ») : disque de test identifié et monté de façon persistante, processus et services observés sans perturbation, scripts de vérification à codes de sortie, playbook commenté rejoué deux fois, puis les six scénarios de panne contrôlée (7.4) avec la procédure commune de diagnostic (7.5).

**Responsable :** MIR Mahan / Jolan Allen / Kenzi Bendjelloul · **Dates :** 19–20/10/2026 · **Statut :** Fait — bilans individuels et revue croisée à compléter par chaque membre

### Travaux réalisés / checklist

- [x] Identifier un disque virtuel dédié avant de le modifier (numéro de série, comparaison hyperviseur / `lsblk`) — réalisé en phase C.
- [x] Créer, monter par UUID et vérifier un espace de données de test, droits compris — réalisé en phase C.
- [x] Examiner processus, services et journaux sur Linux et Windows, sans arrêter de service critique.
- [x] Écrire deux scripts de vérification en lecture seule (Bash, PowerShell) et les tester dans trois situations.
- [x] Rejouer le playbook commenté deux fois, contrôler syntaxe, cible et simulation `--check --diff`.
- [x] Dérouler les six scénarios de panne contrôlée, un seul actif à la fois, avec retour à l'état initial vérifié.
- [x] Consigner les erreurs, les décisions et les mesures de retour arrière.
- [ ] Bilan individuel (section 7 et fiche 10.5 du support) — un par membre.
- [ ] Revue croisée (fiche 10.4, annexe C) : un membre suit la procédure depuis ce dossier sans explication orale.

### Correspondance avec le support

| Étape / livrable du support | Réalisation dans InfraReady | Preuve |
| --- | --- | --- |
| Étapes 1 à 4, exercices A et B : disque identifié, formaté, monté de façon persistante, droits | Disque de 10 Go ajouté à LINUX01, identifié par son numéro de série `INFRA-DATA01` (et non par `/dev/sdb`), ext4 `DATA`, monté sur `/data` par UUID (`nofail`), démontage/remontage via `fstab`, droits par groupe | [P-22](docs/preuves/P-22-linux01-disque-test-montage.txt) |
| Étapes 2 et 5 (Linux) : état initial, processus, mémoire, disque, services, journaux | `hostnamectl`, `ip -br address`, `ps aux --sort=-%cpu`, `free -h`, `df -hT`, `systemctl --state=running`, `journalctl -u nginx` | [P-21](docs/preuves/P-21-linux01-service-nginx-processus.txt), [P-24](docs/preuves/P-24-linux01-analyse-journaux.txt), [P-26](docs/preuves/P-26-linux01-processus-services-journaux.txt) |
| Étapes 2 et 5 (Windows) | `Get-NetIPConfiguration`, `Get-Service`, `Get-Process` trié par CPU, `Get-WinEvent -LogName System` ; aucun service arrêté | [P-14](docs/preuves/P-14-win-dc01-processus-services-script-dnsclient.txt) |
| Étape 6 : scripts de vérification, trois situations | `scripts/check-nginx.sh`, `scripts/Check-DnsClient.ps1` | [P-25](docs/preuves/P-25-script-check-nginx-trois-situations.txt), [P-14](docs/preuves/P-14-win-dc01-processus-services-script-dnsclient.txt) |
| Étape 7, exercice C : playbook commenté, syntaxe, cible, deux exécutions | `linux_base.yml` complété (variable `site_message`, contrôle HTTP + contenu) : 1ᵉʳ passage `changed=1`, 2ᵉ `changed=0` ; simulation corrigée | [P-38](docs/preuves/P-38-playbook-linux-site-message-1er-passage.txt), [P-38b](docs/preuves/P-38b-playbook-linux-site-message-2e-passage.txt), [P-39a](docs/preuves/P-39a-playbook-linux-mode-check-echec.txt), [P-39](docs/preuves/P-39-playbook-linux-mode-check-corrige.txt) |
| 7.4 : six scénarios de panne contrôlée | Voir tableau des scénarios | P-74 à P-79 |
| 7.5 et étape 8 : procédure commune, compte rendu, retour arrière | Appliquée à chaque scénario (délimiter, collecter, corriger un seul élément, `--check --diff`, vérifier, restaurer) | P-74 à P-79, [P-05](docs/preuves/P-05-proxmox-snapshots-arbre-complet.txt) |

> [!note] Adaptations au projet (le support demande d'adapter les noms existants)
> `/data` au lieu de `/srv/infraready` (disque réalisé en phase C) ; site servi depuis `/var/www/infraready` (variable `web_root`) et non `/var/www/html` ; playbook `playbooks/linux_base.yml` et inventaire `inventory/hosts.yml` au lieu de `nginx.yml` / `inventory.ini` ; disque ajouté dans Proxmox et non VMware. Le groupe `linux` contient LINUX01 **et** OPS01 : le play cible explicitement `linux01`, vérifié par `--list-hosts` avant chaque scénario.

### Processus et services observés

| Machine | Élément | État observé | Interprétation | Preuve |
| --- | --- | --- | --- | --- |
| LINUX01 | `nginx` (maître root, workers www-data) | `active`, `enabled`, écoute `0.0.0.0:80` | Service de test autorisé pour les scénarios | P-21, P-26 |
| LINUX01 | `prometheus-node-exporter`, `ssh` | `active` | Supervision et administration depuis OPS01 | P-26 |
| LINUX01 | Processus en tête du tri CPU | `systemd-hostnamed` à 50 % | Démarré par notre propre `hostnamectl` quelques instants avant : un pic de CPU ne prouve pas un défaut | P-26 |
| WIN-DC01 | `NTDS`, `DNS`, `Netlogon`, `W32Time` | `Running`, `Automatic` | Services critiques du domaine : exclus de toute panne volontaire | P-14 |
| WIN-DC01 | `Dnscache` (client DNS), `WinRM` | `Running`, `Automatic` | `Dnscache` contrôlé par `Check-DnsClient.ps1` ; son état ne prouve pas qu'un nom se résout | P-14 |
| WIN-DC01 | Processus en tête du tri CPU | `MsMpEng` (Defender, 109 s), `System`, `windows_exporter` | Temps CPU cumulé depuis le démarrage : normal | P-14 |
| WIN-DC01 | Journal System (20 derniers événements) | 7036 (Service Control Manager), 6038 (LsaSrv, avertissement) | 6038 : NTLM utilisé par un client, ici les connexions WinRM d'Ansible ; aucun événement d'erreur | P-14 |

### Scripts de vérification

| Script | Contrôle | Code 0 | Code 1 | Code 2 | Situations testées |
| --- | --- | --- | --- | --- | --- |
| `scripts/check-nginx.sh [service] [url] [texte]` | Service actif, HTTP 200, texte attendu dans la page | Contrôle positif | Service inactif, site injoignable, HTTP ≠ 200 ou texte absent | Commande absente, service inconnu de l'hôte | Normal → 0 ; texte absent → 1 ; port sans service → 1 ; nginx arrêté → 1 (P-78) ; OPS01 sans nginx → 2 |
| `scripts/Check-DnsClient.ps1 [-Name <service>]` | État local d'un service Windows (défaut `Dnscache`) | Service démarré | Présent mais arrêté | Introuvable | `Dnscache` → 0 ; `AxInstSV` (manuel, déjà arrêté) → 1 ; `ServiceInexistant` → 2 |

Les deux scripts sont en lecture seule et ne corrigent rien (diagnostic et correction séparés). `check-nginx.sh` s'exécute sur l'hôte contrôlé sans `sudo` ; `Check-DnsClient.ps1` s'appelle avec `powershell -NoProfile -File Check-DnsClient.ps1 -Name Dnscache` puis `$LASTEXITCODE`.

### Scénarios de panne contrôlée (7.4)

| # | Défaut introduit (une seule modification) | Symptôme observé | Cause confirmée | Correction et contrôle | Preuve |
| --- | --- | --- | --- | --- | --- |
| 1 | `site_message: "MESSAGE-INCORRECT-SCENARIO-1"` | nginx actif, HTTP 200, playbook `failed=0` ; page servie = fichier déployé = message incorrect | Valeur de variable | Valeur restaurée ; `--syntax-check`, `--list-hosts`, `--check --diff`, exécution ; marqueur absent, message attendu présent | [P-74](docs/preuves/P-74-scenario1-variable-incorrecte.txt) |
| 2 | `{{ site_messsage }}` dans `index.html.j2` | Tâche template en échec : `'site_messsage' is undefined` ; site toujours en 200 avec l'ancienne page (date inchangée) | Nom de variable du modèle | Modèle restauré, exécution réussie, message attendu présent | [P-75](docs/preuves/P-75-scenario2-variable-jinja2-inexistante.txt) |
| 3 | `dest: /tmp/ir-index.html` | Tâche `changed`, fichier créé dans `/tmp` à 13:01 ; fichier servi inchangé (12:59) ; `nginx -T` : `root /var/www/infraready` | Destination ≠ racine du serveur virtuel | Destination restaurée, fichier de test supprimé, playbook `changed=0` | [P-76](docs/preuves/P-76-scenario3-mauvais-chemin-de-destination.txt) |
| 4 | `notify` retiré de « Virtual host nginx » + en-tête `X-InfraReady-Scenario` ajouté au modèle | Tâche `changed`, aucun `RUNNING HANDLER`, aucun rechargement au journal ; en-tête présent sur disque mais absent des réponses HTTP | Notification absente | `notify` rétabli → tâche `ok`, handler non déclenché ; nouvelle modification → handler exécuté, en-tête servi, `Reloaded nginx` au journal ; modèle restauré | [P-77](docs/preuves/P-77-scenario4-handler-non-notifie.txt) |
| 5 | `systemctl stop nginx` | `inactive`, curl `000` (code 7), `check-nginx.sh` → 1 ; ping Ansible et syntaxe OK | Service arrêté, configuration intacte | `nginx -t`, `systemctl start nginx` ; script → 0 ; playbook `changed=0` | [P-78](docs/preuves/P-78-scenario5-nginx-arrete.txt) |
| 6 | B1 : `site_message` changé (l'assertion réussit) ; B2 : ligne `{{ site_message }}` retirée du modèle | HTTP 200 mais tâche « Le message attendu est publié » en échec : « Le message attendu est absent de la page. » | Contenu publié incomplet | Modèle restauré ; `uri` + `assert` réussis | [P-79](docs/preuves/P-79-scenario6-controle-fonctionnel-contenu.txt) |

**Clôture (7.5, phase 6) :** fichiers du projet comparés aux sauvegardes `.etat-initial` (identiques), sauvegardes retirées, dernier passage `changed=0` ; copie du projet sur OPS01 identique au dépôt (sommes SHA-256).

### Plan de test (annexe A du support)

| ID | Test | Résultat attendu | Résultat observé | Statut |
| --- | --- | --- | --- | --- |
| T01 | Identification du disque | Disque de données identifié sans ambiguïté | `sdb` 10 Go, série `INFRA-DATA01`, distinct de `sda` qui porte `/` | ✅ P-22 |
| T02 | Montage du volume | Point de montage et système de fichiers attendus | `/data` ext4 monté par UUID, persistant après démontage/remontage | ✅ P-22 |
| T03 | État du service | nginx actif, site en 200 avec le message attendu | `check-nginx.sh` → 0 ; panne détectée → 1 | ✅ P-25, P-78 |
| T04 | Playbook Ansible | Tâches réussies sur la cible prévue uniquement | `--list-hosts` : `linux01` ; `failed=0` | ✅ P-38 |
| T05 | Idempotence | Aucun changement inattendu à la seconde exécution | `changed=0` ; simulation `changed=0` après correction | ✅ P-38b, P-39 |

### Difficultés / décision / retour arrière

| Problème | Cause | Correction | Résultat |
| --- | --- | --- | --- |
| `--check --diff` en échec et faux changement annoncé sur `/data` | `blkid` et `uri` ne s'exécutent pas en mode check : UUID vide → montage « `UUID=` » annoncé, `page_check` sans contenu | `check_mode: false` sur les 4 tâches en lecture seule (2 `blkid`, 2 `uri`) | Simulation `changed=0 failed=0` ([P-39a](docs/preuves/P-39a-playbook-linux-mode-check-echec.txt) → [P-39](docs/preuves/P-39-playbook-linux-mode-check-corrige.txt)) |
| Simulation de la correction du scénario 1 en échec (`failed=1`) | En mode check la page n'est pas déployée : l'assertion compare la nouvelle valeur à l'ancienne page | Limite assumée du mode `--check` ; exécution réelle ensuite | `failed=0` (P-74) |
| `Check-DnsClient.ps1` renvoie `rc: 1` au lieu de 2 via Ansible | Le module `ansible.builtin.script` ramène tout code non nul à 1 | Test discriminant : exécution directe et lecture de `$LASTEXITCODE` | 0 / 1 / 2 confirmés (P-14) |
| Message « injoignable (000) » ambigu | Le script affichait le code HTTP 000 au lieu de l'erreur | Afficher la première ligne de sortie de curl | Message explicite (P-25) |
| Scénario 6 tel que décrit ne déclenche pas l'assertion | L'assertion compare la page à la variable qui vient de la générer | Défaut porté sur le contenu publié (modèle) | Assertion en échec puis réussie (P-79) |
| Scénario 4 : rétablir `notify` ne suffit pas | Tâche `ok` → aucune notification ; ancienne configuration toujours chargée | Nouvelle modification pour déclencher le handler | Handler exécuté (P-77) |

Retour arrière : snapshot Proxmox `s07_avant_seance4` des 3 VM pris avant la séance ; sauvegardes `.etat-initial` des fichiers du projet sur OPS01 pendant les scénarios ; configuration de référence dans le dépôt.

---

## 12. Séance 6 — Maintenance opérationnelle et supervision

> [!abstract] Objectif
> Appliquer au laboratoire le TP de la séance 6 (support pédagogique n° 6 « Maintenance opérationnelle et supervision ») : en tant que technicien d'exploitation, contrôler l'état de la plateforme, fiabiliser la maintenance, rendre les anomalies observables et conserver des preuves vérifiables. Socle obligatoire UC-01 à UC-06, compléments UC-C1 à UC-C4, un défi avancé (UC-A3).

**Responsable :** MIR Mahan / Jolan Allen / Kenzi Bendjelloul · **Dates :** 23/10/2026 · **Statut :** Fait (socle, 4 compléments, défi UC-A3). La correction de l'incident UC-05 est **préparée mais pas encore appliquée** : elle modifie le contrôleur de domaine et attend une validation explicite (voir UC-05).

Retour arrière : snapshot Proxmox `s09_avant_seance6` des 3 VM, pris le 23/10/2026 à 09:05:43, avant toute modification.

**Déroulé réel de la séance (en rouge : blocage et tests de panne contrôlés)**

```mermaid
gantt
    title Séance 6 — déroulé réel du 23/10/2026
    dateFormat HH:mm
    axisFormat %H:%M
    todayMarker off
    section Démarrage
    Hôte redémarré, VM éteintes (blocage)      :crit, b1, 08:27, 34m
    VM démarrées à la main                     :milestone, 09:01, 0m
    Snapshot s09_avant_seance6                 :milestone, 09:05, 0m
    État initial UC-01 (P-80)                  :a1, 09:06, 4m
    section Supervision
    Écart de règles corrigé UC-02 (P-81)       :a2, 09:15, 6m
    Timer + 2 alertes UC-C4 (P-83)             :a3, 09:22, 4m
    Test alerte 1 - nginx arrêté UC-04         :crit, t1, 09:26, 4m
    Contrôle de santé UC-C2 (P-82)             :a4, 09:31, 4m
    openipmi corrigé (P-80b)                   :a5, 09:35, 2m
    section Incident et maintenance
    Reproduction arrêt ACPI du DC UC-05        :crit, i1, 09:38, 2m
    Dashboard v3 UC-03 (P-85)                  :a6, 09:42, 2m
    Maintenance LINUX01 UC-C1 (P-87)           :a7, 09:45, 1m
    Quotas /data UC-A3 (P-89)                  :a8, 09:48, 5m
    Test alerte 2 - timer arrêté UC-04         :crit, t2, 09:54, 10m
```


### Démarrage — état initial commun

| Étape du support | Constat réel | Preuve |
| --- | --- | --- |
| 1. Noms, adresses, rôles | Conformes à l'inventaire : WIN-DC01 `.10` (AD DS, DNS), LINUX01 `.20` (nginx, `/data`), OPS01 `.30` (Ansible, Prometheus, Grafana) | P-80 |
| 2. Accès autorisés | SSH par clé (rebond par l'hôte) vers LINUX01 et OPS01 ; WinRM depuis OPS01 vers WIN-DC01 ; API Proxmox par jeton | P-80 |
| 3. Services attendus et tests qui les prouvent | Voir la fiche d'état initial (UC-01) : un test fonctionnel par service (DNS, HTTP + contenu, API Prometheus et Grafana, domaine AD) | P-80, P-82 |
| 4. Prometheus, Grafana, Node Exporter, Windows Exporter | Vérifiés **sur les machines** (services actifs, ports, `/metrics`), pas d'après la documentation | P-80, P-81 |
| 5. Blocages initiaux | Voir tableau suivant | P-80 |

| # | Blocage initial | Cause | Action | Statut |
| --- | --- | --- | --- | --- |
| 1 | Laboratoire injoignable (`No route to host`) | L'hôte Proxmox a été redémarré à 08:27 ; les VM n'ont pas l'option « démarrage automatique » (`onboot`) | VM démarrées à la main à 09:01 | Levé (option `onboot` non activée : à décider) |
| 2 | Jeton API Proxmox sans aucun droit (`Permission check failed (/vms/100, VM.PowerMgmt)`) | Jeton créé avec « Privilege Separation » | Séparation retirée par l'étudiant ; snapshot pris ensuite | Levé — jeton à révoquer après la remise |
| 3 | Prometheus charge **4 règles** alors que le dépôt en définit **5** (`ServiceWindowsCritiqueArrete` absente) | La copie du projet sur OPS01 n'avait pas été resynchronisée après une modification des règles | UC-02 : copie resynchronisée avec `main`, `ops01_monitoring.yml` rejoué | Corrigé (P-81a, P-81) |
| 4 | `openipmi.service` en échec à chaque démarrage (LINUX01, OPS01) | Paquet recommandé `ipmitool`, tiré par `prometheus-node-exporter` installé par nos playbooks ; aucun matériel IPMI dans une VM | Service désactivé **par Ansible** dans `linux_base.yml` et `ops01_monitoring.yml` | Corrigé (P-80b) |
| 5 | WIN-DC01 : événements 41 et 6008 « arrêt précédent inattendu » | Incident traité en UC-05 | Diagnostic et reproduction faits, correction en attente de validation | Diagnostiqué (P-86) |


> [!example] Snapshots Proxmox des 3 VM : `s09_avant_seance6` pris avant toute modification (rendu de la sortie de l'API, P-80c)
> ![[P-80c-rendu-proxmox-snapshots-s09.png|760]]

### Travaux réalisés / checklist

- [x] **UC-01** — État de santé initial daté des 3 serveurs, avant toute modification, avec un test fonctionnel par service (P-80).
- [x] **UC-02** — Cibles Linux et Windows vérifiées de bout en bout ; écart de configuration corrigé ; défaut du playbook de supervision corrigé (P-81, P-81a, P-81b).
- [x] **UC-03** — Dashboard d'exploitation v3 : unités, descriptions, données absentes distinguées de zéro, 3 nouveaux panneaux (P-85).
- [x] **UC-04** — Nouvelle alerte `SiteWebIndisponible`, testée de façon contrôlée : déclenchement puis retour à la normale (P-84).
- [ ] **UC-05** — Incident réel (arrêt brutal du DC) diagnostiqué et reproduit (P-86) ; **correction préparée, pas encore appliquée**.
- [x] **UC-06** — Fichiers versionnés, contrôles CI, README et dossier à jour, liste validé / partiel / bloqué (ci-dessous).
- [x] **UC-C1** — Maintenance de LINUX01 encadrée par un contrôle avant / après (P-87).
- [x] **UC-C2** — Playbook de contrôle de santé en lecture seule : `controle_sante.yml` (P-82, P-80b).
- [x] **UC-C3** — Observation ponctuelle comparée à l'historique Prometheus (P-88).
- [x] **UC-C4** — Tâche planifiée tracée : timer systemd `infraready-controle-site` (P-83, P-84).
- [x] **UC-A3** (défi) — Quotas utilisateurs sur le disque de test `/data` (P-89a, P-89).

### Correspondance avec le support

| Use case | Réalisation dans InfraReady | Fichiers | Preuves |
| --- | --- | --- | --- |
| UC-01 État de santé vérifiable | Fiche d'état initial datée (commandes Linux en lecture seule, PowerShell par WinRM) ; contrôles automatisés ensuite par `controle_sante.yml` | `ansible/playbooks/controle_sante.yml` | P-80, P-82 |
| UC-02 Métriques Linux et Windows | Configuration réelle, cibles attendues / observées, endpoints, métriques stockées ; correction de l'écart de règles | `monitoring/prometheus/`, `ops01_monitoring.yml` | P-81a, P-81b, P-81 |
| UC-03 Tableau de bord | Dashboard « InfraReady — Serveurs » v3 provisionné depuis le dépôt | `monitoring/grafana/dashboards/infraready.json` | P-85 |
| UC-04 Alerte exploitable | `SiteWebIndisponible` (+ `ControlePlanifieEnRetard`) | `monitoring/prometheus/rules/infraready.rules.yml` | P-84 |
| UC-05 Incident | INC-2026-10-23-01 : arrêt non propre de WIN-DC01 | `docs/rapport-incident.md` | P-86 |
| UC-06 Livrables | Dépôt, CI, README, dossier, liste des éléments validés / partiels / bloqués | `.github/workflows/validation.yml`, `README.md` | P-64 |
| UC-C1 Maintenance avant / après | `linux_maintenance.yml` sur LINUX01 entre deux `controle_sante.yml` | `docs/procedure-maintenance.md` | P-87 |
| UC-C2 Contrôle de santé Ansible | `controle_sante.yml` (Linux + Windows, lecture seule) | `ansible/playbooks/controle_sante.yml` | P-82, P-80b |
| UC-C3 Ponctuel / historique | Espace disque de `/` : mesure instantanée, historique 19→23/10, pente et projection | — | P-88 |
| UC-C4 Tâche planifiée | Timer systemd + `check-nginx.sh` + métriques textfile + journal | `scripts/controle-site-planifie.sh`, `linux_base.yml` | P-83, P-84 |
| UC-A3 Quotas | Quotas alice / bruno sur `/data` (disque de test) | `ansible/playbooks/linux_quotas.yml` | P-89a, P-89 |

### UC-01 — Fiche d'état initial (23/10/2026, 09:06)

Relevé fait **avant toute modification**, cinq minutes après le démarrage des VM. Outils : sous Linux, `hostnamectl`, `timedatectl`, `df`, `free`, `systemctl`, `journalctl -p err`, `getent`, `curl` (root via sudo, rebond SSH par l'hôte) ; sous Windows, un script PowerShell en lecture seule lancé depuis OPS01 par `ansible win-dc01 -m ansible.windows.win_shell` (`Get-CimInstance`, `w32tm /query /status`, `Get-Service`, `Get-WinEvent`, `Resolve-DnsName`, `Get-ADDomain`).

| Contrôle | WIN-DC01 | LINUX01 | OPS01 | Attendu | Écart |
| --- | --- | --- | --- | --- | --- |
| Identité | Windows Server 2025 build 26100 | Ubuntu 24.04.5, noyau 6.8.0-147 | Ubuntu 24.04.5, noyau 6.8.0-147 | Conforme à l'inventaire | — |
| Heure | Synchronisée NTP (`fr.pool.ntp.org`, strate 3) | NTP synchronisé, Europe/Paris | NTP synchronisé, Europe/Paris | Heure commune (Kerberos) | — |
| Espace disque | `C:` 37,3 % | `/` 26 %, `/data` 1 %, `/boot` 6 % | `/` 23 %, `/boot` 6 % | < 85 % | — |
| Services | NTDS, DNS, Netlogon, Kdc, W32Time, WinRM, windows_exporter : `Running` | nginx, node_exporter : actifs | prometheus, grafana-server, node_exporter : actifs | Tous actifs | — |
| Unités en échec | — | `openipmi.service` | `openipmi.service` | Aucune | **Écart n° 4** |
| Erreurs récentes | 41 (Kernel-Power) et 6008 (EventLog) à 09:01 | 1 (openipmi) | 2 (openipmi, sudo refusé à notre compte d'administration) | Aucune | **Écart n° 5** (incident UC-05) |
| Test fonctionnel | DNS local : `linux01.infraready.test` → `.20` ; domaine AD `infraready.test` ; exporter HTTP 200 | Site HTTP 200 en 0,9 ms ; `/data` monté | Site LINUX01 par le nom DNS : HTTP 200 ; Prometheus « Ready » ; Grafana `database: ok` | Service rendu, pas seulement processus présent | — |
| Supervision | — | — | 4/4 cibles `up` ; **4 règles chargées** | 5 règles (dépôt) | **Écart n° 3** |

> [!note] Un processus actif ne prouve pas un service rendu
> Écart de mesure à connaître : `df` affiche 26 % sur `/` de LINUX01, Prometheus et le contrôle de santé 29,2 %, car l'espace réservé à root est compté comme occupé (`size - avail`).
>
> Chaque service a un test fonctionnel : résolution DNS par le DC et depuis les clients Linux, page HTTP avec contrôle du contenu (par le nom DNS, depuis OPS01), API Prometheus et Grafana, requête Active Directory. Les captures et sorties ne contiennent aucun secret : le vault reste chiffré et les mots de passe ne passent que par l'entrée standard.


> [!example] WIN-DC01 : événements 41 / 6008 relevés dans l'état initial, point de départ de l'incident UC-05 (rendu de la sortie, P-80)
> ![[P-80-rendu-win-dc01-evenements-arret.png|760]]

### UC-02 — Métriques Linux et Windows collectables

**Architecture de supervision après la séance 6 (en bleu : éléments ajoutés)**

```mermaid
flowchart LR
    subgraph L1["LINUX01 — 192.168.50.20"]
        TIM["infraready-controle-site.timer<br/>chaque minute"] --> SCR["controle-site-planifie.sh"]
        SCR --> CHK["check-nginx.sh<br/>service + HTTP + contenu"]
        CHK --> NGX["nginx :80"]
        SCR -- "écriture atomique" --> PROM[("infraready_controle.prom")]
        SCR -- "sortie" --> JRN[("journal systemd")]
        APT["collecteur apt"] --> PROM2[("apt.prom")]
        NE1["node_exporter :9100<br/>+ collecteur textfile"]
        PROM --> NE1
        PROM2 --> NE1
    end
    subgraph DC["WIN-DC01 — 192.168.50.10"]
        WE["windows_exporter :9182<br/>cpu, mémoire, disques, services"]
    end
    subgraph O["OPS01 — 192.168.50.30"]
        NE2["node_exporter :9100"]
        P["Prometheus :9090<br/>scrape 15 s"]
        R{{"7 règles d'alerte<br/>InstanceDown · ServiceWindowsCritiqueArrete<br/>SiteWebIndisponible · ControlePlanifieEnRetard<br/>CpuEleve · MemoireElevee · DisquePresquePlein"}}
        G["Grafana :3000<br/>dashboard v3 — 9 panneaux"]
        A["controle_sante.yml<br/>Ansible, lecture seule"]
    end
    NE1 -- "GET /metrics" --> P
    WE -- "GET /metrics" --> P
    NE2 --> P
    P --> R
    P -- "PromQL" --> G
    R -- "ALERTS" --> G
    A -. "SSH" .-> L1
    A -. "WinRM" .-> DC
    A -. "API" .-> P
    classDef new fill:#1f6feb,color:#fff,stroke:#1f6feb
    class TIM,SCR,PROM,A,R new
```


| Cible attendue (dépôt) | Job | Observée par Prometheus | Durée du scrape | Séries | Preuve de collecte |
| --- | --- | --- | --- | --- | --- |
| LINUX01 `192.168.50.20:9100` | `linux` | `up` | 55 ms | 1 692 | CPU 0,2 %, mémoire 10,4 %, `/` 29,2 %, `/data` 5,3 % |
| OPS01 `localhost:9100` | `linux` | `up` | 50 ms | 1 764 | CPU 6,5 %, mémoire 12,3 % |
| OPS01 `localhost:9090` | `prometheus` | `up` | 3 ms | — | Auto-supervision |
| WIN-DC01 `192.168.50.10:9182` | `windows` | `up` | 25 ms | 3 285 | CPU 0,8 %, mémoire 23,8 %, `C:` 37,3 % ; services DNS, NTDS, Netlogon, Kdc `running = 1` |


> [!example] Prometheus, page des cibles : 4/4 cibles `up` (LINUX01, OPS01, Prometheus, WIN-DC01), après correction de l'écart de règles (P-81)
> ![[P-81-prometheus-cibles-up.png|700]]

- **Chemin vérifié de bout en bout** : configuration chargée (`/etc/prometheus/prometheus.yml`), connexions TCP établies vers `:9100` et `:9182` (`ss`), endpoints `/metrics` en HTTP 200 (164 Ko côté Linux, 263 Ko côté Windows), puis valeurs **lues dans la base Prometheus** (`/api/v1/query`) : la collecte aboutit réellement et n'est pas simulée.
- **Écart corrigé** : `ops01_monitoring.yml` a été rejoué depuis une copie resynchronisée avec `main`. Prometheus charge désormais 5 règles, puis 7 avec celles de la séance (P-81, P-83).
- **Défaut révélé par ce redéploiement** (P-81a) : juste après le redémarrage de Prometheus, la liste des cibles est vide et la vérification du playbook réussissait **sans rien vérifier** (« 0 cibles up »). Au passage suivant, une cible encore « unknown » la faisait échouer. Correction (P-81b) : la tâche attend le premier scrape (`until`, 8 × 5 s) et l'assertion exige une liste non vide. Le cas qui échouait a été rejoué, puis l'idempotence revérifiée.
- **Piège noté** : les noms de service de `windows_exporter` sont sensibles à la casse (`NTDS`, pas `ntds`). Une requête en minuscules renvoie un résultat vide, pas une erreur.

### UC-03 — Tableau de bord d'exploitation (dashboard v3)

**Titre :** « InfraReady — Serveurs » · **Période par défaut :** 6 dernières heures, rafraîchissement 30 s · **Source :** Prometheus (`prometheus-infraready`), provisionnée · **Usage (description du dashboard) :** à la prise de poste, tout ce qui n'est pas vert, toute alerte active ou toute case « NON COLLECTÉ » justifie une investigation, en commençant par `controle_sante.yml`.

| Panneau | Métrique / requête | Unité | Ce que le panneau permet de décider |
| --- | --- | --- | --- |
| Disponibilité des serveurs | `max by (host) (up{job=~"linux\|windows"})` | état | HORS LIGNE ou NON COLLECTÉ → vérifier la VM, l'exporter et le pare-feu |
| Uptime | `time() - node_boot_time_seconds` / `windows_system_boot_time_timestamp` | durée | Une valeur courte inattendue signale un redémarrage non planifié |
| CPU (%) | `100 - avg by (host) (rate(..._idle[2m])) * 100` | % | > 80 % pendant 2 min → alerte `CpuEleve` |
| Mémoire utilisée (%) | `(1 - MemAvailable / MemTotal) * 100` | % | > 90 % pendant 5 min → alerte `MemoireElevee` |
| Stockage utilisé (%) par volume | `(1 - avail / size) * 100` | % | > 85 % → identifier ce qui grossit avant toute maintenance |
| Alertes Prometheus actives | `ALERTS{alertstate="firing"}` | liste | Liste vide = aucune alerte active |
| **Contrôle planifié du site web** (nouveau) | `infraready_controle_succes`, âge de `infraready_controle_derniere_execution_secondes` | état, s | ÉCHEC = site indisponible même si le serveur est EN LIGNE ; âge > 300 s = la tâche ne tourne plus |
| **Maintenance Linux** (nouveau) | `apt_upgrades_pending`, `apt_upgrades_held`, `node_reboot_required` | paquets | Préparer une fenêtre de maintenance (limite constatée en UC-C1) |
| **Stockage utilisé (%) — évolution** (nouveau) | même requête que le stockage, en série temporelle | % | Distinguer une mesure ponctuelle d'une tendance (UC-C3) |

- **Données absentes ≠ zéro** : chaque panneau affiche « NON COLLECTÉ » ou « Aucune donnée » quand aucune série n'existe (`noValue`), et les courbes ne relient pas les trous (`spanNulls: false`). Sur la capture, le labo était éteint avant 09:01 : la zone est vide, elle ne descend pas à 0 %. Pour le panneau « Maintenance Linux », le 0 n'est affiché que si le collecteur `apt` a bien tourné (`... or apt_upgrades_held * 0`). Sans fichier `apt.prom`, le panneau affiche « NON COLLECTÉ ».
- **Déploiement** : `ops01_monitoring.yml` (2ᵉ passage `changed=0`), version 3 vérifiée par l'API Grafana (9 panneaux, tous décrits) (P-85).

![[P-85-grafana-dashboard-v3-exploitation.png|700]]

### UC-04 — Alerte exploitable et testée

Le support demande une alerte liée à une exigence du projet. L'incident de la phase H avait montré un manque : **le site pouvait être indisponible sans aucune alerte**, car seul `up` (l'exporter) était surveillé. La nouvelle alerte s'appuie sur le contrôle planifié de UC-C4.

| Élément | `SiteWebIndisponible` | `ControlePlanifieEnRetard` |
| --- | --- | --- |
| Cible | Site web de LINUX01 (résultat de `check-nginx.sh` publié chaque minute) | Le contrôle planifié lui-même |
| Condition | `infraready_controle_succes{controle="site_web"} == 0` | Dernier contrôle plus vieux que 300 s, ou métrique absente (`absent()`) |
| Durée | 2 min | 5 min |
| Gravité | critical | warning |
| Justification du seuil | Deux contrôles consécutifs en échec (un par minute) : un redémarrage de nginx pendant une maintenance ne déclenche rien | Cinq contrôles manqués : le timer ou le script ne tourne plus ; la surveillance du site est alors aveugle |
| Première action | `journalctl -u infraready-controle-site -n 5` sur LINUX01, puis `systemctl status nginx` | `systemctl list-timers infraready-controle-site.timer`, `journalctl -u infraready-controle-site` |
| Syntaxe | `promtool check config` (local + CI) : 7 règles valides | idem |

**Méthode de test contrôlée :** arrêt de nginx sur LINUX01, un service de test sans dépendance pour AD, le DNS ou la supervision, avec le snapshot `s09_avant_seance6` disponible. **Pas de notification externe** (pas d'Alertmanager) : le test porte sur l'**état de l'alerte** dans Prometheus, pas sur la réception d'un message.


**Chaîne de détection pendant le test 1 (nginx arrêté)**

```mermaid
sequenceDiagram
    autonumber
    participant T as Timer systemd (LINUX01)
    participant S as check-nginx.sh
    participant F as infraready_controle.prom
    participant N as node_exporter
    participant P as Prometheus (OPS01)
    participant G as Grafana
    Note over S: 09:26:14 — nginx arrêté (test contrôlé)
    T->>S: 09:27:12 exécution
    S-->>T: code 1 « ECHEC : nginx n'est pas actif »
    T->>F: succes=0, code=1 (écriture atomique)
    P->>N: scrape toutes les 15 s
    N-->>P: infraready_controle_succes = 0
    Note over P: 09:27:23 SiteWebIndisponible = pending
    Note over P: up(linux01) = 1 → InstanceDown reste inactive
    P->>P: condition vraie pendant 2 min
    Note over P: 09:29:22 SiteWebIndisponible = FIRING
    P-->>G: ALERTS + panneau « ÉCHEC » en rouge
    Note over S: 09:30:05 — nginx redémarré
    T->>S: 09:30:12 exécution → code 0
    T->>F: succes=1
    Note over P: 09:30:32 alerte résolue (27 s)
```

| Heure | Événement | Observé |
| --- | --- | --- |
| 09:26:14 | `systemctl stop nginx` | `inactive` |
| 09:27:12 | 1ᵉʳ contrôle planifié en échec | journal : « ECHEC : le service nginx n'est pas actif » ; unité `failed`, code 1 |
| 09:27:23 | Alerte `pending` | `infraready_controle_succes = 0` ; **`up(linux01)` reste à 1, `InstanceDown` reste inactive** |
| 09:29:22 | Alerte **`firing`** (+3 min 08 s) | Capture P-84 |
| 09:30:05 | `systemctl start nginx` | `active` |
| 09:30:32 | Alerte résolue (27 s après le retour du service) | contrôle OK, `check-nginx.sh` → 0 |


**Cycle de vie des deux alertes pendant les tests**

```mermaid
stateDiagram-v2
    direction LR
    state "SiteWebIndisponible — test 1" as A {
        state "inactive" as i1
        state "pending à 09h27m23" as p1
        state "FIRING à 09h29m22" as f1
        [*] --> i1
        i1 --> p1 : succes = 0
        p1 --> f1 : condition vraie 2 min
        f1 --> i1 : nginx redémarré, résolue à 09h30m32
    }
    state "ControlePlanifieEnRetard — test 2" as B {
        state "inactive" as i2
        state "pending à 09h59m02" as p2
        state "FIRING à 10h04m01" as f2
        [*] --> i2
        i2 --> p2 : âge du contrôle > 300 s
        p2 --> f2 : condition vraie 5 min
        f2 --> i2 : timer redémarré, résolue à 10h04m17
    }
```

![[P-84-prometheus-alerte-sitewebindisponible-firing.png|600]]


> [!example] Grafana, vue arrêtée à 09:29:40 : le contrôle planifié de LINUX01 est en **ÉCHEC** et `SiteWebIndisponible` est `firing`, alors que le serveur reste EN LIGNE (P-84)
> ![[P-84-grafana-dashboard-site-en-echec.png|760]]

> [!example] Prometheus : `infraready_controle_succes` tombe à 0 pendant l'arrêt de nginx puis remonte à 1 (axe horaire en UTC = heure de Paris − 2 h)
> ![[P-84-prometheus-historique-controle-succes.png|700]]

> [!example] Prometheus, page des règles : les nouvelles règles chargées et évaluées sans erreur (extrait, P-83)
> ![[P-83-prometheus-regles-chargees.png|700]]

**Second test, `ControlePlanifieEnRetard` :** arrêt du timer à 09:54:02, alors que nginx reste actif et que le site reste servi. Dernier contrôle de plus de 300 s → `pending` à 09:59:02, **`firing` à 10:04:01** (durée `for` de 5 min respectée), sans que `SiteWebIndisponible` ne se déclenche. Timer redémarré à 10:04:06 : contrôle exécuté aussitôt, alerte résolue à 10:04:17 (P-84).

> [!example] Grafana, vue arrêtée à 10:04:10 : âge du dernier contrôle **10 min** (rouge) et `ControlePlanifieEnRetard` `firing`, pendant que le site reste OK (P-84)
> ![[P-84-grafana-dashboard-controle-en-retard.png|760]]

> [!example] Prometheus : séries `ALERTS` des deux tests (pending puis firing), axe en UTC (P-84)
> ![[P-84-prometheus-historique-alertes.png|700]]


### UC-05 — Incident INC-2026-10-23-01 : arrêt non propre de WIN-DC01

> [!warning] Incident réel, découvert par l'état initial (pas un scénario préparé)
> **Symptôme :** au démarrage du 23/10 à 09:01, WIN-DC01 journalise les événements 41 (Kernel-Power) et 6008 (« l'arrêt précédent du système le 20/10 à 19:32:34 était inattendu »). **Machine :** WIN-DC01 (AD DS, DNS). **Impact supposé :** risque d'incohérence de la base Active Directory (NTDS) et des zones DNS à chaque arrêt de l'hôte, et arrêt de l'hôte rallongé de 3 minutes. Aucun impact utilisateur constaté à ce jour : `dcdiag` n'a pas été relancé dans la séance, le contrôle de santé est OK.

| Étape | Éléments de preuve | Conclusion |
| --- | --- | --- |
| Journaux Windows | 41 + 6008 le 20/10 à 10:40 (arrêt du 19/10 20:50) et le 23/10 à 09:01 (arrêt du 20/10 19:32) ; aucun 1074 / 6006 (arrêt propre) sauf pour les redémarrages de Windows Update | Récurrent : **chaque** arrêt de l'hôte |
| Journal des tâches Proxmox | `stopall` des 19/10 et 20/10 : LINUX01 et OPS01 arrêtées en 2 à 12 s ; **VM 100 : 182-183 s**, puis « VM still running - terminating now with SIGTERM » | Proxmox attend 180 s puis tue le DC |
| Comparaison | VM Linux : fin de journal propre (`systemd-shutdown … Journal stopped`) ; VM 100 sans agent invité (`agent` non défini) | Le problème est propre à Windows |
| Métriques | Derniers échantillons de toutes les cibles à 19:29:4x : Prometheus (OPS01) s'arrête en même temps que les autres VM | **Limite** : la supervision tourne sur le même hôte et ne voit pas la fin de vie du DC |
| Hypothèse | Windows Server ignore le bouton d'alimentation ACPI à l'écran d'ouverture de session quand la stratégie « Arrêt : permet au système d'être arrêté sans avoir à se connecter » est désactivée (valeur par défaut sur Server) | — |
| Observation discriminante | `ShutdownWithoutLogon = 0`, aucune session ouverte (`quser` : « No User exists »), pas de service QEMU-GA | Hypothèse **confortée** |
| Reproduction contrôlée (09:38:45) | Arrêt ACPI demandé par l'API Proxmox, délai 90 s, **sans arrêt forcé** (`forceStop=0`) : « VM quit/powerdown failed - got timeout », VM toujours `running` | Hypothèse **confirmée**, sans arrêt brutal du DC |


> [!example] Journal des tâches Proxmox : la VM 100 met 182-183 s à « s'arrêter » (SIGTERM) et la reproduction contrôlée de 09:38 échoue sur un délai dépassé (rendu de la sortie, P-86)
> ![[P-86-rendu-proxmox-arrets-vm100-reproduction.png|760]]


**Démarche de diagnostic (preuve P-86)**

```mermaid
flowchart TD
    S["Symptôme — 23/10 09:01<br/>WIN-DC01 : événements 41 + 6008<br/>« arrêt précédent inattendu »"] --> Q1{"Accidentel<br/>ou systématique ?"}
    Q1 -- "41/6008 aussi le 20/10<br/>après l'arrêt du 19/10" --> SYS["Systématique :<br/>à chaque arrêt de l'hôte"]
    SYS --> Q2{"Que fait<br/>l'hyperviseur ?"}
    Q2 -- "journal des tâches Proxmox" --> PVE["VM 101/102 arrêtées en 2-12 s<br/>VM 100 : 182-183 s puis<br/>« terminating now with SIGTERM »"]
    PVE --> Q3{"Les métriques<br/>le montrent-elles ?"}
    Q3 -- "non" --> LIM["Limite : Prometheus (OPS01)<br/>s'arrête aussi à 19:29:50"]
    PVE --> H["Hypothèse : Windows Server ignore<br/>le bouton ACPI sans session ouverte"]
    H --> OBS["Observation : ShutdownWithoutLogon = 0<br/>aucune session (quser), pas d'agent QEMU"]
    OBS --> REP["Reproduction contrôlée 09:38<br/>arrêt ACPI, 90 s, forceStop = 0"]
    REP --> RES{"La VM<br/>s'arrête ?"}
    RES -- "non : got timeout,<br/>VM toujours running" --> CAUSE["Cause confirmée"]
    RES -. "oui (aurait infirmé)" .-> AUTRE["Chercher une autre cause"]
    CAUSE --> FIX["Correction proposée :<br/>ShutdownWithoutLogon = 1<br/>dans windows_base.yml"]
    FIX --> WAIT["⏳ En attente de validation<br/>(DC partagé)"]
    classDef bad fill:#da3633,color:#fff,stroke:#da3633
    classDef ok fill:#238636,color:#fff,stroke:#238636
    classDef wait fill:#9e6a03,color:#fff,stroke:#9e6a03
    class S,PVE bad
    class CAUSE ok
    class WAIT wait
```


**Ce qui se passe à l'arrêt de l'hôte**

```mermaid
sequenceDiagram
    participant H as Hôte Proxmox (stopall)
    participant L as LINUX01 / OPS01
    participant W as WIN-DC01
    H->>L: ACPI « bouton d'alimentation »
    L-->>H: arrêt propre en 2 à 12 s
    H->>W: ACPI « bouton d'alimentation »
    Note over W: écran de connexion, aucune session<br/>ShutdownWithoutLogon = 0 → demande ignorée
    H->>H: attente du délai de 180 s
    H->>W: SIGTERM (équivaut à couper le courant)
    Note over W: au démarrage suivant :<br/>événements 41 + 6008
```

**Correction proposée (autorisée, réversible, rejouée en Ansible) :** tâche `win_regedit` dans `windows_base.yml`, `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\shutdownwithoutlogon = 1` ; retour arrière = valeur 0. **Validation prévue :** nouvel arrêt ACPI par l'API (doit aboutir proprement en moins de 90 s), redémarrage, événements 1074 / 6006 et **absence** de 41 / 6008, contrôle de santé complet, puis `windows_base.yml` rejoué deux fois (`changed=0`). Piste complémentaire : agent invité QEMU (ISO virtio-win) avec `agent: 1` pour un arrêt par l'agent.

> [!todo] Correction non appliquée à ce stade
> La modification touche le contrôleur de domaine partagé : elle a été bloquée par le garde-fou de l'agent et attend une validation explicite de l'équipe avant application. Rapport complet : `docs/rapport-incident.md` (INC-2026-10-23-01).

### UC-06 — Intégration aux livrables

| Élément | État | Où |
| --- | --- | --- |
| Configurations, scripts, playbooks, supervision versionnés | ✅ `controle_sante.yml`, `linux_quotas.yml`, `controle-site-planifie.sh`, règles, dashboard v3, correctifs | une branche et une PR par sujet (journal de changements) |
| GitHub Actions | ✅ Contrôles exécutés sur chaque PR : arborescence, `yamllint`, `--syntax-check` (dont les 2 nouveaux playbooks), `ansible-lint` (profil *production*), `promtool` (7 règles), JSON du dashboard, gitleaks, vault chiffré | P-64 |
| Validation ≠ déploiement | ⚠️ La CI **valide les fichiers** ; elle ne déploie rien. Le déploiement est fait depuis OPS01 (copie du dépôt), car un runner hébergé par GitHub ne peut pas joindre le réseau privé du labo | README, section 9 |
| Prérequis, étapes, tests, résultats | ✅ README (commandes de la séance 6) et cette section | `README.md` |
| Aucun secret commité, captures expurgées | ✅ Recherche des vrais secrets avant chaque commit, gitleaks en CI ; les captures ne montrent ni mot de passe ni jeton | — |

**Fusion :** les 7 PR de la séance 6 (#8 à #14) ont été relues et fusionnées par Jolan Allen le 23/10/2026 entre 10:34 et 10:37 ; la CI a été rejouée en vert sur `main` après chaque fusion.

> [!example] GitHub : PR #8 à #14 de la séance 6 fusionnées, contrôles CI 8/8 (P-64)
> ![[P-64-github-pr-seance6-fusionnees.png|700]]

> [!example] GitHub Actions : runs `Validation` verts sur les branches, les PR puis `main` (P-64)
> ![[P-64-github-actions-runs-verts.png|700]]


**Du lab au dépôt : branches, PR, CI et fusion**

```mermaid
flowchart LR
    LAB["Lab (OPS01)<br/>tests réels, 2 passages,<br/>preuves P-80…P-89"] --> BR["7 branches depuis main<br/>fix/… feat/… docs/…"]
    BR --> PR["PR #8 → #14<br/>titre et corps en français"]
    PR --> CI{"GitHub Actions<br/>validation.yml"}
    CI --> J1["Arborescence"]
    CI --> J2["yamllint · syntax-check<br/>ansible-lint"]
    CI --> J3["promtool · JSON dashboard"]
    CI --> J4["gitleaks · vault chiffré"]
    J1 & J2 & J3 & J4 --> V(["12 runs verts"])
    V --> REV["Relecture et fusion<br/>par Jolan Allen"]
    REV --> MAIN["main"]
    MAIN -. "copie vers OPS01<br/>(la CI ne déploie pas :<br/>réseau privé)" .-> LAB
    classDef ok fill:#238636,color:#fff,stroke:#238636
    class V ok
```

| Fonctionnalité | Statut | Cause / action nécessaire |
| --- | --- | --- |
| UC-01 à UC-04, UC-06, UC-C1 à UC-C4, UC-A3 | Validé | — |
| UC-05 : correction de l'arrêt non propre du DC | **Partiel** (diagnostic et reproduction faits) | Validation de l'équipe, puis application de `windows_base.yml` et test d'arrêt ACPI |
| UC-C1 côté Windows | **Non exécuté** (procédure seulement) | Pas de fenêtre de maintenance du DC dans la séance (redémarrage du contrôleur de domaine, boucle KB5007651 connue) ; procédure : `windows_maintenance.yml` (recherche puis `-e maintenance_apply=true`) |
| Notification externe des alertes | **Non configurée** | Pas d'Alertmanager : alertes visibles dans Prometheus et Grafana uniquement |
| Démarrage automatique des VM (`onboot`) | **Non fait** | Choix de l'équipe : les VM restent éteintes au redémarrage de l'hôte (blocage n° 1) |

### UC-C1 — Maintenance planifiée avec contrôle avant / après

| Élément | Contenu |
| --- | --- |
| Périmètre | LINUX01 (VM de test), paquets Ubuntu ; WIN-DC01 hors périmètre de la séance (voir UC-06) |
| Prérequis | Snapshot `s09_avant_seance6` ; contrôle de santé sans ECHEC ; `apt list --upgradable` (8 paquets) |
| Risques | Redémarrage de nginx pendant la mise à jour, paquet cassé, redémarrage noyau requis |
| Moment | 23/10/2026 09:45, hors usage (labo) |
| Mécanisme réel | `apt` via `linux_maintenance.yml` (+ `unattended-upgrades` quotidien pour la sécurité) ; aucune distribution centralisée (pas de WSUS ni de miroir) |
| Conditions d'arrêt | Disque > 85 % ou service attendu inactif avant la maintenance (assertions du playbook) ; service inactif ou site KO après |
| Retour arrière | Restauration du snapshot `s09_avant_seance6` (VM 101) ; redémarrage interdit sans `-e allow_reboot=true` |
| Tests de réception | Services, site HTTP + contenu, DNS, espace disque, journaux, unités en échec : `controle_sante.yml` avant et après |


**Processus de maintenance suivi, avec ses points d'arrêt**

```mermaid
flowchart TD
    A(["Fenêtre de maintenance<br/>LINUX01 — 23/10 09:45"]) --> B["Snapshot s09_avant_seance6"]
    B --> C["controle_sante.yml -e sante_rapport=true<br/>rapport AVANT"]
    C --> D{"ECHEC ou<br/>INACCESSIBLE ?"}
    D -- "oui" --> STOP(["Arrêt : on ne maintient pas<br/>un serveur déjà en défaut"])
    D -- "non (19 lignes OK/ATTENTION/NA)" --> E["linux_maintenance.yml --limit linux01<br/>pré-contrôles disque < 85 %, services actifs"]
    E --> F["apt upgrade : 3 paquets<br/>5 reportés (phasage Ubuntu)"]
    F --> G["post-contrôles : services, HTTP 200"]
    G --> H["controle_sante.yml<br/>rapport APRÈS"]
    H --> I{"diff des statuts<br/>avant / après"}
    I -- "aucun écart" --> OK(["Maintenance validée"])
    I -- "écart" --> RB["Diagnostic, sinon<br/>retour au snapshot"]
    classDef ok fill:#238636,color:#fff,stroke:#238636
    classDef bad fill:#da3633,color:#fff,stroke:#da3633
    class OK ok
    class STOP,RB bad
```

| Contrôle (LINUX01) | Avant (09:45:02) | Après (09:45:29) |
| --- | --- | --- |
| Paquets | 8 en attente | 3 mis à jour (`tmux`, `ubuntu-pro-client`, `ubuntu-pro-client-l10n`), 5 reportés par le phasage d'Ubuntu |
| Services ssh, nginx, node_exporter | actifs | actifs |
| Site web (HTTP + contenu) | 200 | 200 |
| Disque | `/` 29,2 % | `/` 29,2 % |
| Redémarrage requis | non | non |
| Statuts du contrôle de santé | 19 lignes (LINUX01 + OPS01) | **aucun écart de statut** (`diff` des deux rapports) |


> [!example] Maintenance de LINUX01 : 3 paquets installés, 5 reportés par le phasage, aucun écart de statut entre les deux contrôles de santé (rendu de la sortie, P-87)
> ![[P-87-rendu-maintenance-avant-apres.png|760]]

**Limite constatée :** avant la maintenance, le collecteur `apt` de node_exporter comptait les 8 paquets comme « retenus » et 0 « à installer », alors que 3 étaient installables. Après la maintenance, il compte 5 retenus, ce qui correspond aux paquets reportés par le phasage. Le panneau « Maintenance Linux » est donc un indicateur : la liste de référence reste `apt list --upgradable` en pré-contrôle (P-87).

### UC-C2 — Contrôle de santé automatisé avec Ansible

`ansible/playbooks/controle_sante.yml` réutilise l'inventaire du projet (`linux`, `windows`) et le vault pour WinRM.


**Structure du playbook `controle_sante.yml`**

```mermaid
flowchart LR
    subgraph P1["Play 1 — linux (SSH)"]
        L["identité · heure NTP · disques<br/>services · unités en échec<br/>journal 24 h · DNS<br/>site HTTP + contenu<br/>cibles Prometheus · API Grafana"]
    end
    subgraph P2["Play 2 — windows (WinRM)"]
        W["PowerShell lecture seule<br/>w32tm · disques · services AD<br/>journal System · DNS local<br/>Get-ADDomain · exporter"]
        RS["rescue : INACCESSIBLE / ECHEC<br/>au lieu d'arrêter le playbook"]
        W -. "erreur ou injoignable" .-> RS
    end
    subgraph P3["Play 3 — synthèse (localhost)"]
        T["Tableau hôte · contrôle · statut"]
        R[("rapport daté<br/>-e sante_rapport=true")]
        X{"ECHEC ou<br/>INACCESSIBLE ?"}
    end
    L --> T
    W --> T
    RS --> T
    T --> R
    T --> X
    X -- "non" --> OK(["code 0 — 23 OK, 3 ATTENTION, 1 NA"])
    X -- "oui" --> KO(["code 2 — exploitable par un script"])
    classDef ok fill:#238636,color:#fff,stroke:#238636
    classDef bad fill:#da3633,color:#fff,stroke:#da3633
    class OK ok
    class KO bad
```

| Contrôle | Linux | Windows | Statuts possibles |
| --- | --- | --- | --- |
| Identité, durée depuis le démarrage | faits Ansible | `Win32_OperatingSystem` | OK |
| Heure | `timedatectl` (NTP) | `w32tm /query /status` | OK / ECHEC |
| Espace disque (seuil 85 %) | `ansible_mounts` | `Win32_LogicalDisk` | OK / ECHEC |
| Disque de données `/data` | LINUX01 | — | OK / ECHEC / NON APPLICABLE (OPS01) |
| Services attendus | `service_facts` | `Get-Service` | OK / ECHEC |
| Unités systemd en échec | `systemctl list-units --state=failed` | — | OK / ECHEC |
| Erreurs du journal sur 24 h | `journalctl -p err` | `Get-WinEvent` niveaux 1-2 | OK / ATTENTION |
| DNS du domaine | `getent` | `Resolve-DnsName` (DNS local) | OK / ECHEC |
| Tests fonctionnels | site HTTP + contenu par le nom ; cibles Prometheus ; API Grafana | domaine AD ; `windows_exporter` | OK / ECHEC |
| Connexion | — | — | INACCESSIBLE (hôte injoignable ou erreur de privilèges) |


> [!example] Résultat de `controle_sante.yml` : 23 OK, 3 ATTENTION, 1 NON APPLICABLE, 0 ECHEC (rendu de la sortie, P-80b / P-82)
> ![[P-82-rendu-tableau-controle-sante.png|760]]

- **Lecture seule vérifiée** : `changed=0` sur les trois serveurs en exécution normale et en `--check`. Seule l'option `-e sante_rapport=true` écrit un rapport daté dans `~/infraready-logs/` sur OPS01, et cette écriture est annoncée comme `changed`.
- **Résultat exploitable** : un tableau hôte / contrôle / statut / détail, puis un dernier play en échec (code 2) s'il reste un ECHEC ou un INACCESSIBLE. Le playbook peut donc servir de critère d'arrêt (UC-C1) ou être lancé par une tâche planifiée.
- **Premier passage (P-82)** : il a détecté 2 ECHEC réels (`openipmi`), corrigés en Ansible (P-80b) ; ensuite 23 OK, 3 ATTENTION (événements réels des dernières 24 h), 1 NON APPLICABLE, 0 ECHEC.
- **Erreurs de connexion** : un WinRM injoignable, simulé en interrogeant un port fermé (`-e ansible_port=5986`) sans toucher au serveur, produit une ligne INACCESSIBLE avec le message de connexion, au lieu d'interrompre le playbook. Ce test a révélé un défaut, corrigé : avec `--limit`, les hôtes volontairement exclus apparaissaient comme INACCESSIBLE.

### UC-C3 — Observation ponctuelle et suivi dans le temps

**Ressource choisie :** espace occupé sur `/` de LINUX01 et OPS01. OPS01 héberge la base Prometheus, qui grossit avec le temps.


**Périodes couvertes par l'historique Prometheus**

```mermaid
gantt
    title Données disponibles dans Prometheus (UC-C3) — trous = labo éteint
    dateFormat YYYY-MM-DD HH:mm
    axisFormat %d/%m %Hh
    todayMarker off
    section Labo allumé
    19/10 — phases A à H         :done, 2026-10-19 16:30, 2026-10-19 20:48
    20/10 — séance 4, PR 1-5     :done, 2026-10-20 10:40, 2026-10-20 19:29
    23/10 — séance 6             :done, 2026-10-23 09:01, 2026-10-23 11:00
    section Labo éteint
    aucune donnée (13 h)         :crit, 2026-10-19 20:48, 2026-10-20 10:40
    aucune donnée (61 h)         :crit, 2026-10-20 19:29, 2026-10-23 09:01
```

| Élément | Observation |
| --- | --- |
| Mesure ponctuelle (23/10 09:46) | LINUX01 `/` 29,2 % (8,01 Gio occupés, réserve root comprise) ; OPS01 `/` 26,3 % (12,34 Gio) ; base Prometheus 42,4 Mio |
| Historique disponible | Du 19/10 17:00 au 20/10 20:00 puis depuis le 23/10 09:01 : **15 h de données sur 91 h**, le labo étant éteint le reste du temps. Scrape toutes les 15 s, rétention par défaut de 15 jours |
| Unité, période, limites | Octets (Gio), moyenne horaire ; trous = labo éteint (aucune donnée, pas une occupation nulle) ; les séries sans label `host` du 1ᵉʳ démarrage de Prometheus (19/10) sont exclues |
| Tendance décrite | OPS01 : + 0,12 Gio sur ~ 15 h de fonctionnement (12,24 → 12,36 Gio), croissance régulière quand le labo tourne ; LINUX01 : stable (7,96 → 7,98 Gio) |
| Ce qu'il ne faut pas conclure | `deriv()` sur 6 h annonce LINUX01 « − 234 Mio/jour » et `predict_linear()` une occupation de 4,7 % dans 30 jours : la fenêtre ne contient que 45 min de données, dont la maintenance qui a vidé le cache apt. **Une pente calculée sur si peu de données n'est pas une tendance.** On n'attribue pas non plus la croissance d'OPS01 à Prometheus seul (journaux, apt) sans mesure dédiée |
| Proposition de suivi | Panneau « Stockage utilisé (%) — évolution » consulté sur 7 jours. Alerte prédictive à valider **après une semaine de fonctionnement continu** : `predict_linear(node_filesystem_avail_bytes{mountpoint="/"}[3d], 14*86400) < 0`, avec un `for` de 1 h. Taille de la base suivie par `prometheus_tsdb_storage_blocks_bytes` |


> [!example] Grafana, « Stockage utilisé (%) — évolution » du 19/10 au 23/10 : trois îlots de données séparés par les périodes où le labo était éteint (aucune donnée, pas 0 %). On y voit aussi `C:` de WIN-DC01 passer de 24 % à 43 % puis 37 % le 19/10 (Windows Update), et les séries « / » et « /boot » sans label `host` du 1ᵉʳ démarrage de Prometheus (P-88)
> ![[P-88-grafana-evolution-stockage-19-23-oct.png|760]]

### UC-C4 — Tâche planifiée et traçabilité

| Élément de la fiche | Valeur |
| --- | --- |
| Tâche | Contrôle du site web de LINUX01, sans effet destructif (`check-nginx.sh` : lecture seule) |
| Mécanisme | Timer systemd `infraready-controle-site.timer` (1 min après le démarrage, puis chaque minute) → service `oneshot` `infraready-controle-site.service` |
| Déploiement | `linux_base.yml` (scripts copiés depuis `scripts/` vers `/usr/local/lib/infraready/`, unités dans `/etc/systemd/system/`) |
| Compte d'exécution et droits | root **sans aucune capacité** (`CapabilityBoundingSet=` vide), `NoNewPrivileges`, système de fichiers en lecture seule (`ProtectSystem=strict`) sauf `/var/lib/prometheus/node-exporter` ; exposition systemd 6,2 « MEDIUM » |
| Codes de retour | 0 = OK, 1 = contrôle négatif, 2 = erreur d'exécution (ceux de `check-nginx.sh`), 3 = métriques non publiées |
| Traces | Journal : `journalctl -u infraready-controle-site` (sortie du contrôle, `Result=exit-code`) ; métriques : `/var/lib/prometheus/node-exporter/infraready_controle.prom` (écriture atomique), lues par node_exporter puis Prometheus ; Grafana : panneau « Contrôle planifié du site web » |
| Scénario normal testé | Exécution chaque minute, `Result=success`, `ExecMainStatus=0`, métrique `succes=1`, âge < 60 s dans Prometheus (P-83) |
| Diagnostic d'un échec | 1) `systemctl list-timers infraready-controle-site.timer` : le timer tourne-t-il ? 2) `systemctl status infraready-controle-site` / `journalctl -u … -n 20` : dernier code et message ; 3) code 1 → le site (nginx, HTTP, contenu), code 2 → prérequis (curl, unité nginx), code 3 → droits ou espace sur le dossier textfile ; 4) `node_textfile_scrape_error` et âge de la métrique côté Prometheus. Cas réel observé pendant UC-04 : unité `failed`, « ECHEC : le service nginx n'est pas actif » |


> [!example] LINUX01 : timer actif chaque minute, journal du contrôle (« OK : nginx actif… »), fichier de métriques lu par node_exporter puis Prometheus (rendu de la sortie, P-83)
> ![[P-83-rendu-timer-journal-metriques.png|760]]

### UC-A3 (défi) — Prévenir la saturation du stockage avec des quotas

Choix : **quotas** plutôt que RAID logiciel. Un seul disque de test est réservé au TP (`/data`) ; un RAID de démonstration aurait demandé d'ajouter des disques à la VM.


**Comportement des quotas observé (alice, bruno)**

```mermaid
flowchart LR
    Z["0 Mio"] --> S1["alice écrit 220 Mio"]
    S1 --> SOFT{{"seuil souple 200 Mio<br/>dépassé"}}
    SOFT -- "accepté<br/>délai de grâce 7 jours" --> W["quota : 220M* · 7days"]
    W --> S2["alice écrit 100 Mio de plus"]
    S2 --> HARD{{"seuil strict 250 Mio"}}
    HARD -- "refusé à 250 Mio" --> E["dd : Disk quota exceeded<br/>code 1"]
    B["bruno écrit 50 Mio<br/>même dossier"] --> OKB["accepté :<br/>quota indépendant"]
    GF["Garde-fou du playbook :<br/>série INFRA-DATA01 + usrquota,grpquota"] -. "avant toute modification" .-> Z
    classDef warn fill:#9e6a03,color:#fff,stroke:#9e6a03
    classDef bad fill:#da3633,color:#fff,stroke:#da3633
    classDef ok fill:#238636,color:#fff,stroke:#238636
    class SOFT,W warn
    class HARD,E bad
    class OKB ok
```

| Élément | Contenu |
| --- | --- |
| Besoin | Empêcher qu'un administrateur web (alice, bruno) monopolise l'espace commun de `/data` |
| Périmètre | Disque de **test** `/data` de LINUX01 (série `INFRA-DATA01`), dossier `/data/partage-web` (groupe `webadmins`, setgid) ; jamais `/` ni un disque de données réel |
| Seuils | Avertissement (souple) 200 Mio, délai de grâce 7 jours ; blocage (strict) 250 Mio par utilisateur |
| Comportement attendu | Écriture acceptée au-delà de 200 Mio, avec signalement et délai de grâce ; refus (`Disk quota exceeded`) à 250 Mio ; les autres utilisateurs ne sont pas affectés |
| Mise en œuvre | `linux_base.yml` : options de montage `usrquota,grpquota` (variable `data_mount_opts`) ; `linux_quotas.yml` : **garde-fou** (numéro de série du disque et options vérifiés avant toute modification), paquet `quota`, `quotacheck`, `quotaon`, `setquota` seulement si les limites diffèrent |
| Prérequis et restauration | Snapshot `s09_avant_seance6` ; retour arrière : `quotaoff -ug /data`, retirer `usrquota,grpquota` de `data_mount_opts` et rejouer `linux_base.yml`, supprimer `/data/aquota.*` |
| Résultats observés | alice : 220 Mio acceptés (`220M*`, grâce `7days`), puis bloquée à 250 Mio (`dd: … Disk quota exceeded`, code 1) ; bruno écrit 50 Mio sans gêne ; fichiers de test supprimés (P-89) |
| Limites | root n'est pas soumis aux quotas ; `repquota` lit le fichier de quotas, mis à jour en différé, alors que `quota -u` interroge le noyau et fait foi ; aucune trace dans le journal système, l'erreur est renvoyée à l'application |
| Surveillance proposée | Capacité du volume : `DisquePresquePlein` et panneau d'évolution, déjà en place. Quotas, non réalisé : script `repquota -uv -O csv` lancé par un timer, qui publierait `infraready_quota_utilise_octets{user}` et `infraready_quota_limite_octets{user}` (collecteur textfile), avec une alerte quand l'utilisation dépasse 90 % du seuil souple pendant 15 min |


> [!example] Test des quotas : alice acceptée à 220 Mio (délai de grâce), puis **bloquée à 250 Mio** (« Disk quota exceeded ») ; bruno non affecté (rendu de la sortie, P-89)
> ![[P-89-rendu-test-quotas-alice.png|760]]

### Difficultés / décision / retour arrière

| Problème | Cause | Correction | Résultat |
| --- | --- | --- | --- |
| VM éteintes, lab injoignable au démarrage | Hôte redémarré, VM sans `onboot` | Démarrage manuel | Levé (P-80) |
| Jeton API Proxmox sans droit | « Privilege Separation » | Séparation retirée par l'étudiant | Snapshot `s09` pris |
| 4 règles chargées au lieu de 5 | Copie du projet sur OPS01 non resynchronisée | Copie resynchronisée, `ops01_monitoring.yml` rejoué | 5 puis 7 règles (P-81) |
| Vérification des cibles réussie avec **0 cible**, puis échec sur une cible « unknown » | Vérification lancée juste après le redémarrage de Prometheus, avant le premier scrape | `until` (8 × 5 s) + liste non vide exigée | Test du cas en échec OK, idempotent (P-81a → P-81b) |
| `openipmi.service` en échec à chaque démarrage | Paquet recommandé installé par nos playbooks, sans matériel IPMI | Service désactivé + `reset-failed` par handler, dans les deux playbooks | Contrôle de santé sans ECHEC (P-80b) |
| Synthèse du contrôle de santé jamais affichée | PowerShell : `try/catch` interdit directement dans un littéral de table de hachage, et un play dont tous les hôtes échouent arrête le playbook | `$(try { … } catch { … })`, `block/rescue` et `ignore_unreachable` | Ligne ECHEC / INACCESSIBLE au lieu d'un arrêt (P-82) |
| Liste des disques Windows reçue comme texte | Profondeur de sérialisation par défaut de `win_powershell` (2) | `depth: 4` | Disques lus comme données |
| Hôtes exclus par `--limit` signalés INACCESSIBLE | Synthèse calculée sur tout l'inventaire | Hôtes visés = `inventory_hostnames` de `ansible_limit` | Test 3b correct (P-82) |
| `linux_quotas.yml` non idempotent | `repquota` sans `-v` n'affiche pas les comptes sans occupation | `repquota -uv` | `changed=0` au 2ᵉ passage (P-89a → P-89) |
| Arrêt ACPI de WIN-DC01 ignoré | Stratégie `ShutdownWithoutLogon = 0` (défaut Windows Server) | Correction préparée dans `windows_base.yml`, **en attente de validation** | Diagnostic confirmé par reproduction (P-86) |
| Requête des services Windows vide | Noms sensibles à la casse | `name=~"DNS\|NTDS\|…"` | Valeurs lues (P-81) |

### Checklist de fin de séance (6.1 du support)

- [x] État initial documenté pour les systèmes du périmètre (P-80).
- [x] Collecte des métriques Linux et Windows vérifiée (P-81).
- [x] Tableau de bord avec indicateurs lisibles et unités explicites (P-85).
- [x] Au moins une alerte définie et testée dans les limites de l'environnement (P-84).
- [ ] Un incident analysé avec journaux, hypothèse, correction et test de retour au service : analyse, hypothèse et reproduction faites (P-86) ; **correction et test de retour en attente de validation**.
- [x] Résultats, configurations et documentation intégrés au dépôt (PR de la séance 6).
- [x] Pipeline CI/CD vérifié, sans prétendre qu'il déploie dans le réseau privé (P-64).
- [x] Aucun secret publié ; captures et journaux expurgés.
- [x] Compléments (UC-C1 à UC-C4) et défi avancé (UC-A3) réalisés.

---

## 13. Sécurité et limites d'intervention

- [x] VM du laboratoire uniquement, aucun système externe — seules les VM 100 à 102 ont été modifiées ; les autres VM de l'hôte n'ont pas été touchées.
- [x] Cibles contrôlées avant formatage / partitionnement — disques système vérifiés vides avant installation ; disque de test identifié par numéro de série + 5 contrôles avec arrêt automatique.
- [x] Snapshots avant changements majeurs — `s01_installation_ok`, `s02_avant_adds`, `s02_avant_maj_c`, `s02_avant_monitoring`, `s03_avant_ansible`, `s04_avant_maintenance_e`, `s04_avant_maj_windows` ; état final figé dans `s05_phases_a_h_terminees` (arbre complet : [P-05](docs/preuves/P-05-proxmox-snapshots-arbre-complet.txt)) ; puis `s06_avant_mdp_password`, `s07_avant_seance4`, `s08_avant_validation_pr3_5` et `s09_avant_seance6` (23/10/2026 09:05, avant toute modification de la séance 6).
- [x] Moindre privilège — comptes Linux verrouillés, droits par groupe, chloe lit sans écrire, support IT en lecture seule sur le partage Compta, compte `ansible` dédié.
- [x] Ports limités au strict besoin — UFW sur LINUX01 (refus par défaut), WinRM/ICMP limités au labo, exporters limités à OPS01, labo isolé du réseau domestique.
- [x] Aucun secret en clair dans Git ou dans ce dossier — vault AES256, modèles avec `__PLACEHOLDERS__`, fichiers de réponse supprimés après usage, recherche des vrais secrets avant chaque commit, gitleaks dans la CI.
- [x] Playbooks testés avant exécution large — un hôte par playbook, snapshot préalable, second passage pour vérifier la stabilité.
- [x] Changements perturbateurs documentés — redémarrage de promotion du DC, modification réseau de l'hôte (sauvegarde `interfaces.bak-infraready`), changement DNS des VM Linux (sauvegarde netplan).
- [x] Fonctionnalités non réalisées signalées — voir section 15.
- [x] Changements sur le contrôleur de domaine soumis à validation — la correction de l'incident INC-2026-10-23-01 (registre de WIN-DC01) n'est pas appliquée sans accord explicite de l'équipe.

**Limites connues** : WinRM en HTTP (5985) avec chiffrement NTLM du message, mais sans certificat TLS ; Grafana consultable sans compte en lecture seule (rôle Viewer, réseau du labo uniquement) ; Prometheus et Grafana sans TLS (labo isolé) ; mot de passe `sudo` de l'hôte Proxmox faible et à changer en fin de projet ; **jeton API Proxmox** (`root@pam!claude`, séparation des privilèges retirée le 23/10) à révoquer après la remise ; le service du contrôle planifié tourne en root, mais sans aucune capacité et avec un système de fichiers en lecture seule.

---

## 14. Recette finale et matrice des preuves

### Recette finale

| Phase | Validation finale | État | Preuve |
| --- | --- | --- | --- |
| A | VM / IP / réseau / DNS | ✅ Validé | P-01 à P-04c |
| B | AD DS / groupes / comptes / DNS | ✅ Validé | P-10 à P-13 |
| C | Permissions / service / stockage / logs | ✅ Validé | P-20 à P-24 |
| D | Playbooks Linux & Windows / idempotence | ✅ Validé | P-30 à P-35 |
| E | Mises à jour / maintenance | ✅ Validé | P-40 à P-43 |
| F | Exporters / dashboard / alerte | ✅ Validé | P-50 à P-55 |
| G | Workflow GitHub Actions réussi | ✅ Validé (contributions de Kenzi Bendjelloul à compléter) | P-60, P-61 à P-63 |
| H | Incident corrigé / retour normal | ✅ Validé | P-70 à P-73, `docs/rapport-incident.md` |
| Séance 4 | Scripts de vérification / processus et services / 6 scénarios de panne / mode check | ✅ Validé (bilans individuels à compléter) | P-14, P-25, P-26, P-38 à P-39, P-74 à P-79 |
| Séance 6 | État initial, collecte Linux/Windows, dashboard v3, alerte testée, contrôle de santé, tâche planifiée, maintenance avant/après, tendance, quotas | ✅ Validé — ⚠️ incident UC-05 diagnostiqué, correction en attente de validation | P-80 à P-89, P-64 |

### Matrice des preuves

| ID | Date | Test ou capture | Fichier |
| --- | --- | --- | --- |
| P-01 | 19/10/2026 | VM Proxmox, snapshots, pont vmbr1, règles nftables | [P-01](docs/preuves/P-01-proxmox-vms-et-reseau.txt) |
| P-02 | 19/10/2026 | LINUX01 : IP, connectivité, Internet, isolation + contre-test | [P-02](docs/preuves/P-02-linux01-ip-connectivite-isolation.txt) |
| P-02b | 19/10/2026 | OPS01 : IP, connectivité, Internet, isolation | [P-02b](docs/preuves/P-02b-ops01-ip-connectivite-isolation.txt) |
| P-03 | 19/10/2026 | Capture : WIN-DC01 installé, Server Manager | [P-03](docs/preuves/P-03-win-dc01-installe-server-manager.png) |
| P-04 | 19/10/2026 | LINUX01 : DNS du domaine (A, PTR, SRV) | [P-04](docs/preuves/P-04-linux01-resolution-dns-domaine.txt) |
| P-04b | 19/10/2026 | OPS01 : DNS du domaine (A, PTR, SRV) | [P-04b](docs/preuves/P-04b-ops01-resolution-dns-domaine.txt) |
| P-04c | 19/10/2026 | WIN-DC01 : IP, ping et résolution des serveurs | [P-04c](docs/preuves/P-04c-win-dc01-ip-dns.txt) |
| P-05 | 19/10/2026 | Arbre complet des snapshots Proxmox des 3 VM, snapshot final s05 | [P-05](docs/preuves/P-05-proxmox-snapshots-arbre-complet.txt) |
| P-10a | 19/10/2026 | 1er essai de promotion en échec (`reboot_timeout`) | [P-10a](docs/preuves/P-10a-adds-premier-essai-echec-reboot_timeout.txt) |
| P-10 | 19/10/2026 | Installation AD DS + forêt infraready.test | [P-10](docs/preuves/P-10-adds-installation-foret.txt) |
| P-11 | 19/10/2026 | OU, groupes, comptes AD | [P-11](docs/preuves/P-11-ad-ou-groupes-comptes.txt) |
| P-12 | 19/10/2026 | État du domaine, comptes, DNS, zones, dcdiag | [P-12](docs/preuves/P-12-domaine-dns-verifications.txt) |
| P-12b | 19/10/2026 | dcdiag tests fonctionnels + NTP | [P-12b](docs/preuves/P-12b-dcdiag-tests-fonctionnels-ntp.txt) |
| P-13 | 19/10/2026 | Journaux Windows (Security, Directory Service, DNS, System) | [P-13](docs/preuves/P-13-journaux-windows-ad.txt) |
| P-14 | 20/10/2026 | Windows : état initial, services, processus, journal System, script `Check-DnsClient.ps1` (0/1/2) | [P-14](docs/preuves/P-14-win-dc01-processus-services-script-dnsclient.txt) |
| P-15 | 20/10/2026 | `windows_adds.yml` idempotent après correction du DNS du DC (`changed=0` ×2) | [P-15](docs/preuves/P-15-windows-adds-dns-idempotence.txt) |
| P-20 | 19/10/2026 | Comptes, groupes, permissions Linux + tests de droits | [P-20](docs/preuves/P-20-linux01-comptes-groupes-permissions.txt) |
| P-21 | 19/10/2026 | nginx, service et processus | [P-21](docs/preuves/P-21-linux01-service-nginx-processus.txt) |
| P-22 | 19/10/2026 | Disque de test : contrôles, formatage, montage UUID | [P-22](docs/preuves/P-22-linux01-disque-test-montage.txt) |
| P-23 | 19/10/2026 | Mise à jour contrôlée d'Ubuntu | [P-23](docs/preuves/P-23-linux01-mise-a-jour-controlee.txt) |
| P-24 | 19/10/2026 | Analyse des journaux Linux | [P-24](docs/preuves/P-24-linux01-analyse-journaux.txt) |
| P-25 | 20/10/2026 | Script `check-nginx.sh` testé dans 3 situations (codes 0/1/2) | [P-25](docs/preuves/P-25-script-check-nginx-trois-situations.txt) |
| P-26 | 20/10/2026 | LINUX01 : état initial, processus, mémoire, disque, services, journaux nginx | [P-26](docs/preuves/P-26-linux01-processus-services-journaux.txt) |
| P-30 | 19/10/2026 | Ansible : version, inventaire, connexions | [P-30](docs/preuves/P-30-ansible-inventaire-connexions.txt) |
| P-31 | 19/10/2026 | Playbook Linux — 1er passage | [P-31](docs/preuves/P-31-playbook-linux-1er-passage.txt) |
| P-32 | 19/10/2026 | Playbook Linux — 2e passage (idempotence) + UFW | [P-32](docs/preuves/P-32-playbook-linux-2e-passage-idempotence.txt) |
| P-33 | 19/10/2026 | Playbook Windows — 1er passage | [P-33](docs/preuves/P-33-playbook-windows-1er-passage.txt) |
| P-34 | 19/10/2026 | Playbook Windows — 2e passage (idempotence) | [P-34](docs/preuves/P-34-playbook-windows-2e-passage-idempotence.txt) |
| P-35 | 19/10/2026 | Playbook Windows — correction PTR du DC | [P-35](docs/preuves/P-35-playbook-windows-correction-ptr-dc.txt) |
| P-36 | 19/10/2026 | Diagnostic : enregistrements de la zone inverse (statique/dynamique) | [P-36](docs/preuves/P-36-diagnostic-ptr-dc-statique-vs-dynamique.txt) |
| P-36b | 19/10/2026 | Zone inverse après réenregistrement du DC | [P-36b](docs/preuves/P-36b-ptr-dc-apres-reenregistrement-dynamique.txt) |
| P-37 | 19/10/2026 | Playbook Windows stable après réenregistrement du DC (changed=0 ×2) | [P-37](docs/preuves/P-37-playbook-windows-ptr-dc-stable.txt) |
| P-38 | 20/10/2026 | `linux_base.yml` + `site_message` et contrôle de contenu — 1ᵉʳ passage | [P-38](docs/preuves/P-38-playbook-linux-site-message-1er-passage.txt) |
| P-38b | 20/10/2026 | `linux_base.yml` — 2ᵉ passage (`changed=0`) | [P-38b](docs/preuves/P-38b-playbook-linux-site-message-2e-passage.txt) |
| P-39a | 20/10/2026 | Simulation `--check --diff` en échec (blkid / uri non exécutés) | [P-39a](docs/preuves/P-39a-playbook-linux-mode-check-echec.txt) |
| P-39 | 20/10/2026 | Simulation corrigée (`check_mode: false`) puis exécution `changed=0` | [P-39](docs/preuves/P-39-playbook-linux-mode-check-corrige.txt) |
| P-40 | 19/10/2026 | Maintenance Linux (linux01, ops01) : pré-contrôles, apt, post-contrôles | [P-40](docs/preuves/P-40-linux-maintenance-standard.txt) |
| P-40b | 19/10/2026 | Rapports de maintenance générés (`~/infraready-logs/`) | [P-40b](docs/preuves/P-40b-rapports-maintenance-generes.txt) |
| P-41a | 19/10/2026 | Maintenance Windows — 1er essai : lecteur CD vu comme volume plein | [P-41a](docs/preuves/P-41a-windows-maintenance-1er-essai-lecteur-cd.txt) |
| P-41 | 19/10/2026 | Maintenance Windows — recherche des mises à jour (5 trouvées) | [P-41](docs/preuves/P-41-windows-maintenance-recherche-maj.txt) |
| P-42 | 19/10/2026 | Maintenance Windows — installation (5 MAJ, redémarrage du DC, boucle KB5007651) | [P-42](docs/preuves/P-42-windows-maintenance-installation-maj.txt) |
| P-42b | 19/10/2026 | Diagnostic WIN-DC01 : historique WU, journal Système, plateforme Defender | [P-42b](docs/preuves/P-42b-win-dc01-diagnostic-kb5007651-historique-wu.txt) |
| P-42c | 19/10/2026 | Maintenance Windows — passage complet après exclusion de KB5007651 | [P-42c](docs/preuves/P-42c-windows-maintenance-installation-complete-apres-exclusion.txt) |
| P-43 | 19/10/2026 | unattended-upgrades : configuration, minuteries, simulation | [P-43](docs/preuves/P-43-linux01-mises-a-jour-automatiques-unattended.txt) |
| P-70 | 19/10/2026 | Incident nginx : reproduction contrôlée et constat du symptôme (404) | [P-70](docs/preuves/P-70-incident-nginx-reproduction-et-symptome.txt) |
| P-71 | 19/10/2026 | Incident nginx : diagnostic par élimination, cause confirmée | [P-71](docs/preuves/P-71-incident-nginx-diagnostic.txt) |
| P-72a | 19/10/2026 | Incident nginx : 1ᵉʳ essai de correction, handler non exécuté | [P-72a](docs/preuves/P-72a-incident-nginx-correction-1er-essai-handler-non-execute.txt) |
| P-72 | 19/10/2026 | Incident nginx : correction avec le playbook corrigé (reproduction n°2) | [P-72](docs/preuves/P-72-incident-nginx-correction-playbook-corrige.txt) |
| P-73 | 19/10/2026 | Incident nginx : retour à la normale et 2ᵉ passage `changed=0` | [P-73](docs/preuves/P-73-incident-nginx-retour-normale-et-second-passage.txt) |
| P-74 | 20/10/2026 | Scénario 1 : variable incorrecte | [P-74](docs/preuves/P-74-scenario1-variable-incorrecte.txt) |
| P-75 | 20/10/2026 | Scénario 2 : variable Jinja2 inexistante | [P-75](docs/preuves/P-75-scenario2-variable-jinja2-inexistante.txt) |
| P-76 | 20/10/2026 | Scénario 3 : mauvais chemin de destination | [P-76](docs/preuves/P-76-scenario3-mauvais-chemin-de-destination.txt) |
| P-77 | 20/10/2026 | Scénario 4 : handler non notifié | [P-77](docs/preuves/P-77-scenario4-handler-non-notifie.txt) |
| P-78 | 20/10/2026 | Scénario 5 : nginx arrêté | [P-78](docs/preuves/P-78-scenario5-nginx-arrete.txt) |
| P-79 | 20/10/2026 | Scénario 6 : contrôle fonctionnel du contenu | [P-79](docs/preuves/P-79-scenario6-controle-fonctionnel-contenu.txt) |
| P-80 | 23/10/2026 | Séance 6 : état initial des 3 serveurs avant toute modification, blocages initiaux | [P-80](docs/preuves/P-80-seance6-etat-initial-trois-serveurs.txt), [png](docs/preuves/P-80-rendu-win-dc01-evenements-arret.png) |
| P-80c | 23/10/2026 | Arbre des snapshots des 3 VM (API Proxmox), dont `s09_avant_seance6` | [P-80c](docs/preuves/P-80c-proxmox-snapshots-s09.txt), [png](docs/preuves/P-80c-rendu-proxmox-snapshots-s09.png) |
| P-80b | 23/10/2026 | `openipmi` désactivé par Ansible ; contrôle de santé sans ECHEC | [P-80b](docs/preuves/P-80b-seance6-correction-openipmi-et-controle-sante-vert.txt) |
| P-81a | 23/10/2026 | Redéploiement de la supervision : écart de règles corrigé, vérification des cibles instable | [P-81a](docs/preuves/P-81a-seance6-redeploiement-monitoring-verification-cibles-instable.txt) |
| P-81b | 23/10/2026 | Vérification des cibles corrigée (attente du 1ᵉʳ scrape), idempotence | [P-81b](docs/preuves/P-81b-seance6-monitoring-verification-cibles-corrigee.txt) |
| P-81 | 23/10/2026 | Cibles attendues / observées, endpoints, métriques Linux et Windows, règles | [P-81](docs/preuves/P-81-seance6-collecte-metriques-linux-windows.txt), [cibles png](docs/preuves/P-81-prometheus-cibles-up.png) |
| P-82 | 23/10/2026 | `controle_sante.yml` : exécution, `--check`, hôte injoignable, correctif `--limit` | [P-82](docs/preuves/P-82-controle-sante-ansible-lecture-seule.txt), [png](docs/preuves/P-82-rendu-tableau-controle-sante.png) |
| P-83 | 23/10/2026 | Tâche planifiée : timer systemd, journal, métriques textfile, 2 nouvelles règles | [P-83](docs/preuves/P-83-controle-planifie-timer-systemd.txt), [timer png](docs/preuves/P-83-rendu-timer-journal-metriques.png), [règles png](docs/preuves/P-83-prometheus-regles-chargees.png) |
| P-84 | 23/10/2026 | Alertes `SiteWebIndisponible` et `ControlePlanifieEnRetard` : déclenchement et retour à la normale + capture | [P-84](docs/preuves/P-84-alerte-sitewebindisponible-test-controle.txt), [png](docs/preuves/P-84-prometheus-alerte-sitewebindisponible-firing.png), [Grafana échec](docs/preuves/P-84-grafana-dashboard-site-en-echec.png), [Grafana retard](docs/preuves/P-84-grafana-dashboard-controle-en-retard.png), [historique](docs/preuves/P-84-prometheus-historique-controle-succes.png), [ALERTS](docs/preuves/P-84-prometheus-historique-alertes.png) |
| P-85 | 23/10/2026 | Dashboard Grafana v3 : déploiement, vérification par l'API + capture | [P-85](docs/preuves/P-85-grafana-dashboard-v3-deploiement.txt), [png](docs/preuves/P-85-grafana-dashboard-v3-exploitation.png) |
| P-86 | 23/10/2026 | Incident INC-2026-10-23-01 : arrêt non propre de WIN-DC01, diagnostic et reproduction | [P-86](docs/preuves/P-86-incident-arret-non-propre-win-dc01-diagnostic.txt), [png](docs/preuves/P-86-rendu-proxmox-arrets-vm100-reproduction.png) |
| P-87 | 23/10/2026 | Maintenance LINUX01 avec contrôle de santé avant / après | [P-87](docs/preuves/P-87-maintenance-linux01-controle-avant-apres.txt), [png](docs/preuves/P-87-rendu-maintenance-avant-apres.png) |
| P-88 | 23/10/2026 | Espace disque : observation ponctuelle et historique Prometheus | [P-88](docs/preuves/P-88-observation-ponctuelle-vs-historique-disque.txt), [png](docs/preuves/P-88-grafana-evolution-stockage-19-23-oct.png) |
| P-89a | 23/10/2026 | Quotas — 1ᵉʳ essai non idempotent (`repquota` sans `-v`) | [P-89a](docs/preuves/P-89a-quotas-1er-essai-non-idempotent.txt) |
| P-89 | 23/10/2026 | Quotas sur `/data` : idempotence, dépassement souple / strict, nettoyage | [P-89](docs/preuves/P-89-quotas-disque-test-data-linux01.txt), [png](docs/preuves/P-89-rendu-test-quotas-alice.png) |
| P-50a | 19/10/2026 | Monitoring — 1er essai : échec de connexion admin Grafana | [P-50a](docs/preuves/P-50a-ops01-grafana-1er-essai-echec-mot-de-passe-ini.txt) |
| P-50 | 19/10/2026 | Playbook Prometheus + Grafana (cibles up, admin OK) | [P-50](docs/preuves/P-50-ops01-prometheus-grafana-installation.txt) |
| P-50b | 19/10/2026 | Playbook monitoring — 2ᵉ passage (changed=0) | [P-50b](docs/preuves/P-50b-ops01-monitoring-2e-passage-idempotence.txt) |
| P-51 | 19/10/2026 | Capture : cibles Prometheus (4/4 up) | [P-51](docs/preuves/P-51-prometheus-targets.png) |
| P-52 | 19/10/2026 | Cibles, règles, métriques réelles, exporters, ports | [P-52](docs/preuves/P-52-prometheus-cibles-metriques-regles.txt) |
| P-53 | 19/10/2026 | Capture : dashboard Grafana, état normal | [P-53](docs/preuves/P-53-grafana-dashboard-infraready.png) |
| P-54 | 19/10/2026 | Démonstration InstanceDown : chronologie + capture Prometheus | [P-54](docs/preuves/P-54-alerte-instancedown-demonstration.txt), [png](docs/preuves/P-54-prometheus-alerte-instancedown.png) |
| P-55 | 19/10/2026 | Capture : dashboard pendant l'alerte (LINUX01 hors ligne) | [P-55](docs/preuves/P-55-grafana-dashboard-alerte-linux01-hors-ligne.png) |
| P-56 | 20/10/2026 | Dashboard Grafana v2 (variable Hôte, Uptime) déployé, idempotence, requêtes vérifiées | [P-56](docs/preuves/P-56-grafana-dashboard-v2-deploiement-idempotence.txt) |
| P-60a | 19/10/2026 | GitHub Actions sur le dépôt de travail initial : 1er run en échec, 2ᵉ vert | [P-60a](docs/preuves/P-60a-github-actions-depot-de-travail-initial.txt) |
| P-60 | 20/10/2026 | GitHub Actions sur `jolanallen/InfraReady` : run vert, jobs, déclencheurs, auteurs | [P-60](docs/preuves/P-60-github-actions-pipeline-vert.txt) |
| P-61 | 20/10/2026 | Validation des PR #2 et #4 : `verif-idempotence.sh` sur `windows_base` et `linux_base` (IDEMPOTENT) | [P-61](docs/preuves/P-61-validation-pr-idempotence-playbooks.txt) |
| P-62 | 20/10/2026 | Tests négatifs (non idempotent → 1, échec → 2, vault absent ou invalide) ; diagnostic du DNS de `windows_adds` | [P-62](docs/preuves/P-62-validation-pr-tests-negatifs.txt) |
| P-63 | 20/10/2026 | Validation de la PR #1 : calcul d'occupation disque de `linux_maintenance` (simulation) | [P-63](docs/preuves/P-63-validation-pr1-maintenance-linux-calcul-disque.txt) |
| P-64 | 23/10/2026 | GitHub Actions sur les PR de la séance 6 : contrôles exécutés sur chaque branche ; PR #8 à #14 fusionnées | [P-64](docs/preuves/P-64-github-actions-pr-seance6.txt), [PR png](docs/preuves/P-64-github-pr-seance6-fusionnees.png), [Actions png](docs/preuves/P-64-github-actions-runs-verts.png) |

---

## 15. Difficultés, limites et bilan

- **Blocages et corrections :** détaillés dans chaque phase (ISO Ubuntu 26.04 remplacée, carte e1000 → e1000e, nftables à la place d'iptables, paramètre `reboot_timeout` non supporté, `win_powershell` sans `path`, PTR du DC manquant, chemin de disque deviné, secret dans une preuve détecté et nettoyé, push GitHub bloqué par le droit `workflow`, lecteur CD vu comme volume plein, boucle Windows Update sur KB5007651, handler nginx non exécuté après un test en échec ; séance 6 : règles d'alerte non déployées, vérification des cibles réussie sans cible, `openipmi` en échec au démarrage, quotas non idempotents, arrêt ACPI ignoré par le DC — voir section 12).
- **Écarts à l'architecture :**
	- **Proxmox VE 9.1 au lieu de VMware Workstation** — à faire valider par le formateur. Avantages : snapshots, ajout de disque à chaud, installations pilotables en ligne de commande, ressources suffisantes.
	- Ressources légèrement supérieures au plan (vCPU) ; disque Windows en IDE (choix initial conservé).
	- Ubuntu 24.04.**5** (dernière révision de la 24.04 LTS).
- **Fonctionnalités inachevées / pistes :** commits des autres membres de l'équipe ; `KB5007651` exclue de l'installation automatique (boucle Windows Update) et à suivre manuellement ; correction de l'arrêt non propre de WIN-DC01 préparée mais non appliquée (en attente de validation, INC-2026-10-23-01) ; pas d'Alertmanager (alertes visibles dans Prometheus et Grafana, sans notification) ; supervision hébergée sur le même hôte que les serveurs supervisés (aveugle pendant un arrêt de l'hôte) ; VM sans démarrage automatique avec l'hôte ; snapshot Proxmox non pris avant l'incident H (sauvegarde fichier jugée suffisante pour un changement d'une ligne, réversible).
- **Bilan de l'équipe :** [À compléter — synthèse commune en 3 à 5 lignes]

> [!todo] Bilans individuels (questions du support, section 7 « Bilan de fin de séance ») — à rédiger par chaque membre
>
> **MIR Mahan**
> 1. Opération que je sais maintenant réaliser et vérifier : [À compléter]
> 2. Commande qui m'a apporté la preuve la plus utile, et pourquoi : [À compléter]
> 3. Difficulté rencontrée et comment je l'ai isolée : [À compléter]
> 4. Risque identifié (stockage, automatisation, sécurité) : [À compléter]
> 5. Un autre membre peut-il reproduire la procédure à partir du dossier ? Que faudrait-il clarifier ? : [À compléter]
>
> **Jolan Allen (chef de projet)**
> 1. Opération que je sais maintenant réaliser et vérifier : [À compléter]
> 2. Commande qui m'a apporté la preuve la plus utile, et pourquoi : [À compléter]
> 3. Difficulté rencontrée et comment je l'ai isolée : [À compléter]
> 4. Risque identifié (stockage, automatisation, sécurité) : [À compléter]
> 5. Un autre membre peut-il reproduire la procédure à partir du dossier ? Que faudrait-il clarifier ? : [À compléter]
>
> **Kenzi Bendjelloul**
> 1. Opération que je sais maintenant réaliser et vérifier : [À compléter]
> 2. Commande qui m'a apporté la preuve la plus utile, et pourquoi : [À compléter]
> 3. Difficulté rencontrée et comment je l'ai isolée : [À compléter]
> 4. Risque identifié (stockage, automatisation, sécurité) : [À compléter]
> 5. Un autre membre peut-il reproduire la procédure à partir du dossier ? Que faudrait-il clarifier ? : [À compléter]


---

## 16. Annexes et journal de changements

### Arborescence GitHub

```text
InfraReady/
├── .github/workflows/validation.yml
├── ansible/
│   ├── ansible.cfg
│   ├── requirements.yml
│   ├── inventory/
│   │   ├── hosts.yml
│   │   └── group_vars/
│   │       ├── all.yml
│   │       ├── linux/vars.yml
│   │       └── windows/{vars.yml, vault.yml (chiffré)}
│   ├── playbooks/{windows_adds.yml, windows_base.yml, windows_maintenance.yml,
│   │              linux_base.yml, linux_maintenance.yml, linux_quotas.yml,
│   │              ops01_monitoring.yml, controle_sante.yml}
│   └── playbooks/templates/{index.html.j2, nginx-infraready.conf.j2}
├── lab/
│   ├── autoinstall-user-data.yml.tpl
│   ├── autounattend.xml.tpl
│   └── proxmox/{vmbr1.interfaces, infraready-nat.nft, provision-vms.sh}
├── monitoring/
│   ├── prometheus/{prometheus.yml, rules/infraready.rules.yml}
│   └── grafana/{dashboards/infraready.json, provisioning/{datasources/prometheus.yml, dashboards/infraready.yml}}
├── scripts/
│   ├── bootstrap-ansible-user.sh
│   ├── ad-objets.ps1
│   ├── verif-domaine.ps1 · verif-dcdiag-ntp.ps1 · verif-dns-depuis-dc.ps1 · journaux-ad.ps1
│   ├── check-nginx.sh · Check-DnsClient.ps1 · verif-idempotence.sh · controle-site-planifie.sh
├── docs/{procedure-maintenance.md, rapport-incident.md}
├── docs/preuves/            (P-01 … P-89)
├── .gitignore · .yamllint · README.md
└── InfraReady - Dossier technique.md
```

### Journal de changements

| Date | Auteur | Modification | Validation | Preuve / rollback |
| --- | --- | --- | --- | --- |
| 19/10/2026 14:42 | MIR Mahan / Jolan Allen | Pont `vmbr1` + NAT/isolation nftables sur l'hôte | `ifreload -a`, ping/isolation OK | P-01, P-02 / `interfaces.bak-infraready` |
| 19/10/2026 14:47 | MIR Mahan / Jolan Allen | Installations automatiques des 3 VM | 3 VM joignables | P-01, P-03 / — |
| 19/10/2026 14:58 | MIR Mahan / Jolan Allen | Snapshot de base | `qm listsnapshot` | `s01_installation_ok` |
| 19/10/2026 15:05 | MIR Mahan / Jolan Allen | AD DS + forêt infraready.test | dcdiag fonctionnel OK | P-10, P-12b / `s02_avant_adds` |
| 19/10/2026 15:14 | MIR Mahan / Jolan Allen | OU, groupes, comptes AD | Membres conformes | P-11 / `s02_avant_adds` |
| 19/10/2026 15:20 | MIR Mahan / Jolan Allen | NTP externe sur le DC | Stratum 2 | P-12b / — |
| 19/10/2026 15:23 | MIR Mahan / Jolan Allen | Comptes Linux, nginx, disque `/data` | Tests de droits OK | P-20 à P-22 / `s02_avant_maj_c` |
| 19/10/2026 15:24 | MIR Mahan / Jolan Allen | `apt upgrade` LINUX01 (20 paquets) | Code retour 0 | P-23 / `s02_avant_maj_c` |
| 19/10/2026 15:28 | Kenzi Bendjelloul | Playbooks Linux et Windows (2 passages) | changed=0 au 2ᵉ passage | P-31 à P-34 / `s03_avant_ansible` |
| 19/10/2026 | MIR Mahan / Jolan Allen | DNS des VM Linux → DC, PTR du DC | A/PTR/SRV résolus | P-04, P-35 / `/root/50-cloud-init.yaml.bak-dns` |
| 19/10/2026 16:30 | MIR Mahan / Jolan Allen | Prometheus, exporters, Grafana sur OPS01 | Cibles UP, dashboard, alerte testée | P-50 à P-55 / `s04_avant_maintenance_e` |
| 19/10/2026 16:48 | MIR Mahan / Jolan Allen | Maintenance Linux (LINUX01, OPS01), `unattended-upgrades` | Post-contrôles OK, reboot non requis | P-40, P-43 / `s04_avant_maintenance_e` |
| 19/10/2026 16:54 | MIR Mahan / Jolan Allen | Windows Update sur WIN-DC01 (5 MAJ, redémarrage 18:04) | `failed=1` (boucle KB5007651) puis passage complet OK | P-42 à P-42c / `s04_avant_maj_windows` |
| 19/10/2026 19:21 | MIR Mahan / Jolan Allen | `reject_list: [KB5007651]` + gabarit du rapport Windows | `failed=0`, rapport lisible | P-42c / — |
| 19/10/2026 19:27 | MIR Mahan / Jolan Allen | Incident contrôlé : `root` nginx modifié sur LINUX01 | 404 constaté depuis OPS01 | P-70 / `/root/infraready.nginx.bak-incident-h` |
| 19/10/2026 19:30 | MIR Mahan / Jolan Allen | `flush_handlers` avant les vérifications dans `linux_base.yml` ; rejeu sur LINUX01 | HTTP 200, `changed=0` au 2ᵉ passage | P-72, P-73 / — |
| 19/10/2026 19:37 | MIR Mahan / Jolan Allen | Snapshot final des 3 VM | `qm listsnapshot` | P-05 / `s05_phases_a_h_terminees` |
| 20/10/2026 12:50 | MIR Mahan / Jolan Allen / Kenzi Bendjelloul | Snapshot des 3 VM avant la séance 4 | `qm snapshot` | `s07_avant_seance4` |
| 20/10/2026 12:51 | MIR Mahan / Jolan Allen / Kenzi Bendjelloul | `site_message` + contrôle HTTP et contenu dans `linux_base.yml` (2 passages) | `changed=1` puis `changed=0` | P-38, P-38b / `s07_avant_seance4` |
| 20/10/2026 12:52 | MIR Mahan / Jolan Allen / Kenzi Bendjelloul | Scripts `check-nginx.sh` et `Check-DnsClient.ps1` (3 situations chacun) | Codes 0 / 1 / 2 | P-25, P-14 / — |
| 20/10/2026 12:57 | MIR Mahan / Jolan Allen / Kenzi Bendjelloul | `check_mode: false` sur 4 tâches en lecture seule de `linux_base.yml` | Simulation `changed=0 failed=0` | P-39a, P-39 / — |
| 20/10/2026 12:58 | MIR Mahan / Jolan Allen / Kenzi Bendjelloul | 6 scénarios de panne contrôlée (7.4), un à la fois, jusqu'à 13:08 | Retour à l'état initial, `changed=0` | P-74 à P-79 / `.etat-initial`, `s07_avant_seance4` |
| 20/10/2026 14:15 | MIR Mahan / Jolan Allen / Kenzi Bendjelloul | Snapshot des 3 VM avant validation des PR #1 à #5 | `qm snapshot` | `s08_avant_validation_pr3_5` |
| 20/10/2026 14:16 | MIR Mahan / Jolan Allen / Kenzi Bendjelloul | Dashboard Grafana v2 déployé (`ops01_monitoring.yml`, 2 passages) | IDEMPOTENT, version 2 chargée | P-56 / `s08_avant_validation_pr3_5` |
| 20/10/2026 14:18 | MIR Mahan / Jolan Allen / Kenzi Bendjelloul | `windows_base.yml` et `linux_base.yml` via `verif-idempotence.sh` | IDEMPOTENT ×2 | P-61 / — |
| 20/10/2026 14:21 | MIR Mahan / Jolan Allen / Kenzi Bendjelloul | Tests négatifs ; exécution réelle non voulue de `windows_adds.yml` (DNS du DC rejoué, valeur inchangée) | Résolution DNS OK | P-62 / `s08_avant_validation_pr3_5` |
| 20/10/2026 14:24 | MIR Mahan / Jolan Allen / Kenzi Bendjelloul | `linux_maintenance.yml` en simulation (PR #1) | Calcul identique à P-40 | P-63 / — |
| 20/10/2026 14:26 | MIR Mahan / Jolan Allen / Kenzi Bendjelloul | Correctif DNS de `windows_adds.yml` testé (PR #6), puis copie d'OPS01 remise à la version de `main` | IDEMPOTENT | P-15 (PR #6) / `s08_avant_validation_pr3_5` |
| 23/10/2026 09:05 | MIR Mahan / Jolan Allen / Kenzi Bendjelloul | Snapshot des 3 VM avant la séance 6 (API Proxmox) | Tâches `qmsnapshot` OK | `s09_avant_seance6` |
| 23/10/2026 09:06 | MIR Mahan / Jolan Allen / Kenzi Bendjelloul | État initial des 3 serveurs (lecture seule) | 5 écarts relevés | P-80 / — |
| 23/10/2026 09:17 | MIR Mahan / Jolan Allen / Kenzi Bendjelloul | Copie du projet sur OPS01 resynchronisée ; `ops01_monitoring.yml` rejoué (5 règles) puis corrigé (attente du 1ᵉʳ scrape) | IDEMPOTENT | P-81a, P-81b / `s09_avant_seance6` |
| 23/10/2026 09:22 | MIR Mahan / Jolan Allen / Kenzi Bendjelloul | Timer `infraready-controle-site` (`linux_base.yml`) et 2 règles d'alerte (`ops01_monitoring.yml`) | `changed=0` au 2ᵉ passage, 7 règles | P-83 / `s09_avant_seance6` |
| 23/10/2026 09:26 | MIR Mahan / Jolan Allen / Kenzi Bendjelloul | Test d'alerte : nginx arrêté sur LINUX01 puis redémarré (09:30) | firing à +3 min 08 s, résolue 27 s après | P-84 / — |
| 23/10/2026 09:35 | MIR Mahan / Jolan Allen / Kenzi Bendjelloul | `openipmi` désactivé (`linux_base.yml`, `ops01_monitoring.yml`) | Contrôle de santé sans ECHEC | P-80b / `s09_avant_seance6` |
| 23/10/2026 09:38 | MIR Mahan / Jolan Allen / Kenzi Bendjelloul | Reproduction : arrêt ACPI de WIN-DC01 demandé sans arrêt forcé | Ignoré pendant 90 s, VM restée allumée | P-86 / — |
| 23/10/2026 09:43 | MIR Mahan / Jolan Allen / Kenzi Bendjelloul | Dashboard Grafana v3 (`ops01_monitoring.yml`) | IDEMPOTENT, version 3 chargée | P-85 / `s09_avant_seance6` |
| 23/10/2026 09:45 | MIR Mahan / Jolan Allen / Kenzi Bendjelloul | Maintenance LINUX01 (3 paquets) entre deux contrôles de santé | Aucun écart de statut | P-87 / `s09_avant_seance6` |
| 23/10/2026 09:48 | MIR Mahan / Jolan Allen / Kenzi Bendjelloul | `/data` remonté avec `usrquota,grpquota` ; quotas alice / bruno (`linux_quotas.yml`) | IDEMPOTENT après correction ; dépassement testé | P-89a, P-89 / `s09_avant_seance6` |
| 23/10/2026 09:54 | MIR Mahan / Jolan Allen / Kenzi Bendjelloul | Test d'alerte : timer du contrôle planifié arrêté (09:54) puis redémarré (10:04) | `ControlePlanifieEnRetard` firing à 10:04:01, résolue à 10:04:17 | P-84 / — |

**Annexes** : sorties complètes dans `docs/preuves/`, modèles d'installation dans `lab/`, configurations dans `ansible/` et `monitoring/`.

---

## 17. Checklist de remise

- [ ] Dépôt GitHub prêt, avec contributions de l'équipe
- [x] Rapport final en PDF à la racine du dépôt (`InfraReady-Rapport-final.pdf`, sources LaTeX dans `rapport/`) + lien du dépôt
- [x] Captures et sorties de commandes classées (`docs/preuves/`, numérotation par phase)
- [x] Rapport d'incident distinct rédigé (`docs/rapport-incident.md`)
- [ ] PowerPoint final préparé selon modalités du formateur
- [x] TP de la séance 4 réalisé et documenté (section 11, preuves P-14, P-25, P-26, P-38 à P-39, P-74 à P-79)
- [ ] Bilans individuels et revue croisée de la séance 4 (chaque membre)
- [x] TP de la séance 6 réalisé et documenté (section 12, preuves P-80 à P-89, P-64)
- [ ] Correction de l'incident INC-2026-10-23-01 (arrêt non propre de WIN-DC01) : validation de l'équipe puis application
- [ ] Jeton API Proxmox utilisé pendant la séance 6 révoqué
- [x] Aucun secret présent dans les livrables (vérifié à chaque commit)
- [x] Tous les écarts et limites sont mentionnés (section 15)

**Date et plateforme de remise :** [À compléter]
