#!/bin/zsh

# toggle_screen_lock_kde.zsh
# This script changes the KDE screen lock timeout to 20 minutes,
# applies the changes immediately, waits for a specified duration,
# and then restores the original settings.
#
# Debugging / Decisions (2026-02-01) — tray mode dropped on Wayland
# 1) The Problem
# - Wanted a tray icon to quickly toggle screen lock timeout (20 min) and restore safe mode (5 min),
#   with a visible status (icon/tooltip).
# - Symptoms on KDE Plasma Wayland: tray icon showed up, but left/right clicks were often not delivered,
#   or worked once and then stopped. Ctrl+C could also produce lots of repeated "restore" output and
#   notification spam (eventually hitting notification rate limits).
#
# 2) Root Cause
# - Wayland + legacy tray: `yad --notification` is best-effort on Plasma Wayland; GUI may appear but click
#   events may not reliably reach the handler (so no script action and no logs).
# - IPC footgun in earlier iterations: using one FIFO for both "YAD listen commands" and "click events"
#   created two readers on the same FIFO -> race conditions where clicks were consumed by the wrong reader.
# - Lock inheritance: locking via an open FD in a shell script can be inherited by background jobs (timers),
#   making subsequent click handlers block unpredictably unless carefully isolated (`flock` subprocess, `-o`).
#
# 3) The Fix
# - Removed tray mode entirely; keep this script CLI-only (`status`, `restore`, and timed toggle).
# - Made Ctrl+C cleanup idempotent to reduce spam; use notification "replace" hint to avoid flooding.
#
# 4) Key Insight
# - If the tray layer doesn't deliver clicks reliably, further debugging of shell logic is wasted effort:
#   the UI transport is the blocker.
#
# 5) The Lesson
# - On Wayland, prefer native tray integration (StatusNotifier/Qt/Plasma widget) over legacy/X11-ish tools.
# - Never use one FIFO with multiple readers; keep IPC channels single-purpose.
# - Be careful with FD-based locks in shell scripts (background job inheritance).
#
# 6) Verification / Testing
# - Manually observed unreliable click delivery for YAD tray on KDE Plasma Wayland.
# - Manually verified CLI mode works (`status`, `restore`, timed toggle) and doesn't spam infinitely on Ctrl+C.
#
# Decision log protocol lives in `docs/decision_log.md`.

# --------------------------- Configuration ---------------------------

# Fixed New Timeout
NEW_TIMEOUT_MINUTES=20         # New screen lock timeout: 20 minutes

# Default Wait Time
DEFAULT_WAIT_TIME_MINUTES=120  # Default wait time: 120 minutes (2 hours)

# Safe fallback timeout (used for restore command)
SAFE_TIMEOUT_MINUTES=5

# Trap guards (avoid repeated cleanup spam on repeated SIGINT / EXIT)
typeset -g _CONSOLE_CLEANUP_RUNNING=0

# Configuration File and Keys
CONFIG_FILE="$HOME/.config/kscreenlockerrc"
GROUP="Daemon"
KEY_TIMEOUT="Timeout"          # Timeout in minutes before auto-lock
KEY_LOCK_ENABLED="Autolock"   # Autolock enabled (true/false)
KEY_LOCK_ON_LID="LockOnLid"    # Lock on lid close (true/false)

# D-Bus call to apply settings immediately
QDBUS_SERVICE="org.freedesktop.ScreenSaver"
QDBUS_PATH="/ScreenSaver"
QDBUS_METHOD="org.kde.screensaver.configure"

# Lock file to prevent multiple console instances
CONSOLE_LOCK_FILE="/tmp/screen-lock-toggle.lock"

# --------------------------- Lock File Functions -------------------------------

acquire_pid_lock() {
    local lock_file="$1"
    local label="$2"

    if [[ -f "$lock_file" ]]; then
        local old_pid
        old_pid="$(cat "$lock_file" 2>/dev/null)"
        if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
            echo "Error: Another ${label} instance is already running (PID: $old_pid)"
            return 1
        fi
        rm -f "$lock_file"
    fi

    echo $$ > "$lock_file"
}

