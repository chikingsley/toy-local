# Incident Report: Event Tap Timeout Lockout

Date: 2026-02-26  
Status: Investigated, fix implemented on branch  
Severity: P0 (global input reliability risk)

## Summary

ToyLocal intermittently triggered global keyboard/mouse instability while the app was running.  
The concrete failure signal is repeated Quartz event tap timeout disable events:

- `Event tap disabled by timeout; scheduling restart.`

This is a high-risk path because the app uses a `kCGHIDEventTap` callback and may suppress events (`nil` return) for hotkey handling.

## User-Visible Impact

- Intermittent periods where typing/clicking became unreliable.
- At least one severe episode required remote SSH access to recover.
- Reliability degradation was observed during active keyboard usage.

## Evidence (Unified Logs)

Collected with:

```bash
/usr/bin/log show --style syslog --last 12h --predicate 'process == "toy-local"' > /tmp/toylocal_process_12h.log
```

Counts:

- `Event tap disabled by timeout`: **22**
- `Event tap disabled by user input`: **0**

Minute buckets:

- `2026-02-26 06:08`: 2
- `2026-02-26 06:09`: 3
- `2026-02-26 06:10`: 7
- `2026-02-26 06:11`: 2
- `2026-02-26 06:37`: 2
- `2026-02-26 06:38`: 1
- `2026-02-26 06:40`: 1
- `2026-02-26 06:48`: 1
- `2026-02-26 06:49`: 2
- `2026-02-26 06:50`: 1

Representative excerpts:

```text
2026-02-26 06:10:10.115602-0700 ... [KeyEvent] Event tap disabled by timeout; scheduling restart.
2026-02-26 06:10:48.353258-0700 ... [KeyEvent] Event tap disabled by timeout; scheduling restart.
2026-02-26 06:11:21.666194-0700 ... [KeyEvent] Event tap disabled by timeout; scheduling restart.
2026-02-26 06:37:44.258287-0700 ... [KeyEvent] Event tap disabled by timeout; scheduling restart.
2026-02-26 06:49:47.569323-0700 ... [KeyEvent] Event tap disabled by timeout; scheduling restart.
```

## Root Cause Analysis

### What the code was doing

The event tap callback fans out to synchronous handlers inside the callback path:

- [KeyEventMonitorService.swift](/Users/chiejimofor/Documents/Github/always-on-local/ToyLocal/Services/KeyEventMonitorService.swift)

The callback was also indirectly running typing-session tracking work for every key event via a synchronous main-actor hop:

- [AppStore.swift](/Users/chiejimofor/Documents/Github/always-on-local/ToyLocal/Stores/AppStore.swift)

That work includes app-focus checks and tracker updates on every key press, which increases callback latency risk under load.

### Why this maps to the logs

Apple’s CoreGraphics API documents that:

1. Event tap callbacks run on the `CFRunLoop` where the tap source is installed.
2. Unresponsive taps are disabled with `kCGEventTapDisabled...` events.

When callback latency crosses system tolerance repeatedly, the tap is disabled and restart loops can occur, which matches the observed timeout bursts.

## Fix Implemented

### 1) Remove expensive typing-session work from tap callback critical path

Typing session monitoring now uses a buffered async stream:

- tap callback only does `continuation.yield(keyEvent)` and returns
- processing runs in a separate pump task on main actor
- callback path no longer blocks on per-keystroke AppKit/tracker work

File:

- [AppStore.swift](/Users/chiejimofor/Documents/Github/always-on-local/ToyLocal/Stores/AppStore.swift)

## Validation Protocol

1. Build + tests:
   - `xcodebuild -project toy-local.xcodeproj -scheme "toy-local" -configuration Debug build CODE_SIGNING_ALLOWED=NO`
   - `cd ToyLocalCore && swift test`
2. Runtime verification:
   - Run app for normal typing sessions (5-10 min).
   - Confirm no repeated timeout bursts in logs.
3. Log check:
   - `rg -n "Event tap disabled by timeout" /tmp/toylocal_process_12h.log`
   - Expectation after fix: none or isolated rare events, not burst patterns.

## Safe Reproduction Guidance

Deterministic timeout reproduction usually requires intentionally stalling the callback, which is unsafe on a primary machine.  
Safer approach:

1. Reproduce only on a secondary machine/VM/test account.
2. Keep a remote recovery path ready (`ssh` + `pkill -f toy-local`) before test.
3. Use log monitoring as the success criterion for detection.

Given the 22 concrete timeout events already captured with exact timestamps, confidence in diagnosis is high even without deliberate callback stalling.

## Official References

Apple CoreGraphics SDK headers (Xcode):

- `CGEvent.h`:
  - event tap callback runs from the runloop where source is installed
  - unresponsive taps generate `kCGEventTapDisabled...` events
  - `CGEventTapEnable` is the supported re-enable path
- `CGEventTypes.h`:
  - defines `kCGEventTapDisabledByTimeout`
  - defines `CGEventTapInformation` latency fields (`minUsecLatency`, `avgUsecLatency`, `maxUsecLatency`)

Header locations used:

- `/Applications/Xcode.app/.../CoreGraphics.framework/.../Headers/CGEvent.h`
- `/Applications/Xcode.app/.../CoreGraphics.framework/.../Headers/CGEventTypes.h`
