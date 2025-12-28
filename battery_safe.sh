#!/system/bin/sh
# ==========================================
# MTK Battery Safe Charging Controller v2.2
# Author: Rahman
# MTK-safe, UI-safe, kernel-driven
# ==========================================

MODDIR="/data/adb/modules/SysTune"
PIDFILE="$MODDIR/battery_safe.pid"
LOG="$MODDIR/logs/battery_safe.log"
STATUS_FILE="$MODDIR/state/battery_safe.status"
CHG_CTRL="/sys/devices/platform/soc/11280000.i2c/i2c-5/5-0034/11280000.i2c:mt6375@34:mtk_gauge/power_supply/battery/disable"

CHECK_INTERVAL=15
PAUSE_TIME=300        # 5 min disable
SYNC_TIME=60          # 1 min enable (UI sync)

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
echo "⚡ Battery Safe started $(date)" >> "$LOG"

# ---------- State ----------
MODE="NORMAL"
TIMER=0

# ---------- Loop ----------
while true; do
    BATTERY=$(cat /sys/class/power_supply/battery/capacity 2>/dev/null)
    STATUS=$(cat /sys/class/power_supply/battery/status 2>/dev/null)

    # Charger removed → exit
    if [ "$STATUS" != "Charging" ]; then
        echo "🔌 Charger disconnected $(date)" >> "$LOG"
        safe_exit
    fi

    NOW=$(date +%s)

    # ---- 80–89 zone ----
    if [ "$BATTERY" -ge 80 ] && [ "$BATTERY" -lt 90 ]; then
        if [ "$MODE" = "NORMAL" ]; then
            echo 1 > "$CHG_CTRL"
            MODE="PAUSE"
            TIMER=$NOW
            echo "⏸ Pause @80% $(date)" >> "$LOG"
        fi
    fi

    # ---- 90–99 zone ----
    if [ "$BATTERY" -ge 90 ] && [ "$BATTERY" -lt 100 ]; then
        if [ "$MODE" = "NORMAL" ]; then
            echo 1 > "$CHG_CTRL"
            MODE="PAUSE"
            TIMER=$NOW
            echo "⏸ Pause @90% $(date)" >> "$LOG"
        fi
    fi

    # ---- Pause window ----
    if [ "$MODE" = "PAUSE" ] && [ $((NOW - TIMER)) -ge "$PAUSE_TIME" ]; then
        echo 0 > "$CHG_CTRL"
        MODE="SYNC"
        TIMER=$NOW
        echo "▶ Sync charging $(date)" >> "$LOG"
    fi

    # ---- Sync window ----
    if [ "$MODE" = "SYNC" ] && [ $((NOW - TIMER)) -ge "$SYNC_TIME" ]; then
        echo 1 > "$CHG_CTRL"
        MODE="PAUSE"
        TIMER=$NOW
        echo "⏸ Resume pause $(date)" >> "$LOG"
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
Last Update: $(date)
EOF

    sleep "$CHECK_INTERVAL"
done