release_pid_lock() {
    local lock_file="$1"
    rm -f "$lock_file"
}

# --------------------------- Functions -------------------------------

# Function to display usage information
usage() {
    echo "Usage: $0 [wait_time_in_minutes|restore|status]"
    echo ""
    echo "Parameters:"
    echo "  wait_time_in_minutes    Duration to wait before restoring settings. Default is $DEFAULT_WAIT_TIME_MINUTES minutes."
    echo "  restore                 Restore to safe $SAFE_TIMEOUT_MINUTES minute timeout immediately (use if script died)."
    echo "  status                  Show current screen lock settings."
    echo ""
    echo "Examples:"
    echo "  # Run with default wait time ($DEFAULT_WAIT_TIME_MINUTES min)"
    echo "  $0"
    echo ""
    echo "  # Check current status"
    echo "  $0 status"
    echo ""
    echo "  # Restore to safe 5 minute timeout (if script crashed)"
    echo "  $0 restore"
    exit 1
}

# Selected binaries (KDE5 vs KDE6)
KREADCONFIG_BIN="${KREADCONFIG_BIN:-}"
KWRITECONFIG_BIN="${KWRITECONFIG_BIN:-}"
QDBUS_BIN="${QDBUS_BIN:-}"
NOTIFY_SEND_BIN="${NOTIFY_SEND_BIN:-notify-send}"

# Function to check if required commands are available
check_dependencies() {
    local missing=0
    if [[ -z "$KWRITECONFIG_BIN" ]]; then
        if command -v kwriteconfig6 &>/dev/null; then
            KWRITECONFIG_BIN="kwriteconfig6"
        else
            KWRITECONFIG_BIN="kwriteconfig5"
        fi
    fi

    if [[ -z "$KREADCONFIG_BIN" ]]; then
        if command -v kreadconfig6 &>/dev/null; then
            KREADCONFIG_BIN="kreadconfig6"
        else
            KREADCONFIG_BIN="kreadconfig5"
        fi
    fi

    if [[ -z "$QDBUS_BIN" ]]; then
        if command -v qdbus6 &>/dev/null; then
            QDBUS_BIN="qdbus6"
        else
            QDBUS_BIN="qdbus"
        fi
    fi

    for cmd in "$KWRITECONFIG_BIN" "$KREADCONFIG_BIN" "$QDBUS_BIN"; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "Error: '$cmd' command not found. Please install it and try again."
            missing=1
        fi
    done

    # Check for notify-send (optional)
    if ! command -v "$NOTIFY_SEND_BIN" &> /dev/null; then
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
    "$KREADCONFIG_BIN" --file "$file" --group "$group" --key "$key"
}

# Function to set a config value safely
set_config() {
    local file=$1
    local group=$2
    local key=$3
    local value=$4
    "$KWRITECONFIG_BIN" --file "$file" --group "$group" --key "$key" "$value"
}

# Function to send desktop notifications (if enabled)
send_notification() {
    local title="$1"
    local message="$2"
    if [[ "$USE_NOTIFY" == true ]]; then
        # Replace/merge similar notifications to avoid spamming.
        # Supported by many notification daemons (including KDE).
        "$NOTIFY_SEND_BIN" -h "string:x-canonical-private-synchronous:screen-lock-toggle" "$title" "$message"
    fi
}

# Function to apply D-Bus command to reconfigure screensaver
apply_qdbus_command() {
    echo "Applying D-Bus command to reconfigure screensaver..."
    "$QDBUS_BIN" "$QDBUS_SERVICE" "$QDBUS_PATH" "$QDBUS_METHOD" 2>/dev/null
    if [[ $? -eq 0 ]]; then
        echo "Screensaver configuration reloaded successfully."
    else
        echo "Warning: Failed to reload screensaver configuration via D-Bus."
        echo "Settings saved but may require logout/login to take effect."
    fi
}

