import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:typhoon_observer/dashboard.dart';
import 'package:typhoon_observer/dashboard_model.dart';
import 'package:typhoon_observer/data/repository.dart';
import 'package:typhoon_observer/theme.dart';

import 'fixtures.dart';
import 'data_test.dart' show MemoryStore;

void main() {
  for (final width in [360.0, 390.0, 768.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'dashboard has no overflow at width=$width and text scale=$scale',
        (tester) async {
          tester.view.devicePixelRatio = 2;
          tester.view.physicalSize = Size(width * 2, 2000);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          final model = DashboardModel(
            repository: TyphoonRepository(
              store: MemoryStore(),
              client: MockClient(
                (request) async => http.Response(
                  jsonEncode(
                    request.url.path.endsWith('status.json')
                        ? healthJson()
                        : snapshotJson(ended: true),
                  ),
                  200,
                  headers: jsonHeaders,
                ),
              ),
            ),
            clock: () => DateTime.utc(2026, 11, 8, 10, 5),
          );
          await model.refresh();
          await tester.pumpWidget(
            MaterialApp(
              theme: buildTheme(),
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 1000),
                  textScaler: TextScaler.linear(scale),
                ),
                child: DashboardScreen(
                  model: model,
                  mapOverride: const ColoredBox(color: Colors.blueGrey),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('烟花'), findsWidgets);
          expect(find.text('历史台风'), findsWidgets);
          expect(find.text('预警'), findsNothing);
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
        },
      );
    }
  }
  testWidgets(
    'an empty feed explains the absence of records and offers retry',
    (tester) async {
      final data = snapshotJson()
        ..['storms'] = []
        ..['activeCount'] = 0;
      final model = DashboardModel(
        repository: TyphoonRepository(
          store: MemoryStore(),
          client: MockClient(
            (request) async => http.Response(
              jsonEncode(
                request.url.path.endsWith('status.json') ? healthJson() : data,
              ),
              200,
              headers: jsonHeaders,
            ),
          ),
        ),
        clock: () => DateTime.utc(2026, 11, 8, 10, 5),
      );
      await model.refresh();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: DashboardScreen(model: model, mapOverride: const SizedBox()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('暂无可展示的台风记录'), findsOneWidget);
      expect(find.byTooltip('刷新数据快照'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
    },
  );
}
