#!/system/bin/sh
# ==========================================
# MTK Battery Safe Charging Controller v3.0
# Author: Rahman
# Milestone-based, MTK-safe, UI-safe
# ==========================================

MODDIR="/data/adb/modules/SysTune"
PIDFILE="$MODDIR/battery_safe.pid"
LOG="$MODDIR/logs/battery_safe.log"
STATUS_FILE="$MODDIR/state/battery_safe.status"

CHG_CTRL="/sys/devices/platform/soc/11280000.i2c/i2c-5/5-0034/11280000.i2c:mt6375@34:mtk_gauge/power_supply/battery/disable"

CHECK_INTERVAL=15
PAUSE_TIME=300   # 5 minutes pause at milestones

# ---------- Safety ----------
safe_exit() {
    echo 0 > "$CHG_CTRL" 2>/dev/null
    rm -f "$PIDFILE"
    echo "⚡ Battery Safe exited $(date)" >> "$LOG"
    exit 0
}
trap safe_exit EXIT INT TERM

# ---------- Singleton ----------
if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    exit 0
fi
echo $$ > "$PIDFILE"

mkdir -p "$MODDIR/logs" "$MODDIR/state"
echo "⚡ Battery Safe v3 started $(date)" >> "$LOG"

# ---------- State ----------
PAUSE_80_DONE=0
PAUSE_90_DONE=0
PAUSE_95_DONE=0

MODE="NORMAL"
TIMER=0

# ---------- Loop ----------
while true; do
    BATTERY=$(cat /sys/class/power_supply/battery/capacity 2>/dev/null)
    STATUS=$(cat /sys/class/power_supply/battery/status 2>/dev/null)
    NOW=$(date +%s)

    # ---- Charger removed → exit safely ----
    if [ "$STATUS" != "Charging" ]; then
        echo "🔌 Charger disconnected $(date)" >> "$LOG"
        safe_exit
    fi

    # ---- Always allow charging below 80% ----
    if [ "$BATTERY" -lt 80 ]; then
        echo 0 > "$CHG_CTRL"
        MODE="NORMAL"
        TIMER=0
    fi

    # ---- 80% milestone ----
    if [ "$BATTERY" -ge 80 ] && [ "$BATTERY" -lt 90 ] && [ "$PAUSE_80_DONE" -eq 0 ]; then
        echo 1 > "$CHG_CTRL"
        PAUSE_80_DONE=1
        MODE="PAUSE"
        TIMER=$NOW
        echo "⏸ Pause @80% $(date)" >> "$LOG"
    fi

    # ---- 90% milestone ----
    if [ "$BATTERY" -ge 90 ] && [ "$BATTERY" -lt 95 ] && [ "$PAUSE_90_DONE" -eq 0 ]; then
        echo 1 > "$CHG_CTRL"
        PAUSE_90_DONE=1
        MODE="PAUSE"
        TIMER=$NOW
        echo "⏸ Pause @90% $(date)" >> "$LOG"
    fi

    # ---- 95% milestone ----
    if [ "$BATTERY" -ge 95 ] && [ "$BATTERY" -lt 100 ] && [ "$PAUSE_95_DONE" -eq 0 ]; then
        echo 1 > "$CHG_CTRL"
        PAUSE_95_DONE=1
        MODE="PAUSE"
        TIMER=$NOW
        echo "⏸ Pause @95% $(date)" >> "$LOG"
    fi

    # ---- Resume after pause ----
    if [ "$MODE" = "PAUSE" ] && [ $((NOW - TIMER)) -ge "$PAUSE_TIME" ]; then
        echo 0 > "$CHG_CTRL"
        MODE="NORMAL"
        TIMER=0
        echo "▶ Charging resumed $(date)" >> "$LOG"
    fi

    # ---- 100% hard stop ----
    if [ "$BATTERY" -ge 100 ]; then
        echo 1 > "$CHG_CTRL"
        MODE="STOP"
        echo "🛑 Charging stopped @100% $(date)" >> "$LOG"
    fi

    # ---- Status file ----
    cat <<EOF > "$STATUS_FILE"
Battery: $BATTERY%
Charging State: $STATUS
Mode: $MODE
80% Pause Done: $PAUSE_80_DONE
90% Pause Done: $PAUSE_90_DONE
95% Pause Done: $PAUSE_95_DONE
Last Update: $(date)
EOF

    sleep "$CHECK_INTERVAL"
done
