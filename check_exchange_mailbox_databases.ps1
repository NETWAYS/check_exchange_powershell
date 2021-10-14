<#
.NAME

check_exchange_mailbox_databases

.SYNOPSIS

Checks the availability and health of Exchange Databases

.SYNTAX

check_exchange_mailbox_databases.ps1 -Server exchange01 -RequireReplication

.PARAMETER Server

Select the Exchange Server to check (Default: $env:COMPUTERNAME)

.PARAMETER RequireReplication

All databases should have a replicated copy

#>

param(
    [string] $Server = $env:COMPUTERNAME,
    [switch] $RequireReplication,
    [switch] $Verbose
)

. "$PSScriptRoot\nagios-utils.ps1"

try {
    Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn;
} catch {
    Plugin-Exit $NagiosUnknown "Could not load Exchange PowerShell SnapIn: $error"
}

try {
    $databases = Get-MailboxDatabase -Server $server -Status
} catch {
    Plugin-Exit $NagiosUnknown "Could not load Mailbox Databases: $error"
}

if ($databases.Count -eq 0) {
    Plugin-Exit $NagiosUnknown "No Mailbox Databases found on $server!"
}

$dbState = @{}
$performance = @{}

try {
    foreach ($database in $databases) {
        $id = $database.Identity.ToString()
        $dbState[$id] = $db = @{
            Identity = $id
            Object = $database
            Warnings = @()
            Criticals = @()
            State = $NagiosUnknown
        }

        # For later consideration:
        # LastFullBackup
        # LastIncrementalBackup
        # LastDifferentialBackup
        # LastCopyBackup

        if ($database.Recovery -eq $true) {
            $db.Criticals += "in Recovery"
        }
        if ($database.Mounted -ne $true) {
            $db.Criticals += "not Mounted"
        }
        if ($database.InvalidDatabaseCopies.Count -gt 0) {
            $db.Criticals += "with InvalidDatabaseCopies"
        }
        if ($database.MountAtStartup -ne $true) {
            $db.Warnings += "no MountAtStartup"
        }
        if ($database.BackgroundDatabaseMaintenance -ne $true) {
            $db.Warnings += "no BackgroundDatabaseMaintenance"
        }
        if ($RequireReplication -and $database.DatabaseCopies.Count -lt 2) {
            $db.Warnings += "too few DatabaseCopies ($($database.DatabaseCopies.Count))"
        }
        
        $performance[$id] = @{
            database_size = $database.DatabaseSize.ToMB().ToString() + "MB;;;0"
            available_space = $database.AvailableNewMailboxSpace.ToMB().ToString() + "MB;;;0"
            used_space = ($database.DatabaseSize - $database.AvailableNewMailboxSpace).ToMB().ToString() + "MB;;;0"
        }

        if ($db.Criticals -gt 0) {
            $db.State = $NagiosCritical
        } elseif ($db.Warnings -gt 0) {
            $db.State = $NagiosWarning
        } else {
            $db.State = $NagiosOk
        }
    }

    $longOutput = @()
    $state = $NagiosOk
    $problems = @{}

    foreach ($id in $dbState.Keys) {
        $db = $dbState[$id]

        $info = ""
        if ($db.Criticals -gt 0) {
            $info += " " + ($db.Criticals -join ", ")
            if ($state -lt $NagiosCritical) { $state = $NagiosCritical }
            $problems[$id] = 1
        }
        if ($db.Warnings -gt 0) {
            $info += " " + ($db.Warnings -join ", ")
            if ($state -lt $NagiosWarning) { $state = $NagiosWarning }
            $problems[$id] = 1
        }

        $stateText = Plugin-State-Text $db.State
        $longOutput += "[$stateText] ${id}" + $(if ($info) { ":${info}" })
    }

    $pcount = $problems.Count
    $acount = $dbState.Count
    if ($pcount -gt 0) {
        $text = "$pcount of $acount databases having issues: " + ($problems.Keys -join ", ")
    } else {
        $text = "All $acount databases are fine"
    }

    Plugin-Output $state $text $longOutput

    if ($verbose) {
        $databases | fl
    }

    Plugin-Performance-Output $performance

    Plugin-Exit $state
} catch {
    Plugin-Exit $NagiosUnknown "Error during Powershell execution: $error" $error[0].ScriptStackTrace
}
