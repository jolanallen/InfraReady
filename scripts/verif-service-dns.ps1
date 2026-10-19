# Phase H — état du service DNS et journaux associés sur WIN-DC01 (lecture seule)
"== $(hostname) — $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss K')"
"== Service DNS"
Get-Service DNS | Select-Object Name, Status, StartType | Format-Table -AutoSize | Out-String
"== Port 53 en écoute ?"
$l = Get-NetTCPConnection -LocalPort 53 -State Listen -ErrorAction SilentlyContinue
if ($l) { "   oui : " + (($l | Select-Object -ExpandProperty LocalAddress -Unique) -join ', ') } else { "   NON : aucun processus n'écoute sur 53/tcp" }
"== Événements du service DNS (dernière heure) — 2 = démarré, 3 = arrêté, 4 = zones chargées"
Get-WinEvent -FilterHashtable @{ LogName = 'DNS Server'; StartTime = (Get-Date).AddHours(-1) } -ErrorAction SilentlyContinue |
    Select-Object -First 8 TimeCreated, Id, @{n='Message';e={ ($_.Message -split "`r?`n")[0] }} |
    Format-Table -AutoSize -Wrap | Out-String -Width 150
"== Événements System : arrêts/démarrages de service (7036) mentionnant DNS"
Get-WinEvent -FilterHashtable @{ LogName = 'System'; Id = 7036; StartTime = (Get-Date).AddHours(-1) } -ErrorAction SilentlyContinue |
    Where-Object { $_.Message -like '*DNS Server*' } | Select-Object -First 6 TimeCreated, @{n='Message';e={ ($_.Message -split "`r?`n")[0] }} |
    Format-Table -AutoSize -Wrap | Out-String -Width 150
"== Test de résolution locale"
try { "   " + ((Resolve-DnsName linux01.infraready.test -Server 127.0.0.1 -ErrorAction Stop | Where-Object Type -eq 'A').IPAddress) }
catch { "   ECHEC : " + $_.Exception.Message }
