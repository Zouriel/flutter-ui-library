import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'image_edit.dart';

/// The state of a [UiImageEditor]: mode, brush, aspect, crop and history, plus the export. Listen to
/// it (it's a [ChangeNotifier]) for [canUndo], [canRedo], [dirty], [crop] and the rest.
class UiImageEditorController extends ChangeNotifier {
  UiImageEditorController({
    UiImageEditorMode mode = UiImageEditorMode.erase,
    double brushSize = 40,
    double brushSoftness = 0.3,
    double? aspect,
    UiImageCrop? crop,
    bool straightLine = false,
  }) {
    _straightLine = straightLine;
    _mode = mode;
    _brushSize = brushSize;
    _brushSoftness = brushSoftness;
    _aspect = aspect;
    _pendingCrop = crop;
  }

  UiImageEdit? _edit;
  UiImageEditorMode _mode = UiImageEditorMode.erase;
  double _brushSize = 40;
  double _brushSoftness = 0.3;
  double? _aspect;
  UiImageCrop? _pendingCrop;
  bool _straightLine = false;

  /// Where the last stroke ended (image pixels): a Shift-press paints a straight line from here.
  Offset? _lineStart;
  int _loadSeq = 0;
  _UiImageEditorState? _view;

  /// Heard after each committed stroke or crop change, and after undo, redo and reset (the widget's
  /// `onChanged` is called alongside).
  final List<VoidCallback> _changeListeners = [];

  UiImageEditorMode get mode => _mode;
  set mode(UiImageEditorMode v) {
    if (v == _mode) return;
    final crossed = (v == UiImageEditorMode.crop) != (_mode == UiImageEditorMode.crop);
    _view?._abort();
    _mode = v;
    _lineStart = null;
    if (crossed) _view?._fit();
    notifyListeners();
  }

  /// Every press after the first paints straight from where the last stroke ended, as Shift-click
  /// does: for touch screens, where there's no Shift key (a "straight line" button).
  bool get straightLine => _straightLine;
  set straightLine(bool v) {
    if (v == _straightLine) return;
    _straightLine = v;
    notifyListeners();
  }

  /// While Shift is held (or [straightLine] is on): the line from where the last stroke ended to
  /// the pointer, on screen, as the editor shows it.
  @visibleForTesting
  (Offset, Offset)? get linePreview => _view?._linePreview;

  /// The brush's diameter, in image pixels.
  double get brushSize => _brushSize;
  set brushSize(double v) {
    final next = v.clamp(1.0, 1000.0);
    if (next == _brushSize) return;
    _brushSize = next;
    notifyListeners();
  }

  /// 0 is a hard edge, 1 fades out from the centre.
  double get brushSoftness => _brushSoftness;
  set brushSoftness(double v) {
    final next = v.clamp(0.0, 1.0);
    if (next == _brushSoftness) return;
    _brushSoftness = next;
    notifyListeners();
  }

  /// Width / height the crop keeps; null crops freely. Setting it reshapes the crop around its
  /// centre, as an undo step.
  double? get aspect => _aspect;
  set aspect(double? v) {
    if (v == _aspect) return;
    _aspect = v;
    final e = _edit;
    if (e != null && v != null && v > 0 && !_fits(e.crop, v)) {
      if (e.commitCrop(fitAspect(e.crop, v, e.width, e.height))) {
        _changed();
        return;
      }
    }
    notifyListeners();
  }

  static bool _fits(UiImageCrop c, double aspect) => (c.width / c.height - aspect).abs() * c.height < 1;

  /// The crop, in image pixels: null until loaded, then the whole picture unless set. Setting it is
  /// taken as it is (kept inside the image), not as an undo step.
  UiImageCrop? get crop => _edit?.crop ?? _pendingCrop;
  set crop(UiImageCrop? v) {
    final e = _edit;
    if (e == null) {
      _pendingCrop = v;
      return;
    }
    if (v == null || v == e.crop) return;
    e.setCrop(v);
    notifyListeners();
  }

  /// The working copy's size (the picture's, unless it was scaled down to 4096 px).
  Size? get naturalSize => _edit == null ? null : Size(_edit!.width.toDouble(), _edit!.height.toDouble());
  bool get loaded => _edit != null;
  bool get canUndo => _edit?.canUndo ?? false;
  bool get canRedo => _edit?.canRedo ?? false;

  /// Anything erased, or cropped, compared with the original.
  bool get dirty => _edit?.dirty ?? false;

  /// The edit underneath (pixels, mask, history), for tests and tools.
  UiImageEdit? get edit => _edit;

  void undo() {
    _lineStart = null;
    if (_edit?.undo() ?? false) _changed();
  }

  void redo() {
    _lineStart = null;
    if (_edit?.redo() ?? false) _changed();
  }

  /// Back to the original picture, uncropped (or the largest frame of [aspect]), as one undo step.
  void reset() {
    final e = _edit;
    if (e == null) return;
    _view?._abort();
    _lineStart = null;
    final a = _aspect;
    final whole = fullCrop(e.width, e.height);
    if (e.reset(a != null && a > 0 ? fitAspect(whole, a, e.width, e.height) : whole)) _changed();
  }

