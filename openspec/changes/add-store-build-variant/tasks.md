## 1. Implementation
- [x] 1.1 Add App Store vs Direct build configurations (entitlements + signing settings).
- [x] 1.2 Add a process-sampling capability check and cache availability.
- [x] 1.3 Redesign notification trigger logic to fire when any metric is critical (with duration), with process-based notifications only when sampling is available.
- [x] 1.4 Gate per-process list population and process-triggered notifications on availability.
- [x] 1.5 Restore the Detection tab for CPU/memory thresholds + duration, and hide it in sandboxed builds.
- [x] 1.6 Move CPU/memory thresholds out of the Notifications tab into Detection.
- [x] 1.7 Add a concise Settings note describing notification triggers and build differences.
- [x] 1.8 Add diagnostics/logging to confirm the active capability state in debug builds.

## 2. Validation
- [x] 2.1 Verify App Store build runs sandboxed and hides/disables per-process alerts.
- [x] 2.2 Verify Direct build shows the Detection tab and per-process alerts/notifications.
