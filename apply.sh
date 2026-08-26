#!/system/bin/sh
# ==========================================
# SysTune Apply Engine v1.0
# Applies CPU/GPU/Touch tuning
# ==========================================

PROFILE="$1"
[ -z "$PROFILE" ] && PROFILE="balanced"

CPU_PATH="/sys/devices/system/cpu"
GPU_PATH="/sys/class/devfreq/13000000.mali"
CFG="/data/adb/modules/SysTune/config"
CONF="$CFG/profile.conf"

mkdir -p "$CFG"
echo "$PROFILE" > "$CONF"

# ---------- SAFE SYSFS ----------
sys_write() {
    [ -w "$1" ] && echo "$2" > "$1" 2>/dev/null
}

# ---------- CPU ----------
# Cluster aware frequency setting
set_cluster_cpu() {
    local policy="$1" attr="$2" value="$3"
    local policy_path="$CPU_PATH/cpufreq/policy${policy}"
    if [ -d "$policy_path" ]; then
        for cpu in $(cat "$policy_path/related_cpus" 2>/dev/null); do
            sys_write "$CPU_PATH/cpu${cpu}/cpufreq/${attr}" "$value"
        done
    fi
}

# ---------- GPU ----------
set_gpu_gov() {
    sys_write "$GPU_PATH/governor" "$1"
}

set_gpu_max() {
    sys_write "$GPU_PATH/max_freq" "$1"
}

# ---------- TOUCH ----------
set_touch_boost() {
    sys_write /sys/module/msm_input/parameters/touch_boost "$1"
}

# ---------- APPLY ----------
case "$PROFILE" in

battery_saver)
    set_cluster_cpu 0 scaling_governor powersave
    set_cluster_cpu 0 scaling_min_freq 480000
    set_cluster_cpu 0 scaling_max_freq 1200000
    set_cluster_cpu 6 scaling_governor powersave
    set_cluster_cpu 6 scaling_min_freq 480000
    set_cluster_cpu 6 scaling_max_freq 1200000
    set_gpu_gov powersave
    set_gpu_max 450000000
    set_touch_boost 0
;;

balanced)
    set_cluster_cpu 0 scaling_governor schedutil
    set_cluster_cpu 0 scaling_min_freq 600000
    set_cluster_cpu 0 scaling_max_freq 1700000
    set_cluster_cpu 6 scaling_governor schedutil
    set_cluster_cpu 6 scaling_min_freq 600000
    set_cluster_cpu 6 scaling_max_freq 2400000
    set_gpu_gov simple_ondemand
    set_gpu_max 850000000
    set_touch_boost 1
;;

balanced_smooth)
    set_cluster_cpu 0 scaling_governor schedutil
    set_cluster_cpu 0 scaling_min_freq 650000
    set_cluster_cpu 0 scaling_max_freq 1800000
    set_cluster_cpu 6 scaling_governor schedutil
    set_cluster_cpu 6 scaling_min_freq 650000
    set_cluster_cpu 6 scaling_max_freq 2600000
    set_gpu_gov simple_ondemand
    set_gpu_max 900000000
    set_touch_boost 1
;;

performance)
    set_cluster_cpu 0 scaling_governor schedutil
    set_cluster_cpu 0 scaling_min_freq 1000000
    set_cluster_cpu 0 scaling_max_freq 2000000
    set_cluster_cpu 6 scaling_governor performance
    set_cluster_cpu 6 scaling_min_freq 1200000
    set_cluster_cpu 6 scaling_max_freq 2800000
    set_gpu_gov performance
    set_gpu_max 1130000000
    set_touch_boost 1
;;

game_mode)
    set_cluster_cpu 0 scaling_governor schedutil
    set_cluster_cpu 0 scaling_min_freq 1200000
    set_cluster_cpu 0 scaling_max_freq 1800000
    set_cluster_cpu 6 scaling_governor performance
    set_cluster_cpu 6 scaling_min_freq 1200000
    set_cluster_cpu 6 scaling_max_freq 2800000
    set_gpu_gov performance
    set_gpu_max 1130000000
    set_touch_boost 1
;;

*)
    echo "Unknown profile: $PROFILE"
    exit 1
;;

esac

# ---------- PERF EFFICIENCY TWEAKS ----------
PERF_TWEAKS="/data/adb/modules/SysTune/perf_efficiency.sh"
if [ -f "$PERF_TWEAKS" ]; then
    echo "[apply.sh] Executing Perf Efficiency: $PROFILE"
    # Use 'sh' to bypass +x requirement, but redirect errors to service log
    /system/bin/sh "$PERF_TWEAKS" "$PROFILE" >> /data/adb/modules/SysTune/logs/service.log 2>&1
else
    echo "[apply.sh] ERROR: $PERF_TWEAKS not found" >> /data/adb/modules/SysTune/logs/service.log
fi

# ---------- RUNTIME OPTIMIZATION ----------
RUNTIME_OPT="/data/adb/modules/SysTune/optimize_runtime.sh"
if [ -f "$RUNTIME_OPT" ]; then
    echo "[apply.sh] Executing Runtime Optimization: $PROFILE"
    /system/bin/sh "$RUNTIME_OPT" "$PROFILE" >> /data/adb/modules/SysTune/logs/service.log 2>&1
else
    echo "[apply.sh] ERROR: $RUNTIME_OPT not found" >> /data/adb/modules/SysTune/logs/service.log
fi

exit 0
