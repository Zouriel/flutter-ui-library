import 'dart:math' as math;
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';

/// The pixel work behind [UiImageEditor], kept free of widgets so it can be tested on its own and
/// kept in step with the web library (`image-edit.ts`).
///
/// An edit is the original pixels plus a **mask** (one byte a pixel: 255 keeps the pixel, 0 erases
/// it) and a **crop** rectangle. Brushes only change the mask, so restoring always brings back the
/// original.
///
/// Undo keeps per-stroke diffs: the mask is split into 64 x 64 tiles, a stroke records the tiles it
/// touched (before and after, run-length encoded), and a crop change records the two rectangles.
/// History keeps up to 100 steps within 64 MB of encoded data, dropping the oldest first.

/// A crop, in image pixels.
@immutable
class UiImageCrop {
  const UiImageCrop(this.x, this.y, this.width, this.height);
  final int x;
  final int y;
  final int width;
  final int height;

  Rect get rect => Rect.fromLTWH(x.toDouble(), y.toDouble(), width.toDouble(), height.toDouble());

  @override
  bool operator ==(Object other) => other is UiImageCrop && other.x == x && other.y == y && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(x, y, width, height);

  @override
  String toString() => 'UiImageCrop($x, $y, $width x $height)';
}

/// What a drag does in a [UiImageEditor].
enum UiImageEditorMode { crop, erase, restore }

/// Straight (not premultiplied) RGBA pixels, row by row.
@immutable
class UiImageRaster {
  const UiImageRaster(this.width, this.height, this.data);
  final int width;
  final int height;
  final Uint8List data;
}

/// A crop handle, or the inside of the crop ([move]).
enum UiCropHandle { nw, n, ne, e, se, s, sw, w, move }

const int uiImageMaxSide = 4096;
const int uiCropMin = 8;
const int _tile = 64;
const int _maxSteps = 100;
const int _maxBytes = 64 * 1024 * 1024;

/// A rectangle of pixels that needs redrawing.
typedef UiDirtyRect = ({int x, int y, int w, int h});

/// The working size for a picture of [width] x [height]: unchanged unless a side is longer than
/// [maxSide], then scaled down to fit.
(int, int) uiWorkingSize(int width, int height, [int maxSide = uiImageMaxSide]) {
  final k = math.min(1.0, maxSide / math.max(width, height));
  return (math.max(1, (width * k).round()), math.max(1, (height * k).round()));
}

// ----- Brush -----------------------------------------------------------------------------------------

/// How strongly a round brush of radius [r] acts at distance [d] from its centre (1 full, 0 none).
/// [softness] 0 is a hard edge (with a one-pixel anti-aliased rim), 1 fades from the centre out.
double brushFalloff(double d, double r, double softness) {
  final s = softness.clamp(0.0, 1.0);
  final inner = r * (1 - s);
  if (r - inner < 1) return (r + 0.5 - d).clamp(0.0, 1.0);
  if (d <= inner) return 1;
  if (d >= r) return 0;
  final t = (d - inner) / (r - inner);
  return 1 - t * t * (3 - 2 * t);
}

// ----- Run-length encoding ---------------------------------------------------------------------------

/// Pairs of (run length 1-255, value). A mask is mostly long runs of 255 and 0.
Uint8List rleEncode(Uint8List bytes) {
  final out = <int>[];
  var i = 0;
  while (i < bytes.length) {
    final v = bytes[i];
    var n = 1;
    while (n < 255 && i + n < bytes.length && bytes[i + n] == v) {
      n++;
    }
    out
      ..add(n)
      ..add(v);
    i += n;
  }
  return Uint8List.fromList(out);
}

Uint8List rleDecode(Uint8List rle, Uint8List into) {
  var o = 0;
  for (var i = 0; i < rle.length; i += 2) {
    into.fillRange(o, o + rle[i], rle[i + 1]);
    o += rle[i];
  }
  return into;
}

// ----- Crop geometry ---------------------------------------------------------------------------------

UiImageCrop fullCrop(int width, int height) => UiImageCrop(0, 0, width, height);

/// Rounds like JavaScript's Math.round (halves go up), so both libraries land on the same pixel.
int _jsRound(double v) => (v + 0.5).floor();

