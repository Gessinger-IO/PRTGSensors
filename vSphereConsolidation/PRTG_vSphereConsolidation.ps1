[CmdletBinding()] param(
    [Parameter(Mandatory=$true)]
    [string]$server = $null,
    [Parameter(Mandatory=$true)]
    [string]$user = $null,
    [Parameter(Mandatory=$true)]
    [string]$password = $null,
    [Parameter(Mandatory=$false)]
    [switch]$allLinked = $false
)

Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false -Confirm:$false >$null 2>&1
$command = "Connect-VIserver $server -user $user -Password $password $(&{If($allLinked) {'-AllLinked'}}) -Force"
Invoke-Expression -Command $command >$null 2>&1
$vms = Get-VM | Where-Object { $_.ExtensionData.Runtime.consolidationNeeded } | Select-Object Name

$count = $vms | Measure-Object | Select-Object -expand Count

Disconnect-ViServer -Confirm:$false

if($count -gt 0) {
	$message = "VMs require consolidation: $([string[]]$vms -join ', ')"
} else {
	$message = "OK"
}
Write-Host "<prtg>
    <text>$($message)</text>
    <result>
        <channel>ConsolidationCount</channel>
        <value>$($count)</value>
        <unit>Count</unit>
        <limitmode>1</limitmode>
        <limitmaxwarning>0.5</limitmaxwarning>
    </result>
</prtg>"