  /// The crop back to the whole picture (or the largest frame of [aspect]), as one undo step.
  void resetCrop() {
    final e = _edit;
    if (e == null) return;
    final a = _aspect;
    final whole = fullCrop(e.width, e.height);
    if (e.commitCrop(a != null && a > 0 ? fitAspect(whole, a, e.width, e.height) : whole)) _changed();
  }

  /// Zooms by [factor] about the middle of the view.
  void zoomBy(double factor) => _view?._zoomBy(factor);

  /// Frames the whole picture in crop mode, and the crop otherwise.
  void fit() => _view?._fit();

  /// The crop with erased pixels transparent, as straight RGBA, at the working resolution.
  UiImageRaster toRgba() {
    final e = _edit;
    if (e == null) throw StateError('The picture has not loaded yet');
    return e.result();
  }

  /// The crop with erased pixels transparent, as a PNG, at the working resolution.
  Future<Uint8List> toPng() async {
    final r = toRgba();
    final image = await _imageFromPixels(r.data, r.width, r.height);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('Could not encode the picture');
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  // ----- Loading -----

  /// Uses already-decoded pixels as they are (no scaling: keep them within 4096 px yourself).
  void loadRaster(UiImageRaster raster) {
    _loadSeq++;
    _attach(raster);
  }

  /// Decodes an encoded picture (PNG, JPEG, WebP...), scaled down to 4096 px on the long side.
  Future<void> loadBytes(Uint8List bytes) async {
    final seq = ++_loadSeq;
    _detach();
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final (w, h) = uiWorkingSize(descriptor.width, descriptor.height);
    final codec = await descriptor.instantiateCodec(targetWidth: w, targetHeight: h);
    final frame = await codec.getNextFrame();
    codec.dispose();
    descriptor.dispose();
    buffer.dispose();
    final raster = await _rasterOf(frame.image);
    if (seq == _loadSeq) _attach(raster);
  }

  /// Loads from an [ImageProvider], scaled down to 4096 px on the long side.
  Future<void> loadImage(ImageProvider provider) async {
    final seq = ++_loadSeq;
    _detach();
    final completer = Completer<ui.Image>();
    final stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      completer.complete(info.image.clone());
      info.dispose();
      stream.removeListener(listener);
    }, onError: (e, st) {
      if (!completer.isCompleted) completer.completeError(e, st);
      stream.removeListener(listener);
    });
    stream.addListener(listener);
    var image = await completer.future;
    final (w, h) = uiWorkingSize(image.width, image.height);
    if (w != image.width || h != image.height) {
      final rec = ui.PictureRecorder();
      Canvas(rec).drawImageRect(image, Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..filterQuality = FilterQuality.high);
      final pic = rec.endRecording();
      final scaled = await pic.toImage(w, h);
      pic.dispose();
      image.dispose();
      image = scaled;
    }
    final raster = await _rasterOf(image);
    if (seq == _loadSeq) _attach(raster);
  }

  static Future<UiImageRaster> _rasterOf(ui.Image image) async {
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
      if (data == null) throw StateError('Could not read the picture');
      return UiImageRaster(image.width, image.height, data.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  }

  void _detach() {
    _lineStart = null;
    if (_edit == null) return;
    _view?._abort();
    _edit = null;
    _view?._loaded();
    notifyListeners();
  }

  void _attach(UiImageRaster raster) {
    _view?._abort();
    _lineStart = null;
    final e = UiImageEdit(raster);
    final given = _pendingCrop;
    if (given != null && given.x >= 0 && given.y >= 0 && given.x + given.width <= e.width && given.y + given.height <= e.height) e.setCrop(given);
    final a = _aspect;
    if (a != null && a > 0 && !_fits(e.crop, a)) e.setCrop(fitAspect(e.crop, a, e.width, e.height));
    _pendingCrop = null;
    _edit = e;
    _view?._loaded();
    notifyListeners();
  }

  void _notify() => notifyListeners();

  void _changed() {
    notifyListeners();
    for (final l in List.of(_changeListeners)) {
      l();
    }
  }
}

/// Makes an image from straight RGBA. The engine reads raw pixels as premultiplied, so a pixel
/// erased to alpha 0 would otherwise still add its colour (a glow where it should be see-through).
Future<ui.Image> _imageFromPixels(Uint8List rgba, int width, int height) {
  final c = Completer<ui.Image>();
  ui.decodeImageFromPixels(uiPremultiply(rgba), width, height, ui.PixelFormat.rgba8888, c.complete);
  return c.future;
}

/// Straight RGBA as premultiplied, in place.
Uint8List uiPremultiply(Uint8List rgba) {
  for (var i = 0; i < rgba.length; i += 4) {
    final a = rgba[i + 3];
    if (a == 255) continue;
    rgba[i] = (rgba[i] * a / 255 + 0.5).floor();
    rgba[i + 1] = (rgba[i + 1] * a / 255 + 0.5).floor();
    rgba[i + 2] = (rgba[i + 2] * a / 255 + 0.5).floor();
  }
  return rgba;
}

