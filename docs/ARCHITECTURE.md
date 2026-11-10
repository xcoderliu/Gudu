# 架构说明

## 应用边界

咕嘟是 SwiftUI + AppKit 原生 macOS 应用，无服务器、无网络层、无第三方动画引擎。SwiftUI 负责界面与矢量绘制，AppKit 负责菜单栏和跨显示器提醒窗口，AVFoundation / Vision 负责可选的本机摄像头识别，`GuduCore` 负责可测试的计算。

```text
GuduApp
  └─ AppDelegate
       ├─ AppModel ─────────────── UserDefaults
       │    └─ ReminderSchedule   纯时间计算
       ├─ DashboardView
       │    ├─ SettingsView
       │    └─ WaterScene
       ├─ NSStatusItem / NSMenu
       └─ ReminderWindowController
            ├─ ScreenRouter       纯屏幕坐标路由
            ├─ DrinkCameraVerifier ─ CupCameraWorker ─ AVFoundation / Vision
            └─ ReminderPanel × N
                 └─ ReminderView ─ DrinkingRitualScene
                      └─ shared ReminderSession
```

## 状态与计时

`AppModel` 是主 actor 的 ObservableObject，持有偏好、饮水记录、当前时间、下一次提醒与当前展示状态。设置变更自动保存；只有间隔、起止时间、启用状态改变才重算计划。音效、人物、屏幕模式、容量等变更不会重置倒计时。

摄像头检测开关在下次正式提醒生效；关闭时会立即中止当前检测。摄像头正常检测时，Session 通过 `ReminderCompletionGate` 拦截手动确认、回车、延后和自动关闭，识别完成才记水。未授权或采集不可用时，正式提醒使用本次会话的手动回退状态，保留错误与重试，不自动记水、不自动关闭，也不修改保存的检测开关；重试立即恢复检测门控。识别测试不提供手动成功回退。紧急退出和系统会话变化不记水。测试模式与普通动画预览分开，避免预览动画时意外申请摄像头。识别方案、权限和限制见 [CAMERA_VERIFICATION.md](CAMERA_VERIFICATION.md)。

杯具分析围绕已记住的嘴部提供杯身、杯口与倾斜三个裁剪，清晰杯具使用快速路径；较弱的多处杯具线索可结合本机手部关键点，以半速累计有效时间。`DrinkingVesselEvidence` 与 `MouthRegion` 将分数策略、手部位置与裁剪几何放在可测试的 Core 中。测试界面显示短暂的分数与分类名称，不保存图像、关键点或诊断日志。

一个加入主 run loop common mode 的 1 秒 Timer 更新倒计时并判断是否到期。计划以绝对 `Date` 保存，避免按 tick 次数累加引起漂移。展示期间不重复打开提醒。出现大于 90 秒的 tick 空档时走恢复逻辑，明显时间倒退则重算计划。

锁屏、睡眠与非活跃用户会话分别记录，任意条件成立即暂停并关闭提醒，保留正常到期时间；全部解除后由 Core 的 `ReminderRecoveryPlan` 决定正常与补提醒两个时间。未到点保持原时间，过点后保留原间隔的未来正常时间，并安排恢复后 30 秒补一次；多次错过只合并一次。恢复时距下一次正常提醒 ≤ 5 分钟则省略补提醒，正常时间不变。补提醒不能越过当前有效时段，未选日期 / 安静时段直接进入下一正常窗口。

正式提醒被系统中断时保留待补状态，预览和摄像头测试中断不会产生待补提醒；异步退场回调不会把恢复计划覆盖掉。缓冲时再次休眠，下一次恢复重新缓冲。记水、暂停、修改提醒日期 / 时段 / 间隔会清除旧补提醒；5 分钟延后的到期时间也会保留并适用相同恢复规则。完成或关闭提醒后按现有规则安排下一次。系统时钟或时区改变时重算计划。此状态在应用进程内保留，退出后不留后台 daemon，也不会在重启时追补旧提醒。

新安装默认：摄像头开启、45 分钟、周一至周五 09:00–18:30、鼠标屏幕、音效关闭、自动退场关闭；启动应用不立即使用摄像头。JSON 解码保留已保存的值，对缺失字段沿用旧版缺省值，避免新默认覆盖已有偏好。摄像头开启时，自动退场选择器固定显示「不自动关闭」并置灰；保存的普通提醒退场时长不变。关闭摄像头后显示原时长，应用重启后也保留。

