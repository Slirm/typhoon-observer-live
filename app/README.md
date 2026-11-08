# 台风观察 · Flutter

Web 与 Android 共用 `lib/` 的界面、状态、数据解析和地图。用户已审核通过 Web 版本并批准发布到既有 GitHub Pages 地址。

## 环境

- 已验证 Flutter **3.47.9** / Dart **3.13.7**。先安装该版本 SDK，将其 `bin` 配置到 PATH，或在以下命令中使用 SDK 的绝对路径。
- Android Studio 打开本目录 `app/`，Flutter SDK 选择自己的安装目录。
- 需要时在当前 PowerShell 会话设置官方文档列出的国内镜像：

```powershell
$env:FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn'
$env:PUB_HOSTED_URL='https://pub.flutter-io.cn'
```

正式锁文件统一使用 `pub.dev`，CI 会严格校验。使用镜像时不要提交本机对锁文件包源地址的改写；准备发布时先移除 `PUB_HOSTED_URL` 覆盖，再运行 `flutter pub get`。

## 开发与检查

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d edge
```

## 构建 Web 审核版

```powershell
flutter build web --release --no-web-resources-cdn --no-wasm-dry-run --base-href /
```

回到项目根目录运行：

```text
node scripts/preview-flutter.mjs
```

访问 <http://127.0.0.1:4190/>。必须通过 HTTP 打开，不能双击构建目录中的 HTML。

预览服务只监听本机；要访问正式网站，请使用项目首页的 GitHub Pages 链接。

默认读取公开仓库 `https://raw.githubusercontent.com/Slirm/typhoon-observer-live/main/data/` 下的 `latest.json` 与 `status.json`；不直接请求气象原站。数据提交无需重新构建网站。可在构建时使用 `--dart-define=DATA_BASE_URL=https://example.com/data/` 指定以斜杠结尾的数据目录。

正式 Pages 构建使用 `--base-href /typhoon-observer-live/`，由 `.github/workflows/flutter-pages.yml` 执行；另一个工作流只采集并提交数据。

## 结构

- `lib/data/`：快照校验、HTTP 读取、持久化与内存缓存。
- `lib/dashboard_model.dart`：刷新、节点选择、历史/预报、数据时效。
- `lib/dashboard.dart`：同一套响应式实况与地图页面。
- `lib/map/`：纯 Flutter 地图、本地海岸线、轨迹和节点。
- `assets/`：地图、中文字体与许可；没有收费地图调用。
- `android/`、`web/`：Flutter 平台工程，业务界面共用。

首版不包含预警、推送或账户功能。Android 工程已生成并包含网络权限，本次没有构建或验证 Android APK。Flutter Web 首次加载包括引擎、中文字体与地图，体积大于原生 HTML 版本。

## 本次验证

审核阶段 `flutter analyze` 无问题，30项 Flutter 测试、22项既有 Node 测试及 Web release 构建通过。布局测试覆盖360、390、768、1440逻辑像素宽度和2倍字体；Edge 已核对桌面和390像素窄屏的真实数据、地图与节点交互。正式发布会重新执行检查并核对线上版本。
