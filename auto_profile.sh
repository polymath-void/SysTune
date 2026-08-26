#!/system/bin/sh
# SysTune Auto Profile Worker v5.0 (Unified Hybrid Engine)
# Edge-triggered, idempotent, kernel-safe master execution layer

SYS="${SYS:-/data/adb/modules/SysTune}"
STATE_DIR="$SYS/state"
STATE="$STATE_DIR/auto_profile.status"
LAST_PROFILE_FILE="$STATE_DIR/last_profile"
LOG="$SYS/logs/auto_profile.log"

mkdir -p "$STATE_DIR"
[ -f "$STATE_DIR/logging_enabled" ] && ENABLE_LOGGING=1 || ENABLE_LOGGING=0

# Manual fallback
if [ -z "$NEW_PROFILE" ]; then
    NEW_PROFILE="balanced"
    CUR_BAT="$(cat /sys/class/power_supply/battery/capacity 2>/dev/null || echo 0)"
fi

# Read last applied profile (if any)
LAST_PROFILE="$(cat "$LAST_PROFILE_FILE" 2>/dev/null)"

# ---------- EDGE TRIGGER ----------
if [ "$NEW_PROFILE" = "$LAST_PROFILE" ]; then
    return 0 2>/dev/null || exit 0
fi

# ---------- LOAD CONFIG ----------
CONF_FILE="$SYS/config/profiles/${NEW_PROFILE}.conf"
if [ -f "$CONF_FILE" ]; then
    . "$CONF_FILE"
else
    echo "Unknown profile: $NEW_PROFILE"
    return 1 2>/dev/null || exit 1
fi

# ---------- SAFE SYSFS ----------
sys_write() { [ -w "$1" ] && echo "$2" > "$1" 2>/dev/null; }

set_cluster_cpu() {
    local policy="$1" attr="$2" value="$3"
    local policy_path="/sys/devices/system/cpu/cpufreq/policy${policy}"
    if [ -d "$policy_path" ]; then
        for cpu in $(cat "$policy_path/related_cpus" 2>/dev/null); do
            sys_write "/sys/devices/system/cpu/cpu${cpu}/cpufreq/${attr}" "$value"
        done
    fi
}

# ---------- APPLY ----------
set_cluster_cpu 0 scaling_governor "$CPU_LITTLE_GOV"
set_cluster_cpu 0 scaling_min_freq "$CPU_LITTLE_MIN"
set_cluster_cpu 0 scaling_max_freq "$CPU_LITTLE_MAX"
set_cluster_cpu 6 scaling_governor "$CPU_BIG_GOV"
set_cluster_cpu 6 scaling_min_freq "$CPU_BIG_MIN"
set_cluster_cpu 6 scaling_max_freq "$CPU_BIG_MAX"
sys_write "/sys/class/devfreq/13000000.mali/governor" "$GPU_GOV"
sys_write "/sys/class/devfreq/13000000.mali/max_freq" "$GPU_MAX"
sys_write "/sys/module/msm_input/parameters/touch_boost" "$TOUCH_BOOST"

# ---------- WORKERS ----------
[ -f "$SYS/perf_efficiency.sh" ] && /system/bin/sh "$SYS/perf_efficiency.sh" "$NEW_PROFILE" >> "$SYS/logs/service.log" 2>&1
[ -f "$SYS/optimize_runtime.sh" ] && /system/bin/sh "$SYS/optimize_runtime.sh" "$NEW_PROFILE" >> "$SYS/logs/service.log" 2>&1

# ---------- PERSIST STATE ----------
{
    echo "Profile: $NEW_PROFILE"
    echo "Battery: $CUR_BAT"
    echo "Timestamp: $(date +%s)"
} > "$STATE.tmp" && mv -f "$STATE.tmp" "$STATE"

echo "$NEW_PROFILE" > "$LAST_PROFILE_FILE"
chmod 644 "$STATE" "$LAST_PROFILE_FILE"

[ "${ENABLE_LOGGING:-0}" = "1" ] && echo "[$(date '+%H:%M:%S')] Applied $NEW_PROFILE at ${CUR_BAT}%" >> "$LOG"

return 0 2>/dev/null || exit 0
