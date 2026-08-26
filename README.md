# SysTune (Monolith Edition)

SysTune is an ultra-advanced, **100% Native Rust**, event-driven kernel orchestrator for Android (KernelSU/Magisk).

Designed for peak competition-grade performance and absolute zero-overhead battery efficiency, SysTune bypasses standard Android bash scripting to manipulate the Linux kernel `/sys/` and `/proc/` hardware nodes natively.

## The Architecture
SysTune listens directly to kernel `AF_NETLINK` uevents (Hardware interrupt broadcasts) while consuming **0% CPU** in the background.

When a hardware state change occurs (e.g., Battery drops, Screen locks, Charger connects), the Rust daemon awakens, reads your custom `.conf` profile into memory, and writes directly to the CPU, GPU, and RAM kernel boundaries in under 1 millisecond.

### Zero-Fork Design
Traditional Android modules rely on heavy bash `for` loops and `awk`/`sed` string manipulation that tax the processor and drain the battery. SysTune operates exclusively in native Rust memory:
- **Zero Interpreter Lag:** No `/system/bin/sh` bottleneck. 
- **Zero-Disk I/O State:** Hysteresis and runtime states (like thermal tracking) are stored in `struct AppState` RAM, protecting your flash storage from unnecessary writes.
- **Microsecond Iterators:** Pure Rust `fs::read_dir` is used to tune CPU scaling policies and timer_slack limits at blinding speeds.

## Core Features
- **Energy Aware Scheduling (EAS):** Dynamically scales `schedutil` and `sugov_ext` CPU limits.
- **UClamp Task Pinning:** Precisely pins foreground apps to heavy cores and background tasks to efficiency cores.
- **MediaTek FPSGO Tuning:** Natively hooks into the MTK FBT/TA limits.
- **Smart Battery Protection:** Safely scales constant-current (CC) charging rates, applies strict thermal throttling, and fully halts charging at 85% to preserve battery longevity.

## Interactive Dashboard (TUI)
SysTune provides a clean, responsive Terminal User Interface (TUI) for manual overrides and system monitoring.
Simply run `su -c systune` in Termux to launch the dashboard.

## Installation
1. Download the latest flashable ZIP from the Releases page.
2. Flash it in KernelSU or Magisk.
3. Reboot. The Rust daemon automatically takes control in the `late_start` boot sequence.

## Building from Source
SysTune uses GitHub Actions to automatically cross-compile the Rust binary for `aarch64`. 
To build it manually:
```bash
cd orchestrator
cross build --target aarch64-linux-android --release
```