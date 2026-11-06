# 隐私说明 / Privacy

更新时间：2026-11-06

## 本机保存

澄水只在本机保存：提醒间隔、每日时段、屏幕偏好、人物形象、摄像头检测开关、音效 / 退场设置、每杯容量、每日目标，以及包含时间与水量的饮水记录。人物形象是动画外观偏好，不要求填写个人性别。加载应用和新增记录时会清理 90 天前的饮水记录。当天统计按照 Mac 当前的本地日历计算。

这些数据通过 macOS 沙盒 UserDefaults 保存，默认 Bundle ID 为 `local.ripple.WaterReminder`，偏好位于对应沙盒容器中。应用没有登录、账户、云同步、分析或崩溃上报服务。

## 权限

- **摄像头（可选）**：仅在开启强制检测的正式提醒，或主动点击识别测试时申请和使用。默认关闭，普通动画预览不使用摄像头。AVFoundation 提供画面，Vision 仅在本机分析人脸关键点和嘴部区域的杯具分类。画面只存在于内存中，不录像、不保存、不上传，也不进行身份识别；不请求麦克风权限。关闭开关、提醒完成、退出、锁屏或睡眠时停止采集。
- **不需要辅助功能权限**：使用公开的鼠标坐标查询，不监听系统全局输入。
- **不需要屏幕录制权限**：根据显示器的几何范围确定选屏，不读取屏幕像素。
- **不需要通知权限**：提醒由应用自己的窗口呈现。
- **不需要网络访问**：沙盒未声明网络 client / server entitlement。
- **登录时打开**：仅在用户主动启用后，通过系统 `SMAppService` 注册；可随时在应用或系统登录项中关闭。

## 分享与删除

澄水不会把数据发送给开发者或第三方。提交 Issue 时不要上传个人偏好文件；截图也请自行检查。撤销上一杯只删除当天最后一条记录。要完整清除应用本地数据，可在退出应用后移除相应沙盒容器；这会同时移除偏好与历史，请先自行确认需要保留的内容。

如果未来增加数据导出、同步或任何联网能力，应先更新本文档，并在产品中提供明确选择。

## English

Ripple stores reminder preferences and drink entries locally using sandboxed macOS UserDefaults. Entries older than 90 days are pruned when the app loads or a new drink is recorded. There are no accounts, analytics, tracking, cloud synchronization, or remote crash reports.

The app does not require Accessibility, Screen Recording, or Notifications permission. It reads display geometry and the current pointer position, without capturing screen pixels or monitoring global keyboard input. The sandbox does not include network client/server entitlements.

Optional camera verification requests Camera permission only during a forced reminder or an explicit recognition test. It is off by default; ordinary animation previews do not start the camera. AVFoundation supplies frames and Vision processes face landmarks and vessels in the mouth region locally. Frames remain in memory, are not recorded, saved, or uploaded, and are not used for identity recognition. No microphone permission is requested. Capture stops when the reminder finishes or is dismissed, and when the Mac session becomes unavailable.

Launch at login is optional and uses the system-managed SMAppService API. Users can disable it in the app or System Settings. Nothing is shared with the developer. Removing the app's sandbox container after quitting deletes local preferences and history as well.
