# SysTune – CHANGELOG

This document tracks functional and architectural changes for the **SysTune core runtime scripts**.

---

## auto_profile.sh

### v2.0 (Current)

**Role:** One-shot decision engine  
**Pattern:** Decide → Apply → Persist → Exit

#### Added
- PID-based singleton guard (`auto_profile.pid`)
- Battery-aware profile selection
- CPU-load-based escalation logic
- Profile state persistence:
  - `/data/adb/modules/SysTune/state/auto_profile.status`
- Structured logging:
  - `/data/adb/modules/SysTune/logs/auto_profile.log`
- Safe cleanup via `trap` on exit/signals

#### Changed
- Converted from persistent/loop logic to **short-lived execution**
- Eliminated redundant re-application of identical profiles
- Delegated all tuning responsibility to `apply.sh`

#### Decision Logic
| Condition | Selected Profile |
|---------|------------------|
| Battery ≤ 25% | `battery_saver` |
| CPU load > 75% | `performance` |
| Battery ≤ 50% | `balanced` |
| Otherwise | `balanced_smooth` |

#### Design Notes
- No background loops
- No wakelocks
- Safe to trigger from cron, init, or manual calls
- Optimized for minimal power overhead

---

### v1.x

- Re-applied profiles unnecessarily
- No state awareness
- Higher execution overhead
- No singleton protection

---

## battery_safe.sh

### v1.0 (Stable)

**Role:** Charging & thermal protection controller  
**Pattern:** Long-running service (event-driven)

#### Added
- Input current limiting via kernel sysfs
- Battery temperature monitoring
- Safe PID tracking
- Dedicated log file:
  - `/data/adb/modules/SysTune/logs/battery_safe.log`

#### Core Functions
- Prevents over-current during charging
- Reduces thermal stress under high temperature
- Ensures hardware-safe charging behavior

#### Design Notes
- Independent from performance profiles
- Must run as a service
- Conservative by design (hardware-first policy)

---

### Pre-1.0
- Experimental thresholds
- Limited logging
- No PID safety

---

## perf_efficiency.sh

### v1.1 (Current)

**Role:** Profile-aware efficiency refinement layer  
**Pattern:** One-shot tuning (idempotent)

#### Added
- Full **per-profile behavior mapping**:
  - `battery_saver`
  - `balanced`
  - `balanced_smooth`
  - `performance`
  - `game_mode`
- Profile-driven `schedutil` ramp tuning (`rate_limit_us`)
- Dynamic refresh-rate control (peak/min)
- Unified schedtune enforcement:
  - `background.schedtune.boost = 0`
  - `top-app.schedtune.prefer_idle = 1`
- Low-overhead I/O tuning:
  - `mq-deadline`
  - entropy disabled
- Centralized logging:
  - `/data/adb/modules/SysTune/logs/perf_efficiency.log`

#### Profile Intent Mapping
| Profile | CPU Ramp | Refresh Rate | Scheduler Bias |
|-------|---------|--------------|----------------|
| battery_saver | Slow | 30–60 Hz | Efficiency |
| balanced | Medium | 60–90 Hz | Neutral |
| balanced_smooth | Fast | 60–120 Hz | UI-priority |
| performance | Very fast | 60–120 Hz | Aggressive |
| game_mode | Fastest | 120 Hz | Foreground-max |

#### Changed
- Removed global/static tuning
- Balanced profiles now prioritize **race-to-sleep**
- `balanced_smooth` aligned closer to performance without thermal abuse

#### Design Notes
- Safe to re-run
- No persistent state
- Called explicitly from `apply.sh`
- MTK-aware, not vendor-agnostic

---

### v1.0

- Static tuning
- No profile awareness
- No logging
- Experimental behavior

---

## Execution Flow (Authoritative)
