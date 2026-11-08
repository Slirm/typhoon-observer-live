import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:typhoon_observer/map/track_map.dart';
import 'package:typhoon_observer/theme.dart';
import 'package:typhoon_observer/data/typhoon.dart';
import 'package:typhoon_observer/map/land.dart';

import 'fixtures.dart';

void main() {
  test('wide world view includes the full Mercator latitude range', () {
    final camera = MapCamera(
      crs: const SingleWorldMercator(),
      center: const LatLng(0, 0),
      zoom: 1,
      rotation: 0,
      nonRotatedSize: const Size(1044, 540),
      minZoom: 0,
      maxZoom: 7,
    );
    final fitted = CameraFit.bounds(
      bounds: worldBounds,
      padding: const EdgeInsets.all(22),
      minZoom: 0,
    ).fit(camera);
    expect(fitted.visibleBounds.south, lessThanOrEqualTo(-85));
    expect(fitted.visibleBounds.north, greaterThanOrEqualTo(85));
  });
  test('dateline crossings are split at the boundary in either direction', () {
    final east = [
      TrackPoint.fromJson(pointJson('2026-11-08T06:00:00.000Z', 179, 10)),
      TrackPoint.fromJson(pointJson('2026-11-08T09:00:00.000Z', -179, 12)),
    ];
    final segments = splitTrack(east);
    expect(segments, hasLength(2));
    expect(segments.first.last.longitude, 180);
    expect(segments.last.first.longitude, -180);
    expect(segments.first.last.latitude, 11);
    for (final segment in [
      ...segments,
      ...splitTrack(east.reversed.toList()),
    ]) {
      for (var i = 1; i < segment.length; i++) {
        expect(
          (segment[i].longitude - segment[i - 1].longitude).abs(),
          lessThanOrEqualTo(180),
        );
      }
    }
  });
  testWidgets(
    'real Flutter map fits the whole world on a narrow screen with large text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final storm = TyphoonSnapshot.fromJson(snapshotJson()).storms.single;
      Widget page(int selected) => MaterialApp(
        theme: buildTheme(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 1000),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: TrackMap(
                storm: storm,
                showForecast: true,
                selectedIndex: selected,
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(page(1));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('世界视图'));
      await tester.pumpAndSettle();
      final controller = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      expect(controller.camera.visibleBounds.west, lessThanOrEqualTo(-179));
      expect(controller.camera.visibleBounds.east, greaterThanOrEqualTo(179));
      expect(controller.camera.visibleBounds.south, lessThanOrEqualTo(-85));
      expect(controller.camera.visibleBounds.north, greaterThanOrEqualTo(85));
      final center = controller.camera.center, zoom = controller.camera.zoom;
      await tester.pumpWidget(page(0));
      await tester.pumpAndSettle();
      expect(controller.camera.center, center);
      expect(controller.camera.zoom, zoom);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  test('bundled land is genuine global geometry with valid latitude/longitude order', () async {
    final geometry = parseLand(
      jsonDecode(await File('assets/maps/ne_50m_land.geojson').readAsString())
          as Map<String, dynamic>,
    );
    expect(geometry.length, greaterThan(1000));
    final points = geometry.expand((polygon) => polygon.points);
    expect(points.any((point) => point.longitude < -170), isTrue);
    expect(points.any((point) => point.longitude > 170), isTrue);
    expect(
      points.every(
        (point) => point.latitude.abs() <= 90 && point.longitude.abs() <= 180,
      ),
      isTrue,
    );
  });
  test('map bounds contain actual path and the China coast, world bounds fit globally', () {
    final storm = TyphoonSnapshot.fromJson(snapshotJson()).storms.single;
    final bounds = boundsForStorm(storm, includeForecast: true);
    expect(bounds.west, lessThanOrEqualTo(108));
    expect(bounds.east, greaterThanOrEqualTo(127));
    expect(bounds.south, lessThanOrEqualTo(18));
    expect(worldBounds.east - worldBounds.west, greaterThan(350));
  });
  test('malformed land does not masquerade as an empty working basemap', () {
    expect(() => parseLand({'type': 'error'}), throwsFormatException);
    expect(
      () => parseLand({'type': 'FeatureCollection', 'features': []}),
      throwsFormatException,
    );
  });
}
