<#
.NAME

check_outlook_webservices

.SYNOPSIS

Checks the availablitity of EWS

.SYNTAX

check_outlook_webservices.ps1 -Server exchange01

.PARAMETER ClientAccessServer

ClientAccessServer to check against (Default: $env:COMPUTERNAME)

.PARAMETER Mailbox

User Mailbox to check against

.PARAMETER Password

User Password to check against. PLEASE AVOID this and user CredentialPath

.PARAMETER CredentialPath

XML File with Mailbox/Password credential for the Mailbox, see examples how to store this.

(Default: $PSScriptRoot\MailboxCredential.xml)

.PARAMETER MaxCritical

Maximum allowed latency (in milliseconds) before going to critical state

.PARAMETER MaxWarn

Maximum allowed latency (in milliseconds) before going to warning state

.PARAMETER TrustAnySSLCertificate

Do not require trust for the SSL Certificate, set this when common name or SAN does not match

.EXAMPLE

Create a stored credential like this:

    Get-Credential | Export-CliXml .\MailboxCredential.xml

#>

param(
    [string] $ClientAccessServer = $env:COMPUTERNAME,
    [string] $Mailbox,
    [securestring] $Password,
    [string] $CredentialPath = "$PSScriptRoot\MailboxCredential.xml",
    [int]    $MaxWarn = 100,
    [int]    $MaxCrit = 200,
    [switch] $TrustAnySSLCertificate,
    [switch] $Verbose
)

. "$PSScriptRoot\nagios-utils.ps1"

try {
    Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn;
} catch {
    Plugin-Exit $NagiosUnknown "Could not load Exchange PowerShell SnapIn: $error"
}

# setup credential for authentication
[PSCredential] $credential = $null

if (-not $Mailbox -and -not $Password -and $(Test-Path $CredentialPath)) {
    try {
        $credential = Import-Clixml $CredentialPath
    } catch {
        Plugin-Exit $NagiosUnknown "Could not load mailbox credential from ${CredentialPath}: $error"
    }
} elseif (-not $Mailbox) {
    Plugin-Exit $NagiosUnknown "No Mailbox set to check with!"
} elseif (-not $Password) {
    Plugin-Exit $NagiosUnknown "No Password set to check mailbox ${Mailbox}"
} else {
    try {
        $credential = New-Object System.Management.Automation.PSCredential($Mailbox, $Password)
    } catch {
        Plugin-Exit $NagiosUnknown "Could not build credential: $error"
    }
}


# Run the test
$state = @{}
$performance = @{}

# Test-OutlookConnectivity -ProbeIdentity "OutlookRpcSelfTestProbe" -MailboxId $cred.UserName -Credential $cred

try {
    $tests = Test-OutlookWebServices `        -Identity $credential.UserName `        -ClientAccessServer $ClientAccessServer `        -MailboxCredential $credential `
        -TrustAnySSLCertificate:$TrustAnySSLCertificate
} catch {
    Plugin-Exit $NagiosUnknown "Test-OutlookWebServices failed: $error"
}

try {
    foreach ($object in $tests) {
        $id = $object.Scenario
        $state[$id] = $item = @{
            Identity = $id
            Object = $object
            Warnings = @()
            Criticals = @()
            Infos = @()
            State = $NagiosUnknown
        }

        if ($object.Result -ne 'Success') {
            $item.Criticals += $object.Result
            $item.Criticals += ($object.Error -split "\n")[0]
        } else {
            $item.Infos += $object.Result
        }

        $latency = $object.Latency
        if ($latency -gt $MaxCrit) {
            $item.Criticals += "latency critical (${latency})"
        } elseif ($latency -gt $MaxWarn) {
            $item.Warnings += "latency warning (${latency})"
        }

        $performance[$id] = @{
            latency = "${latency}ms;${MaxWarn};${MaxCrit};0"
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
        $text = "$pcount of $acount scenarios are having issues: " + ($problems.Keys -join ", ")
    } else {
        $text = "All $acount scenarios are fine"
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