#!/system/bin/sh
# SysTune - Battery Safe Worker v7.0 (Final Production / BU-808)

BASE="/sys/class/power_supply/mtk-master-charger"
STATE_DIR="/data/adb/modules/SysTune/state"
LOG="/data/adb/modules/SysTune/logs/battery_safe.log"
NOW=$(date +%s)

# --- CONFIGURATION (BU-808 Optimal) ---
MAX_DAILY_SOC=85   
THERM_HI=380       
THERM_LO=340       

# --- HARDWARE READ ---
read -r TEMP < /sys/class/power_supply/battery/temp 2>/dev/null
read -r CAP < /sys/class/power_supply/battery/capacity 2>/dev/null
# Note: CUR_STAT (Charging/Discharging) is inherited from service.sh

log_chg() { [ "${ENABLE_LOGGING:-0}" = "1" ] && echo "$(date '+%H:%M:%S') | $1" >> "$LOG"; }

# --- MANDATORY REFINEMENT A: STATE RESET ---
# If unplugged or SoC drops below the trigger, reset the pulse timer
if [ "$CUR_STAT" != "Charging" ] || [ "$CAP" -lt 80 ]; then
    echo "0" > "$STATE_DIR/last_pause"
    # Exit early if not charging to save CPU cycles
    [ "$CUR_STAT" != "Charging" ] && return 0
fi

# --- 1. THERMAL HYSTERESIS GATE ---
[ -f "$STATE_DIR/therm_throttled" ] || echo "0" > "$STATE_DIR/therm_throttled"
IS_HOT=$(cat "$STATE_DIR/therm_throttled")

if [ "$TEMP" -ge "$THERM_HI" ] || [ "$IS_HOT" -eq 1 ]; then
    if [ "$TEMP" -le "$THERM_LO" ]; then
        echo "0" > "$STATE_DIR/therm_throttled"
        TAG="THERMAL_RELEASE"
    else
        echo "1" > "$STATE_DIR/therm_throttled"
        echo 500000 > "$BASE/input_current_limit"
        TAG="THERMAL_THROTTLE"
        echo "STATUS=COOLING | TEMP=$((TEMP/10))C" > "$STATE_DIR/battery_safe.state"
    fi
fi

# --- 2. MANDATORY REFINEMENT B: HARD-CAP DISABLE ---
if [ "$CAP" -ge "$MAX_DAILY_SOC" ]; then
    # Total disable of CC and input to prevent voltage creep
    echo 0 > "$BASE/input_current_limit"
    echo 0 > "$BASE/constant_charge_current_max"
    TAG="LONGEVITY_CAP_HALT"
    echo "STATUS=HALT | LIMIT=${MAX_DAILY_SOC}%" > "$STATE_DIR/battery_safe.state"
fi

# --- 3. HYBRID SCALING + STAGED PULSE (If not halted) ---
if [ -z "$TAG" ]; then
    [ -f "$STATE_DIR/last_pause" ] || echo "0" > "$STATE_DIR/last_pause"
    LAST_PAUSE=$(cat "$STATE_DIR/last_pause")
    ELAPSED=$((NOW - LAST_PAUSE))

    if [ "$CAP" -lt 50 ]; then
        CURRENT=3200000
        TAG="PHASE_1_FAST"
    elif [ "$CAP" -lt 80 ]; then
        CURRENT=2000000
        TAG="PHASE_2_SCALED"
    else
        if [ "$LAST_PAUSE" -eq 0 ]; then
            echo "$NOW" > "$STATE_DIR/last_pause"
            CURRENT=500000
            TAG="PHASE_3_PULSE_START"
        elif [ "$ELAPSED" -lt 300 ]; then
            CURRENT=500000
            TAG="PHASE_3_PULSE_WAIT"
        else
            CURRENT=1000000
            TAG="PHASE_3_RESUME"
        fi
    fi

    echo "$CURRENT" > "$BASE/input_current_limit"
    echo "$CURRENT" > "$BASE/constant_charge_current_max"
    echo "STATUS=$TAG | LIMIT=$((CURRENT/1000))mA" > "$STATE_DIR/battery_safe.state"
fi

# --- MANDATORY REFINEMENT C: TRANSITION LOGGING ---
if [ "$TAG" != "$(cat "$STATE_DIR/last_tag" 2>/dev/null)" ]; then
    log_chg "$TAG @ ${CAP}% | $((TEMP/10))C"
    echo "$TAG" > "$STATE_DIR/last_tag"
fi

{
    echo "STATUS=\"$TAG\""
    echo "STEP=\"$CAP%\""
    echo "TIME_LEFT=\"N/A\""
} > "$STATE_DIR/battery_safe.state"
