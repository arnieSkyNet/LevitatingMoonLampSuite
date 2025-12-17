#!/bin/bash
# randommoon.sh v0.02.1
# Levitating Moon Lamp Controller via IRTrans
# Portable, configurable, and ready for public use (GitHub)
# UK time zone, cron-friendly
# Features: random colour, brightness, power actions, odd/even minute skipping, persistent state
# New (v0.02.1): Bugfix for array loop (Bash 3.2 compatibility), --delay/-d, --random/-r, combined behaviour
# CLI options: --nolog, --log <file>, --dry-run, --delay <N[s|m|h]>, --random <N[s|m|h]>, --help

VER="0.02.3"
SCRIPT_NAME=$(basename "$0")
DEFAULT_LOG="/home/pi/log/arnie.log"

# -----------------------------
# User-configurable IR client settings
# -----------------------------
IRCLIENT="/home/pi/sbin/irclient"
IR_HOST="arnie"
IR_DEVICE="VGAzerMoonLamp"

# -----------------------------
# User-configurable parameters
# -----------------------------
COLORS=(white red orange pink peach yellow green bluegreen skyblue beachblue seablue royalblue mauve purple crimson lilac)
DIMDELAY=8.4
BRIGHT_MIN=0
BRIGHT_MAX=3

# -----------------------------
# CLI option defaults
# -----------------------------
LOGMODE="on"
LOGFILE="$DEFAULT_LOG"
DRYRUN=0
DELAY_MODE=0
DELAY_SECONDS=0
RANDOM_MODE=0
RANDOM_SECONDS=0

# -----------------------------
# Logging functions
# -----------------------------
timestamp() { date +%T; }
log_msg() {
    local msg="$1"
    local prefix="[$(timestamp) $SCRIPT_NAME v$VER]"
    if [[ "$LOGMODE" = "on" ]]; then
        echo "$prefix $msg" | tee -a "$LOGFILE"
    else
        echo "$prefix $msg"
    fi
}
log_warn() { log_msg "WARNING: $1"; }

# -----------------------------
# Show help
# -----------------------------
show_help() {
    cat <<EOF
$SCRIPT_NAME v$VER
Usage: $SCRIPT_NAME [OPTIONS]

Options:
  --nolog                 Disable logging completely
  --log <file>            Log output to specified file
  --dry-run               Show commands but do not send to lamp
  --delay <N[s|m|h]>, -d  Run continuously every N seconds/minutes/hours (daemon-ish)
  --random <N[s|m|h]>, -r Run with random window
  --help                  Show this help message
EOF
    exit 0
}

# -----------------------------
# Helper: parse interval to seconds
# -----------------------------
parse_interval_to_seconds() {
    local input="$1"
    if [[ "$input" =~ ^([0-9]+)([smh])$ ]]; then
        local val="${BASH_REMATCH[1]}"
        local unit="${BASH_REMATCH[2]}"
        case "$unit" in
            s) echo $((val)); return 0 ;;
            m) echo $((val * 60)); return 0 ;;
            h) echo $((val * 3600)); return 0 ;;
        esac
    fi
    return 1
}

# -----------------------------
# Parse CLI options
# -----------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --nolog) LOGMODE="off"; shift ;;
        --log)
            [[ -n "$2" ]] && LOGFILE="$2" && shift 2 || { echo "Error: --log requires a filename"; exit 1; }
            ;;
        --dry-run) DRYRUN=1; shift ;;
        --delay|-d)
            [[ -n "$2" ]] && DELAY_SECONDS=$(parse_interval_to_seconds "$2") && DELAY_MODE=1 && shift 2 || { echo "Error: --delay requires a value"; exit 1; }
            ;;
        --random|-r)
            [[ -n "$2" ]] && RANDOM_SECONDS=$(parse_interval_to_seconds "$2") && RANDOM_MODE=1 && shift 2 || { echo "Error: --random requires a value"; exit 1; }
            ;;
        --help) show_help ;;
        *) echo "Unknown option: $1"; show_help ;;
    esac
done

# -----------------------------
# Signal handling
# -----------------------------
terminate=0
_on_term() { terminate=1; log_msg "Received termination signal; exiting loop"; }
trap _on_term SIGINT SIGTERM

# -----------------------------
# Main wrapper
# -----------------------------
run_wrapper() {
    log_msg "started (mode: $( [[ $DELAY_MODE -eq 1 ]] && echo loop || echo single ))"
    run_logic
    log_msg "ended"
}

