# SysTune

**Author:** Rahman Shuvo  
**Tested on:** Nothing Phone 2a (MediaTek)

---

## Overview

SysTune is a Termux + root-based system management suite for Mediatek Android devices.  
It provides fine-grained control over charging behavior, automatic system profiles, and real-time monitoring.

SysTune consists of three main modules:

1. **Battery Safe (`battery_safe.sh`)**  
   - Safely manages charging to extend battery life by pausing and resuming charging at configurable thresholds (80%, 90%, 95%, 100%).  
   - Uses kernel-level control, logging, and a status file for tracking.  

2. **Auto Profile (`auto_profile.sh`)**  
   - Automatically switches Termux/system profiles based on battery level or custom triggers.  
   - Profiles are defined in `/data/adb/modules/SysTune/config/profile.conf`.  
   - Status is tracked in `/data/adb/modules/SysTune/state/auto_profile.status`.  

3. **Terminal Monitor (`sys_monitor.sh`)**  
   - Provides a live terminal-based dashboard showing CPU, memory, battery, and module activity.  
   - Integrates with both Battery Safe and Auto Profile for centralized system status monitoring.  

---

## Features

- Kernel-level battery charging control (safe, prevents rapid on/off cycles)  
- Pause/resume charging at configurable battery levels  
- Hard stop at 100% battery  
- Automatic profile switching based on triggers  
- Real-time system monitoring in terminal  
- Detailed logging and status files for each module  
- Git-tracked project for version control  

---

## Installation

1. Clone the repository (example path):

git clone https://github.com/rahmanshuvo-bd/SysTune.git ~/SysTune

and move or copy SysTune directory to "/data/adb/modules"

Or just check last release, just download the module as zip and flash via Magisk KSU.

For clone(:-:)
Grant execution permissions:
Bash
cd ~/SysTune
chmod +x *.sh

**Usage Notes:**
If you flashed the zip via KSU or Magisk, just relax rest of the things scripts do automatically.

#Manual user

*Battery Safe*

Bash
su -c "/data/adb/modules/SysTune/battery_safe.sh"

* Automatically starts when charger is connected.
* Monitors battery every 15 seconds.
* Pauses/resumes charging at 80%, 90%, 95%, and resume till the charger connected.
* Logs and status files:
** /data/adb/modules/SysTune/logs/battery_safe.log
** /data/adb/modules/SysTune/state/battery_safe.status

*Auto Profile*

Bash
su -c "/data/adb/modules/SysTune/auto_profile.sh"

* Automatically switches profiles based on triggers.
* Logs and status files:
** /data/adb/modules/SysTune/logs/auto_profile.log
** /data/adb/modules/SysTune/state/auto_profile.status

*Terminal Monitor*

Bash
su -c "/data/adb/modules/SysTune/sys_monitor.sh"

* Provides live system metrics and module status.
* Useful for debugging and monitoring Battery Safe / Auto Profile activities.

**License**

MIT License