/// Keeps a crop whole-pixel, inside the image, and at least the minimum size.
UiImageCrop clampCrop(double x, double y, double width, double height, int W, int H) {
  final min = math.min(uiCropMin, math.min(W, H)).toDouble();
  final w = _jsRound(math.min(W.toDouble(), math.max(min, width)));
  final h = _jsRound(math.min(H.toDouble(), math.max(min, height)));
  final cx = _jsRound(math.min((W - w).toDouble(), math.max(0, x)));
  final cy = _jsRound(math.min((H - h).toDouble(), math.max(0, y)));
  return UiImageCrop(cx, cy, w, h);
}

/// The largest crop with ratio [aspect] (width / height) inside [within], centred on it.
UiImageCrop fitAspect(UiImageCrop within, double aspect, int W, int H) {
  var w = within.width.toDouble();
  var h = within.height.toDouble();
  if (w / h > aspect) {
    w = h * aspect;
  } else {
    h = w / aspect;
  }
  var wi = math.max(1, _jsRound(w));
  var hi = math.max(1, _jsRound(wi / aspect));
  if (hi > within.height) {
    hi = within.height;
    wi = math.max(1, _jsRound(hi * aspect));
  }
  final x = within.x + (within.width - wi) / 2;
  final y = within.y + (within.height - hi) / 2;
  return UiImageCrop(_jsRound(math.min((W - wi).toDouble(), math.max(0, x))), _jsRound(math.min((H - hi).toDouble(), math.max(0, y))), wi, hi);
}

/// Where a crop goes when [handle] is dragged by ([dx], [dy]) image pixels from [start]: inside the
/// image, at least 8 px, and keeping [aspect] (width / height) when it's set. Corners keep the
/// opposite corner still; edges keep the opposite edge still (and, with an aspect, stay centred the
/// other way).
UiImageCrop dragCrop(UiImageCrop start, UiCropHandle handle, double dx, double dy, int W, int H, double? aspect) {
  final min = math.min(uiCropMin, math.min(W, H)).toDouble();
  if (handle == UiCropHandle.move) {
    return clampCrop(start.x + dx, start.y + dy, start.width.toDouble(), start.height.toDouble(), W, H);
  }
  final L = start.x.toDouble(), T = start.y.toDouble(), R = (start.x + start.width).toDouble(), B = (start.y + start.height).toDouble();
  final name = handle.name;
  final west = name.contains('w'), east = name.contains('e'), north = name.contains('n'), south = name.contains('s');
  if (aspect == null || aspect <= 0) {
    var l = L, t = T, r = R, b = B;
    if (west) l = math.min(math.max(0, L + dx), R - min);
    if (east) r = math.max(math.min(W.toDouble(), R + dx), L + min);
    if (north) t = math.min(math.max(0, T + dy), B - min);
    if (south) b = math.max(math.min(H.toDouble(), B + dy), T + min);
    final x = _jsRound(l), y = _jsRound(t);
    return UiImageCrop(x, y, _jsRound(r) - x, _jsRound(b) - y);
  }
  final minW = math.max(min, min * aspect);
  UiImageCrop finish(double x, double y, double w) {
    var width = math.max(1, _jsRound(w));
    var height = math.max(1, _jsRound(width / aspect));
    if (height > H) {
      height = H;
      width = _jsRound(height * aspect);
    }
    if (width > W) {
      width = W;
      height = _jsRound(width / aspect);
    }
    final cx = _jsRound(math.min((W - width).toDouble(), math.max(0, x)));
    final cy = _jsRound(math.min((H - height).toDouble(), math.max(0, y)));
    return UiImageCrop(cx, cy, width, height);
  }

  if ((west || east) && (north || south)) {
    final ax = west ? R : L, ay = north ? B : T;
    final px = (west ? L : R) + dx, py = (north ? T : B) + dy;
    final rawW = (px - ax) * (east ? 1 : -1);
    final rawH = (py - ay) * (south ? 1 : -1);
    final maxW = math.min(east ? W - ax : ax, (south ? H - ay : ay) * aspect);
    final w = math.min(maxW, math.max(minW, math.max(rawW, rawH * aspect)));
    final h = w / aspect;
    return finish(east ? ax : ax - w, south ? ay : ay - h, w);
  }
  if (west || east) {
    final ax = west ? R : L;
    final cy = (T + B) / 2;
    final rawW = ((west ? L : R) + dx - ax) * (east ? 1 : -1);
    final maxW = math.min(east ? W - ax : ax, 2 * math.min(cy, H - cy) * aspect);
    final w = math.min(maxW, math.max(minW, rawW));
    return finish(east ? ax : ax - w, cy - w / aspect / 2, w);
  }
  final ay = north ? B : T;
  final cx = (L + R) / 2;
  final rawH = ((north ? T : B) + dy - ay) * (south ? 1 : -1);
  final maxH = math.min(south ? H - ay : ay, (2 * math.min(cx, W - cx)) / aspect);
  final h = math.min(maxH, math.max(minW / aspect, rawH));
  final w = h * aspect;
  return finish(cx - w / 2, south ? ay : ay - h, w);
}

