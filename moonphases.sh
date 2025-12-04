#!/bin/bash
#
# moonlamp.sh  v0.01 Set levitating moon lamp colour based on REAL moon events
# UK timezone + special moons + randomised modes + IRTrans
#
# Trigger: cron @ 07:00 UK time
# Runs:    irclient arnie VGAzerMoonLamp <colour>
LOGFILE="/home/pi/log/arnie.log"
SCRIPT_NAME=$(basename "$0")


{
	echo "$SCRIPT_NAME $1 started at $(date)"

export TZ="Europe/London"

############################################
# 1. Today's UK date
############################################
year=$(date +%Y)
month=$(date +%m)
day=$(date +%d)

############################################
# Utility: random colour picker
############################################
pick_random() {
    # Takes a space-separated list, returns one item
    local list=("$@")
    local count=${#list[@]}
    local index=$((RANDOM % count))
    echo "${list[$index]}"
}

############################################
# 2. Calculate moon phase (07)
############################################
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

############################################
# 3. Base phase-colour mapping
############################################
case "$phase" in
    0) colour="royalblue" ;;        # New Moon
    1) colour="white" ;;        # Waxing Crescent
    2) colour="white" ;;        # First Quarter
    3) colour="skyblue" ;;      # Waxing Gibbous
    4) colour="yellow" ;;       # Full Moon
    5) colour="green" ;;        # Waning Gibbous
    6) colour="white" ;;        # Last Quarter
    7) colour="lilac" ;;        # Waning Crescent
esac

############################################
# 4. Randomised rotations for chosen phases
#
# Examples:
#   Full Moon (4) gets rotating "white yellow peach"
#   Waxing Gibbous (3) rotates between "skyblue beachblue royalblue"
#   New Moon (0) rotates between dim/atmospheric colours
############################################

if [ "$phase" -eq 3 ]; then
    # Waxing Gibbous colour rotation
    colour=$(pick_random skyblue beachblue royalblue)
fi

if [ "$phase" -eq 4 ]; then
    # Full Moon rotation
    colour=$(pick_random white yellow peach)
fi

if [ "$phase" -eq 0 ]; then
    # New Moon rotation
    colour=$(pick_random flash mauve lilac purple)
fi

############################################
# 5. Special moon dates (UK TIME SPECIFIC)
#
# Pink Moon = April full moon
# Strawberry Moon = June full moon
# etc.
############################################

# FULL MOON DATES FOR 2025 (UK time)
# (If you want other years, I will generate automatically)
case "$month-$day" in
    "01-14"| "02-12"| "03-14"| "04-13"| "05-12"|"06-11"|"07-10"|"08-09"|"09-08"|"10-07"|"11-05"|"12-04")
        is_full=1 ;;
    *) is_full=0 ;;
esac

# Named full moons by month:
if [ "$is_full" -eq 1 ]; then
    case "$month" in
        "01") colour="skyblue" ;;                 # Wolf Moon
        "02") colour="white" ;;                   # Snow Moon
        "03") colour="green" ;;                   # Worm Moon
        "04") colour="pink" ;;                    # Pink Moon <8
        "05") colour="pink" ;;                    # Flower Moon
        "06") colour="peach" ;;                   # Strawberry Moon <S
        "07") colour="yellow" ;;                  # Buck Moon
        "08") colour="beachblue" ;;               # Sturgeon Moon
        "09") colour="orange" ;;                  # Harvest Moon <>
        "10") colour="orange" ;;                  # Hunters Moon
        "11") colour="skyblue" ;;                 # Beaver Moon
        "12") colour="mauve" ;;                   # Cold Moon
    esac
fi

############################################
# 6. Iron-clad special overrides:
#    Blood Moon (total lunar eclipse)
#    Blue Moon (seasonal)
#    Supermoon / Micromoon
############################################

# KNOWN 2025 UK LUNAR ECLIPSES (Blood Moons)
# 2025: total lunar eclipse on 7 March 2025
if [ "$year-$month-$day" = "2025-03-07" ]; then
    colour="crimson"
fi

# 2025 Blue Moon  no genuine seasonal blue moon this year
# But if wanted:
if [ "$month-$day" = "08-09" ]; then colour="royalblue"; fi

# For 2025 Supermoons (perigee full moons)
case "$year-$month-$day" in
    "2025-10-07"|"2025-11-05")
        colour="white" ;;       # Supermoon = brightest
esac

# Micromoons (apogee full moons)
case "$year-$month-$day" in
    "2025-03-14"|"2025-04-13")
        colour="mauve" ;;
esac

############################################
# 7. Execute IRTrans command
############################################

############################################
# Full Moon override:
# Turn lamp ON, then set special colour WHITE
############################################

if [ "$phase" -eq 4 ]; then
    # Switch lamp ON using its last state (if off)
    /home/pi/sbin/irclient arnie VGAzerMoonLamp on
    sleep 1   # allow IRTrans to process ON before colour

    # Override Full Moon colour
    colour="white"
fi

/home/pi/sbin/irclient arnie VGAzerMoonLamp "$colour"

echo "Moon lamp set to: $colour (UK time: $(date))"


echo "$SCRIPT_NAME ended at $(date)"
} 2>&1 | tee -a "$LOGFILE"
