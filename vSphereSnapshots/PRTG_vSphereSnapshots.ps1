[CmdletBinding()] param(
    [Parameter()] $server = $null,
    [Parameter()] $user = $null,
    [Parameter()] $password = $null
)


Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false -Confirm:$false >$null 2>&1
Connect-VIserver $server -user $user -Password $password -Force
$data = @()
$tags = Get-Tag -Name "allow Snapshots" -Category "snapshots"
$snapvms = Get-VM -Tag $tags
$vms = Get-VM | Where { $snapvms -notcontains $_ }
foreach ($snap in $vms | Get-Snapshot)
{
	$snapshot = New-Object PSCustomObject
	$snapevent = Get-VIEvent -Entity $snap.VM -Types Info -Finish $snap.Created -MaxSamples 1 | Where-Object { $_.FullFormattedMessage -imatch 'Task: Create virtual machine snapshot' }
	$snapshot | Add-Member -type NoteProperty -name VM $snap.VM	
	$snapshot | Add-Member -type NoteProperty -name Name $snap.Name
	$snapshot | Add-Member -type NoteProperty -name SizeMB $snap.sizemb
	$snapshot | Add-Member -type NoteProperty -name created $snap.created
	if ($snapevent -ne $null) {
		$snapshot | Add-Member -type NoteProperty -name CreatedBy $snapevent.UserName
	}
	else {
		$snapshot | Add-Member -type NoteProperty -name CreatedBy "UnKnown"
	}
	if($snapshot.created -lt (Get-Date).AddHours(-72)) {
		$data += $snapshot
	}
}

$count = $data | measure | Select-Object -expand Count

Disconnect-ViServer -Confirm:$false

Write-Host "<prtg>
    <result>
        <channel>Snapshots older than 72 hours</channel>
        <value>$($count)</value>
        <unit>Count</unit>
        <limitmode>1</limitmode>
        <limitmaxwarning>0.5</limitmaxwarning>
        <limitwarningmsg>Snapshots older than 72 hours: $([string[]]$data -join ', ')</limitwarningmsg>
    </result>
</prtg>"