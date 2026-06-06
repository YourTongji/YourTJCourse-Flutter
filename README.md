# YourTJCourse-Flutter

YourTJ 选课社区 Flutter 客户端测试版，当前只生成 Android APK 供手机预发测试。

## 开发约定

- 不提交真实密钥，`.env` 只保留公开默认地址。
- 页面级网络请求使用 Riverpod `autoDispose` 绑定 Dio `CancelToken`，路由退出后请求会被取消。
- 本地不要求编译 APK，预发包由 GitHub Actions 的 `Android Test APK` 生成。

## CI 产物

进入 GitHub Actions，运行 `Android Test APK`，在 Artifacts 下载 `yourtjcourse-flutter-debug-apk` 即可安装测试。
