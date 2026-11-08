import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:typhoon_observer/dashboard_model.dart';
import 'package:typhoon_observer/data/repository.dart';

import 'fixtures.dart';
import 'data_test.dart' show MemoryStore;

void main() {
  test('a fresh status cannot make an old snapshot appear current', () async {
    final data = snapshotJson()..['fetchedAt'] = '2026-11-08T08:00:00.000Z';
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
    expect(model.isStale, isTrue);
    model.dispose();
  });
  test(
    'old active observations remain uncertain even after a successful sync',
    () async {
      final data = snapshotJson();
      data['storms'][0]['observations'][0]['time'] = '2026-11-07T06:00:00.000Z';
      data['storms'][0]['observations'][1]['time'] = '2026-11-07T09:00:00.000Z';
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
      expect(model.isStale, isTrue);
      model.dispose();
    },
  );
  test('historical storms never show forecast and forecast selection clamps on hiding', () async {
    var ended = false;
    final model = DashboardModel(
      repository: TyphoonRepository(
        store: MemoryStore(),
        client: MockClient(
          (request) async => http.Response(
            jsonEncode(
              request.url.path.endsWith('status.json')
                  ? healthJson()
                  : snapshotJson(ended: ended),
            ),
            200,
            headers: jsonHeaders,
          ),
        ),
      ),
      clock: () => DateTime.utc(2026, 11, 8, 10, 5),
    );
    await model.refresh();
    expect(model.points, hasLength(3));
    model.selectPoint(2);
    expect(model.selectedIsForecast, isTrue);
    model.toggleForecast(false);
    expect(model.selectedIndex, 1);
    expect(model.points, hasLength(2));
    ended = true;
    await model.refresh();
    model.toggleForecast(true);
    expect(model.showForecast, isFalse);
    expect(model.points, hasLength(2));
    model.dispose();
  });
  test(
    'refresh failure stays uncertain through clock ticks until recovery',
    () async {
      var offline = false;
      final model = DashboardModel(
        repository: TyphoonRepository(
          store: MemoryStore(),
          client: MockClient((request) async {
            if (offline) throw http.ClientException('offline');
            return http.Response(
              jsonEncode(
                request.url.path.endsWith('status.json')
                    ? healthJson()
                    : snapshotJson(),
              ),
              200,
              headers: jsonHeaders,
            );
          }),
        ),
        clock: () => DateTime.utc(2026, 11, 8, 10, 5),
      );
      await model.refresh();
      expect(model.isStale, isFalse);
      model.selectPoint(0);
      await model.refresh();
      expect(model.selectedIndex, 0);
      offline = true;
      await model.refresh();
      model.recheckTime();
      expect(model.isStale, isTrue);
      expect(model.readFailed, isTrue);
      expect(model.snapshot!.storms, hasLength(1));
      offline = false;
      await model.refresh();
      expect(model.isStale, isFalse);
      model.dispose();
    },
  );
  test(
    'freshness checks synchronization age and active observation age',
    () async {
      var now = DateTime.utc(2026, 11, 8, 10, 5);
      final model = DashboardModel(
        repository: TyphoonRepository(
          store: MemoryStore(),
          client: MockClient(
            (request) async => http.Response(
              jsonEncode(
                request.url.path.endsWith('status.json')
                    ? healthJson()
                    : snapshotJson(),
              ),
              200,
              headers: jsonHeaders,
            ),
          ),
        ),
        clock: () => now,
      );
      await model.refresh();
      expect(model.isStale, isFalse);
      now = now.add(const Duration(minutes: 46));
      expect(model.isStale, isTrue);
      model.dispose();
    },
  );
}
