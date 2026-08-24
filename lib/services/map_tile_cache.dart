// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/services/map_tile_cache.dart
//
// Sovereign TacMap P1 + P3 port:
//  P1 · Cache-first TileProvider — every tile is served from the on-device
//       cache when present; network is the fallback (and fills the cache).
//       This is the public-fallback half of HybridTileInterceptor.
//  P3 · Offline prefetch packs — bulk-download a bounding tile range around
//       a center for a zoom band, with progress + cancel (TilePack port).
//
// OSM usage-policy guard carried over from LandSectorView: prefetch is
// capped and never targets the OSM endpooint aggressively (small zoom band,
// hard tile ceiling, sequential-ish fetching).

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show SynchronousFuture;

import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class MapTileCache {
  MapTileCache._();

  static Directory? _cacheDir;

  static const String _userAgent = 'com.recoveryforall';

  /// Per-layer URL templates (single host — subdomain rotation is skipped
  /// so the cache key stays stable and prefetch stays polite).
  static const Map<String, String> _templates = {
    'dark': 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
    'light': 'https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
    'sat':
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    'topo': 'https://a.tile.opentopomap.org/{z}/{x}/{y}.png',
  };

  static Future<Directory> _dir(String layer) async {
    if (_cacheDir != null) {
      final layerDir = Directory('${_cacheDir!.path}/$layer');
      await layerDir.create(recursive: true);
      return layerDir;
    }
    final base = await getApplicationDocumentsDirectory();
    _cacheDir = Directory('${base.path}/mapcache');
    await _cacheDir!.create(recursive: true);
    final layerDir = Directory('${_cacheDir!.path}/$layer');
    await layerDir.create(recursive: true);
    return layerDir;
  }

  static File _tileFile(Directory layerDir, int z, int x, int y) =>
      File('${layerDir.path}/${z}_{x}_{y}.png');

  static String _urlFor(String layer, int z, int x, int y) {
    final template = _templates[layer] ?? _templates['dark']!;
    return template
        .replaceFirst('{z}', z.toString())
        .replaceFirst('{x}', x.toString())
        .replaceFirst('{y}', y.toString());
  }

  /// Network fetch → cache write. Returns cached file on success.
  static Future<File?> fetchAndCache(
      String layer, int z, int x, int y) async {
    try {
      final layerDir = await _dir(layer);
      final file = _tileFile(layerDir, z, x, y);
      final res = await http.get(
        Uri.parse(_urlFor(layer, z, x, y)),
        headers: {'User-Agent': _userAgent},
      ).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) return null;
      await file.writeAsBytes(res.bodyBytes, flush: true);
      return file;
    } catch (_) {
      return null;
    }
  }

  static Future<void> prefetchTile(String layer, int z, int x, int y) async {
    final layerDir = await _dir(layer);
    if (_tileFile(layerDir, z, x, y).existsSync()) return;
    await fetchAndCache(layer, z, x, y);
  }
}

/// P1 — cache-first tile source for flutter_map.
class CachedTileProvider extends TileProvider {
  final String layer;

  CachedTileProvider({required this.layer});

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return _CachedTileImageProvider(
      layer: layer,
      z: coordinates.z.toInt(),
      x: coordinates.x.toInt(),
      y: coordinates.y.toInt(),
    );
  }
}

class _CachedTileImageProvider
    extends ImageProvider<_CachedTileImageProvider> {
  final String layer;
  final int z;
  final int x;
  final int y;

  _CachedTileImageProvider({
    required this.layer,
    required this.z,
    required this.x,
    required this.y,
  });

  @override
  Future<_CachedTileImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_CachedTileImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
      _CachedTileImageProvider key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key),
      scale: 1.0,
    );
  }

  Future<ui.Codec> _loadAsync(_CachedTileImageProvider key) async {
    final layerDir = await MapTileCache._dir(key.layer);
    final file = MapTileCache._tileFile(layerDir, key.z, key.x, key.y);

    Uint8List bytes;
    if (file.existsSync()) {
      bytes = await file.readAsBytes();
    } else {
      final fetched =
          await MapTileCache.fetchAndCache(key.layer, key.z, key.x, key.y);
      if (fetched == null) {
        throw StateError('tile unavailable');
      }
      bytes = await fetched.readAsBytes();
    }
    return ui.instantiateImageCodec(bytes);
  }

  @override
  bool operator ==(Object other) =>
      other is _CachedTileImageProvider &&
      other.layer == layer &&
      other.z == z &&
      other.x == x &&
      other.y == y;

  @override
  int get hashCode => Object.hash(layer, z, x, y);
}

// ---- P3: offline prefetch packs ----

class TilePrefetch {
  TilePrefetch._();

  /// Slippy-tile numbers for a center/radius at a zoom.
  static ({int xMin, int xMax, int yMin, int yMax}) tileRange({
    required double lat,
    required double lng,
    required double radiusKm,
    required int zoom,
  }) {
    final n = 1 << zoom;
    double lngToX(double lng) => (lng + 180) / 360 * n;
    double latToY(double lat) {
      final rad = lat * math.pi / 180;
      return (1 - math.log(math.tan(rad) + 1 / math.cos(rad)) / math.pi) / 2 * n;
    }

    final dLat = radiusKm / 111.32;
    final dLng = radiusKm / (111.32 * math.cos(lat * math.pi / 180));
    final x0 = lngToX(lng - dLng).floor();
    final x1 = lngToX(lng + dLng).floor();
    final y0 = latToY(lat + dLat).floor();
    final y1 = latToY(lat - dLat).floor();
    return (
      xMin: x0.clamp(0, n - 1),
      xMax: x1.clamp(0, n - 1),
      yMin: y0.clamp(0, n - 1),
      yMax: y1.clamp(0, n - 1),
    );
  }

  /// Downloads the tile pack for [zooms] around a center. Returns the number
  /// of tiles secured. [onProgress] reports (done, total). Cancel by flipping
  /// [isCancelled].
  static Future<int> prefetchPack({
    required String layer,
    required double lat,
    required double lng,
    required double radiusKm,
    required List<int> zooms,
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
    int maxTiles = 800,
  }) async {
    var jobs = <(int, int, int)>[];
    for (final z in zooms) {
      final r = tileRange(lat: lat, lng: lng, radiusKm: radiusKm, zoom: z);
      for (var x = r.xMin; x <= r.xMax; x++) {
        for (var y = r.yMin; y <= r.yMax; y++) {
          jobs.add((z, x, y));
        }
      }
    }
    if (jobs.length > maxTiles) {
      jobs = jobs.sublist(0, maxTiles);
    }

    var done = 0;
    for (final (z, x, y) in jobs) {
      if (isCancelled?.call() ?? false) break;
      await MapTileCache.prefetchTile(layer, z, x, y);
      done++;
      onProgress?.call(done, jobs.length);
      // Tiny politeness gap — OSM-facing endpoints only.
      await Future<void>.delayed(const Duration(milliseconds: 12));
    }
    return done;
  }
}
