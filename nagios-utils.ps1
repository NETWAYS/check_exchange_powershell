$NagiosOk = 0
$NagiosWarning = 1
$NagiosCritical = 2
$NagiosUnknown = 3

$ErrorActionPreference = "Stop"
$error.clear()

# Return human readable state text
function Plugin-State-Text ([int] $code) {
    switch ($code) {
        $NagiosOk {"OK"}
        $NagiosWarning {"WARNING"}
        $NagiosCritical {"CRITICAL"}
        $NagiosUnknown {"UNKNOWN"}
    }
}

function Perfdata-Label ([string] $name) {
    $name = $name -replace '[\s=\\]+', '_'
    $name = $name -replace "'", ''
    $name
}

function Plugin-Output ([int] $code, [string] $output) {
    if ($code > $NagiosUnknown) { $code = $NagiosUnknown }
    $state = Plugin-State-Text $code
    
    Write-Host "${state}: $output"
    foreach ($t in $args) {
        if ($t -isnot [array]) {
          $t = @($t)
        }
        foreach ($l in $t) {
            Write-Host $l
        }
    }
}

function Plugin-Performance-Output ($perfdata, [string] $prefix = '') {
    #if ($perfdata.Count -eq 0) { return }
    $text = ""
    if ($prefix -eq '') { $text += "|" }

    foreach ($key in $perfdata.Keys) {
        $label = Perfdata-Label $key
        $value = $perfdata[$key]

        if ($prefix) {
            $label = "${prefix}::${label}"
        }
        
        if ($value -is [string] -or $value -is [int]) {
            $text += " '${label}'=${value}"
        } elseif ($value -is [hashtable]) {
            $text += Plugin-Performance-Output $value $label
        } else {
            # ignoring invalid perfvalue
        }
    }

    if ($prefix) {
        return $text
    } else {
        Write-Host $text
    }
}

# Exit the plugin in a Nagios Plugin way
function Plugin-Exit ([int] $code, [string] $output) {
    if ($output) {
        Plugin-Output $code $output @args
    }
    exit $code
}
