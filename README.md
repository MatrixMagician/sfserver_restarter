# Satisfactory Server CPU Monitor

A systemd service and shell script to automatically restart a Satisfactory game server when CPU usage remains at 100% across 4 CPU cores for 10 minutes.

## Overview

This monitoring solution is designed for Satisfactory dedicated servers managed by [LinuxGSM](https://linuxgsm.com/) (Linux Game Server Manager). LinuxGSM is a command-line tool for deploying and managing Linux game servers, providing simple start/stop/restart functionality through dedicated user scripts.

The monitor detects when the `FactoryServer-Linux-Shipping` process sustains 400%+ CPU usage (utilizing all 4 cores) for 10 consecutive minutes, then safely restarts the server using LinuxGSM's built-in commands.

## Requirements

- Linux system with systemd
- Satisfactory dedicated server managed by LinuxGSM
- Dedicated `sfserver` user account (or equivalent LinuxGSM user)
- LinuxGSM `sfserver` script in the user's home directory
- 4+ CPU cores
- Root/sudo access for systemd service installation

## Installation

### 1. Install the monitoring script

```bash
# Switch to sfserver user
sudo su - sfserver

# Create the script
nano ~/sfserver-monitor.sh
# Copy content from sfserver-monitor.sh

# Make it executable
chmod +x ~/sfserver-monitor.sh
```

### 2. Install the systemd service

```bash
# Switch back to root/sudo user
exit

# Create the service file
sudo nano /etc/systemd/system/sfserver-monitor.service
# Copy content from sfserver-monitor.service

# Reload systemd and enable the service
sudo systemctl daemon-reload
sudo systemctl enable sfserver-monitor.service
```

### 3. Create log file with proper permissions

```bash
sudo touch /var/log/sfserver-monitor.log
sudo chown sfserver:sfserver /var/log/sfserver-monitor.log
sudo chmod 644 /var/log/sfserver-monitor.log
```

### 4. Start the monitoring service

```bash
sudo systemctl start sfserver-monitor.service
```

## Configuration

The script uses these default settings:
- **Process**: `FactoryServer-Linux-Shipping`
- **CPU Threshold**: 400% (4 cores at 100%)
- **Monitor Duration**: 10 minutes
- **Check Interval**: 30 seconds
- **Stop Wait Time**: 60 seconds before restart
- **Log File**: `/var/log/sfserver-monitor.log`

Modify the configuration variables in `sfserver-monitor.sh` to adjust these settings.

## Management

```bash
# Check service status
sudo systemctl status sfserver-monitor.service

# View real-time logs
sudo journalctl -u sfserver-monitor.service -f

# View custom log file
tail -f /var/log/sfserver-monitor.log

# Stop monitoring
sudo systemctl stop sfserver-monitor.service

# Restart monitoring
sudo systemctl restart sfserver-monitor.service
```

## How It Works

1. **Monitoring**: Checks CPU usage of the Satisfactory process every 30 seconds
2. **Threshold Detection**: Counts consecutive high CPU readings (≥400%)
3. **Restart Trigger**: After 20 consecutive high readings (10 minutes), initiates restart
4. **Safe Restart**: Uses LinuxGSM's `./sfserver stop`, waits 60 seconds, then `./sfserver start`
5. **Verification**: Confirms process termination before restart and successful startup after
6. **Recovery**: Resets counters when CPU usage normalizes

## Features

- ✅ Monitors only the Satisfactory server process
- ✅ Configurable CPU threshold and duration
- ✅ Safe restart with process verification
- ✅ Comprehensive logging with timestamps
- ✅ Automatic service restart on failure
- ✅ Graceful shutdown handling
- ✅ Resets monitoring when server restarts normally
