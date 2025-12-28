#!/system/bin/sh
# ==========================================
# SysTune Service Scheduler (Low Power – Stable)
# Author: Rahman Shuvo
# ==========================================

MODDIR=${0%/*}
LOG="$MODDIR/logs/service.log"
STATE="$MODDIR/state"

mkdir -p "$MODDIR/logs" "$STATE"

log() {
    echo "[service] $(date '+%F %T') | $1" >> "$LOG"
}

# ---- Fix permissions once ----
chmod 755 "$MODDIR/"*.sh
log "Permissions fixed"

log "Scheduler started"

LAST_STATUS="Unknown"

while true; do
    LEVEL=$(cat /sys/class/power_supply/battery/capacity 2>/dev/null)
    STATUS=$(cat /sys/class/power_supply/battery/status 2>/dev/null)

    # -------------------------------
    # Auto profile (once per wake)
    # -------------------------------
    sh "$MODDIR/auto_profile.sh"
    log "auto_profile executed | Battery: ${LEVEL}% | Status: $STATUS"

    # -------------------------------
    # Charger state change detection
    # -------------------------------
    if [ "$STATUS" != "$LAST_STATUS" ]; then
        if [ "$STATUS" = "Charging" ]; then
            log "Charger connected"

        elif [ "$LAST_STATUS" = "Charging" ]; then
            # Charger unplugged → stop battery_safe cleanly
            if [ -f "$STATE/battery_safe.pid" ]; then
                kill "$(cat "$STATE/battery_safe.pid")" 2>/dev/null
                rm -f "$STATE/battery_safe.pid"
                log "battery_safe stopped (charger unplugged)"
            fi
        fi
        LAST_STATUS="$STATUS"
    fi

    # -------------------------------
    # battery_safe (only while charging)
    # -------------------------------
    if [ "$STATUS" = "Charging" ]; then
        if [ ! -f "$STATE/battery_safe.pid" ] || \
           ! kill -0 "$(cat "$STATE/battery_safe.pid")" 2>/dev/null; then

            sh "$MODDIR/battery_safe.sh" &
            echo $! > "$STATE/battery_safe.pid"
            log "battery_safe started"
        fi
    fi

    # -------------------------------
    # Sleep (low power)
    # -------------------------------
    sleep 1800
done
