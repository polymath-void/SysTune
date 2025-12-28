#!/system/bin/sh
# ==========================================
# SysTune Monitor v2.0
# Integrated system & auto_profile dashboard
# Author: Rahman
# ==========================================

REFRESH=5
CPU_PATH="/sys/devices/system/cpu"
GPU_PATH="/sys/class/devfreq/13000000.mali"
SYS="/data/adb/modules/SysTune"
STATUS_FILE="$SYS/state/auto_profile.status"

# ---------- helpers ----------
read_file() { [ -f "$1" ] && cat "$1" 2>/dev/null; }

hz_to_ghz() { awk "BEGIN{printf \"%.2f\", $1/1000000}"; }
hz_to_mhz() { awk "BEGIN{printf \"%.0f\", $1/1000}"; }

# ---------- CPU ----------
cpu_gov() { read_file "$CPU_PATH/cpu0/cpufreq/scaling_governor"; }

cpu_avg_freq() {
    total=0; count=0
    for f in $CPU_PATH/cpu*/cpufreq/scaling_cur_freq; do
        v=$(read_file "$f")
        [ -n "$v" ] && total=$((total+v)) && count=$((count+1))
    done
    [ "$count" -gt 0 ] && hz_to_ghz $((total/count))
}

cpu_load() {
    awk '/^cpu / {u=($2+$4)*100/($2+$4+$5); printf "%.0f",u}' /proc/stat
}

# ---------- GPU ----------
gpu_gov() { read_file "$GPU_PATH/governor"; }
gpu_cur() { hz_to_mhz "$(read_file "$GPU_PATH/cur_freq")"; }
gpu_max() { hz_to_mhz "$(read_file "$GPU_PATH/max_freq")"; }

# ---------- Memory ----------
mem_used() {
    awk '/MemTotal/ {t=$2} /MemAvailable/ {a=$2} END{printf "%.1f", (t-a)/1024/1024}' /proc/meminfo
}
mem_free() {
    awk '/MemAvailable/ {printf "%.1f", $2/1024/1024}' /proc/meminfo
}
swap_used() {
    awk '/SwapTotal/ {t=$2} /SwapFree/ {f=$2} END{printf "%.1f / %.1f", (t-f)/1024/1024, t/1024/1024}' /proc/meminfo
}

# ---------- Battery ----------
bat_lvl() { read_file /sys/class/power_supply/battery/capacity; }
bat_stat() { read_file /sys/class/power_supply/battery/status; }
bat_temp() {
    for z in /sys/class/thermal/thermal_zone*; do
        [ "$(read_file "$z/type")" = "battery" ] &&
            awk '{printf "%.1f",$1/1000}' "$z/temp"
    done
}

# ---------- Thermal ----------
thermal_avg() {
    awk '
    {
        if ($2 > 0 && $2 < 120000) {
            sum += $2; count++
        }
    }
    END {
        if (count>0) printf "%.1f", sum/count/1000
    }' $(grep -l "cpu" /sys/class/thermal/thermal_zone*/type)
}

gpu_temp() {
    for z in /sys/class/thermal/thermal_zone*; do
        type=$(read_file "$z/type")
        [ "$type" = "gpu1" ] && awk '{printf "%.1f",$1/1000}' "$z/temp"
    done
}

# ---------- Auto Profile ----------
ap_status() {
    if [ -f "$STATUS_FILE" ]; then
        read_file "$STATUS_FILE"
    else
        echo "Auto Profile: Not running"
    fi
}

# ---------- UI ----------
box() {
    title="$1"; l1="$2"; l2="$3"; l3="$4"
    printf "┌──────── %-12s ────────┐\n" "$title"
    printf "│ %-22s │\n" "$l1"
    printf "│ %-22s │\n" "$l2"
    printf "│ %-22s │\n" "$l3"
    printf "└────────────────────────┘\n"
}

# ---------- main loop ----------
while true; do
    clear

    box "DEVICE" \
        "Kernel: $(uname -r)" \
        "Arch: $(uname -m)" \
        "Cores: $(nproc)"

    box "CPU" \
        "Gov: $(cpu_gov)" \
        "Avg: $(cpu_avg_freq) GHz" \
        "Load: $(cpu_load)%"

    box "GPU" \
        "Gov: $(gpu_gov)" \
        "Cur: $(gpu_cur) MHz" \
        "Max: $(gpu_max) MHz"

    box "MEMORY" \
        "Used: $(mem_used) GB" \
        "Free: $(mem_free) GB" \
        "Swap: $(swap_used) GB"

    box "BATTERY" \
        "Level: $(bat_lvl)%" \
        "Status: $(bat_stat)" \
        "Temp: $(bat_temp)°C"

    box "THERMAL" \
        "CPU Avg: $(thermal_avg)°C" \
        "GPU: $(gpu_temp)°C" \
        "State: Normal"

    box "AUTO PROFILE" \
        "$(ap_status)" \
        "" \
        "[R] Refresh | [Q] Quit"

    read -t "$REFRESH" -n 1 key
    [ "$key" = "q" ] && exit
done
