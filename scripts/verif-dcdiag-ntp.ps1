# Phase B — tests fonctionnels du DC et source de temps (lecture seule)
"== Heure du DC : " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss K') + " (" + (Get-TimeZone).Id + ")"
"== Source NTP : " + (w32tm /query /source)
(w32tm /query /status | Select-String 'Stratum|Last Successful|Source') -join "`n"
"== dcdiag (tests fonctionnels)"
(dcdiag /test:connectivity /test:advertising /test:sysvolcheck /test:machineaccount /test:netlogons /test:ridmanager /test:services /test:dns /test:fsmocheck |
    Select-String 'passed test|failed test' | ForEach-Object { $_.Line.Trim() }) -join "`n"
