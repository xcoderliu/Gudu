# 发布指南

目标仓库：[xcoderliu/Gudu](https://github.com/xcoderliu/Gudu)。首次版本：`v0.1.0`，MIT License。维护者已于 2026-11-10 确认首次发布，指定 SSH 远端 `git@github.com:xcoderliu/Gudu.git` 与仅 arm64 安装包。后续版本仍需先核对再发布。

## 本地准备

```bash
python3 scripts/check_repository_files.py
swift test
./scripts/check_recovery.sh
./scripts/smoke_test.sh
./scripts/check_completion.sh
./scripts/render_previews.sh
cp .local/previews/gudu-hero.png .local/previews/dashboard.png docs/images/
./scripts/render_motion.sh
cp .local/bean-ritual.gif docs/images/gudu-demo.gif
./scripts/package_release.sh unsigned
./scripts/verify_release.sh
```

默认打包命令仅在本机构建，不使用开发者账号。默认 `unsigned` 会移除链接器可能附带的 arm64 签名，确保产物确实未签名；`adhoc` 才会显式添加本地签名并保留沙盒 / 摄像头 entitlement。两者均为 Release、macOS 14+、仅 arm64，均未公证。输出在 Git 忽略的 `dist/`，不把二进制打进源码提交。

脚本会生成每个 ZIP 的 `.sha256`。完全未签名包在 Apple Silicon 上需要本地补签才能运行，不能称为直接可运行的安装包。详见 [安装指南](INSTALL.md)。

## 最终核对

使用 [发布核对单](PUBLISH_REVIEW.md)，检查名称、截图、隐私、版本、功能、仓库、安装体验和附件签名状态。公开文档中不放开发者电脑绝对路径、用户偏好、公司资料或密钥。真人摄像头素材仅限维护者已明确授权的 `camera-real-use.webp`，保留来源及仅更新品牌区的说明。保留内部旧 Bundle ID 用于数据兼容。

工程设置同步 `scripts/generate_project.py`，生成器保留现有共享 Scheme 的运行配置。只在缺失时创建默认 Scheme。生成前后对比工程及共享 Scheme，避免覆盖维护者的配置。

## 发布流程

1. 根据维护者选择确定发布完全未签名包，或同时提供明确标注的 ad-hoc 备选包。
2. 将 README 中「发布前核对 / 尚未上传」改为实际版本下载入口；将 CHANGELOG 的待发布日期改为实际发布日期，移除 Release Notes 草稿标记。
3. 审查并提交全部源码、文档与公开图片，排除 `dist/`、`build/`、`.local/`、个人 Xcode 状态。提交作者使用维护者个人身份。
4. 推送 `main` 到 `origin`，观察远端 CI；失败时修复并重新验证。
5. CI 通过且上传范围仍与维护者确认一致后，创建并推送 `v0.1.0` 标签，使用 [Release Notes](RELEASE_NOTES_0.1.0.md) 发布 GitHub Release，并上传已核对的 ZIP 和 `.sha256`。
6. 从公开 Release 重新下载并核对 SHA-256、名称与附件。核查 README 图片和源码链接可打开。

不强推、不覆盖已有标签或 Release；若远端有新提交，先读差异再合并。远端 CI 在推送后运行，以 Actions 记录为准，本地通过不代表远端通过。

## 未来的 Developer ID 分发

若维护者以后决定使用自己的开发者证书，再单独配置签名、公证与首次安装验证；这不属于当前未签名发布。不要读取或选择公司的团队，不提交证书、私钥或凭据。
