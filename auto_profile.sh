#!/system/bin/sh
# SysTune Auto Profile Worker v3.3 (Absolute Zero-Fork)

# 1. Environment Anchor
[ -z "$SYS" ] && SYS="/data/adb/modules/SysTune"
STATUS_FILE="$SYS/state/auto_profile.status"
APPLY="$SYS/apply.sh"

# Fallback for variables
[ -z "$CUR_BAT" ] && CUR_BAT=$(cat /sys/class/power_supply/battery/capacity 2>/dev/null || echo 50)

# 2. Pure Shell Contract Read (Zero Forks)
RAW_LINE=""
if [ -f "$STATUS_FILE" ]; then
    # Redirecting file into read built-in avoids spawning 'head'
    IFS= read -r RAW_LINE < "$STATUS_FILE"
fi
LAST_PROFILE="${RAW_LINE#* }" 

# 3. Zone Decision Logic with 2% Buffer (Hysteresis)
# High: 81% / Low: 30%
if [ "$CUR_BAT" -le 30 ]; then
    NEW_PROFILE="battery_saver"
elif [ "$CUR_BAT" -ge 81 ]; then
    NEW_PROFILE="performance"
elif [ "$LAST_PROFILE" = "performance" ] && [ "$CUR_BAT" -ge 79 ]; then
    # Buffer: Stay in performance until drop to 78%
    NEW_PROFILE="performance"
elif [ "$LAST_PROFILE" = "battery_saver" ] && [ "$CUR_BAT" -le 32 ]; then
    # Buffer: Stay in saver until rise to 33%
    NEW_PROFILE="battery_saver"
else
    NEW_PROFILE="balanced_smooth"
fi

# 4. Escape Hatch
if [ "$NEW_PROFILE" = "$LAST_PROFILE" ]; then
    return 0 2>/dev/null || exit 0
fi

# 5. Apply & Atomic State Update
if [ -x "$APPLY" ]; then
    echo "[$(date '+%H:%M:%S')] Transition: ${LAST_PROFILE:-INIT} -> $NEW_PROFILE" >> "$SYS/logs/service.log"
    
    # Speed is priority: source the apply logic
    . "$APPLY" "$NEW_PROFILE"

    # Atomic Write (Observable Contract)
    TMP_STAT="$STATUS_FILE.tmp"
    {
        echo "Profile: $NEW_PROFILE"
        echo "Battery: $CUR_BAT%"
        echo "Status: ${CUR_STAT:-Unknown}"
        echo "Timestamp: $(date +%s)"
    } > "$TMP_STAT"
    
    mv -f "$TMP_STAT" "$STATUS_FILE"
fi

return 0 2>/dev/null || exit 0
