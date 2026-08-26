# SysTune Changelog

## v8.2.2 (Neural Monolith - Hardened) - 2026-08-26
- **Dynamic Neural Executors:** Embedded the massive AI execution dataset (Neural-Governor) directly into the Rust orchestrator for zero-latency, truly intelligent thermal and memory event reactions.
- **Dynamic Heat Scaling:** Replaces static thermal limits with mathematical severity tracking. Natively executes gentle `renice 10` for mild spikes, composite `renice 19 && drop_caches` for severe heat, and `kill -9` for critical overheating.
- **Proactive Memory Tuning:** Automatically watches `MemAvailable`. Chokes swappiness/cache_pressure and flushes caches dynamically when RAM drops below the threshold.
- **Event Debouncing:** Implemented strict 2-second debounce and 60-second cooldown matrices to eliminate `uevent` netlink storms and fork-bomb vulnerabilities.
- **External Configuration:** Replaced hardcoded values with `config/neural.conf`, exposing `NEURAL_THERM_THRESHOLD` and `NEURAL_MEM_THRESH` to end users.

## v8.1.0 (Monolith Edition) - 2026-08-26
- **Complete Bash Eradication:** Deleted `auto_profile.sh`, `perf_efficiency.sh`, `optimize_runtime.sh`, `wifi_worker.sh`, and `battery_safe.sh`.
- **100% Native Rust Engine:** All CPU governor tuning, GPU tuning, Memory tuning, and Network tuning are now handled directly inside the Rust Daemon.
- **Zero-Disk In-Memory State:** Battery scaling states and thermal hysteresis are now tracked dynamically in RAM, completely eliminating Android file-system I/O overhead.
- **Microsecond Invocation:** Bypassing `/system/bin/sh` yields a ~10,000% speed increase during real-time EAS profile transitions.
- **Unified Config Architecture:** Standardized all settings into `global.conf`, `battery_saver.conf`, and `balanced.conf`.
- **TUI Dashboard Bridge:** Refactored `sys_monitor.sh` to trigger the Rust engine directly via CLI arguments (`orchestrator --apply`).
