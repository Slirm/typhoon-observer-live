import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:typhoon_observer/data/typhoon.dart';
import 'package:typhoon_observer/data/repository.dart';

import 'fixtures.dart';

class MemoryStore implements SnapshotStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String data) async {
    value = data;
  }
}

void main() {
  test('coordinates use the correct hemispheres for signed values', () {
    expect(coordinateText(-12.5, latitude: true), '12.5°S');
    expect(coordinateText(-179, latitude: false), '179.0°W');
    expect(coordinateText(22, latitude: true), '22.0°N');
  });
  test('future observations and future forecast issues are rejected before caching', () async {
    final future = snapshotJson();
    future['storms'][0]['observations'][1]['time'] = '2026-11-08T11:00:00.000Z';
    future['storms'][0]['forecast'] = [];
    expect(() => TyphoonSnapshot.fromJson(future), throwsFormatException);
    final issue = snapshotJson();
    issue['storms'][0]['forecastIssuedAt'] = '2026-11-08T10:20:00.000Z';
    expect(() => TyphoonSnapshot.fromJson(issue), throwsFormatException);
    var bad = false;
    final store = MemoryStore();
    final repository = TyphoonRepository(
      store: store,
      client: MockClient(
        (request) async => http.Response(
          jsonEncode(
            request.url.path.endsWith('status.json')
                ? healthJson()
                : bad
                ? future
                : snapshotJson(),
          ),
          200,
          headers: jsonHeaders,
        ),
      ),
    );
    await repository.load();
    final valid = store.value;
    bad = true;
    expect((await repository.load()).fromCache, isTrue);
    expect(store.value, valid);
  });
  test('snapshot reads work as simple cross-origin GET requests', () async {
    final repository = TyphoonRepository(
      store: MemoryStore(),
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.headers.containsKey('cache-control'), isFalse);
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
    );
    expect((await repository.load()).snapshot.storms, hasLength(1));
  });
  test('snapshot preserves actual coordinates, unknown numbers and historical identity', () {
    final data = snapshotJson(ended: true);
    data['storms'][0]['observations'][1]['windSpeed'] = null;
    final snapshot = TyphoonSnapshot.fromJson(data);
    expect(snapshot.storms.single.ended, isTrue);
    expect(snapshot.storms.single.latest.longitude, 125);
    expect(snapshot.storms.single.latest.windSpeed, isNull);
  });
  test('a valid empty snapshot is distinct from malformed input', () {
    final data = snapshotJson()
      ..['storms'] = []
      ..['activeCount'] = 0;
    expect(TyphoonSnapshot.fromJson(data).storms, isEmpty);
    for (final bad in [
      <String, dynamic>{},
      {...data, 'schemaVersion': 9},
      {...data, 'activeCount': 1},
    ]) {
      expect(() => TyphoonSnapshot.fromJson(bad), throwsFormatException);
    }
  });
  test(
    'invalid coordinates, impossible times and repeated points are rejected',
    () {
      final data = snapshotJson();
      data['storms'][0]['observations'][0]['latitude'] = 91;
      expect(() => TyphoonSnapshot.fromJson(data), throwsFormatException);
      final invalidTime = snapshotJson()
        ..['fetchedAt'] = '2026-02-31T10:00:00.000Z';
      expect(
        () => TyphoonSnapshot.fromJson(invalidTime),
        throwsFormatException,
      );
      final repeated = snapshotJson();
      repeated['storms'][0]['observations'][1]['time'] =
          repeated['storms'][0]['observations'][0]['time'];
      expect(() => TyphoonSnapshot.fromJson(repeated), throwsFormatException);
    },
  );
  test('network failure retains the last valid persisted snapshot', () async {
    final store = MemoryStore();
    var offline = false;
    final client = MockClient((request) async {
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
    });
    final repository = TyphoonRepository(client: client, store: store);
    expect((await repository.load()).fromCache, isFalse);
    final saved = store.value;
    offline = true;
    final result = await TyphoonRepository(client: client, store: store).load();
    expect(result.fromCache, isTrue);
    expect(result.snapshot.storms.single.name, '烟花');
    expect(store.value, saved);
  });
  test('malformed successful response cannot replace a valid cache', () async {
    final store = MemoryStore();
    var malformed = false;
    final client = MockClient(
      (request) async => http.Response(
        malformed
            ? '<html>error</html>'
            : jsonEncode(
                request.url.path.endsWith('status.json')
                    ? healthJson()
                    : snapshotJson(),
              ),
        200,
        headers: jsonHeaders,
      ),
    );
    final repository = TyphoonRepository(client: client, store: store);
    await repository.load();
    final saved = store.value;
    malformed = true;
    expect((await repository.load()).fromCache, isTrue);
    expect(store.value, saved);
  });
  test(
    'status failure is visible but does not discard valid storm data',
    () async {
      final repository = TyphoonRepository(
        store: MemoryStore(),
        client: MockClient(
          (request) async => request.url.path.endsWith('status.json')
              ? http.Response('unavailable', 503)
              : http.Response(
                  jsonEncode(snapshotJson()),
                  200,
                  headers: jsonHeaders,
                ),
        ),
      );
      final result = await repository.load();
      expect(result.fromCache, isFalse);
      expect(result.health, isNull);
      expect(result.snapshot.storms, hasLength(1));
    },
  );
  test(
    'cache write failure does not turn a valid read into a data error',
    () async {
      final repository = TyphoonRepository(
        store: FailingStore(),
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
      );
      expect((await repository.load()).fromCache, isFalse);
    },
  );
}

class FailingStore implements SnapshotStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String data) async =>
      throw StateError('storage unavailable');
}
