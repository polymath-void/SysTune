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
[ -f "$SYS/state/logging_enabled" ] && ENABLE_LOGGING=1 || ENABLE_LOGGING=0

log() {
    [ "$ENABLE_LOGGING" = "1" ] && echo "[$(date '+%H:%M:%S')] $1" >> "$LOG"
}

log "===== Applying MTK Perf Efficiency: $PROFILE ====="

CONF_FILE="/data/adb/modules/SysTune/config/profiles/${PROFILE}.conf"
if [ -f "$CONF_FILE" ]; then
    . "$CONF_FILE"
else
    log "Unknown profile: $PROFILE"
    exit 1
fi
PEAK="$PEAK_FPS"
MIN="$MIN_FPS"
BOOST="$STUNE_BOOST"

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
if [ -d /sys/fs/cgroup/cpu/top-app ]; then
    # UClamp logic for kernels 5.4+ (Modern Dimensity chips)
    [ -w /sys/fs/cgroup/cpu/top-app/cpu.uclamp.min ] && echo "$UCLAMP_FG_MIN" > /sys/fs/cgroup/cpu/top-app/cpu.uclamp.min 2>/dev/null
    [ -w /sys/fs/cgroup/cpu/background/cpu.uclamp.max ] && echo "$UCLAMP_BG_MAX" > /sys/fs/cgroup/cpu/background/cpu.uclamp.max 2>/dev/null
    [ -w /sys/fs/cgroup/cpu/top-app/schedtune.boost ] && echo "$STUNE_BOOST" > /sys/fs/cgroup/cpu/top-app/schedtune.boost 2>/dev/null
elif [ -d /dev/cpuctl/top-app ]; then
    # Android 13/14 cgroup v2 mounts
    [ -w /dev/cpuctl/top-app/cpu.uclamp.min ] && echo "$UCLAMP_FG_MIN" > /dev/cpuctl/top-app/cpu.uclamp.min 2>/dev/null
    [ -w /dev/cpuctl/background/cpu.uclamp.max ] && echo "$UCLAMP_BG_MAX" > /dev/cpuctl/background/cpu.uclamp.max 2>/dev/null
elif [ -f /dev/stune/top-app/schedtune.boost ]; then
    echo "$STUNE_BOOST" > /dev/stune/top-app/schedtune.boost 2>/dev/null
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
# 4. Display Refresh Rate (Service Guarded)
# ----------------------------------------------------------
# Use 'getprop' and 'service check' to ensure the Settings provider is safely ready
if [ "$(getprop sys.boot_completed)" = "1" ] && service check settings | grep -q "found"; then
    CUR_PEAK=$(settings get system peak_refresh_rate 2>/dev/null)
    if [ "$CUR_PEAK" != "$PEAK" ]; then
        settings put system peak_refresh_rate "$PEAK" >/dev/null 2>&1
        settings put system min_refresh_rate "$MIN" >/dev/null 2>&1
        log "Display set to ${PEAK}Hz"
    fi
else
    log "SKIP: settings service not ready (device still booting)"
fi

# ----------------------------------------------------------
# 5. FPSGO (Frame Boost Technology) - Phase 3
# ----------------------------------------------------------
FPSGO_PATH="/sys/kernel/fpsgo"
if [ "$FBT_ENABLE" = "1" ] && [ -d "$FPSGO_PATH" ]; then
    [ -w "$FPSGO_PATH/fbt/boost_ta" ] && echo "$FBT_BOOST_TA" > "$FPSGO_PATH/fbt/boost_ta" 2>/dev/null
    [ -w "$FPSGO_PATH/fbt/rescue_percent" ] && echo "$FBT_RESCUE_PERCENT" > "$FPSGO_PATH/fbt/rescue_percent" 2>/dev/null
    [ -w "$FPSGO_PATH/fbt/ultra_rescue" ] && echo "$FBT_ULTRA_RESCUE" > "$FPSGO_PATH/fbt/ultra_rescue" 2>/dev/null
    [ -w "$FPSGO_PATH/fbt/floor_bound" ] && echo "$FBT_FLOOR_BOUND" > "$FPSGO_PATH/fbt/floor_bound" 2>/dev/null
    [ -w "$FPSGO_PATH/fbt_cam/fbt_cam_uclamp_boost_enable" ] && echo "$FBT_CAM_BOOST" > "$FPSGO_PATH/fbt_cam/fbt_cam_uclamp_boost_enable" 2>/dev/null
    log "FPSGO Tuned: TA=$FBT_BOOST_TA Rescue=$FBT_RESCUE_PERCENT Floor=$FBT_FLOOR_BOUND"
fi

log "===== Perf efficiency applied successfully ====="
