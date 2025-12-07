<#
.SYNOPSIS
Randomised Moon Lamp Controller for Windows using IRTrans

.DESCRIPTION
Controls a VGAzer Moon Lamp via IRTrans on Windows. Supports:
- Random colours
- Brightness control
- Power on/off
- Reset and manual commands
- Continuous run with fixed or random delays
- Logging to a file
- Configurable IR client, host, and device

.VERSION
0.02.2
#>

# -----------------------------
# User-configurable IR client settings
# -----------------------------
$IRCLIENT = "C:\Program Files\IRTrans\IRClient.exe"
$IR_HOST = "localhost"
$IR_DEVICE = "VGAzerMoonLamp"
$LOGFILE = "$env:USERPROFILE\Documents\MoonLamp.log"

# -----------------------------
# CLI option defaults
# -----------------------------
$DRYRUN = $false
$DELAY = $null
$RANDOMMAX = $null
$COLOUR = $null
$RESET = $false
$COMMAND = $null

# -----------------------------
# Parse command-line arguments
# -----------------------------
for ($i = 0; $i -lt $Args.Length; $i++) {
    switch ($Args[$i].ToLower()) {
        "--dry-run" { $DRYRUN = $true }
        "--delay"   { $DELAY = $Args[$i+1]; $i++ }
        "--random"  { $RANDOMMAX = $Args[$i+1]; $i++ }
        "--colour"  { $COLOUR = $Args[$i+1]; $i++ }
        "--color"   { $COLOUR = $Args[$i+1]; $i++ }
        "--reset"   { $RESET = $true }
        "-r"        { $RESET = $true }
        "--command" { $COMMAND = $Args[$i+1]; $i++ }
        "-c"        { $COMMAND = $Args[$i+1]; $i++ }
        "--help"    { Write-Host "Usage: randommoon.ps1 [--dry-run] [--delay <Ns|Nm|Nh>] [--random <Ns|Nm|Nh>] [--colour <color>] [--reset] [--command <cmd>]"; exit }
        default     { Write-Host "Unknown option: $($Args[$i])"; exit 1 }
    }
}

# -----------------------------
# Logging function
# -----------------------------
function Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "HH:mm:ss"
    $line = "[$timestamp randommoon.ps1 v0.02.2] $Message"
    if (-not $DRYRUN) { Add-Content -Path $LOGFILE -Value $line }
    Write-Host $line
}

# -----------------------------
# Available colours
# -----------------------------
$COLORS = @("white","red","orange","pink","peach","yellow","green","bluegreen","skyblue","beachblue","seablue","royalblue","mauve","purple","crimson","lilac")
$BRIGHT_MIN = 0
$BRIGHT_MAX = 4

# -----------------------------
# State file
# -----------------------------
$STATEFILE = "$env:USERPROFILE\.moonlamp_state.ps1"
if (Test-Path $STATEFILE) {
    . $STATEFILE
} else {
    $power = "on"
    $colour = "white"
    $brightness = 2
}

# -----------------------------
# Helper functions
# -----------------------------
function Pick-Random {
    param([string[]]$list)
    return $list[(Get-Random -Maximum $list.Length)]
}

function Send-Cmd {
    param([string]$cmd)
    if ($DRYRUN) {
        Log "EXEC: $IRCLIENT $IR_HOST $IR_DEVICE $cmd"
    } else {
        & $IRCLIENT $IR_HOST $IR_DEVICE $cmd
        Log "EXEC: $IRCLIENT $IR_HOST $IR_DEVICE $cmd"
    }
}

function Apply-Brightness {
    param([int]$from, [int]$to)
    if ($from -eq $to) { return }
    if ($from -lt $to) {
        1..($to-$from) | ForEach-Object { Send-Cmd "brighter"; Start-Sleep -Milliseconds 400 }
    } else {
        1..($from-$to) | ForEach-Object { Send-Cmd "dim"; Start-Sleep -Milliseconds 400 }
    }
}

function Save-State {
    @"
`$power='$power'
`$colour='$colour'
`$brightness=$brightness
"@ | Set-Content -Path $STATEFILE
}

# -----------------------------
# Reset if requested
# -----------------------------
if ($RESET) {
    Send-Cmd "off"
    $power = "off"
    Save-State
    Log "Lamp reset to OFF"
    exit
}

# -----------------------------
# Execute manual colour if provided
# -----------------------------
if ($COLOUR) {
    $colour = $COLOUR
    if ($power -eq "off") {
        Send-Cmd "on"
        Start-Sleep 0.6
        $power = "on"
    }
    Send-Cmd $colour
    Save-State
    Log "Lamp colour manually set to $COLOUR"
    exit
}

# -----------------------------
# Execute custom command if provided
# -----------------------------
if ($COMMAND) {
    Send-Cmd $COMMAND
    Log "Custom command executed: $COMMAND"
    exit
}

# -----------------------------
# Main random logic
# -----------------------------
do {
    $newColour = Pick-Random ($COLORS | Where-Object { $_ -ne $colour })
    if (-not $newColour) { $newColour = Pick-Random $COLORS }
    $targetBrightness = Get-Random -Minimum $BRIGHT_MIN -Maximum ($BRIGHT_MAX+1)
    $r = Get-Random -Maximum 100
    if ($r -lt 20) { $powerAction="off" }
    elseif ($r -lt 45) { $powerAction="on" }
    else { $powerAction="leave" }

    Log "DECISIONS: new_colour=$newColour target_brightness=$targetBrightness power_action=$powerAction"

    $colour = $newColour

    # --- OVERRIDE LOGIC ---
    if ($power -eq "off" -and $powerAction -eq "leave") {
        $powerAction = "override"
        Log "WARNING: State mismatch detected: lamp is OFF but action is 'leave'  forcing power ON"
    }

    switch ($powerAction) {
        "off" {
            if ($power -eq "on") { Send-Cmd "off"; $power="off" }
        }
        "on" {
            if ($power -eq "off") { Send-Cmd "on"; Start-Sleep 0.6; $power="on" }
            Send-Cmd $colour
            Apply-Brightness -from $brightness -to $targetBrightness
            $brightness = $targetBrightness
        }
        "leave" {
            if ($power -eq "on") {
                Send-Cmd $colour
                Apply-Brightness -from $brightness -to $targetBrightness
                $brightness = $targetBrightness
            }
        }
        "override" {
            Log "POWER OVERRIDE: forcing ON to resync state"
            Send-Cmd "on"; Start-Sleep 0.6; $power = "on"
            Send-Cmd $colour
            Apply-Brightness -from $brightness -to $targetBrightness
            $brightness = $targetBrightness
        }
    }

    Save-State

    if ($DELAY) {
        if ($DELAY -match "(\d+)([smh])") {
            $num = [int]$matches[1]
            switch ($matches[2]) {
                "s" { $sleepSeconds = $num }
                "m" { $sleepSeconds = $num * 60 }
                "h" { $sleepSeconds = $num * 3600 }
            }
            Start-Sleep -Seconds $sleepSeconds
        }
    } elseif ($RANDOMMAX) {
        if ($RANDOMMAX -match "(\d+)([smh])") {
            $num = [int]$matches[1]
            switch ($matches[2]) {
                "s" { $sleepSeconds = Get-Random -Maximum $num }
                "m" { $sleepSeconds = Get-Random -Maximum ($num*60) }
                "h" { $sleepSeconds = Get-Random -Maximum ($num*3600) }
            }
            Start-Sleep -Seconds $sleepSeconds
        }
    }

} while ($DELAY -or $RANDOMMAX)

Log "Random Moon run ended"
