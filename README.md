<p align="center">
  <img src="assets/images/app_logo.png" width="128" alt="YourTJ Course">
</p>

<h1 align="center">YourTJ Course · HarmonyOS</h1>
<p align="center">
  同济大学选课社区 · HarmonyOS NEXT 客户端<br>
  Flutter + Riverpod + lkcn_ui · YourTJ Course
</p>

<p align="center">
  <img alt="Version" src="https://img.shields.io/badge/version-0.1.0-0AB5C9?style=flat-square">
  <img alt="Platform" src="https://img.shields.io/badge/platform-HarmonyOS_NEXT-0AB5C9?style=flat-square&logo=harmonyos&logoColor=white">
  <img alt="Dart" src="https://img.shields.io/badge/Dart-3-0175C2?style=flat-square&logo=dart&logoColor=white">
  <img alt="UI" src="https://img.shields.io/badge/UI-Material%203%20%2B%20lkcn__ui-0AB5C9?style=flat-square">
  <img alt="Architecture" src="https://img.shields.io/badge/architecture-Riverpod-555?style=flat-square">
  <img alt="License" src="https://img.shields.io/badge/license-Proprietary-lightgrey?style=flat-square">
  <img alt="CI" src="https://img.shields.io/badge/CI-GitHub_Actions-2088FF?style=flat-square&logo=githubactions&logoColor=white">
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#architecture">Architecture</a> •
  <a href="#getting-started">Getting Started</a> •
  <a href="#project-structure">Project Structure</a> •
  <a href="#tech-stack">Tech Stack</a> •
  <a href="#harmonyos-migration">HarmonyOS Migration</a>
</p>

---

**YourTJ Course HarmonyOS** 是同济大学选课社区的 HarmonyOS NEXT 客户端。
本分支基于 Flutter 跨平台框架，借助社区维护的 OpenHarmony Flutter SDK（`openharmony-tpc/flutter_flutter`）将现有 Flutter 应用迁移至 HarmonyOS NEXT 平台，
直接调用 Cloudflare Workers 后端 API，覆盖查课、评课、选课和模拟排课等完整功能。

