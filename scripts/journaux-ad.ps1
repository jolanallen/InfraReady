# Phase B — événements Windows pertinents (lecture seule)
$since = (Get-Date).AddHours(-3)
function Show($log, $ids, $label) {
    "== $label ($log, IDs $($ids -join ','))"
    Get-WinEvent -FilterHashtable @{ LogName = $log; Id = $ids; StartTime = $since } -ErrorAction SilentlyContinue |
        Select-Object -First 8 TimeCreated, Id, @{n='Message';e={ ($_.Message -split "`r?`n")[0] }} |
        Format-Table -AutoSize -Wrap | Out-String -Width 170
}
Show 'Security' 4720 'Création de comptes utilisateurs'
Show 'Security' 4728 'Ajout de membres à un groupe global de sécurité'
Show 'Security' 4727 'Création de groupes globaux de sécurité'
Show 'Directory Service' 1000,1394,2887 'Démarrage AD DS / événements annuaire'
Show 'DNS Server' 2,4 'Démarrage du service DNS / zones chargées'
Show 'System' 1074 'Redémarrages demandés (promotion DC)'
