#!/system/bin/sh
# SysTune - Event-Driven Rust Orchestrator Wrapper

MODDIR="/data/adb/modules/SysTune"
BIN="$MODDIR/orchestrator/target/release/orchestrator"

# --- Singleton Guard ---
PIDFILE="$MODDIR/state/service.pid"
if [ -f "$PIDFILE" ]; then
    OLD_PID=$(cat "$PIDFILE")
    if [ -d "/proc/$OLD_PID" ] && grep -q "orchestrator" "/proc/$OLD_PID/cmdline" 2>/dev/null; then
        exit 0
    fi
    rm -f "$PIDFILE"
fi

mkdir -p "$MODDIR/state" "$MODDIR/logs"
chmod 755 "$MODDIR"/*.sh

if [ -f "$BIN" ]; then
    chmod +x "$BIN"
    exec "$BIN" &
else
    echo "[$(date)] SysTune Binary not found at $BIN. Please compile it with cargo." > "$MODDIR/logs/service.err"
    exit 1
fi
