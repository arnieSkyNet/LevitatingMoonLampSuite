#!/bin/bash
# moonphase.sh - v0.02
# Controls the Levitating Moon Lamp based on moon phases
# Night-only: runs 18:0006:59
# Logging aligned with randommoon.sh style (HH:MM:SS)

VERS="v0.02"
LOGFILE="/home/pi/log/arnie.log"
SCRIPT_NAME=$(basename "$0")
STATEFILE="/home/pi/.moonlamp_state"

# -----------------------------
# User-configurable variables
# -----------------------------
IRCLIENT="/home/pi/sbin/irclient"   # Path to IR client binary
IR_HOST="arnie"                      # IRTrans host; leave blank if not used
IR_DEVICE="VGAzerMoonLamp"           # Device name; leave blank if not used
MOONEVENTSLOC="$HOME/Documents"      # Folder containing moon_events_<YEAR>.txt files
DRYRUN=0
DEBUG=0
MANUAL_COLOUR=""
RESET=0
CUSTOM_COMMAND=""

timestamp() { date '+%H:%M:%S'; }
log() { echo "[$(timestamp) $SCRIPT_NAME $VERS] $1" >> "$LOGFILE"; }

show_help() {
    cat <<EOF
Usage: $SCRIPT_NAME [options]

Options:
  --colour <name>     Manually force a colour (British spelling)
  --color <name>      Manually force a colour (American spelling, fun log)
  --reset, -r         Reset lamp to OFF
  --command <cmd>, -c Execute arbitrary IR command
  --dry-run           Show what would happen without sending IR
  --debug             Print extra debug information
  --help, -h          Show this help message
EOF
}

# -----------------------------
# Parse command line
# -----------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --colour)
            MANUAL_COLOUR="$2"
            shift 2 ;;
        --color)
            MANUAL_COLOUR="$2"
            log "Detected --color (American spelling). Hello Yankee!"
            shift 2 ;;
        --reset|-r)
            RESET=1
            shift ;;
        --command|-c)
            CUSTOM_COMMAND="$2"
            shift 2 ;;
        --dry-run)
            DRYRUN=1
            shift ;;
        --debug)
            DEBUG=1
            shift ;;
        --help|-h)
            show_help
            exit 0 ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1 ;;
    esac
done

log "started"

# -----------------------------
# Night mode check
# -----------------------------
HOUR=$(date +%H)
if [ "$HOUR" -ge 18 ] || [ "$HOUR" -lt 7 ]; then
    log "Night Mode: script running in night window"
else
    log "Day Mode: outside night window, skipping IR send"
    exit 0
fi

# -----------------------------
# Handle reset
# -----------------------------
if [ "$RESET" -eq 1 ]; then
    if [ "$DRYRUN" -eq 0 ]; then
        $IRCLIENT $IR_HOST $IR_DEVICE off
    fi
    log "Lamp reset to OFF"
    exit 0
fi

# -----------------------------
# Load previous state
# -----------------------------
if [ -f "$STATEFILE" ]; then
    source "$STATEFILE"
else
    power="off"
    brightness=1
    colour="white"
fi

# -----------------------------
# Today's date
# -----------------------------
year=$(date +%Y)
month=$(date +%m)
day=$(date +%d)

# -----------------------------
# Utility: random picker
# -----------------------------
pick_random() {
    local list=("$@")
    local count=${#list[@]}
    local index=$((RANDOM % count))
    echo "${list[$index]}"
}

# -----------------------------
# Moon phase calculation
# -----------------------------
calc_phase () {
    y=$1; m=$2; d=$3
    if [ "$m" -lt 3 ]; then
        y=$((y - 1))
        m=$((m + 12))
    fi
    a=$((y / 100))
    b=$((a / 4))
    c=$((2 - a + b))
    e=$((36525 * (y + 4716) / 100))
    f=$((306 * (m + 1) / 10))
    jd=$((c + d + e + f - 1524))
    ip=$(( (jd - 2451550) % 29530503 ))
    phase=$(( (ip / 3681325) % 8 ))
    echo "$phase"
}

phase=$(calc_phase "$year" "$month" "$day")

# -----------------------------
# Base phase-colour mapping
# -----------------------------
case "$phase" in
    0) colour="royalblue" ;;
    1) colour="white" ;;
    2) colour="white" ;;
    3) colour="skyblue" ;;
    4) colour="yellow" ;;
    5) colour="green" ;;
    6) colour="white" ;;
    7) colour="lilac" ;;
