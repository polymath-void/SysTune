#!/system/bin/sh
# SysTune Diagnostic v3.0 - Full Stack Auditor

MODDIR="/data/adb/modules/SysTune"
LOG_DIR="$MODDIR/logs"
STATE_DIR="$MODDIR/state"

# 1. Header & Daemon Logic
echo "------------------------------------------"
echo "SysTune Polymath Diagnostic | $(date '+%H:%M:%S')"
echo "------------------------------------------"

PID=$(pgrep -f "service.sh --daemon" | head -n1)
if [ -n "$PID" ]; then
    OOM=$(cat /proc/$PID/oom_score_adj 2>/dev/null)
    [ "$OOM" -eq -500 ] && OOM_TYPE="GLOBAL" || OOM_TYPE="SANDBOXED"
    echo "[ DAEMON ] Status: RUNNING | PID: $PID | OOM: $OOM ($OOM_TYPE)"
else
    echo "[ DAEMON ] Status: NOT RUNNING"
fi

# 2. Performance & Battery State
echo "[ PERF   ] $([ -f "$STATE_DIR/auto_profile.status" ] && head -n1 "$STATE_DIR/auto_profile.status" || echo "No State")"

CHG_LIMIT="/sys/class/power_supply/mtk-master-charger/input_current_limit"
CUR_LIM=$(cat "$CHG_LIMIT" 2>/dev/null || echo "0")
echo "[ CHARGE ] Hardware Limit: $((CUR_LIM/1000))mA"

# 3. Log Extraction (The "Where is log?" Fix)
echo "\n--- RECENT SERVICE LOGS (Last 5) ---"
if [ -f "$LOG_DIR/service.log" ]; then
    tail -n 5 "$LOG_DIR/service.log"
else
    echo "service.log not found at $LOG_DIR"
fi

echo "\n--- RECENT BATTERY LOGS (Last 5) ---"
if [ -f "$LOG_DIR/battery_safe.log" ]; then
    tail -n 5 "$LOG_DIR/battery_safe.log"
else
    echo "battery_safe.log not found at $LOG_DIR"
fi
echo "------------------------------------------"

if [ -f "/data/adb/modules/SysTune/state/battery_safe.state" ]; then
    . "/data/adb/modules/SysTune/state/battery_safe.state"
    echo "[ BATT   ] $STATUS ($STEP) | Remaining: ${TIME_LEFT:-0}s"
fi
