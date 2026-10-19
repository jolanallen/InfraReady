# Diagnostic : enregistrements de la zone inverse (statique = Timestamp vide, dynamique = horodaté)
Get-DnsServerResourceRecord -ZoneName 50.168.192.in-addr.arpa -RRType Ptr |
    Select-Object HostName, @{n='Cible';e={$_.RecordData.PtrDomainName}}, TimeToLive, Timestamp |
    Format-Table -AutoSize | Out-String -Width 150
"Enregistrement dynamique DNS du DC activé : " + (Get-DnsClient -InterfaceAlias Ethernet).RegisterThisConnectionsAddress
