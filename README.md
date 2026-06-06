<p align="center">
  <img src="assets/images/app_logo.png" width="128" alt="YourTJ Course">
</p>

<h1 align="center">YourTJ Course</h1>
<p align="center">
  同济大学选课社区 · Flutter Android 测试客户端<br>
  Flutter + Riverpod + lkcn_ui · YourTJ选课测试
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#architecture">Architecture</a> •
  <a href="#getting-started">Getting Started</a> •
  <a href="#project-structure">Project Structure</a> •
  <a href="#tech-stack">Tech Stack</a> •
  <a href="#safety--compliance">Safety</a>
</p>

---

**YourTJ Course Flutter** 是同济大学选课社区的 Android 预发测试客户端。
它延续 iOS 版的信息结构与功能边界，同时保留 Flutter 端的移动端设计语言，
直接调用 Cloudflare Workers 后端 API，当前重点覆盖查课、评课、选课和模拟排课。

> iOS 仓库：[YourTJCourse-iOS](https://github.com/YourTongji/YourTJCourse-iOS)
> 后端仓库：[YourTJCourse-Serverless](https://github.com/YourTongji/YourTJCourse-Serverless)

## Features

| 模块 | 功能 | 状态 |
|------|------|------|
| **课程浏览** | 无限滚动列表、关键词搜索、只看有评价筛选、院系筛选、课程详情跳转 | 已接入 |
| **课程详情** | 课程信息头、AI 课程总结、Markdown 评价列表、点赞/取消、隐藏/举报、关联课程 | 已接入 |
| **评价系统** | 评价展示、ICU 多级标题规范化、举报与本机隐藏 | 部分接入 |
| **排课模拟器** | 学期切换、年级/专业选择、课程检索、空段找课、冲突检测、移动端周课表 | 已接入 |
| **公告通知** | 运行时拉取、未读弹窗、「我已知晓」标记已读、本机持久化 | 已接入 |
| **更多设置** | 公告列表、社区规范、反馈说明、安全与合规、关于页 | 已接入 |
| **积分钱包** | Credit 钱包、助记词、远程余额与积分 | 暂不跟进 |

## Architecture

Flutter 版采用轻量分层结构：UI 与交互在 `features`（功能）中，
领域模型与仓库在 `domain`（领域层）中，网络、配置和本机存储在 `core`（基础层）中。

```text
┌─────────────────────────────────────────┐
│  App  (MaterialApp.router, Shell Tabs)  │
├─────────────────────────────────────────┤
│  Features                               │
│  ┌────────┬──────────────┬────────────┐ │
│  │Catalog │Course Detail │ Scheduler  │ │
│  ├────────┼──────────────┼────────────┤ │
│  │Settings│Announcements │            │ │
│  └────────┴──────────────┴────────────┘ │
├─────────────────────────────────────────┤
│  Domain  (models, repositories)         │
├─────────────────────────────────────────┤
│  Core    (Dio, config, local storage)   │
├─────────────────────────────────────────┤
│  Shared  (widgets, markdown helpers)    │
└─────────────────────────────────────────┘
```

**Key design decisions:**

- **真实后端优先**：Release / CI 默认连接 `https://jcourse.yourtj.de`。
- **Action 发包**：本地只做格式化、静态检查和测试，APK 由 GitHub Actions 生成。
- **移动端优先**：排课界面采用分栏 / 标签页自适应，避免横向溢出。
- **生命周期稳定**：Riverpod provider dispose 引起的请求取消不展示为业务错误。
- **钱包隔离**：钱包涉及凭据与 Credit 服务，本测试版暂不纳入功能同步。

## Getting Started

### Prerequisites

- Flutter 3.x
- Android SDK（仅本地调试时需要）
- WSL / Linux 开发环境

不要调用 Windows 挂载目录下的 Flutter SDK。当前推荐使用：

```bash
/root/dev/flutter/bin/flutter --no-version-check pub get
```

### API Configuration

Flutter 版通过 `.env`（环境变量文件）读取 API 地址；CI 会自动生成该文件。

| Environment | API Base | Credit Base |
|-------------|----------|-------------|
| **Default** | `https://jcourse.yourtj.de` | `https://core.credit.yourtj.de` |
| **GitHub Actions** | `API_BASE_URL` secret 或默认真实后端 | `CREDIT_API_BASE_URL` secret 或默认 Credit 后端 |

### Local Checks

```bash
/root/dev/flutter/bin/dart format lib test
/root/dev/flutter/bin/flutter --no-version-check analyze
/root/dev/flutter/bin/flutter --no-version-check test
```

### Android Pre-release

本地不要求编译 APK。

PR 合入 `dev` 后，GitHub Actions 会运行 `Android Test APK` 并上传
`yourtjcourse-flutter-release-apks`。按手机 CPU 架构安装对应 APK：

- `app-arm64-v8a-release.apk`
- `app-armeabi-v7a-release.apk`
- `app-x86_64-release.apk`

## Project Structure

```text
YourTJCourse-Flutter/
├── android/                       # Android 原生工程与启动图标
├── assets/
│   └── images/app_logo.png        # 与 iOS 同步的应用 logo
├── lib/
│   ├── core/                      # 配置、网络、存储等基础能力
│   ├── domain/                    # 课程、评价、公告、AI 总结等模型与仓库
│   ├── features/
│   │   ├── announcements/         # 运行时公告弹窗
│   │   ├── catalog/               # 查课与筛选
│   │   ├── course_detail/         # 课程详情、AI 总结、评价操作
│   │   ├── scheduler/             # 培养方案查课与模拟排课
│   │   └── settings/              # 更多设置
│   └── shared/                    # 复用 UI 状态组件与 Markdown 规则
├── test/                          # 单元测试与 Widget 测试
└── .github/workflows/
    └── android-test.yml           # Android 预发包 Action
```

## Tech Stack

| Layer | Choice |
|-------|--------|
| Language | Dart |
| UI | Flutter Material 3, lkcn_ui |
| State | Riverpod 3 |
| Routing | go_router |
| Networking | Dio |
| Local Storage | shared_preferences, flutter_secure_storage |
| Markdown | flutter_markdown |
| CI/CD | GitHub Actions |

## Workflow

```text
issue + label
     │
     ▼
feature/fix branch
     │
     ▼
PR → dev ──→ Android Test APK ──→ phone testing
                                      │
                                      ▼
                              PR → main after approval
```

### Commit Convention

- `feat(scope): description`
- `fix(scope): description`
- `docs(scope): description`
- `chore(scope): description`

常用 scope：`app`、`catalog`、`course`、`scheduler`、`settings`、`ci`、`docs`。

## Safety & Compliance

- **HTTPS 默认开启**：Release / CI 默认使用真实 HTTPS 后端。
- **无硬编码凭据**：API 地址通过环境变量或默认公开地址配置，不提交 `.env`。
- **UGC 合规**：评价提供举报与本机隐藏入口。
- **请求生命周期处理**：页面切换导致的取消请求不作为业务错误展示。
- **钱包暂不接入**：涉及凭据和 Credit 用户密钥的能力在本测试版中保持隔离。

## License

© 2026 YourTJ. All rights reserved.