/// `ui-image-editor`: crop a picture and erase parts of it with a soft or hard round brush.
///
/// - **crop**: a frame with eight handles; drag inside it to move it. Outside is dimmed, thirds show
///   while dragging, [UiImageEditorController.aspect] keeps its shape, and it stays inside the image.
/// - **erase**: drag to paint transparency; **restore** paints the original back.
///   [UiImageEditorController.brushSize] is the diameter in image pixels and
///   [UiImageEditorController.brushSoftness] runs from a hard edge (0) to very soft (1).
///
/// Shift-click draws a straight line: the editor remembers where the last stroke ended (a click
/// paints a dot there), and a press with Shift held paints straight from that point to the new one
/// with the current brush, as one undo step; the new point is then remembered, so Shift-clicks chain.
/// While Shift is held a faint line shows where it will go. Dragging after a Shift-press carries on
/// freehand from the new point (the same stroke). [UiImageEditorController.straightLine] does the
/// same without Shift, for touch screens. Undo, redo, reset, a new picture or another mode forget
/// the point.
///
/// Erased parts show over a checkerboard. One finger (or a mouse or pen) paints or drags the crop;
/// two fingers pan and pinch-zoom; Ctrl/Cmd + wheel zooms about the pointer; Space + drag or the
/// middle button pans. Once a pen has been used, fingers only navigate ([fingerDraws] null = auto).
/// Every stroke and crop change is one undo step (Ctrl/Cmd+Z, Shift+Ctrl/Cmd+Z or Ctrl+Y); `[` and
/// `]` change the brush size. Give the picture as [image] or [bytes] (scaled down to at most 4096 px
/// on its long side) or as decoded [raster] (used as given); [UiImageEditorController.toPng]
/// exports the crop with erased pixels transparent at the working resolution.
class UiImageEditor extends StatefulWidget {
  const UiImageEditor({
    super.key,
    required this.controller,
    this.image,
    this.bytes,
    this.raster,
    this.label = 'Picture editor',
    this.fingerDraws,
    this.onChanged,
    this.onLoadError,
  }) : assert(image != null || bytes != null || raster != null, 'Give the picture as image, bytes or raster');

  final UiImageEditorController controller;
  final ImageProvider? image;
  final Uint8List? bytes;
  final UiImageRaster? raster;

  /// Accessible name.
  final String label;

  /// Whether a finger paints; null (auto): until a pen is used, then fingers only pan and zoom.
  final bool? fingerDraws;

  /// After each committed stroke or crop change (and undo, redo and reset).
  final VoidCallback? onChanged;

  /// The picture couldn't be loaded.
  final ValueChanged<Object>? onLoadError;

  @override
  State<UiImageEditor> createState() => _UiImageEditorState();
}

enum _G { paint, crop, pan }

class _Drag {
  _Drag(this.kind, this.pointer, this.startLocal, this.startUnits, this.startCenter, {this.handle, this.start});
  final _G kind;
  final int pointer;
  final Offset startLocal;
  final Offset startUnits;
  final Offset startCenter;
  final UiCropHandle? handle;
  final UiImageCrop? start;
  bool moved = false;
}

const double _pad = 24;
const double _minZoom = 0.5;
const double _maxZoom = 64;
const int _displayTile = 256;
const List<(UiCropHandle, double, double)> _handles = [
  (UiCropHandle.nw, 0, 0), (UiCropHandle.n, 0.5, 0), (UiCropHandle.ne, 1, 0), (UiCropHandle.e, 1, 0.5),
  (UiCropHandle.se, 1, 1), (UiCropHandle.s, 0.5, 1), (UiCropHandle.sw, 0, 1), (UiCropHandle.w, 0, 0.5),
];

class _UiImageEditorState extends State<UiImageEditor> {
  final FocusNode _focus = FocusNode(debugLabel: 'UiImageEditor');
  bool _ring = false;
  Size _size = Size.zero;
  double _zoom = 1;
  Offset _center = Offset.zero;
  bool _fitted = false;
  Offset? _hover;
  bool _space = false;
  bool _cropping = false;
  bool _penSeen = false;
  bool _penPainting = false;
  bool _shift = false;
  _Drag? _drag;
  final Map<int, Offset> _pointers = {};
  ({double dist, double zoom, Offset world})? _pinch;

  /// The composed picture, in 256 px tiles, rebuilt where pixels change.
  final Map<int, ui.Image> _tiles = {};
  final Set<int> _stale = {};
  final Map<int, int> _tileGen = {};
  bool _rebuildQueued = false;
  UiImageEdit? _shown;

