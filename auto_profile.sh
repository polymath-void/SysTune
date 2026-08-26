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

# ---------------------------------

# Delegate entirely to the unified config-driven engine
if [ -f "$SYS/apply.sh" ]; then
    /system/bin/sh "$SYS/apply.sh" "$NEW_PROFILE"
else
    echo "ERROR: apply.sh missing!" >> "$LOG"
    exit 1
fi

# Persist state atomically
{
    echo "Profile: $NEW_PROFILE"
    echo "Battery: $CUR_BAT"
    echo "Timestamp: $(date +%s)"
} > "$STATE.tmp" && mv -f "$STATE.tmp" "$STATE"

echo "$NEW_PROFILE" > "$LAST_PROFILE_FILE"
chmod 644 "$STATE" "$LAST_PROFILE_FILE"

[ "${ENABLE_LOGGING:-0}" = "1" ] && echo "[$(date '+%H:%M:%S')] Applied $NEW_PROFILE at ${CUR_BAT}%" >> "$LOG"
