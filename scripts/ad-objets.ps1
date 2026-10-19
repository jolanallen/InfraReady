# Phase B — objets de l'annuaire infraready.test : OU, groupes de sécurité, comptes de test.
# Rejouable : ne crée que ce qui manque. Le mot de passe initial est passé en paramètre (jamais écrit ici).
param([Parameter(Mandatory)][string]$InitialPassword)
$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory

$base = (Get-ADDomain).DistinguishedName
$root = "OU=InfraReady,$base"
$secure = ConvertTo-SecureString $InitialPassword -AsPlainText -Force

# OU
if (-not (Get-ADOrganizationalUnit -Filter "Name -eq 'InfraReady'" -SearchBase $base -SearchScope OneLevel)) {
    New-ADOrganizationalUnit -Name InfraReady -Path $base -ProtectedFromAccidentalDeletion $true
}
foreach ($ou in 'Utilisateurs', 'Groupes') {
    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$ou'" -SearchBase $root -SearchScope OneLevel)) {
        New-ADOrganizationalUnit -Name $ou -Path $root -ProtectedFromAccidentalDeletion $true
    }
}

# Groupes de sécurité globaux
$groups = @(
    @{ Name = 'GG_Support_IT';   Description = 'Support informatique - lecture sur le partage Compta' }
    @{ Name = 'GG_Comptabilite'; Description = 'Comptabilité - modification sur le partage Compta' }
)
foreach ($g in $groups) {
    if (-not (Get-ADGroup -Filter "Name -eq '$($g.Name)'")) {
        New-ADGroup -Name $g.Name -Description $g.Description -GroupScope Global -GroupCategory Security -Path "OU=Groupes,$root"
    }
}

# Comptes de test (fictifs) et appartenance aux groupes
$users = @(
    @{ Sam = 'j.martin';  Given = 'Julie'; Surname = 'Martin';  Group = 'GG_Support_IT' }
    @{ Sam = 's.bernard'; Given = 'Samir'; Surname = 'Bernard'; Group = 'GG_Support_IT' }
    @{ Sam = 'l.petit';   Given = 'Lea';   Surname = 'Petit';   Group = 'GG_Comptabilite' }
    @{ Sam = 't.moreau';  Given = 'Theo';  Surname = 'Moreau';  Group = 'GG_Comptabilite' }
)
$domain = (Get-ADDomain).DNSRoot
foreach ($u in $users) {
    if (-not (Get-ADUser -Filter "SamAccountName -eq '$($u.Sam)'")) {
        New-ADUser -Name $u.Sam -SamAccountName $u.Sam -UserPrincipalName "$($u.Sam)@$domain" `
            -GivenName $u.Given -Surname $u.Surname -DisplayName "$($u.Given) $($u.Surname)" `
            -Path "OU=Utilisateurs,$root" -AccountPassword $secure -Enabled $true -ChangePasswordAtLogon $true
    }
    Add-ADGroupMember -Identity $u.Group -Members $u.Sam
}

# Restitution
Get-ADGroup -Filter * -SearchBase "OU=Groupes,$root" | ForEach-Object {
    [pscustomobject]@{
        Groupe  = $_.Name
        Membres = (Get-ADGroupMember $_ | Select-Object -ExpandProperty SamAccountName | Sort-Object) -join ', '
    }
}
