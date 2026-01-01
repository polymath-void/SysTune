#!/system/bin/sh
# ==========================================
# MTK Battery Safe Charging Controller v3.2
# Author: Rahman
# Device tested: Nothing Phone 2a (MediaTek)
#
# Design goals:
# - Stable, non-spamming, deterministic
# - dumpsys battery = source of truth
# - One-time actions, no oscillation
# ==========================================

MODDIR="/data/adb/modules/SysTune"
PIDFILE="$MODDIR/battery_safe.pid"
LOG="$MODDIR/logs/battery_safe.log"
STATUS_FILE="$MODDIR/state/battery_safe.status"

CHG_CTRL="/sys/devices/platform/soc/11280000.i2c/i2c-5/5-0034/11280000.i2c:mt6375@34:mtk_gauge/power_supply/battery/disable"

CHECK_INTERVAL=15
PAUSE_TIME=300
POST_FULL_WAIT=300
IDLE_SLEEP=900

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
echo "⚡ Battery Safe v3.2 started $(date)" >> "$LOG"

# ---------- State ----------
MODE="NORMAL"

PAUSE_80_DONE=0
PAUSE_90_DONE=0
PAUSE_95_DONE=0
FULL_DONE=0
GAUGE_SYNC_DONE=0

# ---------- Helpers ----------
capacity() {
    cat /sys/class/power_supply/battery/capacity 2>/dev/null
}

status_full() {
    dumpsys battery | grep -q "status: 5"
}

charger_connected() {
    dumpsys battery | grep -q "AC powered: true"
}

# ---------- Main Loop ----------
while true; do
    BAT=$(capacity)

    # Charger removed → exit clean
    if ! charger_connected; then
        echo "🔌 Charger disconnected $(date)" >> "$LOG"
        safe_exit
    fi

    # ---- 80% pause (once) ----
    if [ "$BAT" -ge 80 ] && [ "$PAUSE_80_DONE" -eq 0 ]; then
        echo 1 > "$CHG_CTRL"
        PAUSE_80_DONE=1
        sleep "$PAUSE_TIME"
        echo 0 > "$CHG_CTRL"
        echo "⏸ Pause @80% → resume $(date)" >> "$LOG"
    fi

    # ---- 90% pause (once) ----
    if [ "$BAT" -ge 90 ] && [ "$PAUSE_90_DONE" -eq 0 ]; then
        echo 1 > "$CHG_CTRL"
        PAUSE_90_DONE=1
        sleep "$PAUSE_TIME"
        echo 0 > "$CHG_CTRL"
        echo "⏸ Pause @90% → resume $(date)" >> "$LOG"
    fi

    # ---- 95% pause (once) ----
    if [ "$BAT" -ge 95 ] && [ "$PAUSE_95_DONE" -eq 0 ]; then
        echo 1 > "$CHG_CTRL"
        PAUSE_95_DONE=1
        sleep "$PAUSE_TIME"
        echo 0 > "$CHG_CTRL"
        echo "⏸ Pause @95% → resume $(date)" >> "$LOG"
    fi

    # ---- Full reached (once, authoritative) ----
    if status_full && [ "$FULL_DONE" -eq 0 ]; then
        echo 1 > "$CHG_CTRL"
        FULL_DONE=1
        MODE="POST_FULL"
        echo "🛑 Charging complete (status=Full) $(date)" >> "$LOG"
    fi

    # ---- Post-full gauge sync (once) ----
    if [ "$MODE" = "POST_FULL" ] && [ "$GAUGE_SYNC_DONE" -eq 0 ]; then
        echo 0 > "$CHG_CTRL"
        sleep "$POST_FULL_WAIT"

        echo 1 > "$CHG_CTRL"
        CAP_AFTER=$(capacity)

        echo "🔁 Gauge sync check | capacity=$CAP_AFTER% $(date)" >> "$LOG"

        if [ "$CAP_AFTER" -eq 100 ]; then
            GAUGE_SYNC_DONE=1
            MODE="IDLE"
            echo "✅ Battery gauge stabilized (100%) $(date)" >> "$LOG"
        fi
    fi

    # ---- Idle monitor (silent) ----
    if [ "$MODE" = "IDLE" ]; then
        sleep "$IDLE_SLEEP"
        continue
    fi

    # ---- Status file ----
    cat <<EOF > "$STATUS_FILE"
Battery: $BAT%
Mode: $MODE
Last Update: $(date)
EOF

    sleep "$CHECK_INTERVAL"
done
