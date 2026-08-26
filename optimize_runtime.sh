#!/system/bin/sh
# ==========================================================
# SysTune – Runtime Optimization Layer v2.0
# Optimized for Zero-Fork Execution & Zero-Churn logic
# ==========================================================

PROFILE="$1"
[ -z "$PROFILE" ] && PROFILE="balanced"

SYS="/data/adb/modules/SysTune"
LOG="$SYS/logs/optimize_runtime.log"
mkdir -p "$SYS/logs"

log() {
    [ "${ENABLE_LOGGING:-0}" = "1" ] && echo "[optimize] $(date '+%H:%M:%S') | $1" >> "$LOG"
}

log "Applying runtime optimizations for profile: $PROFILE"

# ----------------------------------------------------------
# 1. App Control Logic (Hardened for Boot-time Stability)
# ----------------------------------------------------------

# ----------------------------------------------------------
# 1. App Control Logic (Hardened for Boot-time Stability)
# ----------------------------------------------------------

SET_APP_RESTRICTION() {
    local pkgs="$1"
    local mode="$2"

    # Use the 'service' binary directly - more robust across ROMs
    if ! service check appops | grep -q "found"; then
        log "SKIP: appops service not ready"
        return 1
    fi

    log "Applying AppOps: $mode"

    for pkg in $pkgs; do
        # tr ensures newlines/spaces from the BLOAT_APPS block don't break the command
        pkg_clean=$(echo "$pkg" | tr -d '[:space:]')
        [ -z "$pkg_clean" ] && continue
        
        # Standard AppOps call
        cmd appops set "$pkg_clean" RUN_IN_BACKGROUND "$mode" 2>/dev/null
        
        if [ "$PROFILE" = "battery_saver" ]; then
            cmd appops set "$pkg_clean" WAKE_LOCK "$mode" 2>/dev/null
        fi
    done
}



GLOBAL_CONF="/data/adb/modules/SysTune/config/global.conf"
[ -f "$GLOBAL_CONF" ] && . "$GLOBAL_CONF"


# ----------------------------------------------------------
# 2. Kernel/System Parameter Writes
# ----------------------------------------------------------
set_lmk() {
    [ -w /sys/module/lowmemorykiller/parameters/minfree ] && \
    echo "$1" > /sys/module/lowmemorykiller/parameters/minfree
}

# ----------------------------------------------------------
# 3. Timer Slack (Zero-Fork Logic)
# ----------------------------------------------------------
set_timer_slack() {
    local SLACK_NS="$1"
    local pid_dir uid_val cmd_val line

    for pid_dir in /proc/[0-9]*; do
        # 1. Quick exit for non-readable/disappearing processes
        [ -r "$pid_dir/status" ] || continue

        # 2. Extract UID using pure shell built-ins (No awk/cut/grep)
        uid_val=""
        while read -r line; do
            case "$line" in
                Uid:*)
                    # Extract the real UID (the first number after Uid:)
                    # Uses shell parameter expansion to trim prefixes/suffixes
                    uid_val=${line#Uid:[[:space:]]}
                    uid_val=${uid_val%%[[:space:]]*}
                    break
                    ;;
            esac
        done < "$pid_dir/status"

        # 3. Target User Apps only (UID >= 10000)
        [ -n "$uid_val" ] && [ "$uid_val" -ge 10000 ] || continue

        # 4. Target package-like names (com.*)
        if [ -r "$pid_dir/cmdline" ]; then
            # Read stops at the first null byte, giving us the process name
            read -r cmd_val < "$pid_dir/cmdline"
            case "$cmd_val" in
                com.*)
                    [ -w "$pid_dir/timerslack_ns" ] && \
                    echo "$SLACK_NS" > "$pid_dir/timerslack_ns" 2>/dev/null
                    ;;
            esac
        fi
    done
}

# ----------------------------------------------------------
# 4. Execution Logic (State Machine)
# ----------------------------------------------------------
CONF_FILE="/data/adb/modules/SysTune/config/profiles/${PROFILE}.conf"
if [ -f "$CONF_FILE" ]; then
    . "$CONF_FILE"
else
    log "Unknown profile: $PROFILE"
    exit 1
fi

SET_APP_RESTRICTION "$BLOAT_APPS" "$APP_RESTRICTION"
set_lmk "$LMK_MINFREE"
set_timer_slack "$TIMER_SLACK"

log "Optimizations applied for: $PROFILE"
exit 0
