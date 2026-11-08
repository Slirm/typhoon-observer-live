import 'dart:async';

import 'package:flutter/material.dart';

import 'dashboard_model.dart';
import 'data/typhoon.dart';
import 'links.dart';
import 'map/track_map.dart';
import 'theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.model, this.mapOverride});
  final DashboardModel model;
  final Widget? mapOverride;
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  Timer? _clockTimer, _refreshTimer;
  bool _foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clockTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => widget.model.recheckTime(),
    );
    _refreshTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      if (_foreground) widget.model.refresh();
    });
    if (widget.model.snapshot == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.model.refresh();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      final last = widget.model.lastSuccess;
      if (last == null ||
          DateTime.now().toUtc().difference(last) >
              const Duration(minutes: 15)) {
        widget.model.refresh();
      } else {
        widget.model.recheckTime();
      }
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListenableBuilder(
        listenable: widget.model,
        builder: (context, _) => LayoutBuilder(
          builder: (context, constraints) {
            final model = widget.model, storm = model.storm;
            final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
            final wide = constraints.maxWidth >= 1100 && scale < 1.5;
            return SingleChildScrollView(
              key: const PageStorageKey('dashboard-scroll'),
              child: Column(
                children: [
                  _header(context, constraints.maxWidth),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1520),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          constraints.maxWidth < 600 ? 16 : 32,
                          28,
                          constraints.maxWidth < 600 ? 16 : 32,
                          24,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '台风实况',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w600,
                                    color: Palette.ink,
                                  ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              '查看中心位置、风力与移动方向，追踪每一次变化。',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 22),
                            _status(context, model),
                            const SizedBox(height: 20),
                            if (storm != null) ...[
                              _stormSummary(context, model, storm),
                              const SizedBox(height: 22),
                              if (wide)
                                Row(
                                  key: const ValueKey('wide-layout'),
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _mapSection(context, model, storm),
                                    ),
                                    const SizedBox(width: 22),
                                    SizedBox(
                                      width: 310,
                                      child: _details(context, model),
                                    ),
                                  ],
                                )
                              else
                                Column(
                                  key: const ValueKey('narrow-layout'),
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _mapSection(context, model, storm),
                                    const SizedBox(height: 20),
                                    _details(context, model),
                                  ],
                                ),
                            ] else
                              _empty(context, model),
                            const SizedBox(height: 26),
                            const Divider(),
                            const SizedBox(height: 16),
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              spacing: 24,
                              runSpacing: 8,
                              children: [
                                Text(
                                  '台风观察 · 海南气象数据',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                Text(
                                  '非官方整理展示 · 所有时间均为北京时间',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );

  Widget _header(BuildContext context, double width) => Container(
    width: double.infinity,
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: Palette.line)),
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: width.clamp(0.0, 1520.0),
          maxWidth: 1520,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: width < 600 ? 16 : 32,
            vertical: 16,
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cyclone_outlined,
                    color: Palette.amber,
                    size: 34,
                  ),
                  const SizedBox(width: 10),
                  Text('台风观察', style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  IconButton(
                    onPressed: () => _about(context),
                    tooltip: '数据来源与说明',
                    icon: const Icon(Icons.info_outline, size: 22),
                  ),
                  Tooltip(
                    message: '刷新数据快照',
                    child: FilledButton.icon(
                      onPressed: widget.model.loading
                          ? null
                          : widget.model.refresh,
                      icon: widget.model.loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh, size: 18),
                      label: Text(widget.model.loading ? '读取中…' : '刷新快照'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _status(BuildContext context, DashboardModel model) {
    final initial = model.snapshot == null;
    final uncertain = !initial && model.isStale;
    final color = uncertain || model.readFailed ? Palette.amber : Palette.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: uncertain || model.readFailed
            ? const Color(0xfffff3e8)
            : const Color(0xffeaf3f6),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: uncertain || model.readFailed
              ? const Color(0xffe8c8a8)
              : const Color(0xffc6dde4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3, right: 12),
            child: Icon(
              uncertain || model.readFailed ? Icons.info_outline : Icons.radar,
              size: 20,
              color: color,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  liveRegion: true,
                  child: Text(
                    initial && model.loading ? '正在读取来源快照' : model.statusTitle,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  initial
                      ? (model.errorMessage ?? '稍候即可查看台风实况与路径。')
                      : model.statusDescription,
                  style: TextStyle(fontSize: 12, height: 1.6, color: color),
                ),
                if (!initial) ...[
                  const SizedBox(height: 7),
                  Text(
                    '最近成功同步：${beijingTime(model.lastSuccess, withYear: true)}',
                    style: TextStyle(fontSize: 11, height: 1.7, color: color),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stormSummary(
    BuildContext context,
    DashboardModel model,
    Storm storm,
  ) => Card(
    semanticContainer: false,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(18),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final picker = Row(
                children: [
                  const Icon(
                    Icons.cyclone_outlined,
                    size: 19,
                    color: Palette.muted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: storm.id,
                        isExpanded: true,
                        menuMaxHeight: 360,
                        items: model.snapshot!.storms
                            .map(
                              (item) => DropdownMenuItem(
                                value: item.id,
                                child: Text(
                                  '${item.name} · ${item.id}${item.ended ? '（历史）' : ''}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: model.loading
                            ? null
                            : (id) {
                                if (id != null) model.selectStorm(id);
                              },
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              );
              final source = TextButton.icon(
                onPressed: () => openExternal(context, officialSourceUrl),
                icon: const Icon(Icons.open_in_new, size: 14),
                label: const Text(
                  '海南气象 · 南海天气',
                  style: TextStyle(fontSize: 12),
                ),
              );
              return constraints.maxWidth > 650
                  ? Row(
                      children: [
                        SizedBox(width: 320, child: picker),
                        const Spacer(),
                        Flexible(child: source),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        picker,
                        Align(alignment: Alignment.centerLeft, child: source),
                      ],
                    );
            },
          ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 9,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                storm.name,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              if (storm.english.isNotEmpty)
                Text(
                  storm.english,
                  style: const TextStyle(fontSize: 13, color: Palette.muted),
                ),
              _tag(
                storm.ended ? '历史台风' : '活跃台风',
                storm.ended ? Palette.muted : Palette.blue,
              ),
              _tag(intensity(storm.latest.windPower), Palette.amber),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
          child: Text(
            storm.ended
                ? '此台风已停止编号，以下为来源保存的历史记录。'
                : '当前展示来源最近发布的实况；影响范围请核对官方信息。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
              final columns = (constraints.maxWidth / (140 * scale))
                  .floor()
                  .clamp(1, 4);
              final width = constraints.maxWidth / columns;
              final point = storm.latest;
              return Wrap(
                runSpacing: 20,
                children: [
                  _metric(
                    context,
                    width,
                    '中心位置',
                    '${coordinateText(point.latitude, latitude: true)} / ${coordinateText(point.longitude, latitude: false)}',
                    storm.ended ? '最后实况位置' : '来源最新实况位置',
                    compact: true,
                  ),
                  _metric(
                    context,
                    width,
                    '中心附近最大风力',
                    '${numberText(point.windPower)} 级',
                    '最大风速 ${numberText(point.windSpeed)} 米/秒',
                  ),
                  _metric(
                    context,
                    width,
                    '移动方向',
                    point.moveDirection ?? '未提供',
                    '移速 ${numberText(point.moveSpeed)} 公里/小时',
                  ),
                  _metric(
                    context,
                    width,
                    '中心气压',
                    '${numberText(point.pressure)} 百帕',
                    '实况时次 ${beijingTime(point.time)}',
                    compact: true,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );

  Widget _metric(
    BuildContext context,
    double width,
    String label,
    String value,
    String detail, {
    bool compact = false,
  }) => SizedBox(
    width: width,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 9),
          Text(
            value,
            style: TextStyle(
              fontSize: compact ? 18 : 25,
              fontWeight: FontWeight.w600,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(detail, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );
  Widget _tag(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
    ),
  );

  Widget _mapSection(
    BuildContext context,
    DashboardModel model,
    Storm storm,
  ) => Card(
    semanticContainer: false,
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 14, 12),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('路径追踪', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 5),
                  Text(
                    '${storm.observations.length} 个实况节点 · 真实世界海岸线',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    label: '显示中国机构预报',
                    child: Switch(
                      value: model.showForecast,
                      onChanged: model.forecastAllowed
                          ? model.toggleForecast
                          : null,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      storm.ended ? '历史记录，仅显示实况' : '显示中国机构预报',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              _legend(context, '实况路径', Palette.blue),
              _legend(context, '预报路径', Palette.amber, dashed: true),
              _legend(context, '最新记录中心', Palette.amber, dot: true),
            ],
          ),
        ),
        if (widget.mapOverride case final preview?)
          SizedBox(height: 400, child: preview)
        else
          TrackMap(
            storm: storm,
            showForecast: model.showForecast,
            selectedIndex: model.selectedIndex,
            onSelected: model.selectPoint,
          ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text('选择时间节点', style: Theme.of(context).textTheme.bodySmall),
        ),
        const SizedBox(height: 9),
        TrackTimeline(
          points: model.points,
          selected: model.selectedIndex,
          lastObservation: storm.observations.length - 1,
          onSelect: model.selectPoint,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          child: Text(
            storm.ended
                ? '历史记录不代表当前天气。地图用于区域参考，不用于导航。'
                : '虚线路径为来源预报，起报时间 ${beijingTime(storm.forecastIssuedAt)}。预报可能随后续分析调整。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    ),
  );
  Widget _legend(
    BuildContext context,
    String text,
    Color color, {
    bool dashed = false,
    bool dot = false,
  }) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (dot)
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
        )
      else if (dashed)
        Row(
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.only(right: 3),
                child: SizedBox(
                  width: 5,
                  height: 2,
                  child: ColoredBox(color: color),
                ),
              ),
          ],
        )
      else
        SizedBox(width: 22, height: 2, child: ColoredBox(color: color)),
      const SizedBox(width: 7),
      Text(text, style: Theme.of(context).textTheme.bodySmall),
    ],
  );

  Widget _details(BuildContext context, DashboardModel model) {
    final storm = model.storm!, point = model.selectedPoint!;
    final type = model.selectedIsForecast
        ? '中国机构预报'
        : model.selectedIndex == storm.observations.length - 1
        ? (storm.ended ? '最后实况' : '最新实况')
        : '历史实况';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          semanticContainer: false,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '节点详情',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    _tag(
                      type,
                      model.selectedIsForecast ? Palette.amber : Palette.blue,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  beijingTime(point.time),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '北京时间 · ${point.time.toUtc().add(const Duration(hours: 8)).year}年',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 22),
                const Divider(),
                const SizedBox(height: 18),
                _detail(
                  context,
                  '中心位置',
                  '${coordinateText(point.latitude, latitude: true)}，${coordinateText(point.longitude, latitude: false)}',
                ),
                _detail(context, '最大风力', '${numberText(point.windPower)} 级'),
                _detail(context, '最大风速', '${numberText(point.windSpeed)} 米/秒'),
                _detail(context, '中心气压', '${numberText(point.pressure)} 百帕'),
                if (!model.selectedIsForecast) ...[
                  _detail(context, '移动方向', point.moveDirection ?? '未提供'),
                  _detail(
                    context,
                    '移动速度',
                    '${numberText(point.moveSpeed)} 公里/小时',
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Card(
          semanticContainer: false,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '数据有时间，也有边界',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  '实况时次是来源分析的时间，成功同步是本站取得数据的时间。两者含义不同。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Text(
                  '后台计划每15分钟同步。刷新快照仅读取本站已保存的数据，调度和来源发布可能延迟。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 15),
                TextButton.icon(
                  onPressed: () => _about(context),
                  icon: const Icon(Icons.info_outline, size: 17),
                  label: const Text('查看数据说明'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _detail(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: LayoutBuilder(
      builder: (context, constraints) =>
          MediaQuery.textScalerOf(context).scale(14) > 22
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(value),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 78,
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
    ),
  );

  Widget _empty(BuildContext context, DashboardModel model) => Card(
    semanticContainer: false,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 46),
      child: Column(
        children: [
          Icon(
            model.loading ? Icons.radar : Icons.cloud_outlined,
            size: 42,
            color: Palette.blue,
          ),
          const SizedBox(height: 18),
          Text(
            model.loading
                ? '正在读取台风记录'
                : model.snapshot == null
                ? '数据快照暂不可用'
                : '暂无可展示的台风记录',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Text(
            model.errorMessage ?? '来源本次没有返回可展示的记录，请稍后刷新或查看官方来源。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => openExternal(context, officialSourceUrl),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('查看官方来源'),
          ),
        ],
      ),
    ),
  );

  void _about(BuildContext context) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      scrollable: true,
      title: const Text('数据来源与说明'),
      content: const SizedBox(
        width: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '来源：海南气象 · 南海天气',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 14),
            Text('本站独立整理来源页面的公开台风记录，不代表来源机构。该网页接口没有稳定开放 API 的服务承诺。'),
            SizedBox(height: 12),
            Text(
              '后台计划每15分钟采集。超过45分钟未成功同步，或活跃台风实况超过12小时，页面会提示核实。已停止编号的台风仅作历史资料。',
            ),
            SizedBox(height: 12),
            Text('蓝色实线表示已发布实况，赭色虚线表示同一中国机构最新批次预报。预报不是已经发生的路径。'),
            SizedBox(height: 12),
            Text('断网时可保留有效缓存，缓存不代表新数据。重要天气判断请核对当地气象部门官方渠道。'),
            SizedBox(height: 12),
            Text('地图采用 Natural Earth 1:50m 自然地理海岸线，不绘制行政边界，不用于导航或精确距离判断。'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => openExternal(context, officialSourceUrl),
          child: const Text('打开官方来源'),
        ),
        TextButton(
          onPressed: () =>
              showLicensePage(context: context, applicationName: '台风观察'),
          child: const Text('开源许可'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
}

class TrackTimeline extends StatefulWidget {
  const TrackTimeline({
    super.key,
    required this.points,
    required this.selected,
    required this.lastObservation,
    required this.onSelect,
  });
  final List<TrackPoint> points;
  final int selected, lastObservation;
  final ValueChanged<int> onSelect;
  @override
  State<TrackTimeline> createState() => _TrackTimelineState();
}

class _TrackTimelineState extends State<TrackTimeline> {
  final _scroll = ScrollController();
  double _itemWidth = 128;
  @override
  void initState() {
    super.initState();
    _reveal();
  }

  @override
  void didUpdateWidget(covariant TrackTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected ||
        oldWidget.points.length != widget.points.length) {
      _reveal();
    }
  }

  void _reveal() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && _scroll.hasClients) {
      final target =
          widget.selected * (_itemWidth + 8) -
          _scroll.position.viewportDimension / 2 +
          _itemWidth / 2;
      _scroll.jumpTo(target.clamp(0, _scroll.position.maxScrollExtent));
    }
  });
  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    _itemWidth = 128 * scale.clamp(1, 2);
    return SizedBox(
      height: 72 * scale,
      child: ListView.separated(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: widget.points.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = index == widget.selected;
          return SizedBox(
            width: _itemWidth,
            child: Semantics(
              selected: selected,
              child: OutlinedButton(
                onPressed: () => widget.onSelect(index),
                style: OutlinedButton.styleFrom(
                  backgroundColor: selected
                      ? const Color(0xfffbf1e6)
                      : Colors.white,
                  side: BorderSide(
                    color: selected ? Palette.amber : Palette.line,
                  ),
                  foregroundColor: selected ? Palette.amber : Palette.ink,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      beijingTime(widget.points[index].time),
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      index > widget.lastObservation
                          ? '中国机构预报'
                          : index == widget.lastObservation
                          ? '最新记录'
                          : '历史实况',
                      style: TextStyle(
                        fontSize: 10,
                        color: selected ? Palette.amber : Palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }
}