# Function to restore to safe timeout
restore_safe() {
    echo "Restoring to safe ${SAFE_TIMEOUT_MINUTES} minute timeout..."
    set_config "$CONFIG_FILE" "$GROUP" "$KEY_TIMEOUT" "$SAFE_TIMEOUT_MINUTES"
    set_config "$CONFIG_FILE" "$GROUP" "$KEY_LOCK_ENABLED" "true"
    apply_qdbus_command
    send_notification "Screen Lock Timeout" "Restored to safe ${SAFE_TIMEOUT_MINUTES} minute timeout."
    echo "Settings restored to ${SAFE_TIMEOUT_MINUTES} minute timeout."
}

# Function to cleanup and restore safe timeout
cleanup() {
    if (( _CONSOLE_CLEANUP_RUNNING )); then
        return 0
    fi
    _CONSOLE_CLEANUP_RUNNING=1
    trap '' SIGINT SIGTERM

    echo ""
    echo "Interrupt received. Restoring to safe ${SAFE_TIMEOUT_MINUTES} minute timeout..."
    set_config "$CONFIG_FILE" "$GROUP" "$KEY_TIMEOUT" "$SAFE_TIMEOUT_MINUTES"
    set_config "$CONFIG_FILE" "$GROUP" "$KEY_LOCK_ENABLED" "true"
    apply_qdbus_command
    send_notification "Screen Lock Timeout" "Restored to safe ${SAFE_TIMEOUT_MINUTES} minute timeout."
    echo "Settings restored to ${SAFE_TIMEOUT_MINUTES} minute timeout."
    rm -f "$CONSOLE_LOCK_FILE"
    exit 1
}

# Function to show current status
show_status() {
    local timeout=$(get_config "$CONFIG_FILE" "$GROUP" "$KEY_TIMEOUT")
    local autolock=$(get_config "$CONFIG_FILE" "$GROUP" "$KEY_LOCK_ENABLED")
    
    echo "Current screen lock settings:"
    echo "  Timeout:     $timeout minutes"
    echo "  Autolock:    $autolock"
    echo ""
    
    if [[ "$timeout" == "$NEW_TIMEOUT_MINUTES" ]]; then
        echo "Status: 🔶 TOGGLED (20 minute timeout active)"
    elif [[ "$timeout" == "$SAFE_TIMEOUT_MINUTES" ]]; then
        echo "Status: 🟢 SAFE MODE (5 minute timeout)"
    else
        echo "Status: 🔵 NORMAL ($timeout minute timeout)"
    fi
}

# --------------------------- Main Script -----------------------------

if [[ "$1" == "restore" ]]; then
    check_dependencies
    restore_safe
    exit 0
fi

if [[ "$1" == "status" ]]; then
    check_dependencies
    show_status
    exit 0
fi

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    usage
    exit 0
fi

# Console mode toggle (may run for a long time)
WAIT_TIME_MINUTES=$DEFAULT_WAIT_TIME_MINUTES
if [[ $# -gt 1 ]]; then
    echo "Error: Too many arguments."
    usage
fi

if [[ $# -eq 1 ]]; then
    if [[ "$1" =~ ^[0-9]+$ ]]; then
        WAIT_TIME_MINUTES="$1"
    else
        echo "Error: Invalid argument '$1'"
        usage
    fi
fi

if ! acquire_pid_lock "$CONSOLE_LOCK_FILE" "console"; then
    exit 1
fi

# Check for dependencies
check_dependencies

# Set trap to catch SIGINT and SIGTERM and call cleanup (console mode only)
trap cleanup SIGINT SIGTERM

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
echo "Waiting for $WAIT_TIME_MINUTES minutes before restoring original settings..."
echo ""

# Wait for the specified duration
sleep "$WAIT_TIME_MINUTES"m

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
release_pid_lock "$CONSOLE_LOCK_FILE"

exit 0
