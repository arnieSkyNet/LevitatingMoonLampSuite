# LevitatingMoonLampSuite

![License](https://img.shields.io/badge/license-MIT-green)
![Bash](https://img.shields.io/badge/language-Bash-yellow)
![PowerShell](https://img.shields.io/badge/language-PowerShell-blue)
![Last Commit](https://img.shields.io/github/last-commit/ArnieSkyNet/LevitatingMoonLampSuite)
![Platform](https://img.shields.io/badge/platform-RaspberryPi%2C-Windows-blue)
![Infrared](https://img.shields.io/badge/IR-IRTrans-orange)

Control and automate your levitating moon lamp with this suite of scripts. Features include randomised colour and brightness changes, power control, moon phase awareness via `moonphase.sh` (Linux) or `moonphase.ps1` (Windows), persistent state between runs, and fully configurable IR client settings. Cron-compatible on Linux (Raspberry Pi) and adaptable for Windows environments.

## Features

- Randomised colour changes with brightness and power control (`randommoon.sh` / `randommoon.ps1`)
- Moon phase-based control with per-year events and special Full Moon highlights (`moonphase.sh` / `moonphase.ps1`)
- Persistent state between runs (remembers last colour and brightness)
- Configurable IR client, host, and device settings
- Manual overrides, reset, and custom IR commands
- Dry-run mode for testing without sending
- Cron-compatible or scheduled task-compatible for automated execution
- Portable for Raspberry Pi and Windows systems
- Continuous run mode with fixed (`--delay`) or randomised (`--random`) intervals
- Per-year moon events data files (user-editable, default location `~/Documents/` or `%USERPROFILE%\Documents\`)
- Automatic fallback when yearly moon events file is missing
- Reset command to return lamp to a known OFF state
- Moon phase and special lunar events are read from a per-year external data file
- Current script version: v0.02

## Included Scripts

### Linux

- **randommoon.sh**: Randomly sets the VGAzer Moon Lamp colours and brightness. Supports manual colour override, reset, custom commands, continuous run, and randomised delay intervals.
- **moonphase.sh**: Controls the VGAzer Moon Lamp based on lunar phases and per-year moon events. Supports night-only operation (18:0006:59 UK time), manual colour override, reset, and custom IR commands.

### Windows

- **randommoon.ps1**: PowerShell version of randomised colour and brightness control. Supports manual colour override, reset, custom commands, continuous run, and randomised delay intervals.
- **moonphase.ps1**: PowerShell version of moon phase control using per-year events. Supports night-only operation (18:0006:59 UK time), manual colour override, reset, and custom IR commands.
- **Moon Events File**: `moon_events_<YEAR>.txt` stored in `~/Documents/` (Linux) or `%USERPROFILE%\Documents\` (Windows) by default. Specify special moon events such as Blood Moon, Supermoon, Micromoon, and seasonal full moons with associated colours.

## Installation

### Linux

1. Clone the repository:

    git clone https://github.com/ArnieSkyNet/LevitatingMoonLampSuite.git
    cd LevitatingMoonLampSuite

2. Edit the top of scripts to configure your IR client:

       IRCLIENT="/home/pi/sbin/irclient"  # Path to your IR client binary
       IR_HOST="arnie"                     # IRTrans host (leave blank if not used)
       IR_DEVICE="VGAzerMoonLamp"          # Device name (leave blank if not used)

3. Make scripts executable:

       chmod +x randommoon.sh moonphase.sh

### Windows

1. Copy the scripts to a folder, e.g., `C:\MoonLampSuite\`.
2. Edit the top of scripts to configure your IR client:

       $IRCLIENT = "C:\Program Files\IRTrans\IRClient.exe"
       $IR_HOST = "localhost"
       $IR_DEVICE = "VGAzerMoonLamp"
       $MOONEVENTSLOC = "$env:USERPROFILE\Documents"

3. Run scripts via PowerShell. Ensure the execution policy allows running scripts:

       Set-ExecutionPolicy -Scope CurrentUser RemoteSigned

## Usage

### Linux

    ./randommoon.sh               # Run with default logging
    ./moonphase.sh                # Run night-only with moon phase logic
    ./randommoon.sh --dry-run     # Show commands without sending
    ./moonphase.sh --colour pink  # Manual colour override
    ./moonphase.sh --reset        # Turn lamp off
    ./moonphase.sh --command flash # Send custom IR command
    ./randommoon.sh --help        # Display help

### Windows

    .\randommoon.ps1
    .\moonphase.ps1
    .\randommoon.ps1 --dry-run
    .\moonphase.ps1 --colour pink
    .\moonphase.ps1 --reset
    .\moonphase.ps1 --command flash
    .\randommoon.ps1 --help

### Optional parameters for continuous or random execution (both Linux & Windows):

- `--delay <Ns|Nm|Nh>`  run continuously, repeating every fixed interval
- `--random <Ns|Nm|Nh>`  run continuously, sleeping a random amount of time up to the specified limit between executions
- `--reset` or `-r`  immediately sends OFF to reset the lamp to its default state
- `--colour <color>` / `--color <color>`  manual colour override
- `--command <cmd>` / `-c <cmd>`  send custom IR command
- `--dry-run`  show commands without sending
- `--help`  display help

**Notes:**

- `--random` works even if `--delay` is not provided, so scripts can be cron-safe (Linux) or task scheduler-safe (Windows).
- `moonphase` scripts only run during night hours (18:0006:59 UK time) and read per-year moon events; if the current years file is missing, the previous year is copied and used, with a log warning.

## Cron / Scheduled Task Example

### Linux

Run `randommoon.sh` every 15 minutes between 07:0017:00:

    */15 7-17 * * * /home/pi/LevitatingMoonLampSuite/randommoon.sh

Run `moonphase.sh` nightly between 18:0006:59:

    0 18 * * * /home/pi/LevitatingMoonLampSuite/moonphase.sh
    0 0-6 * * * /home/pi/LevitatingMoonLampSuite/moonphase.sh

### Windows

Use Task Scheduler to run scripts:

- `randommoon.ps1`  trigger every 15 minutes or as desired.
- `moonphase.ps1`  trigger nightly between 18:0006:59.

## Logging

- Default log file: `/home/pi/log/arnie.log` (Linux) or `%USERPROFILE%\Documents\MoonPhaseLamp.log` (Windows)
- Logs include timestamp, script name, and version for easy tracking
- Example log line format: `[19:36:49 randommoon.sh v0.01] EXEC: /home/pi/sbin/irclient arnie VGAzerMoonLamp purple`
- Both Linux and Windows scripts use the same logging style

## Remote File (IRTrans `.rem` file)

This suite uses an [IRTrans](http://www.irtrans.de/en) `.rem` remote profile to control the moon lamp.  
All `.rem` files, including [`VGAzerMoonLamp.rem`](https://github.com/ArnieSkyNet/IRTrans-Remotes), are maintained in a dedicated repository:

**IRTrans-Remotes**  
[https://github.com/ArnieSkyNet/IRTrans-Remotes](https://github.com/ArnieSkyNet/IRTrans-Remotes)

## Notes

- Manual overrides (`--colour` / `--color`), resets (`--reset` / `-r`), and custom IR commands (`--command` / `-c`) are supported in all scripts.
- Moon phase scripts read the per-year events file; if the current year file does not exist, the previous years file is copied and a log warning is issued for the user to update.

