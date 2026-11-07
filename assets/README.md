# 地图资源

底图与地图组件随站点发布，不在访客浏览时请求外部瓦片或地图 API。

- `maps/ne_50m_land.geojson`：Natural Earth 1:50m 全球陆地，多边形包含主要岛屿；2026-11-07 下载，保留源文件。
  - 维护者源文件：https://github.com/nvkelso/natural-earth-vector/blob/master/geojson/ne_50m_land.geojson
  - 数据介绍：https://www.naturalearthdata.com/downloads/50m-physical-vectors/50m-land/
  - 公共领域使用条款：https://www.naturalearthdata.com/about/terms-of-use/
- `vendor/leaflet/leaflet.js`、`leaflet.css`：Leaflet 1.9.4 稳定版，来自 npm 官方包的 unpkg 分发；BSD-2-Clause，许可完整保存在同目录 `LICENSE`。
  - https://unpkg.com/leaflet@1.9.4/dist/leaflet.js
  - https://unpkg.com/leaflet@1.9.4/dist/leaflet.css
  - https://leafletjs.com/reference-1.9.4.html

只绘制自然地理海岸线，不绘制行政边界。底图适合区域级气象参考，不是卫星影像或街道导航地图。交互缩放限制为 0–7 级，允许窄屏完整展示全球，并匹配该数据的区域参考精度。使用 CircleMarker 和 DivIcon，不使用 Leaflet 默认图片图标。