// ----- The edit --------------------------------------------------------------------------------------

class _TileDiff {
  _TileDiff(this.index, this.before, this.after);
  final int index;
  final Uint8List before;
  final Uint8List after;
}

class _Step {
  _Step(this.tiles, this.cropBefore, this.cropAfter, this.bytes);
  final List<_TileDiff> tiles;
  final UiImageCrop? cropBefore;
  final UiImageCrop? cropAfter;
  final int bytes;
}

class _Stroke {
  _Stroke(this.erase, this.r, this.softness, this.prev, this.last);
  final bool erase;
  final double r;
  final double softness;

  /// Tile index -> its mask bytes before the stroke.
  final Map<int, Uint8List> saved = {};

  /// The last two pointer positions, for the curve through them.
  ({double x, double y}) prev;
  ({double x, double y}) last;
}

/// One image being edited: pixels, mask, crop and history. [onDirty] hears which part of the image
/// needs redrawing after any change.
class UiImageEdit {
  UiImageEdit(UiImageRaster raster)
      : width = raster.width,
        height = raster.height,
        pixels = raster.data,
        mask = Uint8List(raster.width * raster.height)..fillRange(0, raster.width * raster.height, 255),
        crop = fullCrop(raster.width, raster.height),
        _cols = (raster.width / _tile).ceil(),
        _rows = (raster.height / _tile).ceil() {
    _marked = Uint8List(_cols * _rows);
  }

  final int width;
  final int height;
  final Uint8List pixels;
  final Uint8List mask;
  UiImageCrop crop;
  final int _cols;
  final int _rows;

  /// 1 for each tile with anything erased in it.
  late final Uint8List _marked;
  int _markedCount = 0;
  final List<_Step> _undo = [];
  final List<_Step> _redo = [];
  int _bytes = 0;
  _Stroke? _stroke;
  void Function(UiDirtyRect r) onDirty = _ignore;

  static void _ignore(UiDirtyRect r) {}

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  int get stepCount => _undo.length;
  int get historyBytes => _bytes;
  bool get stroking => _stroke != null;

  /// Anything erased, or a crop smaller than the image.
  bool get dirty => _markedCount > 0 || crop != fullCrop(width, height);

  /// The mask value (0-255) at a pixel.
  int maskAt(int x, int y) => mask[y * width + x];

  // ----- Strokes -----

  /// Starts a stroke at ([x], [y]) in image pixels; [size] is the brush's diameter. Paints the first dab.
  void beginStroke(UiImageEditorMode mode, double x, double y, double size, double softness) {
    cancelStroke();
    _stroke = _Stroke(mode != UiImageEditorMode.restore, math.max(0.5, size / 2), softness, (x: x, y: y), (x: x, y: y));
    _segment((x: x, y: y), (x: x, y: y));
  }

  /// Carries the stroke on to ([x], [y]). The line bends smoothly through the pointer positions:
  /// each step draws the curve from the middle of the last two moves to the middle of the next.
  void strokeTo(double x, double y) {
    final s = _stroke;
    if (s == null) return;
    if (math.sqrt(math.pow(x - s.last.x, 2) + math.pow(y - s.last.y, 2)) < 0.5) return;
    final from = (x: (s.prev.x + s.last.x) / 2, y: (s.prev.y + s.last.y) / 2);
    final to = (x: (s.last.x + x) / 2, y: (s.last.y + y) / 2);
    _curve(from, s.last, to);
    s.prev = s.last;
    s.last = (x: x, y: y);
  }

  /// Ends the stroke: one undo step. Returns whether it changed anything.
  bool endStroke() {
    final s = _stroke;
    if (s == null) return false;
    // Finish the curve's last half, to where the pointer lifted.
    _segment((x: (s.prev.x + s.last.x) / 2, y: (s.prev.y + s.last.y) / 2), s.last);
    _stroke = null;
    final tiles = <_TileDiff>[];
    for (final e in s.saved.entries) {
      final after = _readTile(e.key);
      if (listEquals(e.value, after)) continue;
      tiles.add(_TileDiff(e.key, rleEncode(e.value), rleEncode(after)));
      _remark(e.key, after);
    }
    if (tiles.isEmpty) return false;
    _push(_Step(tiles, null, null, tiles.fold(0, (n, t) => n + t.before.length + t.after.length)));
    return true;
  }

