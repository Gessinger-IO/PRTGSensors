Param(
	[Parameter(Mandatory=$True)]
	[string]$server,
	[Parameter(Mandatory=$true)]
    [string]$user = $null,
    [Parameter(Mandatory=$true)]
    [string]$password = $null
)

Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false -Confirm:$false >$null 2>&1
$viServer = Connect-VIserver $server -user $user -Password $password -Force

# VM-Gruppen definieren
$vmGroups = @{
    'DCs' = @('VSRVDC001', 'VSRVDC002')
    'File' = @('VSRVFILE01', 'VSRVFILE02')
    'LBs' = @('vlb001', 'vlb002')
}

# Funktion zur Überprüfung, ob VMs auf verschiedenen Hosts laufen
function AreVMsOnDifferentHosts($vmNames) {
    $hosts = $vmNames | ForEach-Object { (Get-VM $_).VMHost.Name }
    $uniqueHosts = $hosts | Select-Object -Unique
    return $uniqueHosts.Count -eq $hosts.Count
}

Write-Host "<prtg>"
foreach ($group in $vmGroups.Keys) {
	$vmNames = $vmGroups[$group]
    $areOnDifferentHosts = AreVMsOnDifferentHosts $vmNames
	Write-Host "<result>
        <channel>$($group)</channel>
        <value>$([int]$areOnDifferentHosts)</value>
        <unit>Custom</unit>
    </result>"
}
Write-Host "</prtg>"

# Verbindung zum vCenter Server trennen
Disconnect-VIServer -Server * -Confirm:$false