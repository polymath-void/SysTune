#!/system/bin/sh
# SysTune v2.4 - Persistent Global Daemon

MODDIR="/data/adb/modules/SysTune"
STATE="$MODDIR/state"
PIDFILE="$STATE/service.pid"
export SYS="$MODDIR"
export STATE="$STATE"

# 1. Singleton Guard (Improved)
if [ -f "$PIDFILE" ]; then
    OLD_PID=$(cat "$PIDFILE")
    if [ -d "/proc/$OLD_PID" ] && grep -q "service.sh" "/proc/$OLD_PID/cmdline" 2>/dev/null; then
        # If we are already running in background, don't start again
        [ "$1" = "--daemon" ] && exit 0
        echo "Daemon already running (PID $OLD_PID)"
        exit 0
    fi
    rm -f "$PIDFILE"
fi

# 2. Daemonization
if [ "$1" != "--daemon" ]; then
    setsid nohup sh "$0" --daemon >/dev/null 2>&1 &
    exit 0
fi

echo $$ > "$PIDFILE"
echo "[$(date '+%H:%M:%S')] Daemon started (PID $$)" >> "$MODDIR/logs/service.log"

# 3. Execution Wrapper (Prevents Worker Crashes from killing Daemon)
run_worker() {
    # We use a subshell ( ) instead of sourcing . 
    # This protects the Daemon's memory and life-cycle.
    ( 
      export NEW_PROFILE="$1"
      export CUR_BAT="$2"
      export CUR_STAT="$3"
      [ -f "$SYS/$4" ] && . "$SYS/$4" 
    )
}

while true; do
    # Ensure OOM priority every loop
    echo "-500" > /proc/$$/oom_score_adj 2>/dev/null

    # Hardware Polling
    read -r LEVEL < /sys/class/power_supply/battery/capacity 2>/dev/null
    read -r STATUS < /sys/class/power_supply/battery/status 2>/dev/null

    # Performance Zone Logic
    if [ "$LEVEL" -le 30 ]; then ZONE="battery_saver"
    elif [ "$LEVEL" -le 80 ]; then ZONE="balanced_smooth"
    else ZONE="performance"; fi

    if [ "$ZONE" != "$LAST_ZONE" ]; then
        run_worker "$ZONE" "$LEVEL" "$STATUS" "auto_profile.sh"
        LAST_ZONE="$ZONE"
    fi

    # Battery Safety Logic
    if [ "$STATUS" = "Charging" ] || [ "$LAST_CHG" = "Charging" ]; then
        run_worker "$ZONE" "$LEVEL" "$STATUS" "battery_safe.sh"
        LAST_CHG="$STATUS"
    fi

    sleep 60
done
