#!/bin/zsh

# toggle_screen_lock_kde.zsh
# This script changes the KDE screen lock timeout to 20 minutes,
# applies the changes immediately,
# waits for a specified duration provided as a positional parameter,
# and then restores the original settings,
# followed by applying the restored settings immediately.
# It also handles interruptions to ensure original settings are restored.

# --------------------------- Configuration ---------------------------

# Fixed New Timeout
NEW_TIMEOUT_MINUTES=20         # New screen lock timeout: 20 minutes

# Default Wait Time
DEFAULT_WAIT_TIME_SECONDS=3600  # Default wait time: 3600 seconds (1 hour)

# Configuration File and Keys
CONFIG_FILE="$HOME/.config/kscreenlockerrc"
GROUP="Daemon"
KEY_TIMEOUT="Timeout"          # Timeout in minutes before auto-lock
KEY_LOCK_ENABLED="Autolock"   # Autolock enabled (true/false)
KEY_LOCK_ON_LID="LockOnLid"    # Lock on lid close (true/false)

# D-Bus Command to Apply Settings Immediately
QDBUS_COMMAND="qdbus org.freedesktop.ScreenSaver /org/freedesktop/ScreenSaver org.kde.screensaver.configure"

# --------------------------- Functions -------------------------------

# Function to display usage information
usage() {
    echo "Usage: $0 [wait_time_in_seconds]"
    echo ""
    echo "Parameters:"
    echo "  wait_time_in_seconds    Duration to wait before restoring settings. Default is 3600 seconds (1 hour)."
    echo "  If no parameter is provided, the script defaults to a wait time of 3600 seconds."
    echo ""
    echo "Examples:"
    echo "  # Run with default wait time (1 hour)"
    echo "  $0"
    echo ""
    echo "  # Run with a custom wait time of 1800 seconds (30 minutes)"
    echo "  $0 1800"
    exit 1
}

# Function to check if required commands are available
check_dependencies() {
    local missing=0
    for cmd in kwriteconfig5 kreadconfig5 qdbus; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "Error: '$cmd' command not found. Please install it and try again."
            missing=1
        fi
    done

    # Check for notify-send (optional)
    if ! command -v notify-send &> /dev/null; then
        USE_NOTIFY=false
    else
        USE_NOTIFY=true
    fi

    if [[ $missing -eq 1 ]]; then
        exit 1
    fi
}

# Function to get a config value safely
get_config() {
    local file=$1
    local group=$2
    local key=$3
    kreadconfig5 --file "$file" --group "$group" --key "$key"
}

# Function to set a config value safely
set_config() {
    local file=$1
    local group=$2
    local key=$3
    local value=$4
    kwriteconfig5 --file "$file" --group "$group" --key "$key" "$value"
}

# Function to send desktop notifications (if enabled)
send_notification() {
    local title="$1"
    local message="$2"
    if [[ "$USE_NOTIFY" == true ]]; then
        notify-send "$title" "$message"
    fi
}

# Function to apply D-Bus command to reconfigure screensaver
apply_qdbus_command() {
    echo "Applying D-Bus command to reconfigure screensaver..."
    eval "$QDBUS_COMMAND"
    if [[ $? -eq 0 ]]; then
        echo "Screensaver configuration reloaded successfully."
    else
        echo "Error: Failed to reload screensaver configuration."
    fi
}

# Function to cleanup and restore original settings
cleanup() {
    echo ""
    echo "Interrupt received. Restoring original screen lock settings..."
    set_config "$CONFIG_FILE" "$GROUP" "$KEY_TIMEOUT" "$CURRENT_TIMEOUT"
    set_config "$CONFIG_FILE" "$GROUP" "$KEY_LOCK_ENABLED" "$CURRENT_LOCK_ENABLED"
    set_config "$CONFIG_FILE" "$GROUP" "$KEY_LOCK_ON_LID" "$CURRENT_LOCK_ON_LID"

    # Apply D-Bus command to reconfigure screensaver
    apply_qdbus_command

    # Send notification
    send_notification "Screen Lock Timeout" "Original timeout settings have been restored."

    echo "Original screen lock settings have been restored."
    exit 1
}

# --------------------------- Main Script -----------------------------

# Set trap to catch SIGINT and SIGTERM and call cleanup
trap cleanup SIGINT SIGTERM

# Initialize variables with default values
WAIT_TIME_SECONDS=$DEFAULT_WAIT_TIME_SECONDS

# Parse positional arguments
if [[ $# -gt 1 ]]; then
    echo "Error: Too many arguments."
    usage
fi

if [[ $# -eq 1 ]]; then
    if [[ "$1" =~ ^[0-9]+$ ]]; then
        WAIT_TIME_SECONDS="$1"
    else
        echo "Error: 'wait_time_in_seconds' must be a positive integer."
        usage
    fi
fi

# Check for dependencies
check_dependencies

# Verify that the configuration file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Configuration file '$CONFIG_FILE' does not exist."
    exit 1
fi

# Save current settings
echo "Saving current screen lock settings..."
CURRENT_TIMEOUT=$(get_config "$CONFIG_FILE" "$GROUP" "$KEY_TIMEOUT")
CURRENT_LOCK_ENABLED=$(get_config "$CONFIG_FILE" "$GROUP" "$KEY_LOCK_ENABLED")
CURRENT_LOCK_ON_LID=$(get_config "$CONFIG_FILE" "$GROUP" "$KEY_LOCK_ON_LID")

echo "Current Settings:"
echo "  Timeout          : $CURRENT_TIMEOUT minutes"
echo "  Autolock Enabled : $CURRENT_LOCK_ENABLED"
echo "  Lock on Lid      : $CURRENT_LOCK_ON_LID"
echo ""

# Apply new settings
echo "Applying new screen lock settings:"
echo "  Timeout          : $NEW_TIMEOUT_MINUTES minutes"
echo "  Autolock Enabled : true"
echo ""
set_config "$CONFIG_FILE" "$GROUP" "$KEY_TIMEOUT" "$NEW_TIMEOUT_MINUTES"
set_config "$CONFIG_FILE" "$GROUP" "$KEY_LOCK_ENABLED" "true"

# Apply D-Bus command to reconfigure screensaver
apply_qdbus_command

# Send notification
send_notification "Screen Lock Timeout" "Timeout set to $NEW_TIMEOUT_MINUTES minutes."

echo "Screen lock timeout set to $NEW_TIMEOUT_MINUTES minutes."
echo "Waiting for $WAIT_TIME_SECONDS seconds before restoring original settings..."
echo ""

# Wait for the specified duration
sleep "$WAIT_TIME_SECONDS"

# Restore original settings
echo ""
echo "Restoring original screen lock settings:"
echo "  Timeout          : $CURRENT_TIMEOUT minutes"
echo "  Autolock Enabled : $CURRENT_LOCK_ENABLED"
echo "  Lock on Lid      : $CURRENT_LOCK_ON_LID"
echo ""
set_config "$CONFIG_FILE" "$GROUP" "$KEY_TIMEOUT" "$CURRENT_TIMEOUT"
set_config "$CONFIG_FILE" "$GROUP" "$KEY_LOCK_ENABLED" "$CURRENT_LOCK_ENABLED"
set_config "$CONFIG_FILE" "$GROUP" "$KEY_LOCK_ON_LID" "$CURRENT_LOCK_ON_LID"

# Apply D-Bus command to reconfigure screensaver
apply_qdbus_command

# Send notification
send_notification "Screen Lock Timeout" "Original timeout settings have been restored."

echo "Original screen lock settings have been restored."

# Remove trap after successful completion
trap - SIGINT SIGTERM

exit 0

