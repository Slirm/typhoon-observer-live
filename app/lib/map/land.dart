import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data/typhoon.dart';

class LandShape {
  const LandShape(this.points, this.holes);
  final List<LatLng> points;
  final List<List<LatLng>> holes;
}

List<LandShape> parseLand(Map<String, dynamic> data) {
  if (data['type'] != 'FeatureCollection' ||
      data['features'] is! List ||
      (data['features'] as List).isEmpty) {
    throw const FormatException('Invalid land geometry');
  }
  List<LatLng> ring(Object? raw) {
    if (raw is! List || raw.length < 4) {
      throw const FormatException('Invalid land ring');
    }
    return raw
        .map((item) {
          if (item is! List ||
              item.length < 2 ||
              item[0] is! num ||
              item[1] is! num) {
            throw const FormatException('Invalid land coordinates');
          }
          final lon = (item[0] as num).toDouble(),
              lat = (item[1] as num).toDouble();
          if (!lat.isFinite ||
              !lon.isFinite ||
              lat.abs() > 90 ||
              lon.abs() > 180) {
            throw const FormatException('Invalid land coordinates');
          }
          return LatLng(lat, lon);
        })
        .toList(growable: false);
  }

  final result = <LandShape>[];
  for (final feature in data['features'] as List) {
    final geometry = object(object(feature)['geometry']);
    final coords = geometry['coordinates'];
    if (coords is! List ||
        !['Polygon', 'MultiPolygon'].contains(geometry['type'])) {
      throw const FormatException('Invalid land polygons');
    }
    final polygons = geometry['type'] == 'Polygon' ? [coords] : coords;
    for (final polygon in polygons) {
      if (polygon is! List || polygon.isEmpty) {
        throw const FormatException('Invalid land polygon');
      }
      result.add(
        LandShape(
          ring(polygon.first),
          polygon.skip(1).map(ring).toList(growable: false),
        ),
      );
    }
  }
  return result;
}

List<List<LatLng>> splitTrack(List<TrackPoint> points) {
  if (points.isEmpty) return [];
  final segments = <List<LatLng>>[];
  var current = <LatLng>[LatLng(points.first.latitude, points.first.longitude)];
  for (var i = 1; i < points.length; i++) {
    final previous = points[i - 1], next = points[i];
    final delta = next.longitude - previous.longitude;
    if (delta.abs() <= 180) {
      current.add(LatLng(next.latitude, next.longitude));
      continue;
    }
    final shortDelta = delta > 180 ? delta - 360 : delta + 360;
    if (shortDelta == 0) {
      current.add(LatLng(next.latitude, previous.longitude));
    } else {
      final boundary = shortDelta > 0 ? 180.0 : -180.0;
      final fraction = (boundary - previous.longitude) / shortDelta;
      final latitude =
          previous.latitude + (next.latitude - previous.latitude) * fraction;
      if (current.last.longitude != boundary ||
          current.last.latitude != latitude) {
        current.add(LatLng(latitude, boundary));
      }
      if (current.length > 1) segments.add(current);
      current = [
        LatLng(latitude, -boundary),
        LatLng(next.latitude, next.longitude),
      ];
      continue;
    }
    if (current.length > 1) segments.add(current);
    current = [LatLng(next.latitude, next.longitude)];
  }
  if (current.length > 1) segments.add(current);
  return segments;
}

final worldBounds = LatLngBounds(
  const LatLng(-85.0511, -179.9),
  const LatLng(85.0511, 179.9),
);
LatLngBounds boundsForStorm(Storm storm, {required bool includeForecast}) =>
    LatLngBounds.fromPoints([
      const LatLng(18, 108),
      const LatLng(36, 123),
      ...[
        ...storm.observations,
        ...(includeForecast && !storm.ended ? storm.forecast : <TrackPoint>[]),
      ].map((point) => LatLng(point.latitude, point.longitude)),
    ]);
