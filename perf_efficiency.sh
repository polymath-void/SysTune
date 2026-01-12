#!/system/bin/sh
# ==========================================================
# SysTune v2.1 – MTK sugov_ext Optimized (Zero-Fork)
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

log "===== Applying MTK Perf Efficiency: $PROFILE ====="

# Define parameters based on First Principles
case "$PROFILE" in
    battery_saver)
        CPU_RATE=20000 # High latency = Less frequency jitter
        PEAK=60; MIN=30; BOOST=0
        ;;
    performance|balanced_smooth)
        CPU_RATE=1000  # Low latency = Maximum responsiveness
        PEAK=120; MIN=60; BOOST=1
        ;;
    *) # Balanced
        CPU_RATE=4000
        PEAK=120; MIN=60; BOOST=0
        ;;
esac

# ----------------------------------------------------------
# 1. CPU Governor Tuning (sugov_ext & schedutil)
# ----------------------------------------------------------
# Logic: MediaTek sugov_ext splits rate limits into up/down nodes
for policy in /sys/devices/system/cpu/cpufreq/policy*; do
    [ -r "$policy/scaling_governor" ] || continue
    read -r CUR_GOV < "$policy/scaling_governor"

    # Support both standard schedutil and MTK's extended version
    if [ "$CUR_GOV" = "schedutil" ] || [ "$CUR_GOV" = "sugov_ext" ]; then
        GOV_DIR="$policy/$CUR_GOV"
        
        if [ -d "$GOV_DIR" ]; then
            # Iterate through all possible MTK rate limit nodes
            for node in up_rate_limit_us down_rate_limit_us rate_limit_us; do
                TARGET="$GOV_DIR/$node"
                if [ -w "$TARGET" ]; then
                    echo "$CPU_RATE" > "$TARGET" 2>/dev/null
                fi
            done
            log "Tuned $policy ($CUR_GOV) to $CPU_RATE"
        fi
    else
        log "Skipped $policy: Governor is $CUR_GOV (Path hidden)"
    fi
done



# ----------------------------------------------------------
# 2. Schedtune / UClamp (MTK EAS Tuning)
# ----------------------------------------------------------
if [ -f /dev/stune/top-app/schedtune.boost ]; then
    echo "$BOOST" > /dev/stune/top-app/schedtune.boost
elif [ -d /sys/fs/cgroup/cpu/top-app ]; then
    # UClamp logic for kernels 5.4+ (Modern Dimensity chips)
    [ -w /sys/fs/cgroup/cpu/top-app/cpu.uclamp.min ] && echo "$BOOST" > /sys/fs/cgroup/cpu/top-app/cpu.uclamp.min
fi

# ----------------------------------------------------------
# 3. I/O Scheduler (Physical Storage Only)
# ----------------------------------------------------------
for queue in /sys/block/sd*/queue /sys/block/mmcblk*/queue; do
    [ -d "$queue" ] || continue
    [ -w "$queue/scheduler" ] && echo "mq-deadline" > "$queue/scheduler" 2>/dev/null
    [ -w "$queue/add_random" ] && echo 0 > "$queue/add_random" 2>/dev/null
    # Disable iostats to reduce CPU overhead from storage tracking
    [ -w "$queue/iostats" ] && echo 0 > "$queue/iostats" 2>/dev/null
done

# ----------------------------------------------------------
# 4. Display Refresh Rate (Java VM Fork Guard)
# ----------------------------------------------------------
# 'settings' is expensive. Only call if a change is needed.
CUR_PEAK=$(settings get system peak_refresh_rate 2>/dev/null)
if [ "$CUR_PEAK" != "$PEAK" ]; then
    settings put system peak_refresh_rate "$PEAK"
    settings put system min_refresh_rate "$MIN"
    log "Display set to ${PEAK}Hz"
fi

log "===== Perf efficiency applied successfully ====="
