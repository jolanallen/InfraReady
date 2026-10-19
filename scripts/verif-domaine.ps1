# Phase B — vérifications de l'état du domaine et du DNS (lecture seule)
$ErrorActionPreference = 'Continue'
"== Domaine / forêt"
Get-ADDomain | Select-Object DNSRoot, NetBIOSName, DomainMode, PDCEmulator, DistinguishedName | Format-List | Out-String -Width 160
Get-ADForest | Select-Object Name, ForestMode, SchemaMaster, GlobalCatalogs | Format-List | Out-String -Width 160
"== Comptes de test (OU=Utilisateurs,OU=InfraReady)"
Get-ADUser -Filter * -SearchBase "OU=Utilisateurs,OU=InfraReady,$((Get-ADDomain).DistinguishedName)" -Properties MemberOf, Enabled |
    Select-Object SamAccountName, Enabled, @{n='Groupes';e={($_.MemberOf | ForEach-Object { ($_ -split ',')[0] -replace 'CN=' }) -join ','}} |
    Format-Table -AutoSize | Out-String -Width 160
"== Résolution DNS"
foreach ($n in 'infraready.test', 'win-dc01.infraready.test', '_ldap._tcp.dc._msdcs.infraready.test', 'www.ubuntu.com') {
    $t = if ($n -like '_*') { 'SRV' } else { 'A' }
    try {
        $r = Resolve-DnsName $n -Type $t -Server 127.0.0.1 -ErrorAction Stop | Where-Object { $_.Type -eq $t } | Select-Object -First 1
        $v = if ($t -eq 'SRV') { "$($r.NameTarget):$($r.Port)" } else { $r.IPAddress }
        "OK    {0,-40} {1,-4} {2}" -f $n, $t, $v
    } catch { "ECHEC {0,-40} {1}" -f $n, $_.Exception.Message }
}
"== Redirecteurs DNS : " + ((Get-DnsServerForwarder).IPAddress.IPAddressToString -join ', ')
"== Zones DNS"
Get-DnsServerZone | Where-Object { -not $_.IsAutoCreated } | Select-Object ZoneName, ZoneType, IsDsIntegrated, DynamicUpdate | Format-Table -AutoSize | Out-String -Width 160
"== dcdiag /q (aucune ligne = aucun test en échec)"
dcdiag /q
"== Services du DC"
Get-Service NTDS, DNS, Netlogon, kdc, ADWS | Select-Object Name, Status, StartType | Format-Table -AutoSize | Out-String
