# Test d'idempotence : force le DC à réenregistrer ses propres enregistrements DNS (A + PTR)
Register-DnsClient
Start-Sleep -Seconds 10
"Réenregistrement DNS du DC forcé à " + (Get-Date -Format 'HH:mm:ss')
