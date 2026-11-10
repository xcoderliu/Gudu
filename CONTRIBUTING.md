# 贡献指南 / Contributing

欢迎以中文或英文提交 Issue 和 Pull Request。

## 开始之前

先阅读 [README](README.md)、[开发指南](docs/DEVELOPMENT.md) 与 [架构说明](docs/ARCHITECTURE.md)。行为较大的功能建议先开 Issue，说明使用场景与预期。

## 开发流程

1. Fork 仓库并创建功能分支。
2. 使用 Xcode 打开 `Gudu.xcodeproj`。
3. 保持改动围绕一个问题，避免混入无关格式整理。
4. 执行 `swift test`，并构建应用。
5. 涉及提醒界面的改动请附截图 / 动画；涉及多屏、睡眠、时段请说明验证场景。
6. 更新需要的文档与 Changelog，再提交 PR。

时间和屏幕算法应提供有意义的边界测试；纯文案、样式微调无需为实现细节添加重复测试。新增依赖前请说明原生实现不能满足的需求。

## 代码约定

- 主 actor 管理 SwiftUI 状态和 AppKit 窗口。
- 日历与屏幕坐标逻辑放在 `GuduCore`。
- 动画保持矢量绘制，并支持减少动态效果。
- 不新增遥测、追踪或无必要的系统权限。
- 不提交用户状态、签名凭据、构建产物和个人 Xcode 配置。
- 新增源文件时保持 Xcode 工程可直接打开；如重新生成工程，同步维护生成脚本。

## Bug 报告

请包含 macOS / Xcode 版本、芯片类型、屏幕数量与排列、提醒设置、复现步骤，以及期望 / 实际结果。多屏问题请说明是普通桌面、独占全屏、不同 Space 还是 Stage Manager。不要附带个人数据或敏感屏幕内容。

## English

Issues and pull requests in English or Chinese are welcome. Keep changes focused, run `swift test`, and build the app before submitting. Include screenshots for UI changes and reproduction details for schedule or display issues. Keep the checked-in Xcode project and generator consistent. Do not commit credentials, user preferences, build output, or personal IDE state. Contributions are distributed under the project's MIT license.