# -----------------------------
# Main moon lamp logic
# -----------------------------
run_logic() {
    export TZ="Europe/London"
    STATEFILE="$HOME/.moonlamp_state"
    LOCKFILE="/tmp/randommoon.lock"

    exec 200>"$LOCKFILE"
    flock -n 200 || { log_msg "Another instance running; exiting run_logic."; return; }

    pick_random() { local list=("$@"); echo "${list[RANDOM % ${#list[@]}]}"; }

    send_cmd() {
        local cmd="$1"
        log_msg "EXEC: $IRCLIENT ${IR_HOST:-localhost} ${IR_DEVICE:-MoonLamp} $cmd"
        [[ $DRYRUN -eq 0 && -n "$IRCLIENT" ]] && "$IRCLIENT" "${IR_HOST:-localhost}" "${IR_DEVICE:-MoonLamp}" "$cmd"
    }

    apply_brightness_steps() {
        local from=$1 to=$2
        [[ "$from" -eq "$to" ]] && { log_msg "Brightness already at $from"; return; }
        if [[ "$from" -lt "$to" ]]; then
            for i in $(seq 1 $((to-from))); do send_cmd "brighter"; sleep "$DIMDELAY"; done
        else
            for i in $(seq 1 $((from-to))); do send_cmd "dim"; sleep "$DIMDELAY"; done
        fi
    }

    state_init() { power="on"; colour="white"; brightness=2; }

    if [[ -f "$STATEFILE" ]]; then
        . "$STATEFILE" 2>/dev/null || state_init
        [[ "$power" != "on" && "$power" != "off" ]] && power="on"
        [[ ! "$brightness" =~ ^[0-9]+$ ]] && brightness=2
        ((brightness<BRIGHT_MIN)) && brightness=$BRIGHT_MIN
        ((brightness>BRIGHT_MAX)) && brightness=$BRIGHT_MAX
        [[ ! " ${COLORS[*]} " =~ " $colour " ]] && colour="white"
    else state_init; fi

    save_state() {
        tmp=$(mktemp "/tmp/randommoon_state.XXXX")
        { echo "power=$power"; echo "colour=$colour"; echo "brightness=$brightness"; } > "$tmp"
        mv "$tmp" "$STATEFILE"
        chmod 600 "$STATEFILE"
    }

    log_msg "STATE before: power=$power colour=$colour brightness=$brightness"

    # Odd/even minute skip
    minute_int=$((10#$(date +%M)))
    parity_choice=$((RANDOM % 2))
    [[ $((minute_int%2)) -ne $parity_choice ]] && { log_msg "PARITY SKIP: minute=$minute_int parity_choice=$parity_choice"; return; }
    log_msg "PARITY GO: minute=$minute_int parity_choice=$parity_choice"

    # Pick new colour and brightness
    allowed=()
    for c in "${COLORS[@]}"; do
        if [[ "$c" != "$colour" ]]; then
            allowed+=("$c")
        fi
    done
    [[ ${#allowed[@]} -eq 0 ]] && allowed=("${COLORS[@]}")
    new_colour="${allowed[RANDOM % ${#allowed[@]}]}"
    target_brightness=$((RANDOM % (BRIGHT_MAX-BRIGHT_MIN+1) + BRIGHT_MIN))

    # Decide power action
    r=$((RANDOM % 100))
    if [[ $r -lt 20 ]]; then power_action="off"
    elif [[ $r -lt 45 ]]; then power_action="on"
    else power_action="leave"
    fi

    log_msg "DECISIONS: new_colour=$new_colour target_brightness=$target_brightness power_action=$power_action"

    colour="$new_colour"

    # --- OVERRIDE LOGIC ---
    if [[ "$power" = "off" && "$power_action" = "leave" ]]; then
        power_action="override"
        log_warn "State mismatch detected: state says OFF but action required  forcing power override"
    fi

    # Execute power_action
    case "$power_action" in
        off)
            [[ "$power" = "on" ]] && send_cmd "off" && power="off"
            save_state
            ;;
        on)
            [[ "$power" = "off" ]] && send_cmd "on" && sleep "$DIMDELAY" && power="on"
            send_cmd "$colour"
            apply_brightness_steps "$brightness" "$target_brightness"
            brightness=$target_brightness
            save_state
            ;;
        leave)
            [[ "$power" = "on" ]] && { send_cmd "$colour"; apply_brightness_steps "$brightness" "$target_brightness"; brightness=$target_brightness; }
            save_state
            ;;
        override)
            log_warn "POWER OVERRIDE: forcing ON to resync state"
            send_cmd "on"; sleep "$DIMDELAY"; power="on"
            send_cmd "$colour"; apply_brightness_steps "$brightness" "$target_brightness"; brightness=$target_brightness
            save_state
            ;;
    esac

    log_msg "STATE after: power=$power colour=$colour brightness=$brightness"
}

# -----------------------------
# Timing / loop control
# -----------------------------
random_sleep() {
    local maxsec="$1"
    [[ "$maxsec" -le 0 ]] && return
    rand=$((RANDOM % (maxsec+1)))
    [[ $DRYRUN -eq 1 ]] && log_msg "[DRY-RUN] Would sleep random ${rand}s (within ${maxsec}s)" || log_msg "Sleeping random ${rand}s (within ${maxsec}s)"
    [[ $DRYRUN -eq 0 ]] && sleep "$rand"
}

# Start logic
if [[ $DELAY_MODE -eq 0 && $RANDOM_MODE -eq 0 ]]; then run_wrapper; exit 0; fi
if [[ $DELAY_MODE -eq 0 && $RANDOM_MODE -eq 1 ]]; then
    log_msg "One-shot random mode: sleeping up to ${RANDOM_SECONDS}s then running once"
    random_sleep "$RANDOM_SECONDS"
    run_wrapper
    exit 0
fi
if [[ $DELAY_MODE -eq 1 ]]; then
    log_msg "Entering delay loop: delay=${DELAY_SECONDS}s random=${RANDOM_SECONDS}s"
    while true; do
        do_run=1
        if [[ $RANDOM_MODE -eq 1 ]]; then
            roll=$((RANDOM % (RANDOM_SECONDS + 1)))
            log_msg "Random gate roll=${roll}s threshold=${DELAY_SECONDS}s"
            [[ $roll -lt $DELAY_SECONDS ]] && do_run=1 || { do_run=0; log_msg "RANDOM SKIP: roll ${roll} >= ${DELAY_SECONDS} -> skipping this tick"; }
        fi
        [[ $do_run -eq 1 ]] && run_wrapper
        [[ $terminate -eq 1 ]] && { log_msg "Termination flag set; exiting loop"; break; }
        if [[ $DRYRUN -eq 1 ]]; then log_msg "[DRY-RUN] Would sleep ${DELAY_SECONDS}s before next tick"; sleep 1
        else sleep "$DELAY_SECONDS"; fi
    done
fi

exit 0