> **YourTJ 产品矩阵** ·
> [Serverless（后端 API）](https://github.com/YourTongji/YourTJCourse-Serverless) ·
> [iOS（原生版）](https://github.com/YourTongji/YourTJCourse-iOS) ·
> [Flutter（Android 版）](https://github.com/YourTongji/YourTJCourse-Flutter/tree/dev) ·
> [Credit（积分服务）](https://github.com/YourTongji/YourTJ-Credit-Serverless) ·
> [Captcha（验证服务）](https://github.com/YourTongji/YourTJCaptcha)

## Features

| 模块 | 功能 | 状态 |
|------|------|------|
| **课程浏览** | 无限滚动列表、关键词搜索、只看有评价筛选、院系筛选、课程详情跳转 | 已迁移 |
| **课程详情** | 课程信息头、手动触发 AI 课程总结、Markdown 评价列表、点赞/取消、隐藏/举报、关联课程 | 已迁移 |
| **评价系统** | 评价展示、ICU 多级标题规范化、举报与本机隐藏 | 已迁移 |
| **排课模拟器** | 学期切换、年级/专业选择、课程检索、空段找课、冲突检测、移动端周课表 | 已迁移 |
| **公告通知** | 运行时拉取、未读弹窗、「我已知晓」标记已读、本机持久化 | 已迁移 |
| **更多设置** | 公告列表、社区规范、反馈说明、安全与合规、关于页 | 已迁移 |
| **积分钱包** | Credit 钱包、助记词、远程余额与积分 | 暂不跟进（UI 已迁移） |

## Architecture

Flutter 版采用轻量分层结构：UI 与交互在 `features`（功能）中，
领域模型与仓库在 `domain`（领域层）中，网络、配置和本机存储在 `core`（基础层）中。

HarmonyOS 原生接口通过 flutter_ohos 引擎桥接，原生插件使用 OpenHarmony 社区适配版。

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
         ↓ flutter_ohos engine bridge ↓
┌─────────────────────────────────────────┐
│  ohos/  (HarmonyOS Platform Layer)      │
│  ┌──────────┬──────────────────────┐    │
│  │ EntryAbility (ArkTS)           │    │
│  │ FlutterPlugin 桥接             │    │
│  │ HAP 构建配置                   │    │
│  └──────────┴──────────────────────┘    │
└─────────────────────────────────────────┘
```

**Key design decisions:**

- **真实后端优先**：Release / CI 默认连接 `https://jcourse.yourtj.de`。
- **Action 发包**：本地只做格式化、静态检查和测试，HAP 由 GitHub Actions 生成。
- **零本地依赖**：全部编译工作通过 GitHub Actions + OpenHarmony Flutter SDK 完成。
- **插件联邦架构**：原生插件使用 OpenHarmony-TPC 社区维护的 ohos 适配版。

## Getting Started

本分支所有编译工作由 GitHub Actions 自动完成，无需本地搭建鸿蒙开发环境。

### CI 构建

PR 合入 `harmonyos` 后，GitHub Actions 会运行 `HarmonyOS Build HAP` 并上传
构建产物 `.hap` 文件。下载后通过 `hdc` 工具安装到 HarmonyOS NEXT 设备：

```bash
hdc install yourtjcourse.hap
```

### 本地开发（可选）

如需本地调试，需额外安装：
- DevEco Studio（鸿蒙应用开发 IDE）
- HarmonyOS SDK + OpenHarmony Flutter SDK

具体步骤参考 [OpenHarmony Flutter 开发指南](https://gitcode.com/openharmony-tpc/flutter_flutter)。

### API Configuration

Flutter 版通过 `.env`（环境变量文件）读取 API 地址；CI 会自动生成该文件。

| Environment | API Base | Credit Base |
|-------------|----------|-------------|
| **Default** | `https://jcourse.yourtj.de` | `https://core.credit.yourtj.de` |
| **GitHub Actions** | `API_BASE_URL` secret 或默认真实后端 | `CREDIT_API_BASE_URL` secret 或默认 Credit 后端 |

### Local Checks

```bash
# 使用 OpenHarmony Flutter SDK
flutter pub get
flutter analyze
flutter test
```

## Project Structure

```text
YourTJCourse-Flutter/
├── ohos/                          # HarmonyOS 原生工程
│   └── entry/src/main/
│       ├── module.json5           # 鸿蒙模块配置
│       ├── ets/entryability/      # EntryAbility ArkTS 入口
│       └── resources/             # 鸿蒙资源文件
├── assets/
│   └── images/app_logo.png        # 应用 logo
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
    ├── android-test.yml           # Android 预发包 Action（legacy）
    └── harmonyos-build.yml        # HarmonyOS 构建 Action
```

## Tech Stack

| Layer | Choice |
|-------|--------|
| Language | Dart |
| UI | Flutter Material 3, lkcn_ui |
| State | Riverpod 3 |
| Routing | go_router |
| Networking | Dio |
| Local Storage | shared_preferences, flutter_secure_storage_ohos |
| Markdown | flutter_markdown |
| CI/CD | GitHub Actions |
| Platform | HarmonyOS NEXT (OpenHarmony Flutter SDK) |

## HarmonyOS Migration

本分支是 `harmonyos` 分支，从 `dev` 分支分离，专用于 HarmonyOS NEXT 平台适配。

### 迁移方案

- **Flutter SDK**: OpenHarmony-TPC `flutter_flutter`（GitCode 镜像）
- **构建命令**: `flutter build hap --release`
- **产物格式**: `.hap`（HarmonyOS Ability Package）
- **插件策略**: 社区适配版（`flutter_secure_storage_ohos`、`share_plus_harmonyos` 等）
- **CI 策略**: 零本地依赖，全部在 GitHub Actions 上完成

### 与 Android 版的差异

| 项目 | Android 版 (dev) | HarmonyOS 版 (harmonyos) |
|------|:----------------:|:------------------------:|
| 构建工具 | Gradle + AGP | Hvigor + flutter_flutter |
| 产物格式 | APK | HAP |
| 原生代码 | Kotlin | ArkTS |
| CI | android-test.yml | harmonyos-build.yml |
| 原生插件 | Android 实现 | OHOS 实现 |

## Workflow

```text
issue + label
     │
     ▼
feature/fix branch
     │
     ▼
PR → harmonyos ──→ HarmonyOS Build HAP ──→ device testing
                                                  │
                                                  ▼
                                          PR → main after approval
```

### Commit Convention

- `feat(scope): description`
- `fix(scope): description`
- `docs(scope): description`
- `chore(scope): description`

常用 scope：`app`、`catalog`、`course`、`scheduler`、`settings`、`ci`、`docs`、`ohos`。

## Safety & Compliance

- **HTTPS 默认开启**：Release / CI 默认使用真实 HTTPS 后端。
- **无硬编码凭据**：API 地址通过环境变量或默认公开地址配置，不提交 `.env`。
- **UGC 合规**：评价提供举报与本机隐藏入口。
- **请求生命周期处理**：页面切换导致的取消请求不作为业务错误展示。

## License

© 2026 YourTJ. All rights reserved.
