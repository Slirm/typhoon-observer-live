import test from 'node:test';
import assert from 'node:assert/strict';
import { normalizeList, normalizeStorm, normalizeBulletins, sourceTime } from '../scripts/source.mjs';

const observation = (overrides = {}) => ({ Time:'11-05 11:00', Lon:140.4, Lat:28.8, CenterWindPower:10, CenterWindSpeed:28, CenterPressure:982, MoveDirection:'东北', MoveSpeed:63, Type:3, ForecastData:[], ...overrides });
const detail = (overrides = {}) => ({ TyphoonId:'202631', Year:2026, CnName:'烟花', EnName:'In-fa', IsStop:true, StartTime:'10-24 02:00', StopTime:'11-05 11:00', TyphoonPath:[observation()], ...overrides });

test('source time is Beijing time and rejects impossible dates', () => {
  assert.equal(sourceTime('11-05 11:00', 2026), '2026-11-05T03:00:00.000Z');
  assert.throws(() => sourceTime('02-30 11:00', 2026));
  assert.throws(() => sourceTime('bad time', 2026));
});
test('a valid empty year list differs from an error object', () => {
  assert.deepEqual(normalizeList([]), []);
  assert.throws(() => normalizeList({ error:'unavailable' }));
  assert.throws(() => normalizeList([{ TyphoonId:'202631', IsStop:'false' }]));
});
test('normalization preserves ended status and actual values', () => {
  const result = normalizeStorm(detail());
  assert.equal(result.ended, true);
  assert.equal(result.name, '烟花');
  assert.equal(result.observations[0].windPower, 10);
  assert.equal(result.observations[0].longitude, 140.4);
  assert.equal(result.observations[0].time, '2026-11-05T03:00:00.000Z');
});
test('missing numeric fields stay unknown instead of becoming zero', () => {
  const point = normalizeStorm(detail({ TyphoonPath:[observation({ MoveSpeed:null, CenterPressure:null })] })).observations[0];
  assert.equal(point.moveSpeed, null);
  assert.equal(point.pressure, null);
});
test('invalid coordinates, missing paths and identity mismatches fail', () => {
  assert.throws(() => normalizeStorm(detail({ TyphoonPath:[observation({ Lat:999 })] })));
  assert.throws(() => normalizeStorm(detail({ TyphoonPath:[] })));
  assert.throws(() => normalizeStorm(detail(), '202630'));
});
test('observations crossing New Year retain chronological dates', () => {
  const result = normalizeStorm(detail({ Year:2025, TyphoonId:'202599', TyphoonPath:[observation({ Time:'12-31 20:00' }),observation({ Time:'01-01 02:00' })] }));
  assert.equal(result.observations[1].time, '2025-12-31T18:00:00.000Z');
});
test('forecast keeps only the latest Chinese agency batch', () => {
  const forecast = (ForecastOffice, ForecastTime, Time) => observation({ ForecastOffice, ForecastTime, Time });
  const result = normalizeStorm(detail({ IsStop:false, TyphoonPath:[observation({ ForecastData:[
    [forecast('中国','11-05 08:00','11-05 20:00')],
    [forecast('日本','11-05 11:00','11-05 23:00')],
    [forecast('中国','11-05 11:00','11-05 23:00'),forecast('中国','11-05 11:00','11-06 11:00')]
  ] })] }));
  assert.equal(result.forecast.length, 2);
  assert.equal(result.forecastAgency, '中国');
  assert.equal(result.forecastIssuedAt, '2026-11-05T03:00:00.000Z');
  assert.ok(result.forecast.every((point) => point.time > result.forecastIssuedAt));
});
test('forecast dates can cross New Year', () => {
  const result = normalizeStorm(detail({ Year:2025, TyphoonId:'202599', IsStop:false, TyphoonPath:[observation({ Time:'12-31 20:00', ForecastData:[[observation({ ForecastOffice:'中国', ForecastTime:'12-31 20:00', Time:'01-01 08:00' })]] })] }));
  assert.equal(result.forecast[0].time, '2026-01-01T00:00:00.000Z');
});
test('empty bulletin feed never means no valid local warnings', () => {
  const result = normalizeBulletins([]);
  assert.equal(result.status, 'unknown');
  assert.deepEqual(result.records, []);
  assert.throws(() => normalizeBulletins('<html>error</html>'));
});
test('bulletins retain raw title, time and cancellation without inferred color', () => {
  const result = normalizeBulletins([{ TxtTitle:'解除台风四级预警', ProductTime:'2026-11-05 18:00', IsRelieve:true }]);
  assert.equal(result.records[0].title, '解除台风四级预警');
  assert.equal(result.records[0].relieved, true);
  assert.equal(result.status, 'recent_bulletins');
  assert.equal(result.records[0].color, undefined);
});
test('bulletins without a year retain the raw time rather than guessing',()=>{
  const result=normalizeBulletins([{TxtTitle:'来源公报',ProductTime:'01-01 00:15',IsRelieve:false}]);
  assert.equal(result.records[0].issuedAt,null);
  assert.equal(result.records[0].sourceTimeText,'01-01 00:15');
});
