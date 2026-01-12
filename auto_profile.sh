#!/system/bin/sh
# SysTune Auto Profile Worker v3.1 (Atomic & Zero-Fork)

# Safety Fallback for standalone execution
[ -z "$CUR_BAT" ] && CUR_BAT=$(cat /sys/class/power_supply/battery/capacity 2>/dev/null || echo 50)
STATUS_FILE="$SYS/state/auto_profile.status"
APPLY="$SYS/apply.sh"

# 1. Zone Decision Logic
if [ "$CUR_BAT" -le 30 ]; then
    NEW_PROFILE="battery_saver"
elif [ "$CUR_BAT" -ge 81 ]; then
    NEW_PROFILE="performance"
else
    NEW_PROFILE="balanced_smooth"
fi

# 2. Read Last Profile (Pure Shell)
LAST_PROFILE=""
if [ -f "$STATUS_FILE" ]; then
    while read -r line; do
        case "$line" in
            Profile:*) LAST_PROFILE=${line#Profile:[[:space:]]} ;;
        esac
    done < "$STATUS_FILE"
fi

# 3. Exit early if no transition is needed
[ "$NEW_PROFILE" = "$LAST_PROFILE" ] && return 0

# 4. Apply Profile
if [ -x "$APPLY" ]; then
    echo "[$(date '+%H:%M:%S')] Transition: ${LAST_PROFILE:-INIT} -> $NEW_PROFILE" >> "$SYS/logs/service.log"
    
    # Sourcing apply.sh for maximum speed
    . "$APPLY" "$NEW_PROFILE"
    
    # 5. Atomic State Update (Prevents corruption during sudden power-off)
    TMP_STAT="$STATUS_FILE.tmp"
    cat <<EOF > "$TMP_STAT"
Profile: $NEW_PROFILE
Battery: $CUR_BAT%
Status: $CUR_STAT
Timestamp: $(date +%s)
EOF
    mv "$TMP_STAT" "$STATUS_FILE"
fi

return 0
