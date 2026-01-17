#!/system/bin/sh
# SysTune WiFi Worker - Refined v6.0
# Logic: Zero-Fork, Atomic, and Kernel-Direct.

# --- 1. PRE-FLIGHT & PATHS ---
MODDIR="/data/adb/modules/SysTune"
STATE_DIR="$MODDIR/state"
LOG_FILE="$MODDIR/logs/wifi_worker.log"

# Ensure persistence layers exist
[ -d "$STATE_DIR" ] || mkdir -p "$STATE_DIR"
[ -d "$MODDIR/logs" ] || mkdir -p "$MODDIR/logs"

# --- 2. ENVIRONMENT INHERITANCE ---
# Fallbacks ensure the script never executes with empty strings
PROFILE="${NEW_PROFILE:-balanced}"
SCREEN="${CUR_STAT:-ScreenOn}"
INTERFACE="wlan0"

# --- 3. IDEMPOTENCY GUARD (The State Logic) ---
# Read link state directly from kernel to avoid 'dumpsys'
if read -r LINK_STATE < "/sys/class/net/$INTERFACE/operstate" 2>/dev/null; then
    : # Link is valid
else
    LINK_STATE="down"
fi

# Define the unique "Fingerprint" of the current system state
CURRENT_ID="${PROFILE}_${SCREEN}_${LINK_STATE}"
LAST_ID_FILE="$STATE_DIR/last_global_id"

# Check if we actually need to work
read -r LAST_ID < "$LAST_ID_FILE" 2>/dev/null
if [ "$CURRENT_ID" = "$LAST_ID" ]; then
    exit 0
fi

# --- 4. TARGET PARAMETERS (Case Logic) ---
case "$PROFILE" in
    "performance"|"game_mode")
        TCP_CONG="cubic"; SYN_RET=3; SLOW_START=0; BOOST=12 ;;
    "balanced_smooth")
        TCP_CONG="cubic"; SYN_RET=4; SLOW_START=0; BOOST=8  ;;
    "battery_saver")
        TCP_CONG="westwood"; SYN_RET=6; SLOW_START=1; BOOST=0 ;;
    *) # Default Balanced
        TCP_CONG="westwood"; SYN_RET=5; SLOW_START=1; BOOST=4 ;;
esac

# --- 5. KERNEL INJECTION ---
# Function-less injection to maintain absolute shell speed
{
    # Network Stack
    echo "$TCP_CONG" > /proc/sys/net/ipv4/tcp_congestion_control
    echo "$SYN_RET"  > /proc/sys/net/ipv4/tcp_syn_retries
    echo "$SLOW_START" > /proc/sys/net/ipv4/tcp_slow_start_after_idle

    # MTK FPSGO (Only if screen is on and it's a MediaTek device)
    if [ "$SCREEN" = "ScreenOn" ] && [ -d "/sys/kernel/fpsgo" ]; then
        # Find highest PID in foreground (Zero-fork shell expansion)
        read -r FG_TASKS < /dev/cpuset/foreground/tasks
        TARGET_PID="${FG_TASKS##* }" 
        
        if [ "${TARGET_PID:-0}" -gt 2000 ]; then
            echo "$TARGET_PID" > /sys/kernel/fpsgo/composer/fpsgo_control_pid
            echo "$TARGET_PID $BOOST" > /sys/kernel/fpsgo/fbt/fbt_attr_by_pid
        fi
    fi
} 2>/dev/null

# --- 6. ATOMIC LOGGING & PERSISTENCE ---
TIMESTAMP=$(date '+%H:%M:%S')
echo "[$TIMESTAMP] State: $CURRENT_ID | Syn: $SYN_RET | Cong: $TCP_CONG" >> "$LOG_FILE"

# Atomic move to prevent state corruption
echo "$CURRENT_ID" > "$LAST_ID_FILE.tmp"
mv -f "$LAST_ID_FILE.tmp" "$LAST_ID_FILE"

exit 0
