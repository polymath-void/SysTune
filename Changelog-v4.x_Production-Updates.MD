# SysTune Changelog

## [v4.3] – 2026-01-12 – Production Release

### Service (`service.sh`)
- ✅ Converted main loop to **Zero-Fork architecture**; eliminated unnecessary `date`, `cat`, and `awk` forks.
- ⚡ Optimized **event-driven battery monitoring** (zone / charging state transitions).
- 🔗 Integrated **battery_safe worker** execution **only when charging**.
- 🔄 Added **unplug detection** to immediately reset charging limits and state files.
- 🛠 Applied safe `renice` / `ionice` to reduce impact on foreground tasks.
- 🛡 Added existence guards for sourced scripts (`auto_profile.sh`, `battery_safe.sh`).

### Battery Safe Worker (`battery_safe.sh`)
- ⛔ Removed internal loop; now **triggered only by service.sh** (event-driven).
- 🌡 Added **thermal guard with hysteresis** to prevent overheating; zero-fork logging using `/proc/uptime`.
- 🔋 Added **capacity-based charging pauses** (80%, 90%, 95%) with persistent state.
- 💾 Implemented **atomic state persistence** to prevent corruption during rapid state changes.
- 🏁 Added **context guard** to exit early if device is not charging.
- 🔄 Fully idempotent and robust against missing/deleted files.

### Logs & State
- 📝 Unified logging format with monotonic timestamp.
- ⚙ Battery safety thresholds correctly reflected in state file.
- 🔋 No CPU-intensive loops or unnecessary background forks; fully production-hardened.

---

**Notes:**
- This release ensures safe, efficient battery handling for MTK devices.
- Thermal and capacity thresholds are now dynamically managed with zero-fork architecture.
