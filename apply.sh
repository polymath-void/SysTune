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

# ---------- LOAD CONFIG ----------
CONF_FILE="/data/adb/modules/SysTune/config/profiles/${PROFILE}.conf"
if [ -f "$CONF_FILE" ]; then
    . "$CONF_FILE"
else
    echo "Unknown profile: $PROFILE"
    exit 1
fi

# ---------- APPLY ----------
set_cluster_cpu 0 scaling_governor "$CPU_LITTLE_GOV"
set_cluster_cpu 0 scaling_min_freq "$CPU_LITTLE_MIN"
set_cluster_cpu 0 scaling_max_freq "$CPU_LITTLE_MAX"
set_cluster_cpu 6 scaling_governor "$CPU_BIG_GOV"
set_cluster_cpu 6 scaling_min_freq "$CPU_BIG_MIN"
set_cluster_cpu 6 scaling_max_freq "$CPU_BIG_MAX"
set_gpu_gov "$GPU_GOV"
set_gpu_max "$GPU_MAX"
set_touch_boost "$TOUCH_BOOST"

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
