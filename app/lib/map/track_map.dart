import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data/typhoon.dart';
import '../links.dart';
import '../theme.dart';
import 'land.dart';

// A world view shows one Earth, including on a wide desktop window.
class SingleWorldMercator extends Epsg3857 {
  const SingleWorldMercator();
  @override
  bool get replicatesWorldLongitude => false;
}

class TrackMap extends StatefulWidget {
  const TrackMap({
    super.key,
    required this.storm,
    required this.showForecast,
    required this.selectedIndex,
    required this.onSelected,
  });
  final Storm storm;
  final bool showForecast;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  @override
  State<TrackMap> createState() => _TrackMapState();
}

class _TrackMapState extends State<TrackMap> {
  final _controller = MapController();
  late Future<List<Polygon>> _land;
  bool _ready = false;
  int _labelLevel = 1;
  late final _grid = <Polyline>[
    for (var lon = -180; lon <= 180; lon += 10)
      Polyline(
        points: [LatLng(-85, lon.toDouble()), LatLng(85, lon.toDouble())],
        strokeWidth: .6,
        color: const Color(0x2984a5b0),
      ),
    for (var lat = -80; lat <= 80; lat += 10)
      Polyline(
        points: [LatLng(lat.toDouble(), -180), LatLng(lat.toDouble(), 180)],
        strokeWidth: .6,
        color: const Color(0x2984a5b0),
      ),
  ];
  @override
  void initState() {
    super.initState();
    _land = _loadLand();
  }

  Future<List<Polygon>> _loadLand() async {
    final data = jsonDecode(
      await rootBundle.loadString('assets/maps/ne_50m_land.geojson'),
    ) as Map<String, dynamic>;
    return parseLand(data)
        .map(
          (shape) => Polygon(
            points: shape.points,
            holePointsList: shape.holes,
            color: Palette.land,
            borderColor: const Color(0xff94b2b5),
            borderStrokeWidth: .8,
          ),
        )
        .toList(growable: false);
  }

