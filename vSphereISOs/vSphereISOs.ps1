[CmdletBinding()] param(
    [Parameter()] $server = $null,
    [Parameter()] $user = $null,
    [Parameter()] $password = $null
)

Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false -Confirm:$false >$null 2>&1
Connect-VIserver $server -user $user -Password $password -Force
$data = @()
$tags = Get-Tag -Name "allow ISO" -Category "Monitoring"
$isovms = Get-VM -Tag $tags
$vms = Get-VM | Get-CDDrive | select @{N="VM";E="Parent"},IsoPath | where {$_.IsoPath -ne $null -and $isovms.Name -notcontains $_.VM }
foreach ($vm in $vms)
{
	$event = Get-VIEvent -Entity $vm.VM -Types Info | Where-Object { $_.FullFormattedMessage -imatch 'ISO' } | Select -First 1

	if($event -ne $null) {
		if($event.CreatedTime -lt (Get-Date).AddHours(-96)) {
			$data += $vm
		}
	} else {
		$data += $vm
	}
}

$count = $data | measure | Select-Object -expand Count

Disconnect-ViServer -Confirm:$false

$vmNames = $data | Select VM
$message = "OK"
if($count -gt 0) {
	$messsage = [string[]]$vmNames -join ', '
}
Write-Host "<prtg>
	<text>$($messsage)</text>
    <result>
        <channel>ISOs older than 96 hours</channel>
        <value>$($count)</value>
        <unit>Count</unit>
		<limitmode>1</limitmode>
        <limitmaxwarning>0.5</limitmaxwarning>
    </result>
</prtg>"