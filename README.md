# LevitatingMoonLampSuite

![License](https://img.shields.io/badge/license-MIT-green)
![Bash](https://img.shields.io/badge/language-Bash-yellow)
![Last Commit](https://img.shields.io/github/last-commit/ArnieSkyNet/LevitatingMoonLampSuite)
![Platform](https://img.shields.io/badge/platform-RaspberryPi-blue)
![Infrared](https://img.shields.io/badge/IR-IRTrans-orange)

Control and automate your levitating moon lamp with this suite of scripts. Features include randomised colour and brightness changes, power control, moon phase awareness via `moonphase.sh`, persistent state between runs, and fully configurable IR client settings. Cron-compatible on Linux (Raspberry Pi) and adaptable for Windows environments.

## Features

- Randomised colour changes with brightness and power control (`randommoon.sh`)
- Moon phase-based control with per-year events and special Full Moon highlights (`moonphase.sh`)
- Persistent state between runs (remembers last colour and brightness)
- Configurable IR client, host, and device settings
- Manual overrides, reset, and custom IR commands
- Dry-run mode for testing without sending commands
- Cron-compatible for automated scheduling
- Portable for Raspberry Pi and adaptable to Windows systems

## Included Scripts

- **randommoon.sh**: Randomly sets the VGAzer Moon Lamp colours and brightness. Supports manual colour override, reset, and custom commands.
- **moonphase.sh**: Controls the VGAzer Moon Lamp based on lunar phases and per-year moon events. Supports night-only operation (18:0006:59 UK time), manual colour override, reset, and custom IR commands.
- **Moon Events File**: `moon_events_<YEAR>.txt` stored in `~/Documents/` by default. Specify special moon events such as Blood Moon, Supermoon, Micromoon, and seasonal full moons with associated colours.

## Installation

1. Clone the repository:

    git clone https://github.com/ArnieSkyNet/LevitatingMoonLampSuite.git
    cd LevitatingMoonLampSuite

2. Edit the top of scripts to configure your IR client:

       IRCLIENT="/home/pi/sbin/irclient"  # Path to your IR client binary
       IR_HOST="arnie"                     # IRTrans host (leave blank if not used)
       IR_DEVICE="VGAzerMoonLamp"          # Device name (leave blank if not used)

3. Make scripts executable:

       chmod +x randommoon.sh moonphase.sh

## Usage

Run the scripts directly:

    ./randommoon.sh               # Run with default logging
    ./moonphase.sh                # Run night-only with moon phase logic
    ./randommoon.sh --dry-run     # Show commands without sending
    ./moonphase.sh --colour pink  # Manual colour override
    ./moonphase.sh --reset        # Turn lamp off
    ./moonphase.sh --command flash # Send custom IR command
    ./randommoon.sh --help        # Display help

## Cron Job Example

Run `randommoon.sh` every 15 minutes between 07:0017:00:

    */15 7-17 * * * /home/pi/LevitatingMoonLampSuite/randommoon.sh

Run `moonphase.sh` nightly between 18:0006:59:

    0 18 * * * /home/pi/LevitatingMoonLampSuite/moonphase.sh
    0 0-6 * * * /home/pi/LevitatingMoonLampSuite/moonphase.sh

## Logging

- Default log file: `/home/pi/log/arnie.log`
- Logs include timestamp, script name, and version for easy tracking
- Example log line format: `[19:36:49 randommoon.sh v0.01] EXEC: /home/pi/sbin/irclient arnie VGAzerMoonLamp purple`
- Both `randommoon.sh` and `moonphase.sh` use the same logging style

## Remote File (IRTrans `.rem` file)

This suite uses an [IRTrans](http://www.irtrans.de/en) `.rem` remote profile to control the moon lamp.  
All `.rem` files, including [`VGAzerMoonLamp.rem`](https://github.com/ArnieSkyNet/IRTrans-Remotes) required for this project, are maintained in a dedicated repository:

**IRTrans-Remotes**  
[https://github.com/ArnieSkyNet/IRTrans-Remotes](https://github.com/ArnieSkyNet/IRTrans-Remotes)

## Notes

- Manual overrides (`--colour` / `--color`), resets (`--reset` / `-r`), and custom IR commands (`--command` / `-c`) are supported in both scripts.
- `moonphase.sh` reads the per-year events file; if the current year file does not exist, it copies the previous years file and logs a warning for the user to update.