  /// Throws a stroke in progress away, putting the mask back as it was.
  void cancelStroke() {
    final s = _stroke;
    if (s == null) return;
    _stroke = null;
    for (final e in s.saved.entries) {
      _writeTile(e.key, e.value);
    }
  }

  /// A quadratic curve, as straight pieces short enough not to show at this brush size.
  void _curve(({double x, double y}) a, ({double x, double y}) c, ({double x, double y}) b) {
    final s = _stroke!;
    double dist(({double x, double y}) p, ({double x, double y}) q) => math.sqrt((q.x - p.x) * (q.x - p.x) + (q.y - p.y) * (q.y - p.y));
    final chord = dist(a, c) + dist(c, b);
    final n = math.min(64, math.max(1, (chord / math.max(2, s.r * 0.5)).ceil()));
    var p = a;
    for (var i = 1; i <= n; i++) {
      final t = i / n;
      final q = (
        x: (1 - t) * (1 - t) * a.x + 2 * (1 - t) * t * c.x + t * t * b.x,
        y: (1 - t) * (1 - t) * a.y + 2 * (1 - t) * t * c.y + t * t * b.y,
      );
      _segment(p, q);
      p = q;
    }
  }

  /// Paints a straight piece of the stroke: every pixel takes the brush's strength at its distance
  /// from the piece (a capsule), so the edge is smooth with no dab marks. Erase keeps the lower mask
  /// value and restore the higher, so going over a spot twice in one stroke doesn't build up.
  void _segment(({double x, double y}) a, ({double x, double y}) b) {
    final s = _stroke!;
    final reach = s.r + 1;
    final x0 = math.max(0, (math.min(a.x, b.x) - reach).floor()), x1 = math.min(width - 1, (math.max(a.x, b.x) + reach).ceil());
    final y0 = math.max(0, (math.min(a.y, b.y) - reach).floor()), y1 = math.min(height - 1, (math.max(a.y, b.y) + reach).ceil());
    if (x0 > x1 || y0 > y1) return;
    for (var ty = y0 ~/ _tile; ty <= y1 ~/ _tile; ty++) {
      for (var tx = x0 ~/ _tile; tx <= x1 ~/ _tile; tx++) {
        final index = ty * _cols + tx;
        s.saved.putIfAbsent(index, () => _readTile(index));
      }
    }
    final m = mask;
    final vx = b.x - a.x, vy = b.y - a.y;
    final vv = vx * vx + vy * vy;
    final limit = (s.r + 0.5) * (s.r + 0.5);
    for (var y = y0; y <= y1; y++) {
      final py = y + 0.5 - a.y;
      for (var x = x0; x <= x1; x++) {
        final px = x + 0.5 - a.x;
        final t = vv == 0 ? 0.0 : ((px * vx + py * vy) / vv).clamp(0.0, 1.0);
        final dx = px - t * vx, dy = py - t * vy;
        final d2 = dx * dx + dy * dy;
        if (d2 >= limit) continue;
        final f = brushFalloff(math.sqrt(d2), s.r, s.softness);
        if (f <= 0) continue;
        final i = y * width + x;
        if (s.erase) {
          final v = _jsRound(255 * (1 - f));
          if (v < m[i]) m[i] = v;
        } else {
          final v = _jsRound(255 * f);
          if (v > m[i]) m[i] = v;
        }
      }
    }
    onDirty((x: x0, y: y0, w: x1 - x0 + 1, h: y1 - y0 + 1));
  }

  // ----- Crop -----

  /// Sets the crop as one undo step (nothing happens when it's the same). Returns whether it changed.
  bool commitCrop(UiImageCrop next, [UiImageCrop? before]) {
    final from = before ?? crop;
    final after = clampCrop(next.x.toDouble(), next.y.toDouble(), next.width.toDouble(), next.height.toDouble(), width, height);
    crop = after;
    if (from == after) return false;
    _push(_Step(const [], from, after, 32));
    return true;
  }

