# 共享地图与字体资源

- `maps/ne_50m_land.geojson`：复制自项目已核实的 Natural Earth 1:50m 全球陆地原文件，公共领域。来源及说明见根目录 `assets/README.md`。不绘制行政边界，无外部地图瓦片服务。
- `fonts/NotoSansSC-Regular.otf`：Noto Sans SC 简体中文字体，Web/Android 共用相同字形资源；避免浏览器首次打开时依赖远程中文字体。
  - 源文件：https://github.com/notofonts/noto-cjk/blob/main/Sans/SubsetOTF/SC/NotoSansSC-Regular.otf
  - SIL Open Font License 1.1，完整许可为 `fonts/OFL.txt`。

地图使用区域级自然地理数据，不适合街道导航。字体和底图均随 Flutter 资产打包。
