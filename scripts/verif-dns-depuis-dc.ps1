# Phase A — tests IP et DNS depuis WIN-DC01 (lecture seule)
"== Adressage"
Get-NetIPConfiguration | Select-Object InterfaceAlias, @{n='IPv4';e={$_.IPv4Address.IPAddress}}, @{n='Passerelle';e={$_.IPv4DefaultGateway.NextHop}}, @{n='DNS';e={$_.DNSServer.ServerAddresses -join ','}} | Format-Table -AutoSize | Out-String
"== Connectivité et résolution"
foreach ($n in 'linux01.infraready.test', 'ops01.infraready.test', 'win-dc01.infraready.test', 'www.ubuntu.com') {
    $ip = (Resolve-DnsName $n -Type A -ErrorAction SilentlyContinue | Where-Object Type -eq 'A' | Select-Object -First 1).IPAddress
    $ping = if ($ip) { Test-Connection $ip -Count 1 -Quiet } else { $false }
    "{0,-28} {1,-16} ping={2}" -f $n, $ip, $ping
}
"== Inverse : " + ((Resolve-DnsName 192.168.50.20 -Type PTR).NameHost)
