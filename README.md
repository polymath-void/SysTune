# SysTune (Competition Edition)

**SysTune** is a world-class, zero-fork kernel orchestration module designed to unlock the absolute maximum potential of MediaTek Dimensity devices (and generic Android hardware) through bare-metal tuning, proprietary driver interception, and event-driven profile switching. 

Built natively for KernelSU & Magisk. Powered by a background Rust daemon.

---

## 🏆 Key Architectural Features

### 1. 🦀 Event-Driven Rust Orchestrator (`src/main.rs`)
Instead of using infinite polling loops that drain battery, SysTune runs a highly optimized Rust daemon (`orchestrator`).
- **NETLINK Hardware Polling:** Listens directly to Linux `AF_NETLINK` sockets. The daemon sleeps until the kernel emits a `uevent` (e.g., Battery drop, Screen State change).
- **Idempotent Logic Tree:** It dynamically manages state across 3 independent event branches (CPU Profiling, Network/WiFi state, and Hardware Charging) ensuring zero duplicated execution.

### 2. 🚀 Frame Boost Technology (FPSGO) Interception
Standard modules only touch the CPU governor. SysTune directly interfaces with MediaTek's proprietary `fpsgo` subsystem.
- **Microsecond Frame Rescue:** By dynamically injecting `FBT_BOOST_TA` and `FBT_RESCUE_PERCENT` targets during performance mode, the orchestrator instructs the kernel to aggressively scale frequencies specifically on the exact millisecond a game frame drops.

### 3. 🎯 Advanced UClamp Per-Task Topology (EAS)
SysTune completely isolates your games from background noise.
- **Top-App Pinning (`uclamp.min`):** When you launch a game, SysTune violently pins the foreground `cgroup` to the massive Cortex-A715 Big Cores.
- **Background Strangulation (`uclamp.max`):** Restricts background apps strictly to the LITTLE cores, guaranteeing they physically cannot steal cache from your active game.
- *Fully supports modern Android 13/14 (`/dev/cpuctl/`) and legacy Android 11/12 (`/sys/fs/cgroup/cpu/`).*

### 4. ⚡ Zero-Fork Configuration Engine
SysTune relies on a strict `0-Fork` bash execution philosophy. 
- All profiles are loaded entirely in-memory by sourcing `.conf` files. 
- Sub-shells (`$()`), expensive `awk`/`sed` string manipulation, and recursive `grep` calls are heavily optimized out of the core critical path (`apply.sh` & `perf_efficiency.sh`). 

### 5. 🛡️ Absolute Boot-Sequence Stability
SysTune has been meticulously hardened to survive catastrophic edge cases and custom ROM weirdness.
- **Race Condition Prevention:** The orchestrator refuses to trigger Binder IPC calls until it verifies `sys.boot_completed=1` and checks that the Android `system_server` is actively listening.
- **Flawless AppOps Logic:** Uses native shell C-engine word-splitting to parse `/proc/[pid]/status`, guaranteeing perfect app UID extraction regardless of kernel tab/space formatting anomalies.
- **Zero-Log-Spam Guarantee:** Every single background kernel write silently redirects `stderr` to `/dev/null`.

### 6. 🔋 Hardware Thermal Charging Limits (`battery_safe.sh`)
SysTune intercepts the MTK master charger node. When thermal limits are breached, it seamlessly throttles the charging current dynamically. If your battery reaches maximum capacity, it disables CC (Constant Current) to prevent voltage degradation (BU-808 battery standard).

---

## 🛠️ File Structure

* `orchestrator/` - The compiled Rust background daemon.
* `config/profiles/` - Zero-fork plaintext tuning configurations for `performance`, `game_mode`, `balanced`, and `battery_saver`.
* `apply.sh` - The master profile injection engine.
* `perf_efficiency.sh` - Executes Phase 3 FPSGO, Phase 4 UClamp, and `sugov_ext` CPU rate limits.
* `optimize_runtime.sh` - Executes Timer Slack, Low Memory Killer (LMK), and strict AppOps (`RUN_IN_BACKGROUND`).
* `wifi_worker.sh` - Executes TCP congestion controls.
* `sys_monitor.sh` - An interactive command-line dashboard for monitoring live kernel stats.

---

## 📜 Installation
Flash the zip in **KernelSU** or **Magisk**. SysTune will automatically detect your environment, inject the necessary SELinux patches (`sepolicy.rule`), and initialize the background orchestrator.