  UiImageEditorController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKeyboard);
    _c._view = this;
    _c.addListener(_onController);
    _c._changeListeners.add(_onChanged);
    if (_c.loaded) _loaded();
    // Loading tells the controller's listeners, which may be building right now: wait for the frame.
    _loadAfterFrame();
  }

  void _loadAfterFrame() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });

  @override
  void didUpdateWidget(UiImageEditor old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onController);
      old.controller._changeListeners.remove(_onChanged);
      if (old.controller._view == this) old.controller._view = null;
      _c._view = this;
      _c.addListener(_onController);
      _c._changeListeners.add(_onChanged);
      _loaded();
    }
    if (old.image != widget.image || old.bytes != widget.bytes || old.raster != widget.raster) _loadAfterFrame();
  }

  /// Follows Shift wherever focus is, for the straight-line preview.
  bool _onKeyboard(KeyEvent e) {
    final shift = HardwareKeyboard.instance.isShiftPressed;
    if (shift != _shift && mounted) setState(() => _shift = shift);
    return false;
  }

  (Offset, Offset)? get _linePreview {
    final from = _c._lineStart, to = _hover;
    if (from == null || to == null || _c.mode == UiImageEditorMode.crop || _space || _drag?.kind == _G.paint || !(_shift || _c.straightLine)) return null;
    return (_toLocal(from), to);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKeyboard);
    _c.removeListener(_onController);
    _c._changeListeners.remove(_onChanged);
    if (_c._view == this) _c._view = null;
    _clearTiles();
    _focus.dispose();
    super.dispose();
  }

  void _onController() {
    if (mounted) setState(() {});
  }

  void _onChanged() => widget.onChanged?.call();

  void _load() {
    final raster = widget.raster, bytes = widget.bytes, image = widget.image;
    Future<void>? job;
    if (raster != null) {
      _c.loadRaster(raster);
    } else if (bytes != null) {
      job = _c.loadBytes(bytes);
    } else if (image != null) {
      job = _c.loadImage(image);
    }
    job?.catchError((Object e) => widget.onLoadError?.call(e));
  }

  /// A new picture (or none): show it, framed.
  void _loaded() {
    _clearTiles();
    final e = _c._edit;
    _shown = e;
    _fitted = false;
    if (e != null) {
      e.onDirty = _markDirty;
      _markDirty((x: 0, y: 0, w: e.width, h: e.height));
    }
    if (mounted) setState(() {});
  }

  void _clearTiles() {
    for (final img in _tiles.values) {
      img.dispose();
    }
    _tiles.clear();
    _stale.clear();
  }

  void _markDirty(UiDirtyRect r) {
    final e = _shown;
    if (e == null) return;
    final cols = (e.width / _displayTile).ceil();
    for (var ty = r.y ~/ _displayTile; ty <= (r.y + r.h - 1) ~/ _displayTile; ty++) {
      for (var tx = r.x ~/ _displayTile; tx <= (r.x + r.w - 1) ~/ _displayTile; tx++) {
        _stale.add(ty * cols + tx);
      }
    }
    if (_rebuildQueued) return;
    _rebuildQueued = true;
    scheduleMicrotask(_rebuildTiles);
  }

  /// Turns stale tiles into images (asynchronously); a newer rebuild of a tile wins over an older one.
  void _rebuildTiles() {
    _rebuildQueued = false;
    final e = _shown;
    if (e == null || !mounted) return;
    final cols = (e.width / _displayTile).ceil();
    for (final index in _stale.toList()) {
      final x = (index % cols) * _displayTile, y = (index ~/ cols) * _displayTile;
      final w = math.min(_displayTile, e.width - x), h = math.min(_displayTile, e.height - y);
      final gen = (_tileGen[index] ?? 0) + 1;
      _tileGen[index] = gen;
      ui.decodeImageFromPixels(uiPremultiply(e.composeRegion((x: x, y: y, w: w, h: h))), w, h, ui.PixelFormat.rgba8888, (img) {
        if (!mounted || _shown != e || _tileGen[index] != gen) {
          img.dispose();
          return;
        }
        _tiles.remove(index)?.dispose();
        _tiles[index] = img;
        setState(() {});
      });
    }
    _stale.clear();
  }

  // ----- View ------------------------------------------------------------------------------------

  double _fitScale(double w, double h) {
    if (_size.isEmpty || w <= 0 || h <= 0) return 1;
    return math.max(1e-3, math.min(math.max(1.0, _size.width - _pad * 2) / w, math.max(1.0, _size.height - _pad * 2) / h));
  }

  double get _px {
    final e = _c._edit;
    if (e == null) return 1;
    return _fitScale(e.width.toDouble(), e.height.toDouble()) * _zoom;
  }

  Offset _toUnits(Offset local) => _center + (local - _size.center(Offset.zero)) / _px;
  Offset _toLocal(Offset units) => (units - _center) * _px + _size.center(Offset.zero);

  void _fit() {
    final e = _c._edit;
    if (e == null) return;
    final whole = fullCrop(e.width, e.height);
    final c = _c.mode == UiImageEditorMode.crop ? whole : e.crop;
    final base = _fitScale(e.width.toDouble(), e.height.toDouble());
    setState(() {
      _zoom = (base == 0 ? 1.0 : _fitScale(c.width.toDouble(), c.height.toDouble()) / base).clamp(_minZoom, _maxZoom);
      _center = c.rect.center;
    });
  }

  void _zoomBy(double f) => setState(() => _zoom = (_zoom * f).clamp(_minZoom, _maxZoom));

  // ----- Pointer ---------------------------------------------------------------------------------

  bool _isStylus(PointerEvent e) => e.kind == PointerDeviceKind.stylus || e.kind == PointerDeviceKind.invertedStylus;

  void _down(PointerDownEvent e) {
    final middle = e.kind == PointerDeviceKind.mouse && e.buttons == kMiddleMouseButton;
    if (e.kind == PointerDeviceKind.mouse && e.buttons != kPrimaryButton && !middle) return;
    if (_isStylus(e)) _penSeen = true;
    // A pen is painting: anything else touching the screen is a hand resting on it.
    if (_penPainting && e.kind == PointerDeviceKind.touch) return;
    final ed = _c._edit;
    if (ed == null) return;
    _focus.requestFocus();
    _pointers[e.pointer] = e.localPosition;

    if (_pointers.length == 2) {
      // A second finger: whatever the first one was doing is undone, and it becomes a pinch.
      _abort();
      final pts = _pointers.values.toList();
      final mid = (pts[0] + pts[1]) / 2;
      final dist = (pts[0] - pts[1]).distance;
      setState(() => _pinch = (dist: dist == 0 ? 1 : dist, zoom: _zoom, world: _toUnits(mid)));
      return;
    }
    if (_pointers.length > 2) return;

    final u = _toUnits(e.localPosition);
    _Drag drag;
    if (middle || _space) {
      drag = _Drag(_G.pan, e.pointer, e.localPosition, u, _center);
    } else if (_c.mode == UiImageEditorMode.crop) {
      final c = ed.crop;
      final handle = _handleAt(e.localPosition, c, e.kind == PointerDeviceKind.touch);
      final inside = c.rect.contains(u);
      drag = handle != null || inside
          ? _Drag(_G.crop, e.pointer, e.localPosition, u, _center, handle: handle ?? UiCropHandle.move, start: c)
          : _Drag(_G.pan, e.pointer, e.localPosition, u, _center);
    } else {
      drag = _fingerNavigates(e) ? _Drag(_G.pan, e.pointer, e.localPosition, u, _center) : _Drag(_G.paint, e.pointer, e.localPosition, u, _center);
    }
    _drag = drag;
    _penPainting = drag.kind == _G.paint && _isStylus(e);
    if (drag.kind == _G.paint) {
      // Shift (or straightLine) with a remembered point: straight from there to here, then on as usual.
      final from = _c._lineStart;
      final straight = from != null && (HardwareKeyboard.instance.isShiftPressed || _c.straightLine);
      final start = straight ? from : u;
      ed.beginStroke(_c.mode, start.dx, start.dy, math.max(1, _c.brushSize), _c.brushSoftness);
      if (straight) ed.lineTo(u.dx, u.dy);
      if (e.kind == PointerDeviceKind.touch) _hover = e.localPosition;
    }
    if (drag.kind == _G.crop) _cropping = true;
    setState(() {});
  }

  bool _fingerNavigates(PointerDownEvent e) {
    if (e.kind != PointerDeviceKind.touch) return false;
    final setting = widget.fingerDraws;
    return setting == null ? _penSeen : !setting;
  }

  UiCropHandle? _handleAt(Offset local, UiImageCrop c, bool touch) {
    final r = Rect.fromPoints(_toLocal(Offset(c.x.toDouble(), c.y.toDouble())), _toLocal(Offset((c.x + c.width).toDouble(), (c.y + c.height).toDouble())));
    final reach = touch ? 22.0 : 11.0;
    UiCropHandle? best;
    var bestD = double.infinity;
    for (final (h, fx, fy) in _handles) {
      final d = (Offset(r.left + r.width * fx, r.top + r.height * fy) - local).distance;
      if (d <= reach && d < bestD) {
        best = h;
        bestD = d;
      }
    }
    return best;
  }

  void _move(PointerMoveEvent e) {
    if (e.kind != PointerDeviceKind.touch || _drag?.kind == _G.paint) _hover = e.localPosition;
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.localPosition;
    final pinch = _pinch;
    if (pinch != null && _pointers.length >= 2) {
      final pts = _pointers.values.toList();
      final mid = (pts[0] + pts[1]) / 2;
      final dist = math.max(1.0, (pts[0] - pts[1]).distance);
      setState(() {
        _zoom = (pinch.zoom * dist / pinch.dist).clamp(_minZoom, _maxZoom);
        // Keep the spot that was between the fingers between them.
        _center = pinch.world - (mid - _size.center(Offset.zero)) / _px;
      });
      return;
    }
    final d = _drag;
    final ed = _c._edit;
    if (d == null || ed == null || e.pointer != d.pointer) {
      setState(() {});
      return;
    }
    if (d.kind == _G.paint) {
      final u = _toUnits(e.localPosition);
      ed.strokeTo(u.dx, u.dy);
      setState(() {});
      return;
    }
    if (!d.moved && (e.localPosition - d.startLocal).distance < (e.kind == PointerDeviceKind.touch ? 6 : 2)) return;
    d.moved = true;
    if (d.kind == _G.pan) {
      setState(() => _center = d.startCenter - (e.localPosition - d.startLocal) / _px);
      return;
    }
    final u = _toUnits(e.localPosition);
    ed.setCrop(dragCrop(d.start!, d.handle!, u.dx - d.startUnits.dx, u.dy - d.startUnits.dy, ed.width, ed.height, _c.aspect));
    _c._notify();
  }

  void _hoverAt(PointerHoverEvent e) {
    if (e.kind == PointerDeviceKind.touch) return;
    setState(() => _hover = e.localPosition);
  }

  void _up(PointerEvent e, {bool cancelled = false}) {
    if (_pointers.remove(e.pointer) == null) return;
    if (_pinch != null) {
      if (_pointers.length < 2) setState(() => _pinch = null);
      return;
    }
    final d = _drag;
    if (d == null || e.pointer != d.pointer) return;
    if (cancelled) {
      _abort();
      return;
    }
    _drag = null;
    _penPainting = false;
    _cropping = false;
    if (e.kind == PointerDeviceKind.touch) _hover = null;
    final ed = _c._edit;
    if (ed != null) {
      if (d.kind == _G.paint) {
        final u = _toUnits(e.localPosition);
        ed.strokeTo(u.dx, u.dy);
        // Where it lifted is where the next Shift-click's line starts (even if nothing changed).
        _c._lineStart = u;
        if (ed.endStroke()) _c._changed();
      } else if (d.kind == _G.crop) {
        if (ed.commitCrop(ed.crop, d.start)) {
          _c._changed();
        } else {
          _c._notify();
        }
      }
    }
    setState(() {});
  }

  /// Drops a stroke or crop drag in progress, putting things back as they were.
  void _abort() {
    final d = _drag;
    _drag = null;
    _penPainting = false;
    _cropping = false;
    final ed = _c._edit;
    if (d == null || ed == null) return;
    if (d.kind == _G.paint) ed.cancelStroke();
    if (d.kind == _G.crop) {
      ed.setCrop(d.start!);
      _c._notify();
    }
  }

  void _wheel(PointerSignalEvent e) {
    if (e is! PointerScrollEvent) return;
    // A plain wheel belongs to the page; Ctrl/Cmd + wheel zooms about the pointer.
    final k = HardwareKeyboard.instance;
    if (!k.isControlPressed && !k.isMetaPressed) return;
    GestureBinding.instance.pointerSignalResolver.register(e, (event) {
      final s = event as PointerScrollEvent;
      final world = _toUnits(s.localPosition);
      setState(() {
        _zoom = (_zoom * math.exp(-s.scrollDelta.dy * 0.01)).clamp(_minZoom, _maxZoom);
        _center = world - (s.localPosition - _size.center(Offset.zero)) / _px;
      });
    });
  }

  // ----- Keyboard --------------------------------------------------------------------------------

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.space) {
      final down = e is! KeyUpEvent;
      if (down != _space) setState(() => _space = down);
      return KeyEventResult.handled;
    }
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    final keys = HardwareKeyboard.instance;
    final mod = keys.isControlPressed || keys.isMetaPressed;
    if (mod && k == LogicalKeyboardKey.keyZ) {
      if (keys.isShiftPressed) {
        _c.redo();
      } else {
        _c.undo();
      }
      return KeyEventResult.handled;
    }
    if (mod && k == LogicalKeyboardKey.keyY) {
      _c.redo();
      return KeyEventResult.handled;
    }
    if (!mod && (k == LogicalKeyboardKey.bracketLeft || k == LogicalKeyboardKey.bracketRight)) {
      _c.brushSize = uiStepBrush(_c.brushSize, k == LogicalKeyboardKey.bracketRight ? 1 : -1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ----- Build -----------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return LayoutBuilder(builder: (context, box) {
      final size = Size(box.maxWidth.isFinite ? box.maxWidth : 400, box.maxHeight.isFinite ? box.maxHeight : 300);
      if (size != _size) _size = size;
      final e = _c._edit;
      if (e != null && !_fitted) {
        _fitted = true;
        final whole = fullCrop(e.width, e.height);
        final c = _c.mode == UiImageEditorMode.crop ? whole : e.crop;
        final base = _fitScale(e.width.toDouble(), e.height.toDouble());
        _zoom = (_fitScale(c.width.toDouble(), c.height.toDouble()) / base).clamp(_minZoom, _maxZoom);
        _center = c.rect.center;
      }
      final mode = _c.mode;
      final painting = mode != UiImageEditorMode.crop;
      final painter = _ImageEditorPainter(
        tokens: t,
        size: _size,
        center: _center,
        px: _px,
        image: e == null ? null : Size(e.width.toDouble(), e.height.toDouble()),
        tiles: Map.of(_tiles),
        crop: e?.crop,
        mode: mode,
        cropping: _cropping,
        brush: painting && !_space && _hover != null ? (at: _hover!, r: _c.brushSize / 2 * _px, softness: _c.brushSoftness) : null,
        linePreview: _linePreview,
        ring: _ring,
      );
      return Semantics(
        container: true,
        focusable: true,
        label: widget.label,
        value: e == null ? 'Loading' : '${e.width} by ${e.height} pixels, ${mode.name} mode',
        child: Focus(
          focusNode: _focus,
          onKeyEvent: _onKey,
          onFocusChange: (v) => setState(() {
            _ring = v && FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
            if (!v) _space = false;
          }),
          child: MouseRegion(
            cursor: _space ? SystemMouseCursors.grab : (painting ? SystemMouseCursors.precise : MouseCursor.defer),
            onExit: (_) => setState(() => _hover = null),
            child: RawGestureDetector(
              behavior: HitTestBehavior.opaque,
              gestures: {_ImageEditorClaim: GestureRecognizerFactoryWithHandlers<_ImageEditorClaim>(_ImageEditorClaim.new, (_) {})},
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _down,
                onPointerMove: _move,
                onPointerUp: _up,
                onPointerCancel: (e) => _up(e, cancelled: true),
                onPointerHover: _hoverAt,
                onPointerSignal: _wheel,
                child: ClipRect(child: CustomPaint(painter: painter, size: _size)),
              ),
            ),
          ),
        ),
      );
    });
  }
}

