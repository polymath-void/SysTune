#!/system/bin/sh
# ==========================================
# SysTune Module Uninstaller
# Author: Rahman Shuvo
# ==========================================

MODDIR="/data/adb/modules/SysTune"

echo "⚡ Uninstalling SysTune Module..."

# Kill running scripts
for SCRIPT in auto_profile battery_safe sys_monitor service; do
    PIDFILE="$MODDIR/$SCRIPT.pid"
    if [ -f "$PIDFILE" ]; then
        PID=$(cat "$PIDFILE")
        if kill -0 "$PID" 2>/dev/null; then
            echo "🛑 Killing $SCRIPT (PID $PID)"
            kill "$PID"
        fi
        rm -f "$PIDFILE"
    fi
done

# Remove logs and status files
echo "🗑 Removing logs and state files..."
rm -rf "$MODDIR/logs"/*
rm -rf "$MODDIR/state"/*

# Optional: reset configs
CONFIG_DIR="$MODDIR/config"
if [ -d "$CONFIG_DIR" ]; then
    echo "⚙ Resetting configs..."
    rm -f "$CONFIG_DIR/profile.conf"
fi

echo "✅ SysTune Module uninstalled successfully."
exit 0
