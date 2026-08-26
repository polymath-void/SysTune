#!/system/bin/sh
# SysTune - Event-Driven Rust Orchestrator Wrapper

MODDIR=${0%/*}

# Production Grade: Wait for Android to finish booting before starting the orchestrator
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 2
done

# Support both development and production binary paths
if [ -f "$MODDIR/orchestrator_bin" ]; then
    BIN="$MODDIR/orchestrator_bin"
else
    BIN="$MODDIR/orchestrator/target/release/orchestrator"
fi

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
    echo "[$(date)] SysTune Binary not found at $BIN." > "$MODDIR/logs/service.err"
    exit 1
fi
