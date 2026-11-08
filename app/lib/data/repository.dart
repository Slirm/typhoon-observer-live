import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'typhoon.dart';

abstract class SnapshotStore {
  Future<String?> read();
  Future<void> write(String data);
}

class PreferencesStore implements SnapshotStore {
  static const _key = 'typhoon-observer.snapshot.v1';
  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(_key);
  @override
  Future<void> write(String data) async {
    if (!await (await SharedPreferences.getInstance()).setString(_key, data)) {
      throw StateError('Cache could not be saved');
    }
  }
}

class SnapshotResult {
  const SnapshotResult({
    required this.snapshot,
    required this.health,
    this.fromCache = false,
  });
  final TyphoonSnapshot snapshot;
  final SyncHealth? health;
  final bool fromCache;
}

class TyphoonRepository {
  TyphoonRepository({http.Client? client, SnapshotStore? store, Uri? baseUri})
    : _client = client ?? http.Client(),
      _store = store ?? PreferencesStore(),
      _baseUri =
          baseUri ??
          Uri.parse(
            const String.fromEnvironment(
              'DATA_BASE_URL',
              defaultValue: snapshotBaseUrl,
            ),
          );
  final http.Client _client;
  final SnapshotStore _store;
  final Uri _baseUri;
  SnapshotResult? _lastGood;

  Future<Map<String, dynamic>> _get(String name) async {
    final uri = _baseUri
        .resolve(name)
        .replace(
          queryParameters: {
            't': DateTime.now().millisecondsSinceEpoch.toString(),
          },
        );
    final response = await _client
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200 || response.bodyBytes.length > 2000000) {
      throw const FormatException('Snapshot unavailable');
    }
    return object(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<SnapshotResult> load() async {
    try {
      final statusFuture = _get('status.json')
          .then<SyncHealth?>((data) => SyncHealth.fromJson(data))
          .catchError((Object _) => null);
      final raw = await _get('latest.json');
      final snapshot = TyphoonSnapshot.fromJson(raw);
      final health = await statusFuture;
      final result = SnapshotResult(snapshot: snapshot, health: health);
      _lastGood = result;
      // Browser storage can be unavailable; a good network read remains usable.
      try {
        await _store.write(
          jsonEncode({
            'snapshot': raw,
            'health': health == null
                ? null
                : {
                    'ok': health.ok,
                    'lastAttemptAt': health.lastAttemptAt?.toIso8601String(),
                    'lastSuccessAt': health.lastSuccessAt?.toIso8601String(),
                  },
          }),
        );
      } catch (_) {
        /* The in-memory snapshot still survives a later read failure. */
      }
      return result;
    } catch (_) {
      if (_lastGood case final previous?) {
        return SnapshotResult(
          snapshot: previous.snapshot,
          health: previous.health,
          fromCache: true,
        );
      }
      try {
        final cached = await _store.read();
        if (cached != null) {
          final data = object(jsonDecode(cached));
          final snapshot = TyphoonSnapshot.fromJson(object(data['snapshot']));
          final health = data['health'] == null
              ? null
              : SyncHealth.fromJson(object(data['health']));
          _lastGood = SnapshotResult(snapshot: snapshot, health: health);
          return SnapshotResult(
            snapshot: snapshot,
            health: health,
            fromCache: true,
          );
        }
      } catch (_) {
        /* Invalid cache cannot replace a valid source record. */
      }
      throw const FormatException('暂时无法读取数据，请检查网络后重试。');
    }
  }

  void close() => _client.close();
}
