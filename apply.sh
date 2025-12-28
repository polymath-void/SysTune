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
set_cpu_gov() {
    for c in $CPU_PATH/cpu[0-9]*; do
        sys_write "$c/cpufreq/scaling_governor" "$1"
    done
}

set_cpu_min() {
    for c in $CPU_PATH/cpu[0-9]*; do
        sys_write "$c/cpufreq/scaling_min_freq" "$1"
    done
}

set_cpu_max() {
    for c in $CPU_PATH/cpu[0-9]*; do
        sys_write "$c/cpufreq/scaling_max_freq" "$1"
    done
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
    set_cpu_gov powersave
    set_cpu_min 480000
    set_cpu_max 1200000
    set_gpu_gov powersave
    set_gpu_max 450000000
    set_touch_boost 0
;;

balanced)
    set_cpu_gov schedutil
    set_cpu_min 600000
    set_cpu_max 1700000
    set_gpu_gov simple_ondemand
    set_gpu_max 850000000
    set_touch_boost 1
;;

balanced_smooth)
    set_cpu_gov schedutil
    set_cpu_min 650000
    set_cpu_max 1800000
    set_gpu_gov simple_ondemand
    set_gpu_max 900000000
    set_touch_boost 1
;;

performance)
    set_cpu_gov performance
    set_cpu_min 1000000
    set_cpu_max 2000000
    set_gpu_gov performance
    set_gpu_max 1130000000
    set_touch_boost 1
;;

game_mode)
    set_cpu_gov schedutil
    set_cpu_min 1200000
    set_cpu_max 2000000
    set_gpu_gov performance
    set_gpu_max 1130000000
    set_touch_boost 1
;;

*)
    echo "Unknown profile: $PROFILE"
    exit 1
;;

esac

exit 0