  /// Sets the crop without recording it (the host setting it).
  void setCrop(UiImageCrop next) {
    crop = clampCrop(next.x.toDouble(), next.y.toDouble(), next.width.toDouble(), next.height.toDouble(), width, height);
  }

  // ----- History -----

  bool undo() {
    cancelStroke();
    if (_undo.isEmpty) return false;
    final step = _undo.removeLast();
    _apply(step, before: true);
    _redo.add(step);
    return true;
  }

  bool redo() {
    cancelStroke();
    if (_redo.isEmpty) return false;
    final step = _redo.removeLast();
    _apply(step, before: false);
    _undo.add(step);
    return true;
  }

  /// Back to the original image and the whole frame (or [to]), as one undo step.
  bool reset([UiImageCrop? to]) {
    cancelStroke();
    final tiles = <_TileDiff>[];
    for (var index = 0; index < _marked.length; index++) {
      if (_marked[index] == 0) continue;
      final before = _readTile(index);
      final after = Uint8List(before.length)..fillRange(0, before.length, 255);
      tiles.add(_TileDiff(index, rleEncode(before), rleEncode(after)));
      _writeTile(index, after);
    }
    final target = to ?? fullCrop(width, height);
    final whole = clampCrop(target.x.toDouble(), target.y.toDouble(), target.width.toDouble(), target.height.toDouble(), width, height);
    final cropChanged = crop != whole;
    final before = crop;
    crop = whole;
    if (tiles.isEmpty && !cropChanged) return false;
    _push(_Step(tiles, cropChanged ? before : null, cropChanged ? whole : null, 32 + tiles.fold(0, (n, t) => n + t.before.length + t.after.length)));
    return true;
  }

  void _apply(_Step step, {required bool before}) {
    for (final t in step.tiles) {
      final r = _tileRect(t.index);
      _writeTile(t.index, rleDecode(before ? t.before : t.after, Uint8List(r.w * r.h)));
    }
    final c = before ? step.cropBefore : step.cropAfter;
    if (c != null) crop = c;
  }

  void _push(_Step step) {
    _undo.add(step);
    _bytes += step.bytes;
    for (final r in _redo) {
      _bytes -= r.bytes;
    }
    _redo.clear();
    while (_undo.length > _maxSteps || (_bytes > _maxBytes && _undo.length > 1)) {
      _bytes -= _undo.removeAt(0).bytes;
    }
  }

  // ----- Tiles -----

  UiDirtyRect _tileRect(int index) {
    final tx = index % _cols, ty = index ~/ _cols;
    final x = tx * _tile, y = ty * _tile;
    return (x: x, y: y, w: math.min(_tile, width - x), h: math.min(_tile, height - y));
  }

  Uint8List _readTile(int index) {
    final r = _tileRect(index);
    final out = Uint8List(r.w * r.h);
    for (var row = 0; row < r.h; row++) {
      final from = (r.y + row) * width + r.x;
      out.setRange(row * r.w, row * r.w + r.w, mask, from);
    }
    return out;
  }

  void _writeTile(int index, Uint8List bytes) {
    final r = _tileRect(index);
    for (var row = 0; row < r.h; row++) {
      mask.setRange((r.y + row) * width + r.x, (r.y + row) * width + r.x + r.w, bytes, row * r.w);
    }
    _remark(index, bytes);
    onDirty(r);
  }

  void _remark(int index, Uint8List bytes) {
    final was = _marked[index];
    final now = bytes.any((v) => v != 255) ? 1 : 0;
    _marked[index] = now;
    _markedCount += now - was;
  }

  // ----- Output -----

  /// The original pixels with the mask applied, for a part of the image (the display uses it).
  Uint8List composeRegion(UiDirtyRect r) {
    final out = Uint8List(r.w * r.h * 4);
    for (var row = 0; row < r.h; row++) {
      final y = r.y + row;
      for (var col = 0; col < r.w; col++) {
        final i = y * width + r.x + col;
        final o = (row * r.w + col) * 4;
        out[o] = pixels[i * 4];
        out[o + 1] = pixels[i * 4 + 1];
        out[o + 2] = pixels[i * 4 + 2];
        out[o + 3] = _jsRound(pixels[i * 4 + 3] * mask[i] / 255);
      }
    }
    return out;
  }

  /// The result: the crop, with erased pixels transparent.
  UiImageRaster result() => UiImageRaster(crop.width, crop.height, composeRegion((x: crop.x, y: crop.y, w: crop.width, h: crop.height)));
}