### 每周日期与时间窗口

`ReminderSchedule` 接受每周日期集合、`startMinute`、`endMinute` 和间隔，以本地日历构造实际的 `DateInterval`：

- 未选择任何日期时，`isActive` 为 false，下一次提醒与下一起点均为 nil。
- 起点包含，终点不包含。
- 起点小于终点：同一自然日时段。
- 起点大于终点：跨午夜时段归属开始日，结束部分可以延续到未选中的次日。
- 起点等于终点：所选自然日从 00:00 起全天；连续选中的全天日期视作连续活动区间。
- 时段或日期以外，下一次提醒安排在下一个选中窗口的起点。
- 时段内先计算完整间隔；到达或越过当前窗口终点则移到下一起点。
- 延后提醒使用同样规则，只把等待时长换为 5 分钟；长延后也不能跳过不活动的日期再落入后续窗口中间。

日期修改参与 `hasSameSchedule` 比较，立即保存并重排计划；空选时主界面明确显示暂停原因。手动记水与预览仍可使用。快捷的周一至周五仅代表所选星期，不联网判断节假日或调休。

`Calendar.nextDate` 使用 `.nextTime` 和 `.first` 处理夏令时缺失 / 重复小时。真实等待间隔按秒计，时段边界按本地墙上时间解释。

### 完成行为

| 事件 | 写饮水记录 | 下一次计划 |
| --- | --- | --- |
| 主界面 / 菜单栏记一杯 | 是 | 从当前时间重算 |
| 正式提醒确认 | 是 | 从确认时间重算 |
| 正式提醒延后 | 否 | 当前时间 + 5 分钟，并遵守时段 |
| Esc / 自动退场 / 屏幕重配置 | 否 | 按设置间隔重算 |
| 预览完成 / 关闭 | 否 | 保持原计划 |

## 多屏窗口

每次提醒出现时重新读取 `NSScreen.screens` 和 `NSEvent.mouseLocation`。两者使用 AppKit 的全局屏幕坐标，因此直接用 `screen.frame.contains(cursor)` 判断，正确处理左侧负坐标与上下排列；不混用 Quartz 的坐标原点。屏幕路由返回索引，便于不依赖真实硬件测试。

默认选择包含鼠标的第一块屏幕。所有屏幕模式或未匹配到鼠标时，返回全部屏幕。每块屏幕使用 `frame`，覆盖菜单栏和 Dock 所在区域。

窗口为无边框 nonactivating `NSPanel`，使用 `.screenSaver` 级别，以及 `.canJoinAllSpaces` / `.fullScreenAuxiliary` 等公开行为；macOS 15+ 添加 `.canJoinAllApplications`。不调用真正的系统 `toggleFullScreen`，因此不会为提醒创建新 Space。

所有窗口共享一个 `ReminderSession`：相同的动画开始时间、人物、容量、截止时间与完成状态。任一屏幕确认后，其余屏幕同步完成并关闭，保证只记一杯。事件监听、音频播放器与自动关闭任务只有一份，由控制器统一撤销。窗口关闭动画结束后才清空展示状态，避免连续触发。

完成时立即停止摄像头与提醒音轨，淡出并关闭提醒窗口，然后记录一次完成并显示独立的 `CelebrationPanel`。透明撒花窗口不能成为 key / main window，且 `ignoresMouseEvents = true`，桌面可继续操作。所有原目标屏幕共享撒花开始时间，3 秒后关闭；新提醒、锁屏 / 睡眠、显示器变化或退出都会清理撒花。系统事件在淡出期间发生时取消撒花，已经确认的饮水仍按一次完成处理。

显示器重配置时关闭当前窗口，防止窗口留在断开的屏幕上。下次提醒重新路由。

## 矢量动画与声音

`WaterScene` 在 400 × 400 的逻辑画布上描述玻璃杯、波面、气泡、水滴、粒子和涟漪，再等比缩放到实际尺寸。Canvas 通过路径、渐变和椭圆绘制，没有位图逐帧序列。

`ConfettiCelebrationView` 使用 Canvas 绘制 520 片彩纸、圆片、曲线彩带与星形纸片：双侧大扇形喷发配合上方全宽飘落，以固定种子生成位置、颜色、景深大小与翻转，按时间计算阻力和重力，避免逐帧随机闪动。轨迹依据整个屏幕的宽高计算，适应超宽屏；小屏缩放只影响纸片尺寸。撒花只在确认或识别完成后播放，关闭 / 延后不播放。减少动态效果时跳过粒子，只显示 1.4 秒静态完成提示。

