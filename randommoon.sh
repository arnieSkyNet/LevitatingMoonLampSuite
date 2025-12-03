#!/bin/bash
# randommoon.sh v0.01
# Levitating Moon Lamp Controller via IRTrans
# Portable, configurable, and ready for public use (GitHub)
# UK time zone, cron-friendly
# Features: random colour, brightness, power actions, odd/even minute skipping, persistent state
# CLI options: --nolog, --log <file>, --dry-run, --help

VER="0.01"
SCRIPT_NAME=$(basename "$0")
DEFAULT_LOG="/home/pi/log/arnie.log"

# -----------------------------
# User-configurable IR client settings
# -----------------------------
# Users should edit these for their environment
IRCLIENT="/home/pi/sbin/irclient"  # Path to IR client binary
IR_HOST="arnie"                     # IRTrans host; leave blank if not used
IR_DEVICE="VGAzerMoonLamp"          # Device name; leave blank if not used

# -----------------------------
# CLI option defaults
# -----------------------------
LOGMODE="on"
LOGFILE="$DEFAULT_LOG"
DRYRUN=0

# -----------------------------
# Logging function: all output prefixed
# -----------------------------
log_msg() {
    local msg="$1"
    local prefix="[$(date +%T) $SCRIPT_NAME v$VER]"
    if [[ "$LOGMODE" = "on" ]]; then
        echo "$prefix $msg" | tee -a "$LOGFILE"
    else
        echo "$prefix $msg"
    fi
}

# -----------------------------
# Show help
# -----------------------------
show_help() {
    cat <<EOF
$SCRIPT_NAME v$VER
Usage: $SCRIPT_NAME [OPTIONS]

Options:
  --nolog             Disable logging completely
  --log <file>        Log output to specified file
  --dry-run           Show commands but do not send to lamp
  --help              Show this help message

To use: edit the IRCLIENT, IR_HOST, and IR_DEVICE variables at the top
EOF
    exit 0
}

# -----------------------------
# Parse CLI options
# -----------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --nolog)
            LOGMODE="off"
            shift
            ;;
        --log)
            if [[ -n "$2" ]]; then
                LOGFILE="$2"
                LOGMODE="on"
                shift 2
            else
                echo "Error: --log requires a filename"
                exit 1
            fi
            ;;
        --dry-run)
            DRYRUN=1
            shift
            ;;
        --help)
            show_help
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            ;;
    esac
done

# -----------------------------
# Main wrapper for logging
# -----------------------------
run_wrapper() {
    log_msg "started"
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

    COLORS=(white red orange pink peach yellow green bluegreen skyblue beachblue seablue royalblue mauve purple crimson lilac)
    BRIGHT_MIN=0
    BRIGHT_MAX=4

    exec 200>"$LOCKFILE"
    flock -n 200 || { log_msg "Another instance running; exiting."; return; }

    pick_random() {
        local list=("$@")
        local count=${#list[@]}
        local index=$((RANDOM % count))
        echo "${list[$index]}"
    }

    send_cmd() {
        local cmd="$1"
        local full_cmd="$IRCLIENT ${IR_HOST:-localhost} ${IR_DEVICE:-MoonLamp} $cmd"
        log_msg "EXEC: $full_cmd"
        if [[ $DRYRUN -eq 0 ]] && [[ -n "$IRCLIENT" ]]; then
            "$IRCLIENT" "${IR_HOST:-localhost}" "${IR_DEVICE:-MoonLamp}" "$cmd"
        fi
    }

    apply_brightness_steps() {
        local from=$1
        local to=$2
        if [[ "$from" -eq "$to" ]]; then
            log_msg "Brightness already at $from; no steps needed."
            return
        fi
        if [[ "$from" -lt "$to" ]]; then
            steps=$((to - from))
            for i in $(seq 1 "$steps"); do
                send_cmd "brighter"
                sleep 0.4
            done
        else
            steps=$((from - to))
            for i in $(seq 1 "$steps"); do
                send_cmd "dim"
                sleep 0.4
            done
        fi
    }

    state_init() {
        power="on"
        colour="white"
        brightness=2
    }

    if [[ -f "$STATEFILE" ]]; then
        . "$STATEFILE" 2>/dev/null || state_init
        [[ "$power" != "on" && "$power" != "off" ]] && power="on"
        [[ ! "$brightness" =~ ^[0-9]+$ ]] && brightness=2
        ((brightness<BRIGHT_MIN)) && brightness=$BRIGHT_MIN
        ((brightness>BRIGHT_MAX)) && brightness=$BRIGHT_MAX
        found=0
        for c in "${COLORS[@]}"; do [[ "$c" = "$colour" ]] && found=1; done
        [[ $found -eq 0 ]] && colour="white"
    else
        state_init
    fi

    save_state() {
        tmp=$(mktemp "/tmp/randommoon_state.XXXX")
        {
            echo "power=$power"
            echo "colour=$colour"
            echo "brightness=$brightness"
        } > "$tmp"
        mv "$tmp" "$STATEFILE"
        chmod 600 "$STATEFILE"
    }

    log_msg "STATE before: power=$power colour=$colour brightness=$brightness"

    # Odd/even minute random skip
    minute=$(date +%M)
    minute_int=$((10#$minute))
    parity_choice=$((RANDOM % 2))
    minute_parity=$((minute_int % 2))
    if [[ "$minute_parity" -ne "$parity_choice" ]]; then
        log_msg "PARITY SKIP: minute=$minute_int parity_choice=$parity_choice"
        return
    fi
    log_msg "PARITY GO: minute=$minute_int parity_choice=$parity_choice"

    # Pick new colour
    allowed=()
    for c in "${COLORS[@]}"; do [[ "$c" != "$colour" ]] && allowed+=("$c"); done
    [[ ${#allowed[@]} -eq 0 ]] && allowed=("${COLORS[@]}")
    new_colour="${allowed[RANDOM % ${#allowed[@]}]}"

    target_brightness=$((RANDOM % (BRIGHT_MAX - BRIGHT_MIN + 1) + BRIGHT_MIN))

    r=$((RANDOM % 100))
    if [[ "$r" -lt 20 ]]; then
        power_action="off"
    elif [[ "$r" -lt 45 ]]; then
        power_action="on"
    else
        power_action="leave"
    fi

    log_msg "DECISIONS: new_colour=$new_colour target_brightness=$target_brightness power_action=$power_action"

    colour="$new_colour"

    case "$power_action" in
        off)
            if [[ "$power" = "on" ]]; then
                send_cmd "off"
                power="off"
            fi
            save_state
            ;;
        on)
            if [[ "$power" = "off" ]]; then
                send_cmd "on"
                sleep 0.6
                power="on"
            fi
            send_cmd "$colour"
            apply_brightness_steps "$brightness" "$target_brightness"
            brightness=$target_brightness
            save_state
            ;;
        leave)
            if [[ "$power" = "on" ]]; then
                send_cmd "$colour"
                apply_brightness_steps "$brightness" "$target_brightness"
                brightness=$target_brightness
            fi
            save_state
            ;;
    esac

    log_msg "STATE after: power=$power colour=$colour brightness=$brightness"
}

# -----------------------------
# Execute main wrapper
# -----------------------------
run_wrapper

