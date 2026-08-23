#!/system/bin/sh
# SysTune Auto Profile Worker v4.5
# Edge-triggered, idempotent, kernel-safe

SYS="${SYS:-/data/adb/modules/SysTune}"
STATE_DIR="$SYS/state"
STATE="$STATE_DIR/auto_profile.status"
LAST_PROFILE_FILE="$STATE_DIR/last_profile"
LOG="$SYS/logs/auto_profile.log"

mkdir -p "$STATE_DIR"

# Manual fallback
if [ -z "$NEW_PROFILE" ]; then
    NEW_PROFILE="balanced_smooth"
    CUR_BAT="$(cat /sys/class/power_supply/battery/capacity 2>/dev/null || echo 0)"
fi

# Read last applied profile (if any)
LAST_PROFILE="$(cat "$LAST_PROFILE_FILE" 2>/dev/null)"

# ---------- EDGE TRIGGER ----------
if [ "$NEW_PROFILE" = "$LAST_PROFILE" ]; then
    # Nothing changed → exit silently
    exit 0
fi
# ---------------------------------

# CPU scaling function
set_cpu() {
    local gov="$1" max="$2"
    for p in /sys/devices/system/cpu/cpufreq/policy*; do
        echo "$gov" > "$p/scaling_governor" 2>/dev/null
        if [ "$max" -eq 0 ]; then
            cat "$p/cpuinfo_max_freq" > "$p/scaling_max_freq" 2>/dev/null
        else
            echo "$max" > "$p/scaling_max_freq" 2>/dev/null
        fi
    done
}

# Apply profile
case "$NEW_PROFILE" in
    battery_saver)     set_cpu "schedutil" 800000 ;;
    balanced_smooth)  set_cpu "schedutil" 1600000 ;;
    performance)      set_cpu "schedutil" 0 ;;
    *) exit 0 ;;
esac

# Persist state atomically
{
    echo "Profile: $NEW_PROFILE"
    echo "Battery: $CUR_BAT"
    echo "Timestamp: $(date +%s)"
} > "$STATE.tmp" && mv -f "$STATE.tmp" "$STATE"

echo "$NEW_PROFILE" > "$LAST_PROFILE_FILE"
chmod 644 "$STATE" "$LAST_PROFILE_FILE"

[ "${ENABLE_LOGGING:-0}" = "1" ] && echo "[$(date '+%H:%M:%S')] Applied $NEW_PROFILE at ${CUR_BAT}%" >> "$LOG"
