[CmdletBinding()] param(
    [Parameter(Mandatory=$true)]
    [string]$server = $null,
    [Parameter(Mandatory=$true)]
    [string]$user = $null,
    [Parameter(Mandatory=$true)]
    [string]$password = $null,
    [Parameter(ParameterSetName="setAge", Mandatory=$true)]
    [AllowNull()]
    [Nullable[System.Int32]]$maxAge,
    [Parameter(ParameterSetName="setSize", Mandatory=$true)]
    [AllowNull()]
    [Nullable[System.Int32]]$maxMb,
    [Parameter(Mandatory=$false)]
    [switch]$allLinked = $false
)

Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false -Confirm:$false >$null 2>&1
$command = "Connect-VIserver $server -user $user -Password $password $(&{If($allLinked) {'-AllLinked'}}) -Force"
Invoke-Expression -Command $command >$null 2>&1
$data = @()
$tags = Get-Tag -Name "allow Snapshots" -Category "snapshots"
$snapvms = Get-VM -Tag $tags
$vms = Get-VM | Where-Object { $snapvms -notcontains $_ }
$message = ""
if($null -ne $maxAge) {
    $message = "Snapshots older than $($maxAge) hours"
} elseif($null -ne $maxMb) {
    $message = "Snapshots bigger than $($maxMb) MB"
}
foreach ($snap in $vms | Get-Snapshot)
{
    $snapshot = New-Object PSCustomObject
    $snapevent = Get-VIEvent -Entity $snap.VM -Types Info -Finish $snap.Created -MaxSamples 1 | Where-Object { $_.FullFormattedMessage -imatch 'Task: Create virtual machine snapshot' }
    $snapshot | Add-Member -type NoteProperty -name VM $snap.VM    
    $snapshot | Add-Member -type NoteProperty -name Name $snap.Name
    $snapshot | Add-Member -type NoteProperty -name SizeMB $snap.sizemb
    $snapshot | Add-Member -type NoteProperty -name created $snap.created
    if ($null -ne $snapevent) {
        $snapshot | Add-Member -type NoteProperty -name CreatedBy $snapevent.UserName
    }
    else {
        $snapshot | Add-Member -type NoteProperty -name CreatedBy "UnKnown"
    }
    if($null -ne $maxAge) {
        if($snapshot.created -lt (Get-Date).AddHours(($maxDays * -1))) {
            $data += $snapshot
        }
    } elseif($null -ne $maxMb) {
        if($snapshot.SizeMB -gt $maxMb) {
            $data += $snapshot
        }
    } else {
        throw "Missing parameter maxAge or maxMb"
    }
}

$count = $data | Measure-Object | Select-Object -expand Count

Disconnect-ViServer -Confirm:$false

Write-Host "<prtg>
    <result>
        <channel>$($message)</channel>
        <value>$($count)</value>
        <unit>Count</unit>
        <limitmode>1</limitmode>
        <limitmaxwarning>0.5</limitmaxwarning>
        <limitwarningmsg>$($message): $([string[]]$data -join ', ')</limitwarningmsg>
    </result>
</prtg>"