# YOURTJ选课社区 - Flutter 测试版

基于 Flutter 的 YourTJ 选课社区移动端测试应用。

当前应用名称为 `YourTJ选课测试`，默认连接真实后端 `https://jcourse.yourtj.de`。
本仓库用于 Android 预发测试，APK 由 GitHub Actions 生成。

## 项目结构

```text
YourTJCourse-Flutter/
├── android/                # Android 原生工程与启动图标
├── assets/                 # 应用资源
│   └── images/             # Logo 等图片资源
├── lib/
│   ├── core/               # 配置、网络、存储等基础能力
│   ├── domain/             # 课程、评价、设置等领域模型与仓库
│   ├── features/           # 页面功能
│   │   ├── catalog/        # 查课
│   │   ├── course_detail/  # 课程详情、评课与选课评价入口
│   │   ├── scheduler/      # 培养方案查课与模拟排课
│   │   └── settings/       # 设置
│   └── shared/             # 复用 UI 状态组件
├── test/                   # 单元测试与 Widget 测试
└── .github/workflows/      # CI/CD
    └── android-test.yml    # Android 测试 APK 预发包
```

## 技术栈

| 层 | 技术 |
|---|------|
| 客户端 | Flutter, Dart |
| 状态管理 | Riverpod |
| 路由 | go_router |
| 网络 | Dio |
| UI 组件 | lkcn_ui Flutter 组件库 |
| 存储 | shared_preferences, flutter_secure_storage |
| CI/CD | GitHub Actions → Android Debug APK artifact |

## 快速开始

### 环境要求

- Flutter 3.x
- Dart SDK 随 Flutter 提供
- Android SDK（仅本地调试时需要）

本项目默认在 WSL / Linux 环境开发。不要调用 Windows 挂载目录下的 Flutter SDK。

### 安装依赖

```bash
/root/dev/flutter/bin/flutter --no-version-check pub get
```

### 本地检查

```bash
/root/dev/flutter/bin/dart format lib test
/root/dev/flutter/bin/flutter --no-version-check analyze
/root/dev/flutter/bin/flutter --no-version-check test
```

### Android 预发包

本地不要求编译 APK。

进入 GitHub Actions，运行 `Android Test APK`，在 Artifacts 下载
`yourtjcourse-flutter-debug-apk` 后安装测试。

## 开发流程

```text
feature/fix branch ──→ PR ──→ dev ───→ 生成预发测试 APK
                           ↑              │
                       PR Checks          │ 经测试后
                      (analyze           ▼
                       + test)     PR ──→ main
```

### 日常开发

1. 从 `dev` 创建功能分支：`git checkout -b fix/xxx dev`
2. 开发 → commit → push
3. 开 Pull Request 到 `dev`
4. Review 通过后 merge 到 `dev`
5. 通过 `Android Test APK` 下载预发包，在真机上验证

### 当前测试范围

- 查课：课程列表、筛选、课程详情
- 评课：课程评价展示与提交相关入口
- 选课：通过 PK 课程数据查看教学班信息
- 模拟排课：按培养方案、搜索、时间段查课并加入模拟课表

钱包功能暂不纳入本测试版跟进范围。

## 文档

- 后端与接口规范以 `YourTJCourse-Serverless` 为准
- 默认 API 地址：`https://jcourse.yourtj.de`
- 排课接口沿用 Serverless PK API：
  - `GET /api/getAllCalendar`
  - `POST /api/findGradeByCalendarId`
  - `POST /api/findMajorByGrade`
  - `POST /api/findCourseByMajor`
  - `POST /api/findOptionalCourseType`
  - `POST /api/findCourseBySearch`
  - `POST /api/findCourseByTime`

## 贡献

1. Fork 本仓库
2. 创建功能分支：`git checkout -b fix/your-fix-name`
3. 提交更改：遵循 `Conventional Commits`（约定式提交）格式
   - `fix(scope): description` — Bug 修复
   - `feat(scope): description` — 新功能
   - `docs(scope): description` — 文档更新
   - `chore(scope): description` — 构建、CI 等杂项
4. 推送并创建 Pull Request

### Commit 规范

- scope: `app`, `catalog`, `course`, `scheduler`, `settings`, `ci`, `docs`
- 使用英文，祈使语气
- 每个 commit 只做一件事

### Issue 标签

| 标签 | 含义 |
|------|------|
| `area:app` | Flutter 应用基础能力 |
| `area:catalog` | 查课 |
| `area:course` | 课程详情 / 评课 |
| `area:scheduler` | 选课 / 模拟排课 |
| `area:ci` | CI/CD 工作流 |
| `severity:critical` | 数据丢失 / 安全漏洞 / 服务中断 |
| `severity:high` | 功能不可用 / 严重影响用户体验 |
| `severity:medium` | 体验降级 / 非关键功能异常 |
| `severity:low` | 轻微 / 优化 / 未来改进 |

## 许可

本项目仅供学习和研究使用。
