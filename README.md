# 台风观察 · 海南气象数据

在线网站：<https://slirm.github.io/typhoon-observer-live/>

独立整理展示海南气象“南海天气”台风路径页面的数据，不代表来源机构。每15分钟由 GitHub Actions 采集并保存快照，再明确部署到 GitHub Pages；浏览器只读取本站快照，不直接请求气象来源。

## 数据来源

- 官方公众页面：[南海天气台风路径系统](https://www.scsweather.com/Home/Typhoon)
- 平台介绍：[海南省气象局建设的“南海天气”](https://www.scsweather.com/Home/About)
- 当前页面所用接口：`POST /webApi/GetTyphoonListByYear`、`POST /webApi/GetTyphoonPathById`、`GET /webapi/GetEarlyWarningList?top=5`。
- 这些是公开网页所用接口，不是具有稳定服务承诺的开放 API。数据权利属于来源机构；本项目保留来源与时间，不提供商业转授权承诺。

## 展示规则

- 保留台风名称、编号、中心位置、风力／风速、气压、移向／移速及实况时间；缺失数字显示“—”。
- 只有清单中的活跃台风才作为活跃台风展示；没有活跃台风时展示最近停止编号的历史记录，明确标注历史身份。
- 实况与预报分开；预报仅使用同一个“中国”机构的同一最新起报批次。已停止编号台风不展示后续预报。
- 最近5条预警公报不是完整地区有效预警列表。空列表或接口失败均不代表没有预警；请前往官方原站阅读完整公报及防御指南。
- 路径坐标来自来源实况；底图使用 Natural Earth 1:50m 全球陆地与真实海岸线，采用 Web Mercator 投影，不绘制行政边界。支持拖动、缩放、完整路径、定位中心与世界视图，不用于导航或精确距离判断。
- 地图数据和 Leaflet 1.9.4 随网站保存，无外部瓦片、地图 API 密钥或地图调用费用。来源及许可见 [assets/README.md](assets/README.md)。首次读取全球底图约1.6MB，后续按浏览器缓存复用。

## 自动运行

工作流位于 `.github/workflows/update-and-deploy.yml`。

- 每小时第7、22、37、52分钟运行，也可手动运行；代码推送会触发首次采集与部署。
- GitHub 定时任务可能延迟或丢弃，不承诺准点。公开仓库长时间无活动时定时任务可能停用，应检查 Actions 状态。
- `data/latest.json` 保存最后有效的统一快照，`data/raw/` 保存来源原始清单与选中的台风记录，`data/status.json` 保存同步结果。
- 采集失败保留最后有效快照，部署失败状态并令工作流报错。超过45分钟未成功同步时页面标记过期；活跃台风实况超过12小时也提示核实。
- 页面刷新仅更新本站快照；访客持续打开页面时，每15分钟重新读取本站 JSON。
- 不需要气象 API 密钥，不配置付费服务。标准公共运行器和 Pages 适用免费服务的额度及使用限制。

## 本地运行与验证

需要支持内置 fetch 和 node:test 的 Node.js（建议22及以上）。

```text
node --test tests/*.test.mjs
node scripts/fetch-data.mjs
node scripts/serve.mjs
```

然后打开终端给出的本地地址。通过 HTTP 服务读取 JSON，不再使用离线演示数据。

重要天气判断请使用当地气象部门官方渠道。本项目不是官方预警发布系统。
