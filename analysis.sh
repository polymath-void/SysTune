#!/system/bin/sh
# SysTune Diagnostic & Verification Tool (v1.0)

SYS="/data/adb/modules/SysTune"
STATUS_FILE="$SYS/state/auto_profile.status"
LOG_FILE="$SYS/logs/service.log"

header() { echo "\n\033[1;34m=== $1 ===\033[0m"; }
check_node() {
    if [ -w "$1" ]; then
        echo "[\033[0;32m OK \033[0m] $1 = $(cat "$1")"
    else
        echo "[\033[0;31m FAIL \033[0m] $1 (Not writable or missing)"
    fi
}

# 1. Check Service Heartbeat
header "SERVICE STATUS"
PID=$(pgrep -f "service.sh")
if [ -n "$PID" ]; then
    echo "Service running on PID: $PID"
else
    echo "Service NOT running. Start with: su -c \"sh $SYS/service.sh &\""
fi

# 2. Verify Atomic State
header "CURRENT STATE (Atomic Status File)"
if [ -f "$STATUS_FILE" ]; then
    cat "$STATUS_FILE"
else
    echo "No status file found. Threshold not yet crossed."
fi

# 3. Kernel Node Verification (MTK Specific)
header "KERNEL CONFIGURATION"
for policy in /sys/devices/system/cpu/cpufreq/policy*; do
    check_node "$policy/scaling_governor"
    [ -d "$policy/schedutil" ] && check_node "$policy/schedutil/rate_limit_us"
done



# 4. Check for Socket Storm (The problem we solved earlier)
header "NETWORK SOCKET HEALTH"
STORM_COUNT=$(su -c "netstat -ntp | grep -E 'LAST_ACK|FIN_WAIT' | wc -l")
if [ "$STORM_COUNT" -gt 5 ]; then
    echo "[\033[0;33m WARN \033[0m] $STORM_COUNT sockets in hanging state. Try Airplane Mode toggle."
else
    echo "[\033[0;32m CLEAN \033[0m] No socket storm detected."
fi

# 5. Recent Transitions
header "RECENT LOG ENTRIES"
tail -n 5 "$LOG_FILE" 2>/dev/null
