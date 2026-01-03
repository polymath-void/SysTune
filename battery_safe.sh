#!/system/bin/sh
# ================================================================
# MTK Battery Safe Charging Controller v3.6-stable
# Kernel-level input_current_limit control
# ================================================================

MODDIR="/data/adb/modules/SysTune"
PIDFILE="$MODDIR/battery_safe.pid"
LOG="$MODDIR/logs/battery_safe.log"

CHG_LIMIT="/sys/class/power_supply/mtk-master-charger/input_current_limit"
TEMP_NODE="/sys/class/power_supply/battery/temp"
CAP_NODE="/sys/class/power_supply/battery/capacity"

PAUSE_TIME=300
TEMP_LIMIT=430   # 43.0°C (0.1°C units)

ORIG_LIMIT="$(cat "$CHG_LIMIT" 2>/dev/null || echo 3200000)"

log() { echo "$(date '+%F %T') | $1" >> "$LOG"; }

charger_connected() {
    grep -q "1" /sys/class/power_supply/*/online 2>/dev/null
}

set_charging() {
    if [ "$1" = "off" ]; then
        echo 0 > "$CHG_LIMIT"
    else
        echo "$ORIG_LIMIT" > "$CHG_LIMIT"
    fi
}

safe_exit() {
    set_charging on
    rm -f "$PIDFILE"
    log "⚡ Battery Safe exited"
    exit 0
}

# ---- singleton ----
if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    exit 0
fi
echo $$ > "$PIDFILE"

trap safe_exit INT TERM

PAUSE_80=0
PAUSE_90=0
PAUSE_95=0

log "⚡ Battery Safe v3.6 started"

while true; do
    charger_connected || safe_exit

    BAT="$(cat "$CAP_NODE" 2>/dev/null || echo 0)"
    TEMP="$(cat "$TEMP_NODE" 2>/dev/null || echo 0)"

    # Thermal guard
    if [ "$TEMP" -gt "$TEMP_LIMIT" ]; then
        set_charging off
        sleep 60
        continue
    fi

    if [ "$BAT" -ge 95 ] && [ "$PAUSE_95" -eq 0 ]; then
        set_charging off
        log "⏸ Pause @95%"
        sleep "$PAUSE_TIME"
        set_charging on
        PAUSE_95=1
        safe_exit
    fi

    if [ "$BAT" -ge 90 ] && [ "$PAUSE_90" -eq 0 ]; then
        set_charging off
        log "⏸ Pause @90%"
        sleep "$PAUSE_TIME"
        set_charging on
        PAUSE_90=1
    fi

    if [ "$BAT" -ge 80 ] && [ "$PAUSE_80" -eq 0 ]; then
        set_charging off
        log "⏸ Pause @80%"
        sleep "$PAUSE_TIME"
        set_charging on
        PAUSE_80=1
    fi

    sleep 30
done
