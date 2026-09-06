# SysTune (Neural Monolith Edition)

![Production Ready](https://img.shields.io/badge/Status-Production_Ready-brightgreen.svg?style=for-the-badge)
![Native Rust](https://img.shields.io/badge/Core-100%25_Native_Rust-orange.svg?style=for-the-badge)
![Zero Overhead](https://img.shields.io/badge/Overhead-0%25-blue.svg?style=for-the-badge)
![KernelSU / Magisk](https://img.shields.io/badge/Supported-KernelSU_%7C_Magisk-success.svg?style=for-the-badge)

**SysTune** is an ultra-advanced, **100% Native Rust**, event-driven kernel optimizer and battery saver module for Android (KernelSU and Magisk). 

Designed for peak competition-grade performance and absolute zero-overhead battery efficiency, SysTune completely bypasses standard Android bash scripting to manipulate Linux kernel hardware nodes (`/sys/` and `/proc/`) natively. It features **Neural Executors**—dynamic scaling algorithms derived directly from AI execution logs—to intelligently throttle, nuke, or restructure background tasks based on real-time hardware telemetry.

## 🚀 The Architecture (Zero-Overhead Daemon)
Unlike traditional Magisk modules that rely on heavy bash `for` loops and `awk`/`sed` string manipulation, SysTune operates exclusively in native Rust memory:
- **0% CPU Background Usage:** SysTune listens directly to kernel `AF_NETLINK` hardware interrupt broadcasts (uevents). The daemon sleeps at 0% CPU until a strict hardware state change occurs.
- **Zero Interpreter Lag:** No `/system/bin/sh` bottlenecks. Kernel tuning is executed via pure Rust `fs::read_dir` iterators in under 1 millisecond.
- **Zero-Disk I/O State:** Hysteresis and runtime states (like thermal tracking and debouncing) are stored in strict `struct AppState` RAM, protecting your NAND/UFS flash storage from unnecessary writes.

## 🧠 Core Features
- **Neural Thermal Executors:** Embedded AI-driven logic dynamically mitigates heat without interrupting your workflow. It aggressively prioritizes lowering background apps (`renice 19`) and dropping RAM caches for severe spikes, whilst safely ignoring core Android PIDs (`system_server`, `zygote`) to completely prevent unexpected device reboots. Built-in microsecond cooldowns prevent the daemon from looping and generating heat itself.
- **Hysteresis Battery Protection:** Uses advanced hysteresis loops for charging. If your battery hits 38°C (Configurable `THERM_HI`), it instantly drops the charging current to a safe 500mA trickle. It will *not* resume fast-charging until the battery physically cools down past a safe 34°C (`THERM_LO`), protecting your battery's lifespan while gaming. It also safely limits maximum charge capacity to 85% for longevity.
- **Energy Aware Scheduling (EAS):** Dynamically scales `schedutil` and `sugov_ext` CPU limits based on intelligent memory profiles.
- **UClamp Task Pinning:** Precisely pins foreground apps to heavy cores and background apps to efficiency cores for maximum battery saving.
- **MediaTek FPSGO Tuning:** Natively hooks into the MTK FBT/TA frame limits.

## 📊 Decoupled Interactive Dashboard (TUI)
SysTune provides a clean, responsive Terminal User Interface (TUI) for manual overrides and system monitoring.
- **Decoupled Architecture:** The dashboard is completely decoupled from the Rust Daemon. When you change profiles, it simply writes to a lightweight RAM state file (`manual_profile`), which the daemon seamlessly picks up. This guarantees that using the dashboard will never lag your device or fork parallel processes.
- **Instant Actions:** With a single key press (e.g. `R` to refresh), you can drop RAM caches, monitor live battery temperature, or force `Battery Saver` / `Balanced` modes.
- **Auto Mode Restoring:** Press `0` at any time to instantly delete your manual override and restore the neural Auto Profile engine. 

Simply run `su -c systune` in Termux to launch the dashboard.

## ⚙️ Installation & Usage
1. Download the latest flashable ZIP from the [Releases](https://github.com/polymath-void/SysTune/releases) page.
2. Flash it via KernelSU or Magisk.
3. Reboot. The Rust daemon automatically takes control in the `late_start` boot sequence.

## 🛠️ Building from Source
SysTune uses GitHub Actions to automatically cross-compile the Rust binary for `aarch64`. 
To build it manually:
```bash
cd orchestrator
cross build --target aarch64-linux-android --release
```