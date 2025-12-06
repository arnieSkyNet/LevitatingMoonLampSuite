<#
.SYNOPSIS
Moon Phase-based Moon Lamp Controller for Windows using IRTrans

.DESCRIPTION
Controls a VGAzer Moon Lamp via IRTrans based on lunar phases and per-year moon events.
Supports night-only operation (18:0006:59 UK time), manual colour override, reset, and custom IR commands.

.VERSION
0.02
#>

# -----------------------------
# User-configurable IR client settings
# -----------------------------
$IRCLIENT = "C:\Program Files\IRTrans\IRClient.exe"
$IR_HOST = "localhost"
$IR_DEVICE = "VGAzerMoonLamp"
$LOGFILE = "$env:USERPROFILE\Documents\MoonPhaseLamp.log"

# -----------------------------
# Per-year moon events file location
# -----------------------------
$YEAR = (Get-Date).Year
$MOONEVENTSLOC = "$env:USERPROFILE\Documents"
$MOONEVENTS = Join-Path $MOONEVENTSLOC "moon_events_$YEAR.txt"

# -----------------------------
# CLI defaults
# -----------------------------
$DRYRUN = $false
$COLOUR = $null
$RESET = $false
$COMMAND = $null

# -----------------------------
# Parse command-line arguments
# -----------------------------
param([string[]]$Args)

for ($i = 0; $i -lt $Args.Length; $i++) {
    switch ($Args[$i].ToLower()) {
        "--dry-run" { $DRYRUN = $true }
        "--colour"  { $COLOUR = $Args[$i+1]; $i++ }
        "--color"   { $COLOUR = $Args[$i+1]; $i++ }
        "--reset" { $RESET = $true }
        "-r" { $RESET = $true }
        "--command" { $COMMAND = $Args[$i+1]; $i++ }
        "-c" { $COMMAND = $Args[$i+1]; $i++ }
        "--help" { Write-Host "Usage: moonphase.ps1 [--dry-run] [--colour <color>] [--reset] [--command <cmd>]"; exit }
        default { Write-Host "Unknown option: $($Args[$i])"; exit 1 }
    }
}

# -----------------------------
# Logging function
# -----------------------------
function Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
    $line = "[$timestamp moonphase.ps1 v0.02] $Message"
    if (-not $DRYRUN) {
        Add-Content -Path $LOGFILE -Value $line
    }
    Write-Host $line
}

# -----------------------------
# State file
# -----------------------------
$STATEFILE = "$env:USERPROFILE\.moonphase_lamp_state.ps1"
if (Test-Path $STATEFILE) {
    . $STATEFILE
} else {
    $power = "on"
    $colour = "white"
    $brightness = 2
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
    & $IRCLIENT $IR_HOST $IR_DEVICE "off"
    $power = "off"
    Save-State
    Log "Lamp reset to OFF"
    exit
}

# -----------------------------
# Manual colour override
# -----------------------------
if ($COLOUR) {
    if ($power -eq "off") { & $IRCLIENT $IR_HOST $IR_DEVICE "on"; Start-Sleep -Milliseconds 600; $power="on" }
    & $IRCLIENT $IR_HOST $IR_DEVICE $COLOUR
    $colour = $COLOUR
    Save-State
    Log "Lamp colour manually set to $COLOUR"
    exit
}

# -----------------------------
# Custom IR command
# -----------------------------
if ($COMMAND) {
    & $IRCLIENT $IR_HOST $IR_DEVICE $COMMAND
    Log "Custom command executed: $COMMAND"
    exit
}

# -----------------------------
# Check night-only operation (18:0006:59 UK time)
# -----------------------------
$UKTime = (Get-Date).ToUniversalTime().AddHours(0) # adjust if needed
$hour = $UKTime.Hour
if ($hour -ge 7 -and $hour -lt 18) {
    Log "Outside night hours; exiting."
    exit
}

# -----------------------------
# Load moon events file
# -----------------------------
if (-not (Test-Path $MOONEVENTS)) {
    $PrevYearFile = Join-Path $MOONEVENTSLOC "moon_events_$($YEAR-1).txt"
    if (Test-Path $PrevYearFile) {
        Copy-Item $PrevYearFile $MOONEVENTS
        Log "Moon events file for $YEAR not found; copied from previous year. Please update."
    } else {
        Log "No moon events file found; exiting."
        exit
    }
}

$events = Get-Content $MOONEVENTS | Where-Object { $_ -and ($_ -notmatch "^#") } | ForEach-Object {
    $parts = $_ -split "\s+"
    [PSCustomObject]@{ Date=$parts[0]; Colour=$parts[1]; Phase=$parts[2] }
}

# -----------------------------
# Determine today's moon phase
# -----------------------------
$todayMD = (Get-Date).ToString("MM-dd")
$todayEvent = $events | Where-Object { $_.Date -eq $todayMD } | Select-Object -First 1

if ($todayEvent) {
    $phaseColour = $todayEvent.Colour
    $phaseName = $todayEvent.Phase
} else {
    $phaseColour = $colour
    $phaseName = "Regular"
}

# -----------------------------
# Apply moon phase control
# -----------------------------
if ($power -eq "off") { & $IRCLIENT $IR_HOST $IR_DEVICE "on"; Start-Sleep -Milliseconds 600; $power="on" }
& $IRCLIENT $IR_HOST $IR_DEVICE $phaseColour
$colour = $phaseColour
Save-State
Log "Moon phase control applied: $phaseName ($phaseColour)"


