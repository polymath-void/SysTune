#!/system/bin/sh
# =================================================================
# SysTune - Battery Safe Worker v4.1 (Production Grade)
# =================================================================

# 1. Environment & Fallbacks
[ -z "$SYS" ] && SYS="/data/adb/modules/SysTune"
[ -z "$CUR_BAT" ] && CUR_BAT=$(cat /sys/class/power_supply/battery/capacity 2>/dev/null || echo 50)
STATE_FILE="$SYS/state/battery_safe.state"
LOG="$SYS/logs/battery_safe.log"

CHG_LIMIT="/sys/class/power_supply/mtk-master-charger/input_current_limit"
TEMP_NODE="/sys/class/power_supply/battery/temp"
TEMP_LIMIT=430    # 43.0°C
HYSTERESIS=15     # 1.5°C (Resume at 41.5°C)

# 2. State Loading
[ -f "$STATE_FILE" ] && . "$STATE_FILE"
: "${PAUSE_80:=0}" "${PAUSE_90:=0}" "${PAUSE_95:=0}" "${THERMAL_ACTIVE:=0}"

log_chg() {
    read -r up rest < /proc/uptime
    echo "${up%%.*}s | $1" >> "$LOG"
}


set_charging() {
    [ -w "$CHG_LIMIT" ] || return 1
    if [ "$1" = "off" ]; then
        echo 0 > "$CHG_LIMIT"
    else
        # MTK Default Limit
        echo 3200000 > "$CHG_LIMIT"
    fi
}

# 3. Thermal Logic with Hysteresis
# Pure shell reads (Zero-Fork)
read -r TEMP < "$TEMP_NODE" 2>/dev/null || TEMP=0
if [ "$TEMP" -gt "$TEMP_LIMIT" ]; then
    set_charging off
    [ "$THERMAL_ACTIVE" -eq 0 ] && log_chg "ALERT: THERMAL LIMIT REACHED ($((TEMP/10))C)"
    THERMAL_ACTIVE=1
elif [ "$THERMAL_ACTIVE" -eq 1 ] && [ "$TEMP" -lt $((TEMP_LIMIT - HYSTERESIS)) ]; then
    log_chg "INFO: THERMAL NORMALIZED ($((TEMP/10))C)"
    THERMAL_ACTIVE=0
fi

# Exit early if thermal guard is still holding the line
[ "$THERMAL_ACTIVE" -eq 1 ] && goto_persist

# 4. Capacity-Based Pausing (Deterministic If-Elif)
if [ "$CUR_BAT" -ge 95 ] && [ "$PAUSE_95" -eq 0 ]; then
    set_charging off
    log_chg "PAUSE: 95% REACHED"
    PAUSE_95=1
elif [ "$CUR_BAT" -ge 90 ] && [ "$PAUSE_90" -eq 0 ]; then
    set_charging off
    log_chg "PAUSE: 90% REACHED"
    PAUSE_90=1
elif [ "$CUR_BAT" -ge 80 ] && [ "$PAUSE_80" -eq 0 ]; then
    set_charging off
    log_chg "PAUSE: 80% REACHED"
    PAUSE_80=1
elif [ "$PAUSE_80" -eq 0 ] && [ "$PAUSE_90" -eq 0 ] && [ "$PAUSE_95" -eq 0 ]; then
    # Only ensure ON if no safety pauses have been triggered yet
    set_charging on
fi

# 5. Atomic State Persist
goto_persist() {
    TMP="$STATE_FILE.tmp"
    {
        echo "PAUSE_80=$PAUSE_80"
        echo "PAUSE_90=$PAUSE_90"
        echo "PAUSE_95=$PAUSE_95"
        echo "THERMAL_ACTIVE=$THERMAL_ACTIVE"
    } > "$TMP"
    mv "$TMP" "$STATE_FILE"
}
goto_persist
