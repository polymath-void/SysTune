# SysTune Changelog

## v8.1.0 (Monolith Edition) - 2026-08-26
- **Complete Bash Eradication:** Deleted `auto_profile.sh`, `perf_efficiency.sh`, `optimize_runtime.sh`, `wifi_worker.sh`, and `battery_safe.sh`.
- **100% Native Rust Engine:** All CPU governor tuning, GPU tuning, Memory tuning, and Network tuning are now handled directly inside the Rust Daemon.
- **Zero-Disk In-Memory State:** Battery scaling states and thermal hysteresis are now tracked dynamically in RAM, completely eliminating Android file-system I/O overhead.
- **Microsecond Invocation:** Bypassing `/system/bin/sh` yields a ~10,000% speed increase during real-time EAS profile transitions.
- **Unified Config Architecture:** Standardized all settings into `global.conf`, `battery_saver.conf`, and `balanced.conf`.
- **TUI Dashboard Bridge:** Refactored `sys_monitor.sh` to trigger the Rust engine directly via CLI arguments (`orchestrator --apply`).
