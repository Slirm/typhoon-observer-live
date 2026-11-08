const jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

Map<String, dynamic> snapshotJson({bool ended = false}) => {
  'schemaVersion': 1,
  'fetchedAt': '2026-11-08T10:00:00.000Z',
  'activeCount': ended ? 0 : 1,
  'storms': [
    {
      'id': '202631',
      'name': '烟花',
      'english': 'In-fa',
      'ended': ended,
      'observations': [
        pointJson('2026-11-08T06:00:00.000Z', 122, 20),
        pointJson('2026-11-08T09:00:00.000Z', 125, 22),
      ],
      'forecast': [pointJson('2026-11-08T12:00:00.000Z', 127, 24)],
      'forecastAgency': '中国',
      'forecastIssuedAt': '2026-11-08T09:00:00.000Z',
    },
  ],
};

Map<String, dynamic> pointJson(String time, num lon, num lat) => {
  'time': time,
  'longitude': lon,
  'latitude': lat,
  'windPower': 10,
  'windSpeed': 28,
  'pressure': 982,
  'moveDirection': '东北',
  'moveSpeed': 20,
};

Map<String, dynamic> healthJson({bool ok = true}) => {
  'ok': ok,
  'lastSuccessAt': '2026-11-08T10:00:00.000Z',
  'lastAttemptAt': '2026-11-08T10:00:00.000Z',
};