`TimelineView(.animation)` 为水位、正弦波、下落、扩散与呼吸提供时间：

- 前 3.5 秒水位缓慢升起。
- 多层不同相位波面形成水的层次。
- 气泡上浮，涟漪循环扩散，水滴轻轻上下浮动。
- 全屏背景波浪单独以较低刷新频率绘制。
- 减少动态效果启用时固定时间参数，并取消窗口淡入淡出。

应用图标 PNG 是 macOS 图标资源；它们不参与动画。图标由仓库中的原生矢量绘图脚本再生成。

全屏 `DrinkingRitualScene` 使用 960 × 440 逻辑画布呈现开放式厨房台面、水槽与鹅颈直饮净水龙头。豆豆小人走近接水、拿杯、倾斜喝水、放低杯子并微笑舒气。`GuduCore.DrinkingTimeline` 提供 15 秒循环动作的阶段与缓动进度，所有屏幕使用同一个开始时间。减少动态效果时固定为喝水后放松的画面。

`DrinkingBodyPose` 统一规划豆豆小人、杯子与手臂的位置。小人先走到手臂可触及范围，再伸手、握住杯子并携杯后退。上臂与前臂分别固定为 36 / 34 逻辑单位，通过两圆交点求肘部位置；手腕与前景小手跟随杯子的旋转。喝水期间让旋转后的杯沿锚点贴合嘴部锚点，避免沿用旧人形的头部高度。步幅和身体起伏在走路起停时缓入缓出。整段时间线的骨骼长度、握杯位置、杯沿贴嘴与肘部连续性由测试约束。

小人统一为单一豆形轮廓、薄荷色填充、深色圆润描边、点状眼睛与短手短脚，不绘制独立人头、头发、肤色或服装。没有性别或形象选择，也没有为人物类型保留设置字段。小人及厨房始终由原生路径绘制，不使用概念图位图作为运行时动画。

`HydrationRitual.wav` 是与时间线同步的 15 秒合成音效：1.45 秒开始流水，7.15–8.64 秒分三次咕嘟，10.65 秒轻呼气。确认按钮播放短 `Satisfied.wav`。`AVAudioPlayer` 由窗口控制器持有，多屏不会叠加播放，关闭提醒会停止声音。系统 Reduce Motion 开启时，配合静态画面只播放一次短舒气声。音效默认关闭，可在设置启用。

音频由标准库 Python 脚本离线合成，为项目原创素材，没有真人录音或第三方采样；原脚本和 WAV 一起纳入 Git。

## 持久化

每周日期由 `Set<ReminderWeekday>` 表示，编码使用 Foundation 星期编号（周日为 1），界面顺序固定为周一至周日。旧偏好缺少此字段或为 null 时补齐每天提醒；空数组保留为暂停自动提醒；无效编号会被过滤，避免重置其他偏好。

偏好与记录分别编码为 JSON Data，写入沙盒 UserDefaults 的 `reminderSettings`、`hydrationEntries`。加载时对偏好数值范围归一化，缺失字段使用对应默认值，无法解码时使用默认设置。旧版 `character` 字段不在当前 CodingKeys 中，读取时忽略其值，后续保存也不再写入；其他偏好与独立保存的饮水记录不受影响。饮水记录在加载与新增时清理 90 天前数据。

没有云同步、用户账号和远程配置。开机启动使用 `SMAppService.mainApp`，由系统管理注册与授权状态，不自行写入 LaunchAgents。

## 扩展建议

- 增加其他动画主题时保留 WaterScene 的单一时间源与 Reduce Motion 入口。
- 修改设置数据结构时提供旧字段兼容解码与迁移测试。
- 新增统计或导出时，继续区分确认饮水与预览 / 关闭提醒。
- 发布多语言版本时再引入 String Catalog，避免把文案散落在新增代码中。

## Apple API 参考

- [NSEvent.mouseLocation](https://developer.apple.com/documentation/appkit/nsevent/mouselocation)
- [NSScreen.frame](https://developer.apple.com/documentation/appkit/nsscreen/frame)
- [NSWindow.CollectionBehavior](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct)
- [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)
