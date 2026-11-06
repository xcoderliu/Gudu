# 发布指南

## 首次推送 GitHub

本地仓库已经准备好 Git、README、MIT License、贡献模板与 CI 配置。创建 GitHub 空仓库后，在项目目录执行以下命令，把 `YOUR_NAME` 和仓库名替换成实际值：

```bash
git remote add origin git@github.com:YOUR_NAME/WaterReminder.git
git push -u origin main
```

如果远端已经有初始化提交，先检查并合并远端历史，避免强制覆盖。不要把令牌写在 URL、脚本或文档中。仓库建议主题：`macos`、`swiftui`、`water-reminder`、`vector-animation`、`menu-bar-app`。

创建远端仓库与推送属于发布步骤，应由项目维护者决定仓库账号、名称和可见性后执行。

## 发布前

1. 在目标 macOS / Xcode 上执行 `swift test` 和 Release 构建。
2. 按 [验证记录](VALIDATION.md) 的人工检查表测试实际多屏与系统行为。
3. 更新版本号、`CHANGELOG.md`、截图与验证环境说明。
4. 确认 Git 没有个人数据、Derived Data、签名文件、证书或 Token。
5. 如果修改工程设置，同步更新 `scripts/generate_project.py`。

GitHub Actions 在远端执行后才能确认远端 CI 通过；本地构建通过不等同于远端 CI 已通过。

## 本机试用

```bash
./scripts/build.sh
open build/Build/Products/Debug/Ripple.app
```

也可以在 Finder 中把 `Ripple.app` 复制到 Applications 后使用。默认是仅用于本地开发的 ad-hoc 签名，没有 Apple 公证，不能作为已公证发行版提供给其他用户。

## Developer ID 分发

正式分发需维护者自己的 Apple Developer 账号与 Developer ID Application 证书：

1. 修改 Bundle ID 为维护者持有的唯一标识。
2. 在 Xcode Signing & Capabilities 中选择团队与 Developer ID 签名，启用 Hardened Runtime。移除开发用的 `CODE_SIGN_IDENTITY = -` 设置，按分发方式选择签名管理策略。
3. Product → Archive，使用 Organizer 的分发流程导出并公证。
4. 完成票据附加后，在另一台未安装过该应用的 Mac 上验证首次打开与登录启动。
5. 创建带校验和的发布压缩包，再上传 GitHub Release。

不要提交私钥、证书、App Store Connect API key 或公证凭据。当前工程尚未执行 Developer ID 签名与公证，也不包含自动上传 / 发布脚本。

## 版本与标签

维护者确认版本可以发布后，再创建标签，例如：

```bash
git tag -a v0.1.0 -m 'Ripple 0.1.0'
git push origin v0.1.0
```

开源代码的可用性与二进制签名 / 公证是两个独立步骤，发布说明应清楚标注支持系统、已验证硬件和二进制签名状态。
