const officialSourceUrl = 'https://www.scsweather.com/Home/Typhoon';
const snapshotBaseUrl =
    'https://raw.githubusercontent.com/Slirm/typhoon-observer-live/main/data/';

Map<String, dynamic> object(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Expected an object');
  }
  return value;
}

DateTime utcTime(Object? value) {
  if (value is! String ||
      !RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?Z$')
          .hasMatch(value)) {
    throw const FormatException('Expected a UTC timestamp');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null ||
      parsed.year != int.parse(value.substring(0, 4)) ||
      parsed.month != int.parse(value.substring(5, 7)) ||
      parsed.day != int.parse(value.substring(8, 10)) ||
      parsed.hour != int.parse(value.substring(11, 13)) ||
      parsed.minute != int.parse(value.substring(14, 16)) ||
      parsed.second != int.parse(value.substring(17, 19))) {
    throw const FormatException('Invalid timestamp');
  }
  return parsed.toUtc();
}

num? _number(Object? value, num min, num max) {
  if (value == null) return null;
  if (value is! num || !value.isFinite || value < min || value > max) {
    throw const FormatException('Invalid number');
  }
  return value;
}

class TrackPoint {
  const TrackPoint({
    required this.time,
    required this.longitude,
    required this.latitude,
    this.windPower,
    this.windSpeed,
    this.pressure,
    this.moveDirection,
    this.moveSpeed,
  });
  final DateTime time;
  final double longitude, latitude;
  final num? windPower, windSpeed, pressure, moveSpeed;
  final String? moveDirection;
  factory TrackPoint.fromJson(Map<String, dynamic> data) {
    final lon = _number(data['longitude'], -180, 180),
        lat = _number(data['latitude'], -90, 90);
    if (lon == null || lat == null) {
      throw const FormatException('Missing coordinates');
    }
    return TrackPoint(
      time: utcTime(data['time']),
      longitude: lon.toDouble(),
      latitude: lat.toDouble(),
      windPower: _number(data['windPower'], 0, 25),
      windSpeed: _number(data['windSpeed'], 0, 150),
      pressure: _number(data['pressure'], 500, 1100),
      moveSpeed: _number(data['moveSpeed'], 0, 300),
      moveDirection: data['moveDirection'] is String
          ? data['moveDirection'] as String
          : null,
    );
  }
}

List<TrackPoint> _points(Object? value, {bool required = false}) {
  if (value is! List || value.length > 5000 || (required && value.isEmpty)) {
    throw const FormatException('Invalid track');
  }
  final points = value
      .map((row) => TrackPoint.fromJson(object(row)))
      .toList(growable: false);
  for (var i = 1; i < points.length; i++) {
    if (!points[i].time.isAfter(points[i - 1].time)) {
      throw const FormatException('Track times must increase');
    }
  }
  return List.unmodifiable(points);
}

class Storm {
  const Storm({
    required this.id,
    required this.name,
    required this.english,
    required this.ended,
    required this.observations,
    required this.forecast,
    this.forecastAgency,
    this.forecastIssuedAt,
  });
  final String id, name, english;
  final bool ended;
  final List<TrackPoint> observations, forecast;
  final String? forecastAgency;
  final DateTime? forecastIssuedAt;
  TrackPoint get latest => observations.last;
  factory Storm.fromJson(Map<String, dynamic> data) {
    if (data['id'] is! String ||
        !RegExp(r'^\d{6,8}$').hasMatch(data['id'] as String) ||
        data['name'] is! String ||
        (data['name'] as String).trim().isEmpty ||
        data['ended'] is! bool) {
      throw const FormatException('Invalid storm identity');
    }
    final observations = _points(data['observations'], required: true);
    final forecast = _points(data['forecast'] ?? []);
    final issue = data['forecastIssuedAt'] == null
        ? null
        : utcTime(data['forecastIssuedAt']);
    if (forecast.isNotEmpty &&
        (data['forecastAgency'] != '中国' ||
            issue == null ||
            forecast.any(
              (point) =>
                  !point.time.isAfter(observations.last.time) ||
                  !point.time.isAfter(issue),
            ))) {
      throw const FormatException('Invalid forecast batch');
    }
    return Storm(
      id: data['id'] as String,
      name: data['name'] as String,
      english: data['english'] is String ? data['english'] as String : '',
      ended: data['ended'] as bool,
      observations: observations,
      forecast: forecast,
      forecastAgency: data['forecastAgency'] as String?,
      forecastIssuedAt: issue,
    );
  }
}

class TyphoonSnapshot {
  const TyphoonSnapshot({
    required this.fetchedAt,
    required this.activeCount,
    required this.storms,
  });
  final DateTime fetchedAt;
  final int activeCount;
  final List<Storm> storms;
  factory TyphoonSnapshot.fromJson(Map<String, dynamic> data) {
    if (data['schemaVersion'] != 1 ||
        data['storms'] is! List ||
        data['activeCount'] is! int) {
      throw const FormatException('Invalid snapshot');
    }
    final storms = (data['storms'] as List)
        .map((row) => Storm.fromJson(object(row)))
        .toList(growable: false);
    final activeCount = data['activeCount'] as int;
    if (storms.length > 20 ||
        activeCount < 0 ||
        activeCount != storms.where((storm) => !storm.ended).length ||
        storms.map((storm) => storm.id).toSet().length != storms.length) {
      throw const FormatException('Inconsistent storm list');
    }
    final fetchedAt = utcTime(data['fetchedAt']);
    final latestAllowed = fetchedAt.add(const Duration(minutes: 5));
    if (storms.any(
      (storm) =>
          storm.latest.time.isAfter(latestAllowed) ||
          (storm.forecastIssuedAt?.isAfter(latestAllowed) ?? false),
    )) {
      throw const FormatException(
        'Observation or forecast issue is after collection',
      );
    }
    return TyphoonSnapshot(
      fetchedAt: fetchedAt,
      activeCount: activeCount,
      storms: List.unmodifiable(storms),
    );
  }
}

class SyncHealth {
  const SyncHealth({required this.ok, this.lastAttemptAt, this.lastSuccessAt});
  final bool ok;
  final DateTime? lastAttemptAt, lastSuccessAt;
  factory SyncHealth.fromJson(Map<String, dynamic> data) {
    if (data['ok'] is! bool) throw const FormatException('Invalid sync state');
    return SyncHealth(
      ok: data['ok'] as bool,
      lastAttemptAt: data['lastAttemptAt'] == null
          ? null
          : utcTime(data['lastAttemptAt']),
      lastSuccessAt: data['lastSuccessAt'] == null
          ? null
          : utcTime(data['lastSuccessAt']),
    );
  }
}

String coordinateText(double value, {required bool latitude}) =>
    '${value.abs().toStringAsFixed(1)}°${latitude ? (value < 0 ? 'S' : 'N') : (value < 0 ? 'W' : 'E')}';

String numberText(num? value) => value == null
    ? '—'
    : value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();
String beijingTime(DateTime? value, {bool withYear = false}) {
  if (value == null) return '未提供';
  final time = value.toUtc().add(const Duration(hours: 8));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${withYear ? '${time.year}/' : ''}${two(time.month)}/${two(time.day)} ${two(time.hour)}:${two(time.minute)}';
}

String intensity(num? wind) => wind == null
    ? '强度未提供'
    : wind >= 16
    ? '超强台风'
    : wind >= 14
    ? '强台风'
    : wind >= 12
    ? '台风'
    : wind >= 10
    ? '强热带风暴'
    : wind >= 8
    ? '热带风暴'
    : '热带低压';
