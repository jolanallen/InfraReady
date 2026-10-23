---
title: InfraReady — Séance 6, maintenance opérationnelle et supervision
type: synthese
date: 2026-10-23
tags:
  - infraready
  - seance-6
  - supervision
---

# InfraReady — Séance 6 : maintenance opérationnelle et supervision

> [!info] Note de synthèse visuelle
> Résumé illustré du TP de la séance 6 (support pédagogique n° 6), réalisé le **23/10/2026** sur le laboratoire Proxmox. Le détail complet, avec les tableaux, les difficultés et les limites, se trouve dans la **section 12 du dossier technique** : [[InfraReady - Dossier technique#12. Séance 6 — Maintenance opérationnelle et supervision]]. Chaque image renvoie à une preuve `P-xx` de `docs/preuves/`.

| Champ | Valeur |
| --- | --- |
| **Équipe** | MIR Mahan / Jolan Allen (chef de projet) / Kenzi Bendjelloul |
| **Retour arrière** | Snapshot Proxmox `s09_avant_seance6` des 3 VM, pris le 23/10/2026 à 09:05 |
| **Livraison** | PR #8 à #14 sur `jolanallen/InfraReady`, CI verte, fusionnées le 23/10/2026 |
| **Preuves** | P-80 à P-89, P-64 (texte horodaté + captures) |

## La journée en un coup d'œil

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

## Bilan par use case

| Use case | Ce qui a été fait | Statut | Preuves |
| --- | --- | --- | --- |
| UC-01 État de santé | Fiche d'état initial datée des 3 serveurs, avant toute modification ; 5 écarts relevés | ✅ | P-80, P-80b, P-80c |
| UC-02 Métriques Linux / Windows | 4/4 cibles `up`, métriques lues dans Prometheus ; écart de règles et vérification du playbook corrigés | ✅ | P-81a, P-81b, P-81 |
| UC-03 Tableau de bord | Dashboard Grafana v3 : unités, descriptions, « NON COLLECTÉ » au lieu d'un faux 0, 3 nouveaux panneaux | ✅ | P-85 |
| UC-04 Alerte exploitable | `SiteWebIndisponible` et `ControlePlanifieEnRetard`, déclenchées puis résolues lors de tests contrôlés | ✅ | P-84 |
| UC-05 Incident | Arrêt brutal de WIN-DC01 à chaque arrêt de l'hôte : cause trouvée et reproduite | ⚠️ correction en attente de validation | P-86 |
| UC-06 Livrables | Code, CI, README et dossier à jour ; validé / partiel / bloqué listé | ✅ | P-64 |
| UC-C1 Maintenance avant / après | Maintenance de LINUX01 entre deux contrôles de santé : aucun écart | ✅ | P-87 |
| UC-C2 Contrôle de santé Ansible | `controle_sante.yml`, lecture seule, OK / ATTENTION / ECHEC / INACCESSIBLE | ✅ | P-82 |
| UC-C3 Ponctuel / historique | Disque : mesure du jour comparée à 4 jours d'historique | ✅ | P-88 |
| UC-C4 Tâche planifiée | Timer systemd qui contrôle le site chaque minute, avec traces dans le journal et dans Prometheus | ✅ | P-83 |
| UC-A3 Défi : quotas | alice bloquée à 250 Mio sur le disque de test `/data` | ✅ | P-89 |

## 1. Démarrage et état initial

![[P-80c-rendu-proxmox-snapshots-s09.png|760]]

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

![[P-82-rendu-tableau-controle-sante.png|760]]

> [!note] Rendus de sorties
> Les images dont le nom contient `rendu` mettent en forme une **sortie de commande réelle**, dont le texte intégral est dans la preuve `.txt` indiquée en haut de l'image. Les autres images sont des captures d'écran de Prometheus, Grafana ou GitHub.

## 2. Supervision : collecte et tableau de bord

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

![[P-81-prometheus-cibles-up.png|700]]

![[P-85-grafana-dashboard-v3-exploitation.png|760]]

## 3. Tâche planifiée et alertes testées

![[P-83-rendu-timer-journal-metriques.png|760]]

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

**Test 1 — nginx arrêté sur LINUX01 (09:26 → 09:30)** : le contrôle passe en ÉCHEC, `SiteWebIndisponible` déclenche à +3 min 08, alors qu'`InstanceDown` reste muette puisque le serveur est toujours en ligne.

![[P-84-grafana-dashboard-site-en-echec.png|760]]

![[P-84-prometheus-historique-controle-succes.png|700]]

**Test 2 — timer arrêté (09:54 → 10:04)** : plus aucun contrôle, `ControlePlanifieEnRetard` déclenche après 10 min sans résultat, puis se résout 11 s après le redémarrage du timer.

![[P-84-grafana-dashboard-controle-en-retard.png|760]]

## 4. Incident INC-2026-10-23-01 : arrêt brutal du contrôleur de domaine

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

![[P-80-rendu-win-dc01-evenements-arret.png|760]]

![[P-86-rendu-proxmox-arrets-vm100-reproduction.png|760]]

> [!warning] Correction préparée, pas encore appliquée
> Cause : `ShutdownWithoutLogon = 0`, la valeur par défaut de Windows Server, fait ignorer la demande d'arrêt de Proxmox ; la VM est tuée au bout de 180 s. Correction proposée : passer la valeur à 1 via `windows_base.yml`. Elle modifie le DC partagé et attend la validation de l'équipe. Rapport complet : [[rapport-incident]].

## 5. Maintenance, tendance et quotas

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

![[P-87-rendu-maintenance-avant-apres.png|760]]

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

![[P-88-grafana-evolution-stockage-19-23-oct.png|760]]

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

![[P-89-rendu-test-quotas-alice.png|760]]

## 6. Livraison : PR et intégration continue

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

![[P-64-github-pr-seance6-fusionnees.png|700]]

![[P-64-github-actions-runs-verts.png|700]]

## Reste à faire

- [ ] Valider puis appliquer la correction de l'arrêt du DC (UC-05) et rejouer le test d'arrêt.
- [ ] Révoquer le jeton API Proxmox utilisé pendant la séance.
- [ ] Décider du démarrage automatique des VM avec l'hôte (`onboot`).
