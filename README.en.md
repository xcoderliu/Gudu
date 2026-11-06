# Ripple · 澄水

**A small pause. A sip of water. A little care for yourself.**

A native macOS water reminder with configurable intervals, daily hours, a menu-bar companion, and a full-screen vector animation that follows the display under your pointer.

[简体中文](README.md) · [Development](docs/DEVELOPMENT.md) · [Architecture](docs/ARCHITECTURE.md) · [Contributing](CONTRIBUTING.md) · [MIT License](LICENSE)

![Ripple dashboard](docs/images/dashboard.png)

## Features

- Reminder intervals from 1 to 240 minutes, with quick presets.
- Daily start/end times, overnight schedules, and an all-day option when both times match.
- Resolution-independent SwiftUI Canvas animation: a calm dashboard glass and a full-screen open-kitchen ritual with a filtered-water tap, filling a cup, sipping, and a relieved exhale.
- Neutral, woman, and man character options; the neutral character is the default.
- Optional synchronized pouring, gulping, and sigh sound effects, synthesized offline. Multiple displays share one audio player.
- Pointer-display targeting, an explicit all-display mode, and an all-display fallback when no display matches the pointer.
- Drink confirmation, five-minute snooze, Escape to dismiss, and optional automatic dismissal.
- Optional experimental camera verification: Apple Vision remembers the mouth position and checks nearby vessels even when the face is covered. About one second of accumulated detections completes a reminder; missed detections pause progress without resetting it.
- Menu-bar access even after closing the dashboard.
- Daily intake, configurable serving size and goal, and undo for the most recent drink.
- No overdue reminder bursts after sleep or lock; the interval restarts when the session becomes available.
- Keyboard access and a static vector scene when Reduce Motion is enabled.
- Offline operation, local preferences/history, no account or analytics, and optional launch at login.

![Full-screen reminder](docs/images/reminder.png)

The Lottie-style animation is implemented directly with SwiftUI vector paths and timelines. There are no third-party runtime dependencies. See [WaterScene.swift](Ripple/Animation/WaterScene.swift) and [DrinkingRitualScene.swift](Ripple/Animation/DrinkingRitualScene.swift). The original sound assets are generated with [make_sounds.py](scripts/make_sounds.py), with no recordings or downloaded samples.

## Build and run

Requires **macOS 14+ and Xcode 16+**. The current build has been checked on Apple Silicon with macOS 26.5.1 and Xcode 26.3. The user interface is currently in Simplified Chinese.

Open `Ripple.xcodeproj`, select **Ripple → My Mac**, and press **⌘R**. The checked-in project uses local ad-hoc signing, so a developer team is not required for local development.

```bash
./scripts/build.sh --run
./scripts/test.sh
```

The app is built at `build/Build/Products/Debug/Ripple.app`.

## Behavior

The default schedule is **09:00–21:00, every 45 minutes**. Launching inside the window starts a full interval; launching outside it schedules the next reminder at the next start time. The end time is exclusive. A reminder that would cross the end moves to the next start, including a snoozed reminder.

Previewing the animation neither records water nor changes the schedule. Confirming a real reminder records one serving. Dismissing or timing out never records a drink. Closing the dashboard keeps the app running in the menu bar; quitting stops reminders.

**⌘D** records a drink from the dashboard, **⌘P** previews, **Return** confirms a reminder, and **Esc** dismisses it. These shortcuts work while the appropriate Ripple interface has keyboard focus; no global shortcuts are registered.

For launch at login, copy the built app to Applications first. The system may require approval in System Settings → General → Login Items.

### Camera verification

Enable “强制检测喝水” in settings, or try “测试摄像头识别（不记水）” first. macOS asks for camera permission. Verification runs only during a forced reminder or an explicit recognition test; ordinary animation previews never start the camera. Frames remain in local memory and are neither saved nor uploaded.

Show your face once to locate the mouth, then drink normally. The last reliable mouth position remains available for the current session even when the cup hides your face. Missed detections pause progress without reducing it; exiting or retrying starts fresh. You do not need to keep your mouth visible or lower the cup.

Forced reminders disable manual confirmation, Return-to-record, snooze, and automatic dismissal. Hold Escape for two seconds for an unrecorded emergency exit, or use the close button and confirm. Camera errors offer retry and exit. The test mode never records water.

This detects a vessel in the mouth region, not swallowing or actual intake volume. Recorded water uses the configured serving size. The feature is currently off by default and needs real-device accuracy validation. See [camera verification](docs/CAMERA_VERIFICATION.md).

## Source layout

`Ripple/` contains the SwiftUI/AppKit application. `Sources/RippleCore/` contains the local Swift package for schedules, display routing, and models. `Tests/RippleCoreTests/` covers schedule boundaries, daylight saving, snoozing, and multi-display geometry. `scripts/` contains reproducible development helpers, and `docs/` explains the architecture, privacy, validation, and release process.

See [development](docs/DEVELOPMENT.md), [architecture](docs/ARCHITECTURE.md), and [validation](docs/VALIDATION.md) for details. Most extended documentation is currently in Chinese; contributions in either language are welcome.

## Limitations and privacy

Ripple must remain running to remind you. Protected system/login screens may cover ordinary application windows. Spaces, exclusive fullscreen apps, and Stage Manager need verification on the intended setup. Display reconfiguration dismisses the current overlay; the next reminder reads the current display list again.

Intel Macs, other OS versions, Developer ID signing, and notarized distribution still require their own validation. The daily goal is a user-configurable habit tracker.

All preferences and up to 90 days of drink history are kept on this Mac. No network access, telemetry, accessibility permission, or screen-recording permission is required. See [privacy](docs/PRIVACY.md).

## Contributing and license

Contributions are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a PR. Ripple is available under the [MIT License](LICENSE). For a first GitHub release or signed distribution, follow [RELEASING.md](docs/RELEASING.md).
