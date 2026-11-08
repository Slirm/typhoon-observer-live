# 台风观察 · Flutter Web / Android

在线网站：<https://slirm.github.io/typhoon-observer-live/>

统一 Flutter 前端，Web 与 Android 共用界面、状态、数据解析和地图。独立整理展示海南气象“南海天气”数据，不代表来源机构。Actions 每15分钟计划采集快照；浏览器读取公开仓库的原始 JSON，不直接请求气象来源。数据更新不需要重新编译或部署网页。

## 数据来源

- 官方公众页面：[南海天气台风路径系统](https://www.scsweather.com/Home/Typhoon)
- 平台介绍：[海南省气象局建设的“南海天气”](https://www.scsweather.com/Home/About)
- 当前页面所用接口：`POST /webApi/GetTyphoonListByYear`、`POST /webApi/GetTyphoonPathById`、`GET /webapi/GetEarlyWarningList?top=5`。
- 这些是公开网页所用接口，不是具有稳定服务承诺的开放 API。数据权利属于来源机构；本项目保留来源与时间，不提供商业转授权承诺。

## 展示规则

- 保留台风名称、编号、中心位置、风力／风速、气压、移向／移速及实况时间；缺失数字显示“—”。
- 只有清单中的活跃台风才作为活跃台风展示；没有活跃台风时展示最近停止编号的历史记录，明确标注历史身份。
- 实况与预报分开；预报仅使用同一个“中国”机构的同一最新起报批次。已停止编号台风不展示后续预报。
- 本版不提供预警或推送；请前往官方原站阅读公报及防御指南。
- 路径坐标来自来源实况；底图使用 Natural Earth 1:50m 全球陆地与真实海岸线，采用 Web Mercator 投影，不绘制行政边界。支持拖动、缩放、完整路径、定位中心与世界视图，不用于导航或精确距离判断。
- 纯 Flutter 地图、本地海岸线与中文字体随网站保存，无外部收费瓦片或地图 API 密钥。资源来源及许可见 [app/assets/README.md](app/assets/README.md)。首次打开需加载 Flutter 引擎、字体与地图，体积大于旧 HTML 版本。

## 自动运行

采集工作流为 `.github/workflows/update-and-deploy.yml`；网站发布工作流为 `.github/workflows/flutter-pages.yml`。

- 每小时第7、22、37、52分钟计划采集，也可手动运行。Flutter 仅在 `app/` 或其发布工作流变化时构建；数据提交不会触发整个网站重新发布。
- GitHub 定时任务可能延迟或丢弃，不承诺准点。公开仓库长时间无活动时定时任务可能停用，应检查 Actions 状态。
- `data/latest.json` 保存最后有效的统一快照，`data/raw/` 保存来源原始清单与选中的台风记录，`data/status.json` 保存同步结果。
- 采集失败保留最后有效快照，保存失败状态并令工作流报错。超过45分钟未成功同步时页面标记过期；活跃台风实况超过12小时也提示核实。
- 页面刷新仅读取公开仓库快照；访客持续打开页面时，每15分钟重新读取。默认数据目录为 `https://raw.githubusercontent.com/Slirm/typhoon-observer-live/main/data/`，Web 与未来 Android 共用。
- 不需要气象 API 密钥，不配置付费服务。标准公共运行器和 Pages 适用免费服务的额度及使用限制。

## 本地运行与验证

需要支持内置 fetch 和 node:test 的 Node.js（建议22及以上）。

```text
node --test tests/*.test.mjs
node scripts/fetch-data.mjs
node scripts/preview-flutter.mjs
```

先按 [Flutter 工程说明](app/README.md) 安装 SDK 并构建 Web，再打开预览地址。正式 Pages 使用 `/typhoon-observer-live/` 作为构建 base href。Android 工程已保留，本轮没有构建 APK。根目录旧 HTML 仅保留作回退参考，正式部署使用 `app/build/web/`。

重要天气判断请使用当地气象部门官方渠道。本项目不是官方预警发布系统。
