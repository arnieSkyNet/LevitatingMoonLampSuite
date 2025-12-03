# LevitatingMoonLampSuite

Control and automate your levitating moon lamp with this suite of scripts. Features include randomised colour and brightness changes, power control, optional Full Moon highlights, and persistent state between runs. Fully configurable for different IR clients and devices, cron-compatible on Linux (Raspberry Pi), and adaptable for Windows environments.

## Features

- Randomised colour changes with brightness and power control
- Persistent state between runs (remembers last colour and brightness)
- Optional Full Moon highlight scripts
- Configurable IR client, host, and device settings
- Dry-run mode for testing without sending commands
- Cron-compatible for automated scheduling
- Portable for Raspberry Pi and adaptable to Windows systems

## Installation

1. Clone the repository:

    git clone https://github.com/yourusername/LevitatingMoonLampSuite.git
    cd LevitatingMoonLampSuite

2. Edit the top of `randommoon.sh` (and other scripts if applicable) to configure your IR client:

       IRCLIENT="/home/pi/sbin/irclient"  # Path to your IR client binary
       IR_HOST="arnie"                     # IRTrans host (leave blank if not used)
       IR_DEVICE="VGAzerMoonLamp"          # Device name (leave blank if not used)

3. Make scripts executable:

       chmod +x randommoon.sh

## Usage

Run the scripts directly:

    ./randommoon.sh           # Run with default logging
    ./randommoon.sh --nolog   # Disable logging
    ./randommoon.sh --log /path/to/logfile.log   # Log to custom file
    ./randommoon.sh --dry-run # Show commands without sending
    ./randommoon.sh --help    # Display help

## Cron Job Example

Run every 15 minutes:

    */15 * * * * /home/pi/LevitatingMoonLampSuite/randommoon.sh

## Logging

- Default log file: `/home/pi/log/arnie.log`
- Logs include timestamp and script version for easy tracking
- Example log line format: `[19:36:49 randommoon.sh v0.01] EXEC: /home/pi/sbin/irclient arnie VGAzerMoonLamp purple`

## Future Enhancements

- Integration with lunar cycles for Full Moon overrides
- Windows-specific implementation (GUI or background service)
- Additional lamp presets or colour schemes
