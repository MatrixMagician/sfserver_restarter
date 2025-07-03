#!/bin/bash

# Satisfactory Server CPU Monitor
# Monitors FactoryServer-Linux-Shipping process and restarts if CPU usage >= 400% for 10 minutes
# Author: Oliver Hingst and Claude
# Version: 1.0

# Configuration
PROCESS_NAME="FactoryServer-Linux-Shipping"
CPU_THRESHOLD=400  # 400% (4 cores at 100%)
MONITOR_DURATION=600  # 10 minutes in seconds
CHECK_INTERVAL=30     # Check every 30 seconds
LOG_FILE="/var/log/sfserver-monitor.log"
SFSERVER_SCRIPT="$HOME/sfserver"
STOP_WAIT_TIME=60     # Wait 1 minute after stop before restart

# Counters
high_cpu_count=0
total_checks=$((MONITOR_DURATION / CHECK_INTERVAL))

# Logging function
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Function to get CPU usage for the Satisfactory process
get_process_cpu() {
    local pid=$(pgrep -f "$PROCESS_NAME" | head -1)
    if [[ -z "$pid" ]]; then
        echo "0"
        return 1
    fi
    
    # Get CPU usage using ps (returns cumulative CPU percentage)
    local cpu_usage=$(ps -p "$pid" -o %cpu --no-headers 2>/dev/null | tr -d ' ')
    if [[ -z "$cpu_usage" ]]; then
        echo "0"
        return 1
    fi
    
    # Convert to integer (remove decimal point)
    cpu_usage=$(echo "$cpu_usage" | cut -d'.' -f1)
    echo "${cpu_usage:-0}"
    return 0
}

# Function to check if process is running
is_process_running() {
    pgrep -f "$PROCESS_NAME" >/dev/null 2>&1
}

# Function to stop the server
stop_server() {
    log_message "INFO" "Attempting to stop Satisfactory server..."
    
    if [[ -x "$SFSERVER_SCRIPT" ]]; then
        "$SFSERVER_SCRIPT" stop
        local stop_exit_code=$?
        
        if [[ $stop_exit_code -eq 0 ]]; then
            log_message "INFO" "Stop command executed successfully"
        else
            log_message "WARN" "Stop command returned non-zero exit code: $stop_exit_code"
        fi
    else
        log_message "ERROR" "sfserver script not found or not executable at: $SFSERVER_SCRIPT"
        return 1
    fi
    
    # Wait and verify the process has stopped
    local wait_count=0
    local max_wait=12  # Wait up to 2 minutes (12 * 10 seconds)
    
    while is_process_running && [[ $wait_count -lt $max_wait ]]; do
        sleep 10
        ((wait_count++))
        log_message "INFO" "Waiting for server to stop... ($((wait_count * 10))s)"
    done
    
    if is_process_running; then
        log_message "ERROR" "Server process still running after stop command. Manual intervention may be required."
        return 1
    else
        log_message "INFO" "Server process confirmed stopped"
        return 0
    fi
}

# Function to start the server
start_server() {
    log_message "INFO" "Waiting $STOP_WAIT_TIME seconds before restart..."
    sleep "$STOP_WAIT_TIME"
    
    log_message "INFO" "Attempting to start Satisfactory server..."
    
    if [[ -x "$SFSERVER_SCRIPT" ]]; then
        "$SFSERVER_SCRIPT" start
        local start_exit_code=$?
        
        if [[ $start_exit_code -eq 0 ]]; then
            log_message "INFO" "Start command executed successfully"
            
            # Wait a moment and verify the process started
            sleep 15
            if is_process_running; then
                log_message "INFO" "Server process confirmed running"
                return 0
            else
                log_message "WARN" "Start command succeeded but process not detected running"
                return 1
            fi
        else
            log_message "ERROR" "Start command returned non-zero exit code: $start_exit_code"
            return 1
        fi
    else
        log_message "ERROR" "sfserver script not found or not executable at: $SFSERVER_SCRIPT"
        return 1
    fi
}

# Function to restart the server
restart_server() {
    log_message "WARN" "HIGH CPU DETECTED: Restarting Satisfactory server due to sustained high CPU usage"
    
    if stop_server; then
        if start_server; then
            log_message "INFO" "Server restart completed successfully"
            # Reset counters after successful restart
            high_cpu_count=0
        else
            log_message "ERROR" "Server restart failed - start phase failed"
        fi
    else
        log_message "ERROR" "Server restart failed - stop phase failed"
    fi
}

# Signal handlers for graceful shutdown
cleanup() {
    log_message "INFO" "Monitor received shutdown signal, exiting gracefully"
    exit 0
}

trap cleanup SIGTERM SIGINT

# Main monitoring loop
log_message "INFO" "Starting Satisfactory Server CPU Monitor"
log_message "INFO" "Process: $PROCESS_NAME"
log_message "INFO" "CPU Threshold: ${CPU_THRESHOLD}%"
log_message "INFO" "Monitor Duration: ${MONITOR_DURATION}s (${total_checks} checks)"
log_message "INFO" "Check Interval: ${CHECK_INTERVAL}s"

while true; do
    # Check if the process is running
    if ! is_process_running; then
        log_message "INFO" "Satisfactory server process not running, resetting counters"
        high_cpu_count=0
        sleep "$CHECK_INTERVAL"
        continue
    fi
    
    # Get current CPU usage
    current_cpu=$(get_process_cpu)
    cpu_status=$?
    
    if [[ $cpu_status -ne 0 ]]; then
        log_message "WARN" "Could not retrieve CPU usage for process"
        high_cpu_count=0
        sleep "$CHECK_INTERVAL"
        continue
    fi
    
    # Check if CPU usage exceeds threshold
    if [[ $current_cpu -ge $CPU_THRESHOLD ]]; then
        ((high_cpu_count++))
        log_message "WARN" "High CPU detected: ${current_cpu}% (${high_cpu_count}/${total_checks} checks)"
        
        # Check if we've exceeded the duration threshold
        if [[ $high_cpu_count -ge $total_checks ]]; then
            restart_server
        fi
    else
        # Reset counter if CPU usage is below threshold
        if [[ $high_cpu_count -gt 0 ]]; then
            log_message "INFO" "CPU usage normalized: ${current_cpu}%, resetting counter"
            high_cpu_count=0
        else
            log_message "DEBUG" "CPU usage normal: ${current_cpu}%"
        fi
    fi
    
    sleep "$CHECK_INTERVAL"
done