esac

# -----------------------------
# Randomised rotations for phases
# -----------------------------
if [ "$phase" -eq 0 ]; then colour=$(pick_random flash mauve lilac purple); fi
if [ "$phase" -eq 3 ]; then colour=$(pick_random skyblue beachblue royalblue); fi
if [ "$phase" -eq 4 ]; then colour=$(pick_random white yellow peach); fi

# -----------------------------
# Per-year Moon Events File
# -----------------------------
MOONEVENTS="$MOONEVENTSLOC/moon_events_${year}.txt"

if [ ! -f "$MOONEVENTS" ]; then
    PREV_YEAR=$((year - 1))
    PREV_FILE="$MOONEVENTSLOC/moon_events_${PREV_YEAR}.txt"
    if [ -f "$PREV_FILE" ]; then
        cp "$PREV_FILE" "$MOONEVENTS"
        log "No moon events file for $year found. Copied $PREV_YEAR file to $year. Please update it."
    else
        log "No moon events file found for $year or $PREV_YEAR. No special events will be applied."
        MOONEVENTS=""
    fi
fi

# -----------------------------
# Apply special moon events if today matches
# -----------------------------
if [ -f "$MOONEVENTS" ]; then
    while read -r line; do
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        evt_date=$(echo "$line" | awk '{print $1}')
        evt_colour=$(echo "$line" | awk '{print $2}')
        evt_desc=$(echo "$line" | cut -d' ' -f3-)
        today=$(date +%m-%d)
        if [ "$today" == "$evt_date" ]; then
            colour="$evt_colour"
            log "Special moon event today: $evt_desc, overriding colour to $colour"
        fi
    done < "$MOONEVENTS"
fi

# -----------------------------
# Manual colour override
# -----------------------------
if [ -n "$MANUAL_COLOUR" ]; then
    colour="$MANUAL_COLOUR"
    log "Manual override: colour=$colour"
fi

# -----------------------------
# Execute custom command if supplied
# -----------------------------
if [ -n "$CUSTOM_COMMAND" ]; then
    if [ "$DRYRUN" -eq 0 ]; then
        $IRCLIENT $IR_HOST $IR_DEVICE "$CUSTOM_COMMAND"
    fi
    log "Executed custom command: $CUSTOM_COMMAND"
fi

# -----------------------------
# Send IR colour command
# -----------------------------
if [ "$DRYRUN" -eq 1 ]; then
    log "[DRY-RUN] Would send: $IRCLIENT $IR_HOST $IR_DEVICE $colour"
else
    log "Executing: $IRCLIENT $IR_HOST $IR_DEVICE $colour"
    $IRCLIENT $IR_HOST $IR_DEVICE "$colour"
fi

# -----------------------------
# Random brightness adjustments
# -----------------------------
rand_clicks=$((RANDOM % 3 + 1))
action=$(pick_random dim brighter)

if [ "$power" = "off" ] && [ "$action" = "brighter" ]; then
    if [ "$DRYRUN" -eq 0 ]; then
        $IRCLIENT $IR_HOST $IR_DEVICE on
    fi
    power="on"
    brightness=1
    log "Lamp was off, turned on for brighter adjustment"
fi

for i in $(seq 1 $rand_clicks); do
    if [ "$DRYRUN" -eq 0 ]; then
        $IRCLIENT $IR_HOST $IR_DEVICE "$action"
    fi
    (( brightness += (action == "brighter" ? 1 : -1) ))
    brightness=$(( brightness < 1 ? 1 : (brightness > 3 ? 3 : brightness) ))
    log "Brightness adjustment: $action (step $i), brightness=$brightness"
done

# -----------------------------
# Save updated state
# -----------------------------
echo "power=$power" > "$STATEFILE"
echo "brightness=$brightness" >> "$STATEFILE"
echo "colour=$colour" >> "$STATEFILE"

log "Moon lamp set to: $colour, brightness=$brightness, power=$power"
log "ended"

