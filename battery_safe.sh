#!/system/bin/sh
# SysTune - Battery Safe Worker v5.0 (Staged Pulse Logic)

BASE="/sys/class/power_supply/mtk-master-charger"
STATE_DIR="/data/adb/modules/SysTune/state"
LOG="/data/adb/modules/SysTune/logs/battery_safe.log"
NOW=$(date +%s)

log_chg() { echo "$(date '+%H:%M:%S') | $1" >> "$LOG"; }

# Initialize State Files if missing
[ -f "$STATE_DIR/last_pause" ] || echo "0" > "$STATE_DIR/last_pause"
[ -f "$STATE_DIR/passed_steps" ] || echo "" > "$STATE_DIR/passed_steps"

PASSED=$(cat "$STATE_DIR/passed_steps")
LAST_PAUSE=$(cat "$STATE_DIR/last_pause")
ELAPSED=$((NOW - LAST_PAUSE))

apply_current() {
    echo "$1" > "$BASE/constant_charge_current_max" 2>/dev/null
    echo "$1" > "$BASE/input_current_limit" 2>/dev/null
}

# --- STAGE DEFINITION ---
TARGET_PAUSE=0
for step in 80 90 95; do
    # If we are at/above a step and haven't 'passed' it yet
    if [ "$CUR_BAT" -ge "$step" ] && ! echo "$PASSED" | grep -q "$step"; then
        if [ "$LAST_PAUSE" -eq 0 ]; then
            # Start new pause timer
            echo "$NOW" > "$STATE_DIR/last_pause"
            TARGET_PAUSE=1
            log_chg "TRIP: ${step}% reached. Starting 5min cool-down."
            break
        elif [ "$ELAPSED" -lt 300 ]; then
            # Still in the 5min window
            TARGET_PAUSE=1
            break
        else
            # 5min finished
            echo "${PASSED}${step}," > "$STATE_DIR/passed_steps"
            echo "0" > "$STATE_DIR/last_pause"
            log_chg "RESUME: ${step}% pause complete. Continuing..."
        fi
    fi
done

# --- EXECUTION ---
if [ "$TARGET_PAUSE" -eq 1 ]; then
    apply_current 500000
    REMAINING=$((300 - ELAPSED))
    # Update status for analysis.sh
    echo "STATUS=PAUSED | STEP=${CUR_BAT}% | TIME_LEFT=${REMAINING}s" > "$STATE_DIR/battery_safe.state"
else
    # Default: Use built-in fast charge (3.2A)
    apply_current 3200000
    echo "STATUS=CHARGING | STEP=NORMAL | LIMIT=3.2A" > "$STATE_DIR/battery_safe.state"
fi

# Reset logic: If unplugged, clear the 'passed' steps for next session
if [ "$CUR_STAT" != "Charging" ]; then
    echo "" > "$STATE_DIR/passed_steps"
    echo "0" > "$STATE_DIR/last_pause"
fi
