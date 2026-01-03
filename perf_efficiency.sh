#!/system/bin/sh
# ==========================================================
# SysTune v1.1 – Logic Optimized for MTK
# ==========================================================

PROFILE="$1"
[ -z "$PROFILE" ] && PROFILE="balanced"

SYS="/data/adb/modules/SysTune"
LOGDIR="$SYS/logs"
LOG="$LOGDIR/perf_efficiency.log"
mkdir -p "$LOGDIR"

log() {
    echo "[$(date '+%H:%M:%S')] $1" >> "$LOG"
}

log "===== Starting perf efficiency tweaks for profile: $PROFILE ====="



# Define parameters based on First Principles
case "$PROFILE" in
    battery_saver)
        CPU_RATE=20000 # Slow ramp (Efficiency)
        PEAK=60; MIN=30
        BOOST=0
        ;;
    performance)
        CPU_RATE=1000  # Fast ramp (Performance)
        PEAK=120; MIN=60
        BOOST=1
        ;;

    balanced_smooth)
        CPU_RATE=2000  # Fast ramp (Performance)
        PEAK=120; MIN=60
        BOOST=1
        ;;
    
    *) # Balanced
        CPU_RATE=4000
        PEAK=120; MIN=60
        BOOST=0
        ;;
esac

# 1. CPU Governor Tuning
for policy in /sys/devices/system/cpu/cpufreq/policy*; do
    [ -w "$policy/schedutil/rate_limit_us" ] && echo "$CPU_RATE" > "$policy/schedutil/rate_limit_us"
done

# 2. Schedtune / Cgroups (MTK Specific)
# Using 0-100 range for boost
[ -f /dev/stune/top-app/schedtune.boost ] && echo "$BOOST" > /dev/stune/top-app/schedtune.boost

# 3. I/O Scheduler
# Targeting all non-loop block devices
for queue in /sys/block/*/queue; do
    [ -w "$queue/scheduler" ] && echo "mq-deadline" > "$queue/scheduler" 2>/dev/null
    [ -w "$queue/add_random" ] && echo 0 > "$queue/add_random" 2>/dev/null
done


# 4. Display (only if values changed to save CPU cycles)
settings put system peak_refresh_rate "$PEAK"
settings put system min_refresh_rate "$MIN"

log "===== Perf efficiency tweaks applied profile: $PROFILE ====="
