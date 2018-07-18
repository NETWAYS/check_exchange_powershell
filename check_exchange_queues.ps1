<#
.NAME

check_exchange_queues

.SYNOPSIS

Checks the status of Exchange MailQueues

.SYNTAX

check_exchange_queues.ps1 -Server exchange01

.PARAMETER Server

Select the Exchange Server to check (Default: $env:COMPUTERNAME)

.PARAMETER MaxCritical

Maximum allowed messages in queue before going to critical state (Not applied to ShadowRedundancy queues)

.PARAMETER MaxWarn

Maximum allowed messages in queue before going to warning state (Not applied to ShadowRedundancy queues)

.PARAMETER MaxDeferredCritical

Maximum allowed deferred messages in queue before going to critical state

.PARAMETER MaxDeferredWarn

Maximum allowed deferred messages in queue before going to warning state

.PARAMETER MaxLockedCritical

Maximum allowed locked messages in queue before going to critical state

.PARAMETER MaxLockedWarn

Maximum allowed locked messages in queue before going to warning state

#>

param(
    [string] $Server = $env:COMPUTERNAME,
    [int]    $MaxWarn = 20,
    [int]    $MaxCrit = 50,
    [int]    $MaxDeferredWarn = 5,
    [int]    $MaxDeferredCrit = 10,
    [int]    $MaxLockedWarn = 5,
    [int]    $MaxLockedCrit = 10,
    [switch] $Verbose
)

. "$PSScriptRoot\nagios-utils.ps1"

try {
    Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn;
} catch {
    Plugin-Exit $NagiosUnknown "Could not load Exchange PowerShell SnapIn: $error"
}

try {
    $objects = Get-Queue -Server $server
} catch {
    Plugin-Exit $NagiosUnknown "Could not load Mail Queues: $error"
}

if ($objects.Count -eq 0) {
    Plugin-Exit $NagiosUnknown "No Mail Queues found on $server!"
}

$state = @{}
$performance = @{}

try {
    foreach ($object in $objects) {
        $id = $object.Identity.ToString()
        $state[$id] = $item = @{
            Identity = $id
            Object = $object
            Warnings = @()
            Criticals = @()
            Infos = @()
            State = $NagiosUnknown
        }

        if ($object.Status -ne 'Active' -and $object.Status -ne 'Ready') {
            $item.Criticals += "inactive"
        } else {
            $item.Infos += $object.Status
        }

        $deferred = $object.DeferredMessageCount
        if ($deferred -gt $MaxDeferredCrit) {
            $item.Criticals += "too many deferred (${deferred})"
        } elseif ($deferred -gt $MaxDeferredWarn) {
            $item.Warnings += "too many deferred (${deferred})"
        } else {
            $item.Infos += "deferred (${deferred})"
        }

        $locked = $object.LockedMessageCount
        if ($locked -gt $MaxLockedCrit) {
            $item.Criticals += "too many locked (${locked})"
        } elseif ($locked -gt $MaxLockedWarn) {
            $item.Warnings += "too many locked (${locked})"
        } else {
            $item.Infos += "locked (${locked})"
        }

        $messages = $object.MessageCount
        $notShadow = $object.DeliveryType -ne "ShadowRedundancy"
        if ($notShadow -and $messages -gt $MaxCrit) {
            $item.Criticals += "too many messages (${messages})"
        } elseif ($notShadow -and $messages -gt $MaxWarn) {
            $item.Warnings += "too many messages (${messages})"
        } else {
            $item.Infos += "messages (${messages})"
        }

        $performance[$id] = @{
            count = if ($notShadow) { "${messages};${MaxWarn};${MaxCrit};0" } else { "${messages};;;0" }
            deferred = "${deferred};${MaxDeferredWarn};${MaxDeferredCrit};0"
            locked = "${locked};${MaxLockedWarn};${MaxLockedCrit};0"
        }

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
        $longOutput += "[$stateText] ${id}" + $(if ($info) { ":${info}" })
    }

    $pcount = $problems.Count
    $acount = $state.Count
    if ($pcount -gt 0) {
        $text = "$pcount of $acount queues are having issues: " + ($problems.Keys -join ", ")
    } else {
        $text = "All $acount queues are fine"
    }

    Plugin-Output $exitCode $text $longOutput

    if ($verbose) {
        $objects | fl
    }

    Plugin-Performance-Output $performance

    Plugin-Exit $exitCode
} catch {
    Plugin-Exit $NagiosUnknown "Error during Powershell execution: $error" $error[0].ScriptStackTrace
}
