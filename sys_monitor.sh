#!/system/bin/sh
# ==========================================
# SysTune Monitor v3.0 - Interactive Dashboard
# Integrated system & auto_profile dashboard
# ==========================================

REFRESH=3
CPU_PATH="/sys/devices/system/cpu"
GPU_PATH="/sys/class/devfreq/13000000.mali"
SYS="/data/adb/modules/SysTune"
STATUS_FILE="$SYS/state/auto_profile.status"

# ---------- helpers ----------
read_file() { [ -f "$1" ] && cat "$1" 2>/dev/null; }

hz_to_ghz() { awk "BEGIN{printf \"%.2f\", $1/1000000}"; }
hz_to_mhz() { awk "BEGIN{printf \"%.0f\", $1/1000}"; }

# ---------- Hardware Info ----------
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

gpu_gov() { read_file "$GPU_PATH/governor"; }
gpu_cur() { hz_to_mhz "$(read_file "$GPU_PATH/cur_freq")"; }
gpu_max() { hz_to_mhz "$(read_file "$GPU_PATH/max_freq")"; }

mem_used() {
    awk '/MemTotal/ {t=$2} /MemAvailable/ {a=$2} END{printf "%.1f", (t-a)/1024/1024}' /proc/meminfo
}
mem_free() {
    awk '/MemAvailable/ {printf "%.1f", $2/1024/1024}' /proc/meminfo
}

bat_lvl() { read_file /sys/class/power_supply/battery/capacity; }
bat_stat() { read_file /sys/class/power_supply/battery/status; }
bat_temp() {
    for z in /sys/class/thermal/thermal_zone*; do
        [ "$(read_file "$z/type")" = "battery" ] &&
            awk '{printf "%.1f",$1/1000}' "$z/temp"
    done
}

thermal_avg() {
    awk '
    {
        if ($2 > 0 && $2 < 120000) {
            sum += $2; count++
        }
    }
    END {
        if (count>0) printf "%.1f", sum/count/1000
    }' $(grep -l "cpu" /sys/class/thermal/thermal_zone*/type 2>/dev/null)
}

ap_status() {
    if [ -f "$STATUS_FILE" ]; then
        head -n 1 "$STATUS_FILE" | cut -d' ' -f2
    else
        echo "Not running"
    fi
}

logging_status() {
    if [ -f "$SYS/state/logging_enabled" ]; then
        echo -e "\033[1;32mON\033[0m"
    else
        echo -e "\033[1;31mOFF\033[0m"
    fi
}

# ---------- UI & Input ----------
msg=""

apply_profile() {
    echo "$1" > "$SYS/state/manual_profile"
    msg="Profile changed to $1 (Daemon will sync shortly)"
}

# main loop
while true; do
    clear
    printf "\033[1;36m=== SysTune Interactive Dashboard ===\033[0m\n\n"

    # Row 1
    printf "\033[1;33m[ CPU ]\033[0m                   \033[1;33m[ GPU ]\033[0m\n"
    printf "Gov:  %-15s   Gov:  %-15s\n" "$(cpu_gov)" "$(gpu_gov)"
    printf "Load: %-15s   Cur:  %-15s\n" "$(cpu_load)%" "$(gpu_cur) MHz"
    printf "Avg:  %-15s   Max:  %-15s\n" "$(cpu_avg_freq) GHz" "$(gpu_max) MHz"
    echo ""

    # Row 2
    printf "\033[1;32m[ MEMORY ]\033[0m                \033[1;32m[ BATTERY ]\033[0m\n"
    printf "Used: %-15s   Level:  %-15s\n" "$(mem_used) GB" "$(bat_lvl)%"
    printf "Free: %-15s   Status: %-15s\n" "$(mem_free) GB" "$(bat_stat)"
    printf "                        Temp:   %-15s\n" "$(bat_temp)°C"
    echo ""

    # Row 3
    printf "\033[1;35m[ SYSTEM STATE ]\033[0m\n"
    printf "Active Profile: \033[1;37m%-15s\033[0m\n" "$(ap_status)"
    printf "CPU Avg Temp:   %-15s\n" "$(thermal_avg)°C"
    echo ""

    # Actions Box
    printf "\033[1;34m┌─────────────────────────────────────────┐\033[0m\n"
    printf "\033[1;34m│\033[0m \033[1;37mINSTANT ACTIONS\033[0m                         \033[1;34m│\033[0m\n"
    printf "\033[1;34m│\033[0m [0] Auto Profile (Remove Override)        \033[1;34m│\033[0m\n"
    printf "\033[1;34m│\033[0m [1] Force Battery Saver                   \033[1;34m│\033[0m\n"
    printf "\033[1;34m│\033[0m [2] Force Balanced                        \033[1;34m│\033[0m\n"
    printf "\033[1;34m│\033[0m [3] Drop RAM Caches (Clear Memory)        \033[1;34m│\033[0m\n"
    printf "\033[1;34m│\033[0m [4] Restart SysTune Daemon                \033[1;34m│\033[0m\n"
    printf "\033[1;34m│\033[0m [5] Toggle Performance Logs (Now: $(logging_status)) \033[1;34m│\033[0m\n"
    printf "\033[1;34m│\033[0m [R] Refresh Dashboard       [Q] Quit      \033[1;34m│\033[0m\n"
    printf "\033[1;34m└─────────────────────────────────────────┘\033[0m\n"

    # Message popup
    if [ -n "$msg" ]; then
        printf "\n\033[1;32m=> $msg\033[0m\n"
        msg=""
    else
        echo ""
    fi

    # Read input with timeout
    read -t "$REFRESH" -n 1 key

    case "$key" in
        0) 
            rm -f "$SYS/state/manual_profile"
            msg="Restored Auto Profile Logic!"
            ;;
        1) apply_profile "battery_saver" ;;
        2) apply_profile "balanced" ;;
        3) 
            echo 3 > /proc/sys/vm/drop_caches 2>/dev/null
            msg="RAM Caches Dropped!"
            ;;
        4) 
            pkill -f orchestrator
            sh "$SYS/service.sh"
            msg="Daemon Restarted!"
            ;;
        5)
            if [ -f "$SYS/state/logging_enabled" ]; then
                rm -f "$SYS/state/logging_enabled"
                msg="Performance Logging DISABLED"
            else
                touch "$SYS/state/logging_enabled"
                msg="Performance Logging ENABLED"
            fi
            ;;
        q|Q) 
            clear
            exit 0 
            ;;
        r|R) 
            msg="Refreshed."
            ;;
    esac
done
