# SysTune

**Author:** Polymath-Void  
**Tested on:** Nothing Phone 2a (MediaTek)

SysTune is a Termux + root-based system management suite for MediaTek Android devices. It provides fine-grained control over **battery charging, automatic profile switching, performance efficiency, runtime optimization, and real-time monitoring**. SysTune ensures **battery safety, performance stability, and optimized runtime behavior** without user intervention.

---

## Modules & Features

### Battery Safe (`battery_safe.sh`)
- Safely manages charging thresholds (80%, 90%, 95%, 100%)  
- Thermal guard prevents overheating with hysteresis logic  
- Zero-fork implementation; reads/writes kernel nodes directly  
- Logs and atomic state tracking  
- Automatic trigger when charger is connected

### Auto Profile (`auto_profile.sh`)
- Switches system/Termux profiles automatically based on battery or custom triggers  
- Configurable via `/data/adb/modules/SysTune/config/profile.conf`  
- Works with Battery Safe & performance tuning  
- Logs and state tracking

### Terminal Monitor (`sys_monitor.sh`)
- Live terminal dashboard showing CPU, memory, battery, and module activity  
- Centralized view of Battery Safe & Auto Profile  
- Useful for debugging and monitoring module activity

### Performance Efficiency (`perf_efficiency.sh`)
- Dynamically balances CPU/GPU performance vs efficiency  
- Load-based scaling prevents battery drain while maintaining responsiveness  
- Works with Auto Profile for profile-specific tuning

### Runtime Optimizer (`optimize_runtime.sh`)
- Monitors RAM, background processes, and memory pressure  
- Adjusts Low Memory Killer (LMK) minfree to prevent aggressive OOM kills  
- Throttles background tasks when battery is low or thermal limits are reached

---

## Features Table

| Feature | Battery Safe | Auto Profile | Terminal Monitor | Perf Efficiency | Runtime Optimizer |
|---------|:------------:|:------------:|:----------------:|:---------------:|:----------------:|
| Charging Threshold Control | ✅ |  |  |  |  |
| Thermal Protection | ✅ |  |  |  |  |
| Zero-Fork Implementation | ✅ |  |  |  |  |
| Automatic Profile Switching |  | ✅ |  |  |  |
| CPU/GPU Scaling Optimization |  |  |  | ✅ |  |
| Runtime Memory Optimization |  |  |  |  | ✅ |
| Real-Time Terminal Monitoring |  |  | ✅ |  |  |
| Atomic State Tracking | ✅ | ✅ |  | ✅ | ✅ |
| Logs for Debugging | ✅ | ✅ |  | ✅ | ✅ |

---

## Installation

**Option 1: Clone & Install**  
```bash
git clone https://github.com/rahmanshuvo-bd/SysTune.git ~/SysTune
mv ~/SysTune /data/adb/modules/
cd /data/adb/modules/SysTune
chmod +x *.sh

Option 2: 
-* Flash via Magisk/KSU
-* Download the latest zip release
-* Flash via Magisk or KernelSU
Scripts start automatically on boot or when charger is connected

# Usage
Battery Safe:
Bash
su -c "/data/adb/modules/SysTune/battery_safe.sh" 

Auto Profile:
Bash
su -c "/data/adb/modules/SysTune/auto_profile.sh"

Terminal Monitor:
Bash
su -c "/data/adb/modules/SysTune/sys_monitor.sh"


Performance Efficiency & Runtime Optimizer run automatically with profiles or can be triggered manually.

Benefits
** Battery Safety: Pause/resume charging at configurable thresholds; hard stop at 100%
** Thermal Protection: Avoids overheating with zero-fork, kernel-level monitoring
** Performance Efficiency: Optimizes CPU/GPU scaling without user intervention
** Runtime Optimization: Adjusts memory management to prevent crashes or slowdowns
** Automatic Profile Switching: System adapts to battery level or custom triggers
** Real-Time Monitoring: Terminal dashboard with centralized metrics
** Zero-Fork Architecture: Reduces CPU wakeups and avoids unnecessary process spawning
** Detailed Logging: All modules maintain state and logs for debugging and analysis


# License
MIT License. Free to use, modify, and distribute. Contributions are welcome.

~•Polymath-Void•~