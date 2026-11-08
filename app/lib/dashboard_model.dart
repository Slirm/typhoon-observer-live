import 'package:flutter/foundation.dart';

import 'data/repository.dart';
import 'data/typhoon.dart';

class DashboardModel extends ChangeNotifier {
  DashboardModel({required this.repository, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;
  final TyphoonRepository repository;
  final DateTime Function() _clock;
  TyphoonSnapshot? snapshot;
  SyncHealth? health;
  bool loading = false, readFailed = false, showForecast = false;
  String? errorMessage, _stormId;
  int selectedIndex = 0;
  bool _disposed = false;
  Storm? get storm {
    final storms = snapshot?.storms;
    if (storms == null || storms.isEmpty) return null;
    return storms.where((item) => item.id == _stormId).firstOrNull ??
        storms.first;
  }

  bool get forecastAllowed =>
      storm != null && !storm!.ended && storm!.forecast.isNotEmpty;
  List<TrackPoint> get points => storm == null
      ? []
      : [
          ...storm!.observations,
          ...(showForecast ? storm!.forecast : <TrackPoint>[]),
        ];
  TrackPoint? get selectedPoint =>
      points.isEmpty ? null : points[selectedIndex.clamp(0, points.length - 1)];
  bool get selectedIsForecast =>
      storm != null && selectedIndex >= storm!.observations.length;
  DateTime? get lastSuccess => health?.lastSuccessAt ?? snapshot?.fetchedAt;
  bool get isStale {
    final now = _clock().toUtc();
    if (snapshot == null) return true;
    final success = lastSuccess!;
    return readFailed ||
        health?.ok != true ||
        now.difference(success) > const Duration(minutes: 45) ||
        success.difference(now) > const Duration(minutes: 5) ||
        now.difference(snapshot!.fetchedAt) > const Duration(minutes: 45) ||
        snapshot!.fetchedAt.difference(now) > const Duration(minutes: 5) ||
        snapshot!.storms.any(
          (item) =>
              item.latest.time.difference(now) > const Duration(minutes: 5) ||
              (!item.ended &&
                  now.difference(item.latest.time) > const Duration(hours: 12)),
        );
  }

  String get statusTitle => snapshot == null
      ? '暂时无法读取数据'
      : isStale
      ? '数据需要核实'
      : snapshot!.activeCount > 0
      ? '正在追踪 ${snapshot!.activeCount} 个活跃台风'
      : '暂无活跃台风';
  String get statusDescription => readFailed
      ? '无法取得新快照，当前保留上次有效记录，请核对数据时间。'
      : isStale
      ? '同步状态异常或数据已过期，请到官方来源核实。'
      : snapshot!.activeCount == 0
      ? '下方展示最近结束台风的历史记录。'
      : '实况和预报以来源发布时间为准。';

  Future<void> refresh() async {
    if (loading || _disposed) return;
    loading = true;
    notifyListeners();
    final oldId = storm?.id, oldTime = selectedPoint?.time;
    try {
      final result = await repository.load();
      if (_disposed) return;
      snapshot = result.snapshot;
      health = result.health;
      readFailed = result.fromCache;
      errorMessage = result.fromCache ? '网络读取失败，已保留有效缓存。' : null;
      _stormId = storm?.id;
      showForecast =
          forecastAllowed && (oldId == _stormId ? showForecast : true);
      final previous = oldId == _stormId && oldTime != null
          ? points.indexWhere((point) => point.time == oldTime)
          : -1;
      selectedIndex = previous >= 0
          ? previous
          : (storm?.observations.length ?? 1) - 1;
    } catch (_) {
      if (_disposed) return;
      readFailed = true;
      errorMessage = '暂时无法读取数据，请检查网络后重试。';
    } finally {
      if (!_disposed) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void selectStorm(String id) {
    if (snapshot?.storms.any((item) => item.id == id) != true) return;
    _stormId = id;
    showForecast = forecastAllowed;
    selectedIndex = storm!.observations.length - 1;
    notifyListeners();
  }

  void selectPoint(int index) {
    if (index < 0 || index >= points.length) return;
    selectedIndex = index;
    notifyListeners();
  }

  void toggleForecast(bool show) {
    showForecast = show && forecastAllowed;
    if (selectedIndex >= points.length) selectedIndex = points.length - 1;
    notifyListeners();
  }

  void recheckTime() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    repository.close();
    super.dispose();
  }
}
