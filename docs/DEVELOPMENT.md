# 开发指南

## 环境

- macOS 14+
- Xcode 16+（含 Command Line Tools）
- Swift 5.9+，由 Xcode 自带工具链提供
- Python 3 仅用于可选的 Xcode 工程再生成

没有 CocoaPods、Carthage、Homebrew 或第三方 Swift Package 依赖。`RippleCore` 是仓库内的本地 Package。

## 启动

```bash
open Ripple.xcodeproj
```

选择 Ripple Scheme、My Mac，然后 ⌘R。默认 Bundle ID 为 `local.ripple.WaterReminder`，本地 ad-hoc 签名不要求团队。其他签名方式见 [发布指南](RELEASING.md)。

```bash
./scripts/build.sh --run
```

命令行构建使用 `build/` 保存 Derived Data；该目录已经加入 `.gitignore`。要预览动画，可以从应用主界面点击「预览动画」，或在新的应用进程启动时传入：

```bash
open build/Build/Products/Debug/Ripple.app --args --preview
```

`--preview` 在应用启动时读取。应用已经运行时，请直接使用界面按钮。

## 测试

```bash
swift test
```

也可执行 `./scripts/test.sh`。核心逻辑测试作为 Swift Package 运行，应用 Scheme 的 Test action 没有重复配置另一套测试宿主。可以单独用 Xcode 打开 `Package.swift` 运行 Package tests。

时间测试固定日历和时区，不依赖测试机当天的时间与区域。屏幕测试使用构造的显示器矩形，不要求 CI 接入多台显示器。实际多屏窗口、锁屏与 Space 行为需要手动检查；见 [VALIDATION.md](VALIDATION.md)。

应用状态与真实 Timer 的集成检查（约 1 分钟）：

```bash
./scripts/smoke_test.sh
```

此检查使用隔离的临时偏好，验证预览不改变计划、记水与撤销、实际一分钟触发、延后五分钟与暂停。它不显示提醒窗口，也不改动真实数据；需要当前 Mac 会话保持可用，不在无图形会话的 CI 中运行。

完成与撒花的原生窗口检查：

```bash
./scripts/check_completion.sh
```

检查使用真实窗口控制器、隐藏窗口和隔离偏好，验证提醒先关闭、撒花透明且鼠标穿透、多屏同一时间源、自动清理、重复完成只记一次、预览不记水，以及延后 / 系统中断清理。不显示窗口，不播放声音，不访问摄像头；同样需要 macOS 图形会话。

构建 Release：

```bash
xcodebuild -project Ripple.xcodeproj -scheme Ripple \
  -configuration Release -derivedDataPath build build
```

## 目录与生成文件

- `Ripple/`：应用代码与资源。
- `Sources/RippleCore/`：不依赖 AppKit 生命周期的逻辑与模型。
- `Tests/RippleCoreTests/`：核心逻辑测试。
- `Ripple.xcodeproj/`：纳入 Git，可直接打开。
- `scripts/generate_project.py`：确定性生成器，源文件新增后可运行。
- `scripts/make_icon.swift`：由矢量路径生成 macOS 图标 PNG。
- `scripts/make_sounds.py`：离线合成接水、喝水与舒气音效。
- `scripts/render_previews.sh`：由实际 SwiftUI 视图导出文档插图。

新增 / 删除应用 Swift 文件后，可以在 Xcode 添加 / 删除相应引用；也可以执行：

```bash
python3 scripts/generate_project.py
```

**生成器会整体重写 `project.pbxproj` 和共享 Scheme。** 如果修改了工程构建设置，先把对应改动同步进生成器，再重新生成。生成器使用确定性 ID，重复运行不会产生随机差异。核心 Package 新增 Swift 文件不需要重新生成工程。

重新生成图标：

```bash
swift scripts/make_icon.swift
```

重新生成原创音效（标准库 Python，无需第三方库）：

```bash
python3 scripts/make_sounds.py
```

如果修改音效节奏，请同步修改 `DrinkingTimeline` 的动作节点；原音轨长度为 15 秒，与动画循环一致。

文档配图使用隔离的临时 UserDefaults suite 与示例饮水记录，并固定动画时间以获取稳定画面：

```bash
./scripts/render_previews.sh
```

该脚本从视图渲染图片，不读取屏幕像素，也不改动真实应用的饮水数据。`docs/images/` 中的图片属于应用视图渲染，真实界面还包含 macOS 窗口边框。

可以给脚本传入输出目录，例如 `./scripts/render_previews.sh "$PWD/.local/previews"`，避免覆盖文档插图。`camera-diagnostics.png` 使用虚构分数展示测试页的诊断组件，不包含真实摄像头画面或实测识别结果。

检查拿杯动作与撒花，可执行 `./scripts/render_motion.sh`，在 `.local/` 导出 `pickup-motion.gif`、拿杯六帧对照图、`confetti-motion.gif`、透明撒花 PNG 与减少动态效果的静态提示 PNG。撒花 GIF 的渐变背景仅用于展示透明叠加效果，不是桌面截图。它们直接使用应用的矢量代码渲染，属于开发用配图，不会被打包为应用动画。

## 开发约定

- UI 与窗口管理在主 actor 执行；时间与屏幕计算留在 `RippleCore`。
- 使用 `Calendar` 处理每日起止时间，不用固定 86,400 秒推算下一天。
- 新增动画优先使用 SwiftUI 矢量路径；遵守「减少动态效果」。
- 不添加网络请求或追踪。摄像头权限仅服务于用户明确开启的可选识别功能，关闭时不能采集画面。
- 所有关闭路径都必须同步关闭多屏窗口，并移除键盘事件监听。
- 用户数据、构建产物、Xcode 个人状态及签名凭据不要提交 Git。

## 调试提醒

建议先用「预览动画」检查动画与选屏。需要验证自动提醒时，把间隔改为 1 分钟，并确保当前时间在设置的每日时段内。完成测试后恢复原设置。不要通过缩短生产代码中的计时常量测试，以免误提交。

本地偏好由沙盒 UserDefaults 管理。路径、数据键与生命周期见 [PRIVACY.md](PRIVACY.md) 和 [ARCHITECTURE.md](ARCHITECTURE.md)。
