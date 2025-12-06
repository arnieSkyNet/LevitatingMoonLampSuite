#!/bin/bash
# randommoon.sh v0.02
# Levitating Moon Lamp Controller via IRTrans
# Portable, configurable, and ready for public use (GitHub)
# UK time zone, cron-friendly
# Features: random colour, brightness, power actions, odd/even minute skipping, persistent state
# New (v0.02): --delay/-d (loop), --random/-r (random window), combined behaviour
# CLI options: --nolog, --log <file>, --dry-run, --delay <N[s|m|h]>, --random <N[s|m|h]>, --help
 
VER="0.02"
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
DELAY_MODE=0
DELAY_SECONDS=0
RANDOM_MODE=0
RANDOM_SECONDS=0

# -----------------------------
# Logging function: all output prefixed
# -----------------------------
timestamp() { date +%T; }   # HH:MM:SS
log_msg() {
    local msg="$1"
    local prefix="[$(timestamp) $SCRIPT_NAME v$VER]"
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
  --nolog                 Disable logging completely
  --log <file>            Log output to specified file
  --dry-run               Show commands but do not send to lamp
  --delay <N[s|m|h]>, -d  Run continuously every N seconds/minutes/hours (daemon-ish)
  --random <N[s|m|h]>, -r Run with random window:
                           * If used alone: sleep random(0..N) then run once and exit
                           * If used with --delay: on each tick roll random(0..N), if roll < delay -> run
  --help                  Show this help message

Notes:
- Units: s = seconds, m = minutes, h = hours (required)
- Examples:
    ./randommoon.sh                      # single run (cron-friendly)
    ./randommoon.sh -d 6m                # run loop every 6 minutes (keep running)
    ./randommoon.sh -r 15m               # one-shot: wait random(0..15m), then run once
    ./randommoon.sh -d 10m -r 4m         # loop every 10m; each tick random gate within 4m
    @reboot /path/to/randommoon.sh -d 6m
EOF
    exit 0
}

# -----------------------------
# Helper: parse interval like 6m, 30s, 2h -> seconds
# Returns 0 on success (echo seconds), non-zero on failure
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
        --delay|-d)
            if [[ -n "$2" ]]; then
                sec=$(parse_interval_to_seconds "$2") || { echo "Invalid --delay value: $2"; exit 1; }
                DELAY_MODE=1
                DELAY_SECONDS="$sec"
                shift 2
            else
                echo "Error: --delay requires a value like 6m"
                exit 1
            fi
            ;;
        --random|-r)
            if [[ -n "$2" ]]; then
                sec=$(parse_interval_to_seconds "$2") || { echo "Invalid --random value: $2"; exit 1; }
                RANDOM_MODE=1
                RANDOM_SECONDS="$sec"
                shift 2
            else
                echo "Error: --random requires a value like 15m"
                exit 1
            fi
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
# Signal handling for clean exit in loop mode
# -----------------------------
terminate=0
_on_term() {
    terminate=1
    log_msg "Received termination signal; exiting loop"
}
trap _on_term SIGINT SIGTERM

# -----------------------------
# Main wrapper for logging
# -----------------------------
run_wrapper() {
    log_msg "started (mode: $( [[ $DELAY_MODE -eq 1 ]] && echo loop || echo single ))"
    run_logic
    log_msg "ended"
}

# -----------------------------
# Main moon lamp logic (unchanged core behavior)
# -----------------------------
run_logic() {
    export TZ="Europe/London"

    STATEFILE="$HOME/.moonlamp_state"
    LOCKFILE="/tmp/randommoon.lock"

    COLORS=(white red orange pink peach yellow green bluegreen skyblue beachblue seablue royalblue mauve purple crimson lilac)
    BRIGHT_MIN=0
    BRIGHT_MAX=4

    # Acquire lock inside run_logic to avoid multiple simultaneous runs
    exec 200>"$LOCKFILE"
    flock -n 200 || { log_msg "Another instance running; exiting run_logic."; return; }

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
    # flock lock released when function ends and FD closed
}

# -----------------------------
# Timing / loop control
# -----------------------------
# Behavior summary:
# - No flags: single run (existing behavior)
# - RANDOM only: one-shot sleep random(0..RANDOM_SECONDS); run once; exit
# - DELAY only: loop forever; run every DELAY_SECONDS
# - DELAY + RANDOM: loop forever; each tick roll random(0..RANDOM_SECONDS):
#       if roll < DELAY_SECONDS -> execute run_logic; else skip
# All runs still subject to lockfile/parity inside run_logic

# Helper: random sleep (seconds)
random_sleep() {
    local maxsec="$1"
    if [[ "$maxsec" -le 0 ]]; then return; fi
    rand=$((RANDOM % (maxsec + 1)))   # 0..maxsec inclusive
    if [[ $DRYRUN -eq 1 ]]; then
        log_msg "[DRY-RUN] Would sleep random ${rand}s (within ${maxsec}s)"
    else
        log_msg "Sleeping random ${rand}s (within ${maxsec}s)"
        sleep "$rand"
    fi
}

# Start logic
if [[ $DELAY_MODE -eq 0 && $RANDOM_MODE -eq 0 ]]; then
    # Single run (cron-friendly)
    run_wrapper
    exit 0
fi

# RANDOM only -> one-shot: sleep random(0..RANDOM_SECONDS) then run once
if [[ $DELAY_MODE -eq 0 && $RANDOM_MODE -eq 1 ]]; then
    if [[ $DRYRUN -eq 1 ]]; then
        log_msg "[DRY-RUN] One-shot random mode: would sleep up to ${RANDOM_SECONDS}s then run once"
        random_sleep "$RANDOM_SECONDS"
        run_wrapper
    else
        log_msg "One-shot random mode: sleeping up to ${RANDOM_SECONDS}s then running once"
        random_sleep "$RANDOM_SECONDS"
        run_wrapper
    fi
    exit 0
fi

# DELAY loop (with or without RANDOM)
if [[ $DELAY_MODE -eq 1 ]]; then
    log_msg "Entering delay loop: delay=${DELAY_SECONDS}s random=${RANDOM_SECONDS}s"
    while true; do
        # If random mode enabled, decide whether to run this tick
        do_run=1
        if [[ $RANDOM_MODE -eq 1 ]]; then
            roll=$((RANDOM % (RANDOM_SECONDS + 1)))  # 0..RANDOM_SECONDS
            if [[ $DRYRUN -eq 1 ]]; then
                log_msg "[DRY-RUN] Random gate roll=${roll}s threshold=${DELAY_SECONDS}s"
            else
                log_msg "Random gate roll=${roll}s threshold=${DELAY_SECONDS}s"
            fi
            if [[ $roll -lt $DELAY_SECONDS ]]; then
                do_run=1
                log_msg "RANDOM GO: roll ${roll} < ${DELAY_SECONDS} -> will run this tick"
            else
                do_run=0
                log_msg "RANDOM SKIP: roll ${roll} >= ${DELAY_SECONDS} -> skipping this tick"
            fi
        fi

        if [[ $do_run -eq 1 ]]; then
            run_wrapper
        fi

        # Exit if termination requested
        if [[ $terminate -eq 1 ]]; then
            log_msg "Termination flag set; exiting loop"
            break
        fi

        # Sleep for the fixed delay (DELAY_SECONDS)
        if [[ $DRYRUN -eq 1 ]]; then
            log_msg "[DRY-RUN] Would sleep ${DELAY_SECONDS}s before next tick"
            # do not actually sleep long in dry-run; short pause for readability
            sleep 1
        else
            sleep "$DELAY_SECONDS"
        fi
    done
fi

exit 0

