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
    echo "[optimize] $(date '+%H:%M:%S') | $1" >> "$LOG"
}

log "Applying runtime optimizations for profile: $PROFILE"

# ----------------------------------------------------------
# 1. App Control Logic
# ----------------------------------------------------------

# Use appops instead of pm disable where possible to avoid broadcast storms
SET_APP_RESTRICTION() {
    local mode="$2" # ignore or allow
    for pkg in $1; do
        cmd appops set "$pkg" RUN_IN_BACKGROUND "$mode" 2>/dev/null
        cmd appops set "$pkg" WAKE_LOCK "$mode" 2>/dev/null
    done
}

BLOAT_APPS="
com.facebook.katana
com.facebook.appmanager
com.facebook.services
com.facebook.system
com.miui.analytics
com.google.android.feedback
com.google.android.printservice.recommendation
"

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
case "$PROFILE" in

    battery_saver)
        SET_APP_RESTRICTION "$BLOAT_APPS" "ignore"
        set_lmk "18432,23040,27648,32256,55296,80640"
        set_timer_slack 50000000 # 50ms batching
        ;;

    balanced_smooth|balanced)
        SET_APP_RESTRICTION "$BLOAT_APPS" "allow"
        set_lmk "12288,15360,18432,21504,43008,64512"
        set_timer_slack 20000000 # 20ms batching
        ;;

    performance|game_mode)
        SET_APP_RESTRICTION "$BLOAT_APPS" "allow"
        set_lmk "8192,10240,12288,14336,28672,40960"
        set_timer_slack 1000000  # 1ms (High responsiveness)
        ;;

esac

log "Optimizations applied for: $PROFILE"
exit 0
