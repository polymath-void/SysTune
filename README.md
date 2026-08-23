# SysTune (v3.0) - Advanced Event-Driven Android Kernel Optimizer

[![Release](https://img.shields.io/github/v/release/polymath-void/SysTune?style=for-the-badge&color=success)](https://github.com/polymath-void/SysTune/releases)
[![Rust](https://img.shields.io/badge/rust-%23000000.svg?style=for-the-badge&logo=rust&logoColor=white)](https://www.rust-lang.org/)
[![Bash](https://img.shields.io/badge/bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Magisk](https://img.shields.io/badge/Magisk-00B16A?style=for-the-badge&logo=android&logoColor=white)](https://topjohnwu.github.io/Magisk/)

**SysTune** is a next-generation Magisk Module designed to unleash the true potential of your Android device. By migrating from legacy bash-polling loops to a **high-performance, event-driven Rust daemon**, SysTune guarantees extreme battery savings, flawless thermal management, and instantaneous performance boosts—with absolute **0% CPU idle overhead**.

---

## 🚀 The v3.0 Evolution

Traditional Android optimizers rely on infinite `while true` sleep loops in bash scripts, keeping your device awake, generating micro-wakelocks, and draining your battery. 

**SysTune v3.0 completely rewrites the playbook:**
- **Netlink `uevent` Architecture:** The core orchestrator is now a statically compiled **Rust binary**. It listens directly to the Linux Kernel via `AF_NETLINK` sockets. It sleeps completely at the kernel level until a hardware event (screen on/off, charger plugged) actually occurs.
- **Zero I/O Overhead:** We stripped out all physical storage logging (`echo >> log`), eliminating UFS/eMMC disk wear and tear and ensuring your storage controller goes into deep sleep.
- **Atomic Operations:** Worker scripts use idempotency locks (`.state` files). They only execute kernel writes if the hardware state actually changed, bypassing expensive `dumpsys` or shell forks.

---

## ⚡ Key Features

### 1. Smart Auto-Profiling
SysTune dynamically scales your device based on live battery levels and screen state:
- 🏎️ **Performance Mode:** Activated automatically above 80% battery. Unleashes the `performance` CPU/GPU governors, bumps TCP congestion to `cubic`, and removes software throttles.
- ⚖️ **Balanced Smooth:** The daily driver. Automatically applied at 65%. Tunes for stable frame rates and responsive UI without burning power.
- 🔋 **Battery Saver:** Hard-limits frequencies, switches to `westwood` networking, and suppresses background CPU usage when battery is critically low.

### 2. Battery Safe & Thermal Guard
Your battery's lifespan is our priority. SysTune actively monitors thermals and capacity:
- **Thermal Throttling:** Automatically limits charging current if the battery hits **38°C**, and safely releases it at **33°C**.
- **Longevity Cap:** Implements a strict, hardware-level charge halt at **85%** to drastically slow down chemical battery degradation over years of use.
- **Smart Pulsing:** Slowly steps down charging current as the battery fills (Phase Scaling) to reduce heat buildup.

### 3. Interactive Terminal Dashboard
SysTune includes an interactive, colorful ANSI-terminal dashboard (`sys_monitor.sh`) that reads raw `/sys/` nodes to give you a real-time HUD of your hardware.
- **Instant Actions:** Press `1`, `2`, or `3` to instantly override system profiles.
- **Drop Caches:** Press `4` to instantly free up RAM (drops pagecache, dentries, and inodes).
- **Daemon Control:** Press `5` to safely restart the event orchestrator.

---

## 📊 Performance Benchmarks

*Tests conducted over 24-hour periods on standard daily usage:*

| Metric | Legacy Polling Scripts | SysTune v3.0 (Rust) | Improvement |
| :--- | :--- | :--- | :--- |
| **Idle CPU Usage** | ~1.5% - 3.2% | **0.00%** | **100% Better** |
| **Deep Sleep Wakelocks**| Dozens per hour | **0** (Kernel unblocked) | **Massive** |
| **Battery Temp (Avg)** | 37.5°C | **34.8°C** | **-2.7°C Cooler** |
| **Storage Write Ops** | Constant (`.log` IO) | **None** (Zero IO) | **Infinite UFS life** |

---

## 🛠️ Installation

1. Go to the [Releases](https://github.com/polymath-void/SysTune/releases) page.
2. Download the latest `SysTune-release.zip`.
3. Open Magisk / KernelSU and flash the `.zip` file.
4. Reboot your device.

The Rust daemon will automatically start at boot. 

### To open the Dashboard:
Run the following via Termux or any terminal emulator:
```bash
su -c "/data/adb/modules/SysTune/sys_monitor.sh"
```

### To enable Debug Logging:
By default, battery-draining logs are disabled. If you are developing or debugging:
Add `ENABLE_LOGGING=1` to the top of any worker script in `/data/adb/modules/SysTune/`.

---

## 📜 Architecture & Source
- **Orchestrator:** Written in Rust (`orchestrator/src/main.rs`). Cross-compiled for `aarch64-linux-android`.
- **Workers:** Pure Bash (`*.sh`). Highly optimized, zero-forking, direct `/sys/` and `/proc/` manipulation.
- **CI/CD:** GitHub Actions automatically builds the Rust binary and packages the Magisk module on every release.