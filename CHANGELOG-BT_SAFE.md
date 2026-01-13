# Battery Safe Changelog

Dedicated changelog for the Battery Safe charging controller.

---
## v3.2 – Stable
- Fixed repeated 100% stop spam
- Reworked pause logic (one-time execution)
- Post-full gauge sync stabilized
- Silent idle monitoring mode
- Safe charger disconnect handling

## [v3.1.0] – Post-Full Gauge Sync Update
### Added
- Post-full stabilization phase after reaching 100%
- Charging resume/stop cycle for battery gauge synchronization
- Capacity vs dumpsys status comparison
- Low-pressure idle wait mode (15-minute intervals)

### Improved
- Charging stop happens only once at 100%
- Reduced kernel write frequency
- Cleaner and more meaningful logs
- Safe exit logic unified across all states

### Fixed
- Battery capacity stuck at incorrect levels after overnight charging
- Repeated “Charging stopped @100%” log spam
- UI and kernel capacity mismatch issues

---

## [v3.0.0] – Smart Multi-Stage Charging
### Added
- Charging pause points at 80%, 90%, and 95%
- Time-based charging resume logic
- Improved singleton handling using PID file

### Improved
- Charging stability
- MTK device compatibility
- Script readability and maintainability

---

## [v2.0.0] – Stability Improvements
### Improved
- Charging resume reliability
- Safer exit on charger disconnect

### Fixed
- Charging not re-enabled on script exit
- Duplicate script execution issues

---

## [v1.0.0] – Initial Release
### Added
- Basic charging control logic
- Charger detection
- Logging support

---
