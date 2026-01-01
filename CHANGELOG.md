# SysTune Changelog

All notable changes to this project will be documented in this file.

The format follows a simplified semantic versioning model:
- MAJOR.MINOR.PATCH

---

## [Unreleased]
- Ongoing improvements and internal refinements

---

## [v1.0.0] – Initial Release
### Added
- SysTune Magisk module base structure
- Battery Safe charging controller (v1)
- Auto Profile framework (CPU/GPU profile switching)
- Background service initialization support
- Logging and PID-based singleton protection

---

## [v2.0.0] – Stability & Control Update
### Improved
- Battery Safe charging logic refined
- Reduced aggressive charging toggles
- Improved charger disconnect handling
- Auto Profile reliability improvements
- Safer service lifecycle handling

### Fixed
- Charging state not restoring on exit
- Multiple instance spawning issues

---

## [v3.0.0] – Smart Charging & System Harmony
### Added
- Battery Safe v3 logic with multi-stage charging control (80/90/95/100)
- Clean charging pause/resume strategy
- Better compatibility with MTK devices
- Improved logs and state tracking

### Improved
- Auto Profile behavior under long uptime
- Reduced system pressure
- More predictable service exits

---

## [v3.1.0] – Battery Gauge Sync & Low-Pressure Mode
### Improved
- Battery Safe post-full gauge synchronization logic
- Reduced battery polling frequency
- Cleaner charger disconnect handling
- Long idle wait mode after charging completion

### Fixed
- Battery capacity desync after overnight charging
- Repeated charging stop spam in logs

---
