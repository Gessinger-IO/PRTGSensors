Param(
    [Parameter(Mandatory=$True)]
    [string]$name,
	[Parameter(Mandatory=$True)]
	[string]$server

)
function Get-vSphereMonitoringData
{
    param (
		[Parameter(Mandatory, ValueFromPipeline)] [Object]$vmhost
    )

    $cluster = $false
    if($vmhost.GetType().FullName -eq "VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl")
    {
        $esx = $vmhost
    } elseif($vmhost.GetType().FullName -eq "VMware.VimAutomation.ViCore.Impl.V1.Inventory.ClusterImpl")
    {
        $esx = Get-VMHost -Location $vmhost
        $cluster = $true
    }
    $vm = Get-VM -Location $vmhost | Where-Object { $_.PowerState -eq "PoweredOn" }
    $cpuTot = $(if($cluster -eq $true -and $vmhost.HAEnabled -eq $true) {($esx | Measure-Object -Property CpuTotalMhz -Sum).Sum - (($esx | Measure-Object -Property CpuTotalMhz -Sum).Sum / $vmhost.ExtensionData.Host.Count)} Else {($esx | Measure-Object -Property CpuTotalMhz -Sum).Sum})
    $cpuUse = ($esx | Measure-Object -Property CpuUsageMhz -Sum).Sum
    $memTot = $(if($cluster -eq $true -and $vmhost.HAEnabled -eq $true) {($esx | Measure-Object -Property MemoryTotalGB -Sum).Sum - (($esx | Measure-Object -Property MemoryTotalGB -Sum).Sum / $vmhost.ExtensionData.Host.Count)} Else {($esx | Measure-Object -Property MemoryTotalGB -Sum).Sum})
    $memUse = ($esx | Measure-Object -Property MemoryUsageGB -Sum).Sum
    [cultureinfo]::currentculture = 'en-US';
    $obj = [ordered]@{
        'Object'           = $vmhost.Name
        'Total CPU Ghz'     = [math]::Round($cpuTot / 1000, 0)
        'CPU Usage'         = "{0:n2}" -f (($cpuUse / $cpuTot) * 100)
        'CPU Free'          = "{0:n2}" -f ((($cpuTot - $cpuUse) / $cpuTot) * 100)
        'Total RAM GB'      = [math]::Round($memTot, 0)
        'RAM Usage'         = "{0:n2}" -f (($memUse / $memTot) * 100)
        'RAM Free'       = "{0:n2}" -f ((($memTot - $memUse) / $memTot) * 100)
        'No Hosts'          = $(if($cluster -eq $true) {$vmhost.ExtensionData.Host.Count} else {"1"})
        'No VMs'             = $(if($cluster -eq $true) {& {
            $esxVM = Get-View -Id $vmhost.ExtensionData.Host -Property VM
            $vm = @()
            if ($esxVM.VM) {
                $vm = Get-View -Id $esxVM.VM -Property Summary.Config.Template | Where-Object { -not $_.Summary.Config.Template }
            }
            $vm.Count
        }} else {& {
            $esxVM = Get-View -Id $vmhost.ExtensionData.MoRef
            $vm = @()
            if ($esxVM.VM) {
                $vm = Get-View -Id $esxVM.VM -Property Summary.Config.Template | Where-Object { -not $_.Summary.Config.Template }
            }
            $vm.Count
        }})
        'vCPU'              = ($vm.NumCpu | Measure-Object -Sum).Sum
        'pCPU'              = ($esx.NumCpu | Measure-Object -Sum).Sum
        'vCPURatio'         = "{0:n2}" -f [math]::Round((($vm.NumCpu | Measure-Object -Sum).Sum / ($esx.NumCpu | Measure-Object -Sum).Sum),2)
        'vMem'              = [math]::Round(($vm.MemoryGB | Measure-Object -Sum).Sum)
        'pMem'              = [math]::Round(($esx.MemoryTotalGB | Measure-Object -Sum).Sum)
        'vMemRatio'         = "{0:n2}" -f [math]::Round((($vm.MemoryGB | Measure-Object -Sum).Sum / ($esx.MemoryTotalGB | Measure-Object -Sum).Sum),2)
    }
    return $obj
}

Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false -Confirm:$false >$null 2>&1
$viServer = Connect-VIServer $server

$vmhost = $null
$vmhost = Get-VMHost -Name $name -ErrorAction SilentlyContinue
if($null -eq $vmhost) {$vmhost = Get-Cluster -Name $name}
if($null -ne $vmhost)
{
    $obj = Get-vSphereMonitoringData -vmhost $vmhost
    $totalCPU = $obj.'Total CPU Ghz'
    $prtg = "<prtg>
    <result>
        <channel>Total CPU</channel>
        <unit>Custom</unit>
        <customUnit>Ghz</customUnit>
        <mode>Absolute</mode>
        <showChart>1</showChart>
        <showTable>1</showTable>
        <warning>0</warning>
        <float>1</float>
        <value>" + $obj."Total CPU Ghz" + "</value>
    </result>
    <result>
        <channel>CPU Usage</channel>
        <unit>Custom</unit>
        <customUnit>pct</customUnit>
        <mode>Absolute</mode>
        <showChart>1</showChart>
        <showTable>1</showTable>
        <warning>0</warning>
        <float>1</float>
        <value>" + $obj."CPU Usage" + "</value>
    </result>
    <result>
        <channel>CPU Free</channel>
        <unit>Custom</unit>
        <customUnit>pct</customUnit>
        <mode>Absolute</mode>
        <showChart>1</showChart>
        <showTable>1</showTable>
        <warning>0</warning>
        <float>1</float>
        <value>" + $obj."CPU Free" + "</value>
    </result>
    <result>
        <channel>Total RAM</channel>
        <unit>Custom</unit>
        <customUnit>GB</customUnit>
        <mode>Absolute</mode>
        <showChart>1</showChart>
        <showTable>1</showTable>
        <warning>0</warning>
        <float>1</float>
        <value>" + $obj."Total RAM GB" + "</value>
    </result>
    <result>
        <channel>RAM Usage</channel>
        <unit>Custom</unit>
        <customUnit>pct</customUnit>
        <mode>Absolute</mode>
        <showChart>1</showChart>
        <showTable>1</showTable>
        <warning>0</warning>
        <float>1</float>
        <value>" + $obj."RAM Usage" + "</value>
    </result>
    <result>
        <channel>RAM Free</channel>
        <unit>Custom</unit>
        <customUnit>pct</customUnit>
        <mode>Absolute</mode>
        <showChart>1</showChart>
        <showTable>1</showTable>
        <warning>0</warning>
        <float>1</float>
        <value>" + $obj."RAM Free" + "</value>
    </result>
    <result>
        <channel>pCPU : vCPU Ratio</channel>
        <unit>Custom</unit>
        <mode>Absolute</mode>
        <showChart>1</showChart>
        <showTable>1</showTable>
        <warning>0</warning>
        <float>1</float>
        <value>" + $obj."vCPURatio" + "</value>
    </result>
 </prtg>"
    Write-Host $prtg
}

Disconnect-VIServer -Confirm:$false -Server $viServer
