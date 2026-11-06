# 摄像头强制检测（实验性）

## 行为与使用

开启设置中的「强制检测喝水」后，正式提醒会等待杯子或水瓶在嘴边区域稳定出现约 1 秒，随后自动完成并记录预设的一杯。不要求先放下或完成整段举杯 / 放杯动作。

普通动画预览不访问摄像头。「测试摄像头识别（不记水）」会单独启动检测，识别完成或退出都不写入饮水记录，可用来检查角度和光线。首次使用需要 macOS 摄像头授权；拒绝、系统限制、没有设备、摄像头占用或中断时，界面提供说明与重试。

强制提醒不接受点击确认、回车记水、延后或自动退场。紧急退出可以点击右上角并确认，或长按 Esc 2 秒；此路径不记录饮水。系统锁屏、睡眠、切换用户与显示器变化仍可中止提醒并关闭摄像头。识别测试可直接 Esc / 关闭退出。

摄像头检测当前默认关闭；已有偏好文件缺少新字段时也保持关闭，不会因升级而自动开启。关闭开关会立即中止当前识别并请求停止摄像头，本次不记录饮水。真实设备效果需要验证后再决定是否改变新安装的默认值。

## 实现

采集使用 AVFoundation，面部关键点使用 [VNDetectFaceLandmarksRequest](https://developer.apple.com/documentation/vision/vndetectfacelandmarksrequest)。以嘴部为中心计算归一化区域后，使用系统内置 [VNClassifyImageRequest](https://developer.apple.com/documentation/vision/vnclassifyimagerequest) 对该区域分类，无需下载第三方模型。嘴部被杯子遮挡时，已检测人脸的边界可提供嘴部位置估计。

`CupCameraWorker` 在 capture queue 配置 / 启停会话，在另一条 Vision queue 以约 6 fps 分析，避免从帧回调里阻塞停止会话。分类固定为 Revision 1，只接受实际查询到的杯具标识 `cup`、`mug`、`drinking_glass`、`bottle`、`jug`；不按子串匹配，因此 `cupcake`、`eyeglasses` 等不会当作杯具。

`DrinkGestureDetector` 只接收人脸数量、置信度和嘴边杯具置信度，不接收或保存图像。需要画面中有一张可靠的人脸、杯具分数达到 0.22，并累计约 0.8 秒有效检测；短暂分类抖动允许约 0.25 秒容差。大于 0.75 秒的帧空档会重置，避免睡眠或卡顿累计为识别成功。多个人脸、长期丢脸、过低置信度不会完成。

`MouthRegion` 根据宽高比计算范围并裁剪到 Vision 的单位坐标；`ReminderCompletionGate` 控制强制完成、延后和超时策略。`DrinkCameraVerifier` 在主 actor 发布状态，用 token 忽略过期回调，并在缺少画面、失败或退出时请求关闭会话。多屏共用一个 verifier、摄像头会话和完成状态，不会重复记水。

权限依据 [AVCaptureDevice.requestAccess](https://developer.apple.com/documentation/avfoundation/avcapturedevice/requestaccess(for:completionhandler:))。工程提供 `NSCameraUsageDescription` 和 `com.apple.security.device.camera` entitlement，不添加麦克风或网络权限。请求授权期间会降低提醒窗口级别，避免遮挡系统授权弹窗。

## 隐私与边界

画面仅在本机内存分析，不保存、录像或上传，不用于身份识别。正常模式与普通动画预览不会申请或开启摄像头。检测结束、提醒退出与会话不可用时停止采集。不要在日志、测试产物、截图或 Issue 中加入真实摄像头画面。

该方案是 **“嘴边区域出现杯具”的启发式判断**，不能证实水已入口、液体类型、吞咽或实际毫升数。单目画面没有可靠深度信息，角度、透明杯、遮挡、光线和背景都可能产生漏检 / 误检。饮水量仍按用户的每杯容量记账。

## 验证

纯逻辑测试覆盖杯具稳定出现即可完成、无需放下、短暂出现、空画面区域、低置信度、多人 / 丢脸、帧空档、旧时间戳、一次完成锁定、错误标签、嘴部区域边界和完成门控。它们验证程序约束，不代表识别模型在真实场景中的准确率。

实际摄像头授权、设备占用、不同杯子、光线和角度需要维护者通过「测试摄像头识别」验证。本次开发不自动开启真实摄像头，也没有保存真实摄像头测试素材。详细状态见 [验证记录](VALIDATION.md)。
