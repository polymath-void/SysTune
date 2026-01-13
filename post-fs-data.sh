#!/system/bin/sh
# SysTune Boot Anchor
# Fix permissions at every boot

chown -R root:root /data/adb/modules/SysTune && chmod -R 755 /data/adb/modules/SysTune

# Launch the daemon into the Global Namespace
/system/bin/sh /data/adb/modules/SysTune/service.sh --daemon &