  @override
  void didUpdateWidget(covariant TrackMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storm.id != widget.storm.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _ready) _fitTrack();
      });
    }
  }

  void _fitTrack() => _controller.fitCamera(
    CameraFit.bounds(
      bounds: boundsForStorm(
        widget.storm,
        includeForecast: widget.showForecast,
      ),
      padding: const EdgeInsets.all(36),
      maxZoom: 5,
      minZoom: 0,
    ),
  );
  void _zoom(double delta) {
    final camera = _controller.camera;
    _controller.move(camera.center, (camera.zoom + delta).clamp(0, 7));
  }

  void _changed(MapCamera camera, bool gesture) {
    final span = camera.visibleBounds.east - camera.visibleBounds.west;
    final level = span > 120
        ? 0
        : span > 55
        ? 1
        : 2;
    if (level != _labelLevel) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && level != _labelLevel) {
          setState(() => _labelLevel = level);
        }
      });
    }
  }

  List<TrackPoint> get _points => [
    ...widget.storm.observations,
    ...(widget.showForecast && !widget.storm.ended
        ? widget.storm.forecast
        : <TrackPoint>[]),
  ];
  Widget _label(String name, {bool sea = false, bool large = false}) =>
      IgnorePointer(
        child: Center(
          child: Text(
            name,
            textScaler: TextScaler.noScaling,
            softWrap: false,
            style: TextStyle(
              fontSize: large
                  ? 15
                  : sea
                  ? 12
                  : 11,
              color: sea ? const Color(0xff486d79) : const Color(0xff506c63),
              fontWeight: large ? FontWeight.w600 : FontWeight.w400,
              letterSpacing: large ? 2 : 1,
            ),
          ),
        ),
      );
  List<Marker> _labels() => [
    if (_labelLevel == 0)
      for (final row in const [
        (43.0, 90.0, '亚洲'),
        (48.0, 15.0, '欧洲'),
        (5.0, 20.0, '非洲'),
        (43.0, -105.0, '北美洲'),
        (-16.0, -60.0, '南美洲'),
        (-25.0, 135.0, '大洋洲'),
      ])
        Marker(
          point: LatLng(row.$1, row.$2),
          width: 80,
          height: 25,
          child: _label(row.$3),
        ),
    if (_labelLevel > 0)
      for (final row in const [
        (34.0, 108.0, '中国'),
        (37.0, 138.0, '日本'),
        (16.0, 122.0, '菲律宾'),
        (20.0, 104.0, '越南'),
      ])
        Marker(
          point: LatLng(row.$1, row.$2),
          width: 100,
          height: 28,
          child: _label(row.$3, large: true),
        ),
    if (_labelLevel > 0)
      for (final row in const [
        (17.0, 115.0, '南 海'),
        (30.0, 130.0, '东 海'),
        (21.0, 145.0, '西北太平洋'),
      ])
        Marker(
          point: LatLng(row.$1, row.$2),
          width: 120,
          height: 26,
          child: _label(row.$3, sea: true),
        ),
    if (_labelLevel > 1)
      for (final row in const [
        (23.7, 121.0, '台湾岛'),
        (19.2, 109.7, '海南岛'),
        (31.2, 121.5, '上海'),
        (24.5, 118.1, '厦门'),
        (22.3, 114.2, '香港'),
        (20.0, 110.3, '海口'),
        (35.7, 139.7, '东京'),
      ])
        Marker(
          point: LatLng(row.$1, row.$2),
          width: 65,
          height: 22,
          child: _label(row.$3),
        ),
  ];
  List<Marker> _nodes() {
    final points = _points, last = widget.storm.observations.length - 1;
    return [
      for (var i = 0; i < points.length; i++)
        Marker(
          point: LatLng(points[i].latitude, points[i].longitude),
          width: i == last ? 42 : 24,
          height: i == last ? 42 : 24,
          child: Tooltip(
            message:
                '${beijingTime(points[i].time)} · ${numberText(points[i].windPower)}级${i > last ? ' · 预报' : ''}',
            child: Semantics(
              button: true,
              label:
                  '选择${beijingTime(points[i].time)}${i > last ? '预报' : '实况'}节点',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.onSelected(i),
                child: Center(
                  child: Container(
                    width: i == last ? 16 : 6,
                    height: i == last ? 16 : 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == last ? Palette.amber : Colors.white,
                      border: Border.all(
                        color: i == last
                            ? Colors.white
                            : i > last
                            ? Palette.amber
                            : Palette.blue,
                        width: i == last ? 3 : 1.5,
                      ),
                      boxShadow: i == last
                          ? [
                              const BoxShadow(
                                color: Color(0x40935917),
                                spreadRadius: 7,
                                blurRadius: 0,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      if (widget.selectedIndex < points.length)
        Marker(
          point: LatLng(
            points[widget.selectedIndex].latitude,
            points[widget.selectedIndex].longitude,
          ),
          width: 28,
          height: 28,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Palette.amber, width: 2),
              ),
            ),
          ),
        ),
      if (_labelLevel > 0)
        Marker(
          point: LatLng(
            widget.storm.latest.latitude,
            widget.storm.latest.longitude,
          ),
          width: 150,
          height: 86,
          alignment: Alignment.topCenter,
          child: IgnorePointer(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1220343e),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${widget.storm.name} · ${widget.storm.ended ? '最后实况' : '最新中心'}',
                      textScaler: TextScaler.noScaling,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${numberText(widget.storm.latest.windPower)}级 / ${widget.storm.id}',
                      textScaler: TextScaler.noScaling,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final storm = widget.storm;
    final height = (MediaQuery.sizeOf(context).height * .58).clamp(
      340.0,
      540.0,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _ready ? _fitTrack : null,
                icon: const Icon(Icons.route_outlined, size: 16),
                label: const Text('完整路径'),
              ),
              OutlinedButton.icon(
                onPressed: _ready
                    ? () => _controller.move(
                        LatLng(storm.latest.latitude, storm.latest.longitude),
                        5,
                      )
                    : null,
                icon: const Icon(Icons.my_location_outlined, size: 16),
                label: const Text('定位中心'),
              ),
              OutlinedButton.icon(
                onPressed: _ready
                    ? () => _controller.fitCamera(
                        CameraFit.bounds(
                          bounds: worldBounds,
                          padding: const EdgeInsets.all(22),
                          minZoom: 0,
                        ),
                      )
                    : null,
                icon: const Icon(Icons.public, size: 16),
                label: const Text('世界视图'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: height,
          child: ClipRect(
            child: Stack(
              children: [
                Positioned.fill(
                  child: FutureBuilder<List<Polygon>>(
                    future: _land,
                    builder: (context, land) => FlutterMap(
                      mapController: _controller,
                      options: MapOptions(
                        crs: const SingleWorldMercator(),
                        backgroundColor: Palette.ocean,
                        minZoom: 0,
                        maxZoom: 7,
                        initialCameraFit: CameraFit.bounds(
                          bounds: boundsForStorm(
                            storm,
                            includeForecast: widget.showForecast,
                          ),
                          padding: const EdgeInsets.all(36),
                          maxZoom: 5,
                          minZoom: 0,
                        ),
                        cameraConstraint: CameraConstraint.containCenter(
                          bounds: LatLngBounds(
                            const LatLng(-75, -180),
                            const LatLng(80, 180),
                          ),
                        ),
                        interactionOptions: InteractionOptions(
                          flags:
                              InteractiveFlag.all &
                              ~InteractiveFlag.rotate &
                              ~InteractiveFlag.scrollWheelZoom,
                          doubleTapZoomDuration:
                              MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 180),
                        ),
                        onMapReady: () =>
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) setState(() => _ready = true);
                            }),
                        onPositionChanged: _changed,
                      ),
                      children: [
                        if (land.hasData)
                          PolygonLayer(
                            polygons: land.data!,
                            drawInSingleWorld: true,
                            polygonLabels: false,
                          ),
                        PolylineLayer(
                          polylines: _grid,
                          drawInSingleWorld: true,
                        ),
                        MarkerLayer(markers: _labels()),
                        PolylineLayer(
                          drawInSingleWorld: true,
                          polylines: [
                            for (final segment in splitTrack(
                              storm.observations,
                            ))
                              Polyline(
                                points: segment,
                                color: Palette.blue,
                                strokeWidth: 2.6,
                                borderColor: Colors.white,
                                borderStrokeWidth: 1.6,
                              ),
                            if (widget.showForecast &&
                                !storm.ended &&
                                storm.forecast.isNotEmpty)
                              for (final segment in splitTrack([
                                storm.latest,
                                ...storm.forecast,
                              ]))
                                Polyline(
                                  points: segment,
                                  color: Palette.amber,
                                  strokeWidth: 2.5,
                                  pattern: StrokePattern.dashed(
                                    segments: [7, 6],
                                  ),
                                ),
                          ],
                        ),
                        MarkerLayer(markers: _nodes()),
                      ],
                    ),
                  ),
                ),
                const Positioned(
                  left: 16,
                  top: 16,
                  child: ExcludeSemantics(
                    child: Text(
                      'N ↑',
                      style: TextStyle(
                        fontSize: 12,
                        color: Palette.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: Column(
                    children: [
                      _mapButton(Icons.add, '放大地图', () => _zoom(1)),
                      const SizedBox(height: 7),
                      _mapButton(Icons.remove, '缩小地图', () => _zoom(-1)),
                    ],
                  ),
                ),
                Positioned(
                  left: 10,
                  bottom: 10,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .88),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        child: Text(
                          '经纬网间隔 10°',
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(fontSize: 10, color: Palette.muted),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        FutureBuilder<List<Polygon>>(
          future: _land,
          builder: (context, land) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 14, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  land.hasError
                      ? '底图暂不可用，实况路径仍可查看。'
                      : land.hasData
                      ? '真实海岸线 · 拖动地图，使用＋／−或双指缩放'
                      : '正在加载世界海岸线…',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (land.hasError)
                  TextButton(
                    onPressed: () => setState(() => _land = _loadLand()),
                    child: const Text('重试底图'),
                  ),
                TextButton(
                  onPressed: () => openExternal(
                    context,
                    'https://www.naturalearthdata.com/',
                  ),
                  child: const Text(
                    '底图：Natural Earth',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _mapButton(IconData icon, String tooltip, VoidCallback action) =>
      Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(7),
          side: const BorderSide(color: Color(0xffa2bac1)),
        ),
        child: IconButton(
          onPressed: _ready ? action : null,
          tooltip: tooltip,
          icon: Icon(icon, size: 22),
          color: Palette.blue,
        ),
      );
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
