# Repository guidance

- This is a native macOS SwiftUI + AppKit application. Keep runtime dependencies local and offline.
- Use vector paths for reminder animation and respect Reduce Motion.
- Place deterministic schedule/display logic in `Sources/GuduCore`; verify relevant boundaries with `swift test`.
- Build with `xcodebuild -project Gudu.xcodeproj -scheme Gudu -configuration Debug -derivedDataPath build build`.
- New app source files must be included in the checked-in Xcode project. If regenerating, preserve build changes in `scripts/generate_project.py` first.
- Preserve app sandboxing. Never add private APIs, global input monitoring, tracking, or network access without an explicit product requirement.
- Keep screenshots limited to app content; never commit real user data, credentials, Derived Data, or personal IDE state.
- The maintainer explicitly authorized `docs/images/camera-real-use.webp` for public project documentation. This one supplied screenshot is an exception to the real-user-image rule; do not capture or add other real camera images. Do not add production-process or authorization captions under product images.
- Update user-facing docs when behavior changes. State clearly which OS/hardware configurations have actually been verified.

## 沟通

用户用中文时用中文回复。用户用英文时，先用自然英文回答实际问题，再给对应中文说明，最后给保留原意的自然英文改写；不要因为语言纠错中断开发。