/// One `[` or `]`: a pixel at a time below 10, then about a fifth at a time.
double uiStepBrush(double size, int dir) {
  if (dir > 0) return math.min(1000, size < 10 ? size.floorToDouble() + 1 : (size * 1.2 + 0.5).floorToDouble());
  return math.max(1, size <= 10 ? size.ceilToDouble() - 1 : (size / 1.2 + 0.5).floorToDouble());
}

/// Takes every pointer that lands on the editor, so a scroll view or page swipe around it never
/// steals a stroke, whatever the touch slop.
class _ImageEditorClaim extends OneSequenceGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolvePointer(event.pointer, GestureDisposition.accepted);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerUpEvent || event is PointerCancelEvent) stopTrackingPointer(event.pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'image editor claim';
}

class _ImageEditorPainter extends CustomPainter {
  _ImageEditorPainter({
    required this.tokens,
    required this.size,
    required this.center,
    required this.px,
    required this.image,
    required this.tiles,
    required this.crop,
    required this.mode,
    required this.cropping,
    required this.brush,
    required this.linePreview,
    required this.ring,
  });

  final UiTokens tokens;
  final Size size;
  final Offset center;
  final double px;
  final Size? image;
  final Map<int, ui.Image> tiles;
  final UiImageCrop? crop;
  final UiImageEditorMode mode;
  final bool cropping;
  final ({Offset at, double r, double softness})? brush;
  final (Offset, Offset)? linePreview;
  final bool ring;

