# DanmakuPiP - AI 弹幕画中画

iPhone 画中画（PiP）悬浮窗 App，通过局域网 WebSocket 连接 PC 端的 AI 弹幕助手服务器。

## 功能

- 连接 PC 端 WebSocket 服务器（端口 8765）
- 接收 `ai_pair` 消息（精选弹幕 + AI 回复）
- 使用 `AVSampleBufferDisplayLayer` 渲染文字为视频帧
- `AVPictureInPictureController` 显示系统级画中画

## 使用 Codemagic 构建

### 第一步：上传到 GitHub

1. 在 GitHub 创建新仓库（例如 `DanmakuPiP`）
2. 将本目录下的 **所有内容**（包括 `DanmakuPiP.xcodeproj/`）推送到仓库
3. 仓库根目录结构如下：

```
DanmakuPiP/
├── codemagic.yaml              ← Codemagic 自动识别
├── export_options.plist
├── README.md
├── DanmakuPiP.xcodeproj/       ← Xcode 项目（已生成）
│   └── project.pbxproj
└── DanmakuPiP/
    ├── Sources/                ← Swift 源码
    │   ├── DanmakuPiPApp.swift
    │   ├── ContentView.swift
    │   ├── WebSocketManager.swift
    │   ├── PiPManager.swift
    │   ├── TextToVideoRenderer.swift
    │   └── DanmakuModels.swift
    └── Resources/              ← 资源文件
        ├── Info.plist
        ├── DanmakuPiP.entitlements
        └── Assets.xcassets/
```

### 第二步：Codemagic 配置

1. 登录 [Codemagic.io](https://codemagic.io)
2. 点击 **"Add application"** → 选择你的 GitHub 仓库
3. Codemagic 自动检测 `DanmakuPiP.xcodeproj` → **选择 iOS App**
4. 在 Environment 中设置：
   - **`FCI_DEVELOPMENT_TEAM`**: 你的 Apple Team ID
   - 上传 Apple 开发者签名证书（p12 + 描述文件）
5. 运行 `ios-build` workflow
6. 下载 `.ipa`，用 AltStore / SideStore 安装到 iPhone

### 手动构建（有 Mac）

```bash
open DanmakuPiP.xcodeproj
```

选择自己的开发者账号签名后，直接 Xcode → Run 到 iPhone。

## 连接说明

1. PC 端运行 `start.bat`，启动弹幕捕获服务
2. PC 端浏览器打开 `http://localhost:3000` → 页面显示局域网 IP
3. iPhone App 输入该 IP，端口 8765
4. 点击 **连接** → **启动悬浮窗**
5. 返回桌面或打开抖音直播 → PiP 悬浮窗显示 AI 回复
