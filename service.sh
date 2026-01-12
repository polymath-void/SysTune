#!/system/bin/sh
# SysTune - Production Service v4.2

# 1. Delay to ensure system is fully booted
sleep 30

MODDIR="/data/adb/modules/SysTune"
# Set highest priority (Real-time / High Priority)
# Replace this
# renice -n -20 -p $$
# ionice -c 1 -n 0 -p $$

# With this
renice -n 10 -p $$
ionice -c 2 -n 7 -p $$ 2>/dev/null

# Export variables for sourced worker
export SYS="$MODDIR"
export STATE="$SYS/state"
export BAT_CAP="/sys/class/power_supply/battery/capacity"
export BAT_STAT="/sys/class/power_supply/battery/status"

# Reset state on boot to ensure fresh application
rm -f "$STATE/auto_profile.status"
LAST_ZONE="-1"
LAST_STAT=""

get_zone() {
    local cap=$1
    if [ "$cap" -le 30 ]; then echo 0; elif [ "$cap" -le 80 ]; then echo 1; else echo 2; fi
}

# The Zero-Fork Loop
# ... initialization block ...

while true; do
	# Pure shell reads (Zero-Fork)
	read -r CUR_BAT < "$BAT_CAP" 2>/dev/null || CUR_BAT=50
	read -r CUR_STAT < "$BAT_STAT" 2>/dev/null || CUR_STAT="Discharging"
	
    CUR_ZONE=$(get_zone "$CUR_BAT")

    # Event Trigger: Change in Zone or Power Status
    if [ "$CUR_ZONE" != "$LAST_ZONE" ] || [ "$CUR_STAT" != "$LAST_STAT" ]; then
        . "$SYS/auto_profile.sh"

        # On Unplug: Reset Charging Hardware & Safety State
        if [ "$CUR_STAT" != "Charging" ]; then
            [ -w /sys/class/power_supply/mtk-master-charger/input_current_limit ] && \
                echo 3200000 > /sys/class/power_supply/mtk-master-charger/input_current_limit
            rm -f "$STATE/battery_safe.state"
        fi

        LAST_ZONE="$CUR_ZONE"
        LAST_STAT="$CUR_STAT"
    fi

    # While Charging: Run worker every 60s
    if [ "$CUR_STAT" = "Charging" ]; then
        . "$SYS/battery_safe.sh"
        sleep 60
    else
        sleep 120
    fi
done