  Offset _screen(double x, double y) => Offset(size.width / 2 + (x - center.dx) * px, size.height / 2 + (y - center.dy) * px);

  @override
  void paint(Canvas canvas, Size _) {
    final t = tokens;
    canvas.drawRect(Offset.zero & size, Paint()..color = t.surfaceSubtle);
    final img = image;
    if (img != null) {
      final rect = Rect.fromPoints(_screen(0, 0), _screen(img.width, img.height));
      final visible = rect.intersect(Offset.zero & size);
      // The checkerboard shows through whatever is erased: about 10 screen pixels a square.
      if (!visible.isEmpty) {
        canvas.drawRect(visible, Paint()..color = t.surface);
        final dark = Paint()..color = Color.lerp(t.surface, t.text, 0.14)!;
        const sq = 10.0;
        final i0 = ((visible.left - rect.left) / sq).floor(), i1 = ((visible.right - rect.left) / sq).ceil();
        final j0 = ((visible.top - rect.top) / sq).floor(), j1 = ((visible.bottom - rect.top) / sq).ceil();
        canvas.save();
        canvas.clipRect(visible);
        for (var j = j0; j < j1; j++) {
          for (var i = i0 + ((i0 + j).isOdd ? 1 : 0); i < i1; i += 2) {
            canvas.drawRect(Rect.fromLTWH(rect.left + i * sq, rect.top + j * sq, sq, sq), dark);
          }
        }
        canvas.restore();
      }
      final cols = (img.width / _displayTile).ceil();
      final paint = Paint()..filterQuality = px > 3 ? FilterQuality.none : FilterQuality.medium;
      for (final entry in tiles.entries) {
        final x = (entry.key % cols) * _displayTile.toDouble(), y = (entry.key ~/ cols) * _displayTile.toDouble();
        final tile = entry.value;
        final dst = Rect.fromPoints(_screen(x, y), _screen(x + tile.width, y + tile.height));
        if (!dst.overlaps(Offset.zero & size)) continue;
        canvas.drawImageRect(tile, Rect.fromLTWH(0, 0, tile.width.toDouble(), tile.height.toDouble()), dst, paint);
      }
      canvas.drawRect(rect, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = t.border);
    }
    final c = crop;
    if (c != null) {
      final f = Rect.fromPoints(_screen(c.x.toDouble(), c.y.toDouble()), _screen((c.x + c.width).toDouble(), (c.y + c.height).toDouble()));
      final cropMode = mode == UiImageEditorMode.crop;
      // Outside the crop is dimmed; more when erasing, where it's only context.
      final dim = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect((Offset.zero & size).inflate(1))
        ..addRect(f);
      canvas.drawPath(dim, Paint()..color = t.overlay.withValues(alpha: t.overlay.a * (cropMode ? 0.8 : 0.9)));
      // Chrome over the picture uses the media colours: light on a dark outline, whatever the theme.
      final shadow = Paint()
        ..style = PaintingStyle.stroke
        ..color = t.mediaScrim.withValues(alpha: 0.5)
        ..strokeWidth = 3;
      final line = Paint()
        ..style = PaintingStyle.stroke
        ..color = t.mediaOnScrim
        ..strokeWidth = 1.5;
      if (cropMode) {
        canvas.drawRect(f, shadow);
        canvas.drawRect(f, line);
        if (cropping) {
          final third = Paint()
            ..color = t.mediaOnScrim.withValues(alpha: 0.7)
            ..strokeWidth = 1;
          for (final k in const [1 / 3, 2 / 3]) {
            canvas.drawLine(Offset(f.left + f.width * k, f.top), Offset(f.left + f.width * k, f.bottom), third);
            canvas.drawLine(Offset(f.left, f.top + f.height * k), Offset(f.right, f.top + f.height * k), third);
          }
        }
        final l = math.max(6.0, math.min(18.0, math.min(f.width / 3, f.height / 3)));
        final markShadow = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 6
          ..color = t.mediaScrim.withValues(alpha: 0.45);
        final mark = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 4
          ..color = t.mediaOnScrim;
        for (final (_, fx, fy) in _handles) {
          final x = f.left + f.width * fx, y = f.top + f.height * fy;
          final p = Path();
          if (fx != 0.5 && fy != 0.5) {
            final ix = fx == 0 ? 1 : -1, iy = fy == 0 ? 1 : -1;
            p
              ..moveTo(x, y + iy * l)
              ..lineTo(x, y)
              ..lineTo(x + ix * l, y);
          } else if (fx == 0.5) {
            p
              ..moveTo(x - l / 2, y)
              ..lineTo(x + l / 2, y);
          } else {
            p
              ..moveTo(x, y - l / 2)
              ..lineTo(x, y + l / 2);
          }
          canvas.drawPath(p, markShadow);
          canvas.drawPath(p, mark);
        }
      } else {
        _dashedRect(canvas, f, line..color = t.mediaOnScrim.withValues(alpha: 0.7));
      }
    }
    final line = linePreview;
    if (line != null) {
      final (a, z) = line;
      canvas.drawLine(a, z, Paint()
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = t.mediaScrim.withValues(alpha: 0.35));
      final len = (z - a).distance;
      if (len > 0) {
        final dir = (z - a) / len;
        final dash = Paint()
          ..strokeWidth = 1.25
          ..strokeCap = StrokeCap.round
          ..color = t.mediaOnScrim.withValues(alpha: 0.75);
        for (var d = 0.0; d < len; d += 9) {
          canvas.drawLine(a + dir * d, a + dir * math.min(len, d + 5), dash);
        }
      }
    }
    final b = brush;
    if (b != null) {
      canvas.drawCircle(b.at, b.r, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = t.mediaScrim.withValues(alpha: 0.5));
      canvas.drawCircle(b.at, b.r, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25
        ..color = t.mediaOnScrim);
      final inner = b.r * (1 - b.softness.clamp(0.0, 1.0));
      if (inner > 2 && inner < b.r - 2) {
        canvas.drawCircle(b.at, inner, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = t.mediaOnScrim.withValues(alpha: 0.6));
      }
      if (b.r < 4) canvas.drawCircle(b.at, 1.5, Paint()..color = t.mediaOnScrim);
    }
    if (ring) {
      canvas.drawRect((Offset.zero & size).deflate(1), Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = t.borderFocus);
    }
  }

  void _dashedRect(Canvas canvas, Rect r, Paint paint) {
    for (final (a, b) in [(r.topLeft, r.topRight), (r.topRight, r.bottomRight), (r.bottomRight, r.bottomLeft), (r.bottomLeft, r.topLeft)]) {
      final len = (b - a).distance;
      if (len == 0) continue;
      final dir = (b - a) / len;
      for (var d = 0.0; d < len; d += 8) {
        canvas.drawLine(a + dir * d, a + dir * math.min(len, d + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_ImageEditorPainter old) => true;
}
