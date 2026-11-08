# 共享地图与字体资源

- `maps/ne_50m_land.geojson`：复制自项目已核实的 Natural Earth 1:50m 全球陆地原文件，公共领域。来源及说明见根目录 `assets/README.md`。不绘制行政边界，无外部地图瓦片服务。
- `fonts/NotoSansSC-Regular.otf`：衍生字体 **Typhoon Sans SC Regular**，Web/Android 共用，约2.23MB。为缓存兼容保留既有资源文件名，内部字体名称已更改。包含 GB2312 的6,763个常用汉字、原字体非汉字字符及现有界面/来源文本用字，共9,753个字符；不依赖远程字体完成当前界面显示。
  - 源文件：https://github.com/notofonts/noto-cjk/blob/main/Sans/SubsetOTF/SC/NotoSansSC-Regular.otf
  - SIL Open Font License 1.1，完整许可为 `fonts/OFL.txt`。
  - 未修改的8.33MB上游原字体保存在 `app/tool/fonts/`，不作为运行时资源打包。
  - 安装 `fonttools==4.68.0` 后，在工程根目录运行 `python app/tool/build_ui_font.py` 重新生成。脚本校验当前 Dart 文案、已保存来源名称的字形覆盖及2.5MB启动预算；若加入罕见汉字，可重新生成补充。

地图使用区域级自然地理数据，不适合街道导航。字体和底图均随 Flutter 资产打包。
