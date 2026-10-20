# Séance 4 — contrôle en lecture seule de l'état d'un service Windows (défaut : Dnscache, le client DNS).
# Usage : .\Check-DnsClient.ps1 [-Name <service>]
# Codes de sortie :
#   0 = service présent et démarré
#   1 = service présent mais pas démarré
#   2 = service introuvable sur cet hôte
# Limite : vérifie l'état local du service, pas la résolution d'un nom (voir verif-dns-depuis-dc.ps1).
param([string]$Name = "Dnscache")

$service = Get-Service -Name $Name -ErrorAction SilentlyContinue
if ($null -eq $service) {
    Write-Output "ERREUR : service $Name introuvable sur $env:COMPUTERNAME"
    exit 2
}
if ($service.Status -eq "Running") {
    Write-Output "OK : le service $Name ($($service.DisplayName)) est actif"
    exit 0
}
Write-Output "ECHEC : le service $Name ($($service.DisplayName)) est $($service.Status)"
exit 1
