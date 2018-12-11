<#
.NAME

check_exchange_health

.SYNOPSIS

Checks the server health of Microsoft Exchange

.SYNTAX

check_exchange_health.ps1 -Server exchange01

.PARAMETER Server

Exchange Server to check against (Default: $env:COMPUTERNAME)

. PARAMETER IgnoreDisabled

Ignore Disabled monitors and don't mark them as Critical (DEFAULT: $true)
#>

param(
    [string] $Server = $env:COMPUTERNAME,
    [boolean] $IgnoreDisabled = $true,
    [string[]] $Scenarios = @{},
    [switch] $Verbose
)

. "$PSScriptRoot\nagios-utils.ps1"

try {
    Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn;
} catch {
    Plugin-Exit $NagiosUnknown "Could not load Exchange PowerShell SnapIn: $error"
}

$state = @{}
$performance = @{}

try {
    if ($Scenarios.count -gt 0 -and $IgnoreDisabled -eq $true) {
      $objects = Get-ServerHealth -Identity $Server | Where-Object { $_.Name -notin $Scenarios } | ? alertvalue -ne disabled
    } elseif ($IgnoreDisabled -eq $true) {
      $objects = Get-ServerHealth -Identity $Server | ? alertvalue -ne disabled
    } else {
      $objects = Get-ServerHealth -Identity $Server
    }
} catch {
    Plugin-Exit $NagiosUnknown "Get-ServerHealth failed: $error"
}

#$objects[0] | fl
#exit

try {
    foreach ($object in $objects) {
        if ($object.CurrentHealthSetState -eq 'NotApplicable') { continue }

        $id = $object.Name
        $state[$id] = $item = @{
            Name = $id
            Object = $object
            Warnings = @()
            Criticals = @()
            Infos = @()
            State = $NagiosUnknown
        }

        if ($object.AlertValue -ne 'Healthy') {
            $item.Criticals += $object.AlertValue
            $item.Criticals += $object.Error
        } elseif ($Verbose) {
            $item.Infos += $object.AlertValue
        }

        <#
        $performance[$id] = @{
            #latency = "${latency}ms;${MaxWarn};${MaxCrit};0"
        }
        #>

        if ($item.Criticals -gt 0) {
            $item.State = $NagiosCritical
        } elseif ($item.Warnings -gt 0) {
            $item.State = $NagiosWarning
        } else {
            $item.State = $NagiosOk
        }
    }

    $longOutput = @()
    $exitCode = $NagiosOk
    $problems = @{}

    foreach ($id in $state.Keys) {
        $item = $state[$id]

        $info = ""
        if ($item.Criticals -gt 0) {
            $info += " " + ($item.Criticals -join ", ")
            if ($exitCode -lt $NagiosCritical) { $exitCode = $NagiosCritical }
            $problems[$id] = 1
        }
        if ($item.Warnings -gt 0) {
            $info += " " + ($item.Warnings -join ", ")
            if ($exitCode -lt $NagiosWarning) { $exitCode = $NagiosWarning }
            $problems[$id] = 1
        }
        if ($item.Infos -gt 0) {
            $info += " " + ($item.Infos -join ", ")
        }

        $stateText = Plugin-State-Text $item.State
        if ($Verbose -or $info) {
            $longOutput += "[$stateText] ${id}:${info}"
        }
    }

    $pcount = $problems.Count
    $acount = $state.Count
    if ($pcount -gt 0) {
        $text = "$pcount of $acount scenarios are having issues: " + ($problems.Keys -join ", ")
    } else {
        $text = "All $acount scenarios are fine"
    }

    Plugin-Output $exitCode $text $longOutput

    if ($verbose) {
        $objects
    }

    #Plugin-Performance-Output $performance

    Plugin-Exit $exitCode
} catch {
    Plugin-Exit $NagiosUnknown "Error during Powershell execution: $error" $error[0].ScriptStackTrace
}
