#!/system/bin/sh
# ==========================================
# SysTune Auto Profile Worker v2.0 (One-Shot)
# Author: Rahman
# Purpose: Decide → apply → update state → exit
# ==========================================

SYS="/data/adb/modules/SysTune"
PIDFILE="$SYS/auto_profile.pid"
LOG="$SYS/logs/auto_profile.log"
STATUS_FILE="$SYS/state/auto_profile.status"
APPLY="$SYS/apply.sh"

mkdir -p "$SYS/logs" "$SYS/state"

log() {
    echo "[auto_profile] $(date) | $1" >> "$LOG"
}

# ---------- Singleton (short-lived) ----------
if [ -f "$PIDFILE" ]; then
    OLD_PID=$(cat "$PIDFILE" 2>/dev/null)
    if kill -0 "$OLD_PID" 2>/dev/null; then
        log "Another instance running (PID=$OLD_PID), exiting"
        exit 0
    fi
fi
echo $$ > "$PIDFILE"

cleanup() {
    rm -f "$PIDFILE"
}
trap cleanup EXIT INT TERM

log "Worker started (PID=$$)"

# ---------- Read battery ----------
BATTERY=$(cat /sys/class/power_supply/battery/capacity 2>/dev/null)
[ -z "$BATTERY" ] && {
    log "Battery read failed, exiting"
    exit 1
}

# ---------- CPU load ----------
CPU_LOAD=$(awk '/^cpu / {u=($2+$4)*100/($2+$4+$5); printf "%.0f\n",u}' /proc/stat 2>/dev/null)
[ -z "$CPU_LOAD" ] && CPU_LOAD=0

# ---------- Decide profile ----------
if [ "$BATTERY" -le 25 ]; then
    NEW_PROFILE="battery_saver"
elif [ "$CPU_LOAD" -gt 75 ]; then
    NEW_PROFILE="performance"
elif [ "$BATTERY" -le 50 ]; then
    NEW_PROFILE="balanced"
else
    NEW_PROFILE="balanced_smooth"
fi

# ---------- Read last applied profile ----------
LAST_PROFILE=""
if [ -f "$STATUS_FILE" ]; then
    LAST_PROFILE=$(awk -F': ' '/^Profile:/ {print $2}' "$STATUS_FILE")
fi

# ---------- Apply if needed ----------
if [ "$NEW_PROFILE" = "$LAST_PROFILE" ]; then
    log "No change (profile=$NEW_PROFILE)"
    exit 0
fi

if [ ! -x "$APPLY" ]; then
    log "apply.sh missing or not executable"
    exit 1
fi

log "Applying profile: $NEW_PROFILE (Battery=$BATTERY%, CPU=$CPU_LOAD%)"
sh "$APPLY" "$NEW_PROFILE"

# ---------- Update state ----------
cat <<EOF > "$STATUS_FILE"
Profile: $NEW_PROFILE
Battery: $BATTERY%
CPU Load: $CPU_LOAD%
Last Change: $(date)
EOF

log "Profile applied successfully: $NEW_PROFILE"
exit 0
