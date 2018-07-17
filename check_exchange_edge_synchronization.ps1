<#
.NAME

check_exchange_queues

.SYNOPSIS

Checks the status of Exchange MailQueues

.SYNTAX

check_exchange_queues.ps1 -Server exchange01

.PARAMETER Server

Select the Exchange Server to check (Default: $env:COMPUTERNAME)

.PARAMETER MaxCrit

Maximum minutes the last sync can old before having a critical state

.PARAMETER MaxWarn

Maximum minutes the last sync can old before having a warning state

#>

param(
    [string] $Identity,
    [int]    $MaxWarn = 5,
    [int]    $MaxCrit = 10,
    [string] $VerifyRecipient,
    [switch] $Verbose
)

. "$PSScriptRoot\nagios-utils.ps1"

$ValidSyncStates = @('Normal', 'Synchronized', 'InProgress')
$WarningSyncStates = @('Warning', 'Inconclusive')

try {
    Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn;
} catch {
    Plugin-Exit $NagiosUnknown "Could not load Exchange PowerShell SnapIn: $error"
}

try {
    $options = @{}

    if ($Identity) {
        $options.Identity = $Identity
    }

    $objects = Get-EdgeSubscription @options
} catch {
    Plugin-Exit $NagiosUnknown "Could not load Edge Subscriptions: $error"
}

if ($objects.Count -eq 0) {
    Plugin-Exit $NagiosUnknown "No Edge Subscriptions found!"
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

        $testOptions = @{
            TargetServer = $id
            MaxReportSize = 10
            MonitoringContext = $true
        }

        #if ($VerifyRecipient) {
        #    $testOptions.VerifyRecipient = $VerifyRecipient
        #}

        $item.Test = $test = Test-EdgeSynchronization @testOptions

        if ($test -eq $null) {
            $item.Criticals += "no test data!"
            continue
        }

        if ($test.SyncStatus -NotIn $ValidSyncStates) {
            $item.Criticals += "status $($test.SyncStatus)"
        } else {
            $item.Infos += $test.SyncStatus
        }

        if ($test.FailureDetail) {
            $item.Criticals += "failure detail: $($test.FailureDetail)"
        }

        $now = $test.UtcNow
        $lastSync = $test.LastSynchronizedUtc
        $diff = New-Timespan -Start $lastSync -End $now
        $minutes = $diff.Minutes
        $ageInfo = "sync ${minutes} minutes old"
        if ($minutes -lt 0) {
            $item.Critical += "sync ${minutes} minutes in the future!"
        } elseif ($minutes -gt $MaxCrit) {
            $item.Criticals += $ageInfo
        } elseif ($minutes -gt $MaxWarn) {
            $item.Warnings += $ageInfo
        } else {
            $item.Infos += $ageInfo
        }

        $performance[$id] = @{
            sync_age = "$($lastSync.Second)s;$($MaxWarn * 60);$($MaxCrit * 60);0"
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
        $text = "$pcount of $acount Edge Synchronizations are having issues: " + ($problems.Keys -join ", ")
    } else {
        $text = "All $acount Edge Synchronizations are fine"
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
