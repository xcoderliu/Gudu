# 安装咕嘟 · Gudu

支持 Apple Silicon（M 系列芯片）和 macOS 14 或更新版本。本次安装包仅包含 arm64，不提供 Intel 版本。

从 [xcoderliu/Gudu Releases](https://github.com/xcoderliu/Gudu/releases) 下载，并对照同页 `.sha256` 文件校验：

```bash
shasum -a 256 Gudu-0.1.0-macos-arm64-unsigned.zip
```

## 完全未签名包（unsigned）

这个包没有任何代码签名，也没有开发者证书或 Apple 公证。**Apple Silicon 不能直接运行完全未签名的 arm64 可执行文件**；至少需要本地 ad-hoc 签名。此限制与购买开发者账号无关，见 [Apple 对 Apple Silicon 代码签名要求的说明](https://developer.apple.com/documentation/macos-release-notes/macos-big-sur-11_0_1-universal-apps-release-notes)。

解压后，文件夹内有 `Gudu.app`、`Gudu.entitlements`、README 和 MIT License。确认下载来源与校验和后，在终端进入这个解压文件夹执行：

```bash
codesign --force --sign - --options runtime --entitlements Gudu.entitlements Gudu.app
codesign --verify --deep --strict Gudu.app
```

`--sign -` 仅生成本地 ad-hoc 签名，不读取开发者证书、不登录 Apple 账号。然后将 `Gudu.app` 拖入「应用程序」。这仍然不是 Apple 认证或公证。

## 自行构建本地 ad-hoc 包（可选）

本次 Release 不提供 ad-hoc 附件。开发者可执行 `./scripts/package_release.sh adhoc` 自行生成 `Gudu-0.1.0-macos-arm64-adhoc.zip`，它添加本地 ad-hoc 签名；没有开发者证书、没有 Team ID、没有使用 Apple 账号，也没有公证。它与完全未签名包明确区分，不能标成「完全无签名」。

确认来源和 SHA-256 后解压，将 `Gudu.app` 拖到「应用程序」。不要同时运行旧版和新版；退出旧版后替换应用。

## 首次打开

未公证的应用可能受到 Gatekeeper 拦截。确认来源可信后，按 [Apple 的首次打开说明](https://support.apple.com/102445)，在「系统设置 → 隐私与安全性」中查看本次拦截并选择允许打开；系统版本不同，界面文字可能有变化。不需要关闭整个系统的安全保护。

本地 ad-hoc 签名不使用会按期限失效的开发者证书。它不提供稳定的开发者身份；换包后系统可能重新询问摄像头授权或要求重新允许登录项。不要承诺所有 macOS 版本都无提示安装。

首次启动后：

1. 在「提醒设置」选每周提醒日、时间与间隔。
2. 新安装默认周一至周五 09:00–18:30、45 分钟、工作屏幕、音效与自动退场关闭；实验性摄像头检测默认开启。应用启动和普通动画预览不使用摄像头，可先使用「测试摄像头识别（不记水）」。正式提醒才申请授权；未授权或摄像头不可用时可手动确认。
3. 需要登录启动时，在设置中主动启用「登录时打开」。安装包不会自动注册登录项。

## 从旧名字升级

品牌和应用文件已改为咕嘟 / Gudu，内部 Bundle ID 沿用 `local.ripple.WaterReminder`，便于读取原来的沙盒设置与饮水记录。不要手动删除旧沙盒容器。实际更新后若授权状态改变，请在系统设置检查摄像头和登录项。
