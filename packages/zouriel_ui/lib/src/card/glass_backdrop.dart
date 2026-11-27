import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../theme/glass_sheet.dart';
import '../theme/theme.dart';

@visibleForTesting
int uiGlassBackdropDebugBuildCount = 0;

@visibleForTesting
int uiGlassBackdropDebugDisposeCount = 0;

/// The three glass surfaces supported by the web `ui-card`.
enum UiCardGlassStrength { frosted, clear, liquid }

/// A static background for the glass cards inside it, the twin of
/// `ui-glass-backdrop`. The background is blurred once and cards paint aligned slices of it.
class UiGlassBackdrop extends StatefulWidget {
  const UiGlassBackdrop({
    super.key,
    this.image,
    this.dim = 0,
    this.color = const Color(0x00000000),
    this.transition,
    required this.child,
  });

  /// The background image. With no image, cards keep their tint and rim but do not blur.
  final ImageProvider? image;

  /// A black overlay over the background, from transparent to opaque.
  final double dim;

  /// The background colour, painted below [image].
  final Color color;

  /// The cross-fade duration when [image] changes. Defaults to [UiTokens.motionSlow].
  /// A zero duration swaps as soon as the image and its blurred copy are ready.
  final Duration? transition;
  final Widget child;

  @override
  State<UiGlassBackdrop> createState() => _UiGlassBackdropState();
}

class _UiGlassBackdropState extends State<UiGlassBackdrop>
    with SingleTickerProviderStateMixin {
  late final UiGlassBackdropModel _model = UiGlassBackdropModel(
    onReady: _startReadyLayer,
  );
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: Duration.zero,
  )..addListener(() => _model._setFadeProgress(_fade.value));
  ImageStream? _stream;
  late final ImageStreamListener _listener = ImageStreamListener((info, _) {
    _model.setImage(info.image.clone(), animate: true);
    info.dispose();
  }, onError: (_, _) => _model.setImage(null, animate: true));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _model.setTokens(context.ui);
    _resolveImage();
  }

  @override
  void didUpdateWidget(UiGlassBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) _resolveImage();
    _model.setStyle(widget.color, widget.dim);
  }

  Duration get _transition => widget.transition ?? context.ui.motionSlow;

  void _startReadyLayer() {
    if (!mounted) return;
    final layer = _model._takeReadyLayer();
    if (!_model.readyLayerWasRequested) return;
    final animate = _model.readyShouldAnimate &&
        _transition > Duration.zero &&
        context.uiAnimate;
    if (!animate || !_model.hasShownLayer) {
      _fade.stop();
      _model._commitReadyLayer(layer);
      return;
    }
    _model._beginFade(layer);
    _fade
      ..duration = _transition
      ..forward(from: 0);
  }

  void _resolveImage() {
    final next = widget.image?.resolve(createLocalImageConfiguration(context));
    if (next?.key == _stream?.key && next != null) return;
    _stream?.removeListener(_listener);
    _stream = next;
    if (next == null) {
      _model.setImage(null, animate: true);
    } else {
      next.addListener(_listener);
    }
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _fade.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _model.setTokens(context.ui);
    _model.setStyle(widget.color, widget.dim);
    // Slices follow the backdrop through a LayerLink, resolved when the frame is composited, so a
    // scroll or a moved repaint boundary needs no rebuild or repaint here.
    return UiGlassBackdropScope(
        model: _model,
        child: CompositedTransformTarget(
          link: _model.link,
          child: _UiGlassBackdropHost(
            model: _model,
            child: CustomPaint(
              painter: _GlassBackgroundPainter(_model),
              child: widget.child,
            ),
          ),
        ),
    );
  }
}

class UiGlassBackdropScope extends InheritedNotifier<UiGlassBackdropModel> {
  const UiGlassBackdropScope({super.key, required this.model, required super.child})
    : super(notifier: model);

  final UiGlassBackdropModel model;

  static UiGlassBackdropModel? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<UiGlassBackdropScope>()?.model;
}

class _UiGlassBackdropHost extends SingleChildRenderObjectWidget {
  const _UiGlassBackdropHost({required this.model, required super.child});

  final UiGlassBackdropModel model;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _GlassBackdropRenderBox(model);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _GlassBackdropRenderBox).model = model;
}

class _GlassBackdropRenderBox extends RenderProxyBox {
  _GlassBackdropRenderBox(this._model);

  UiGlassBackdropModel _model;
  Size? _laidOutSize;

  set model(UiGlassBackdropModel value) {
    if (value == _model) return;
    _model = value;
    markNeedsLayout();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _model.host = this;
  }

  @override
  void detach() {
    if (_model.host == this) _model.host = null;
    super.detach();
  }

  @override
  void performLayout() {
    super.performLayout();
    if (_laidOutSize != size) {
      _laidOutSize = size;
      _model.setSize(size);
    }
  }
}

class UiGlassBackdropModel extends ChangeNotifier {
  UiGlassBackdropModel({required this.onReady});

  final VoidCallback onReady;
  final LayerLink link = LayerLink();
  UiTokens? _tokens;
  Color _color = const Color(0x00000000);
  double _dim = 0;
  Size _size = Size.zero;
  int _generation = 0;
  bool _building = false;
  bool _disposed = false;
  ui.Image? _pendingImage;
  ui.Image? _buildingImage;
  bool _pendingAnimate = true;
  _BackdropLayer? _readyLayer;
  bool _readyLayerWasRequested = false;
  bool _readyShouldAnimate = true;
  _BackdropLayer? _current;
  List<_VisibleBackdropLayer> _from = <_VisibleBackdropLayer>[];
  _BackdropLayer? _target;
  bool _fading = false;
  double _fadeProgress = 1;
  final Set<_BackdropLayer> _owned = <_BackdropLayer>{};
  RenderBox? host;

  bool get hasBlur => _visibleLayers.isNotEmpty &&
      _size.width > 0 &&
      _size.height > 0;
  Size get size => _size;
  bool get hasShownLayer => _current != null || _from.isNotEmpty;
  bool get readyLayerWasRequested => _readyLayerWasRequested;
  bool get readyShouldAnimate => _readyShouldAnimate;

  List<_VisibleBackdropLayer> get _visibleLayers {
    final target = _target;
    if (!_fading) {
      return _current == null
          ? _from
          : <_VisibleBackdropLayer>[_VisibleBackdropLayer(_current!, 1)];
    }
    final fromOpacity = 1 - _fadeProgress;
    final visible = <_VisibleBackdropLayer>[];
    for (final layer in _from) {
      if (layer.opacity * fromOpacity > 0) {
        visible.add(_VisibleBackdropLayer(layer.layer, layer.opacity * fromOpacity));
      }
    }
    if (target != null && _fadeProgress > 0) {
      visible.add(_VisibleBackdropLayer(target, _fadeProgress));
    }
    return visible;
  }

  void setTokens(UiTokens value) {
    if (_tokens == value) return;
    _tokens = value;
    _rebuildCurrent();
    _scheduleBuild();
  }

  void setStyle(Color color, double dim) {
    final nextDim = dim.clamp(0.0, 1.0).toDouble();
    if (_color == color && _dim == nextDim) return;
    _color = color;
    _dim = nextDim;
    _rebuildCurrent();
    _scheduleBuild();
    notifyListeners();
  }

  void setImage(ui.Image? value, {required bool animate}) {
    _generation++;
    if (_pendingImage != null && !identical(_pendingImage, _buildingImage)) {
      _pendingImage!.dispose();
    }
    _pendingImage = value;
    _pendingAnimate = animate;
    _discardReadyLayer();
    _readyLayerWasRequested = true;
    _readyShouldAnimate = animate;
    if (value == null) {
      _pendingImage = null;
      onReady();
      return;
    }
    _scheduleBuild();
  }

  void setSize(Size value) {
    if (_size == value) return;
    _size = value;
    _rebuildCurrent();
    _scheduleBuild();
  }

  void _rebuildCurrent() {
    final image = _current?.image;
    if (image == null || _pendingImage != null) return;
    _generation++;
    _pendingImage = image.clone();
    _pendingAnimate = false;
  }

  void _scheduleBuild() {
    if (_pendingImage == null || _tokens == null || _size.isEmpty) return;
    final generation = _generation;
    if (_building) return;
    _building = true;
    _buildingImage = _pendingImage!;
    unawaited(_build(generation, _buildingImage!));
  }

  Future<void> _build(int generation, ui.Image source) async {
    try {
      uiGlassBackdropDebugBuildCount++;
      // A quarter-size cache is enough for a frosted surface and makes the expensive blur cheap.
      final scale = 0.25;
      final width = math.max(1, (_size.width * scale).ceil());
      final height = math.max(1, (_size.height * scale).ceil());
      final tokens = _tokens;
      if (tokens == null || _size.isEmpty) return;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final bounds = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
      canvas.saveLayer(
        bounds,
        Paint()
          // The shared copy uses the strongest card blur. Each card applies its own static
          // saturation/contrast matrix while painting its slice; there is still one image and no
          // per-card backdrop filter.
          ..imageFilter = ui.ImageFilter.blur(
            sigmaX:
                math.max(
                  tokens.glassBlur,
                  math.max(tokens.glassCardClearBlur, tokens.glassLiquidBlur),
                ) *
                scale /
                2,
            sigmaY:
                math.max(
                  tokens.glassBlur,
                  math.max(tokens.glassCardClearBlur, tokens.glassLiquidBlur),
                ) *
                scale /
                2,
            tileMode: TileMode.clamp,
          ),
      );
      canvas.scale(scale, scale);
      _paintBackground(canvas, _size, source, _color, _dim);
      canvas.restore();
      final picture = recorder.endRecording();
      final result = await picture.toImage(width, height);
      picture.dispose();

      if (generation != _generation || !identical(source, _pendingImage) || _size.isEmpty) {
        result.dispose();
        if (!identical(source, _pendingImage) && !_disposed) source.dispose();
        return;
      }
      _pendingImage = null;
      final layer = _BackdropLayer(source, result);
      _owned.add(layer);
      _discardReadyLayer();
      _readyLayer = layer;
      _readyShouldAnimate = _pendingAnimate;
      onReady();
    } finally {
      _building = false;
      _buildingImage = null;
      if (_pendingImage != null && generation != _generation) {
        _scheduleBuild();
      }
    }
  }

  _BackdropLayer? _takeReadyLayer() {
    final layer = _readyLayer;
    _readyLayer = null;
    return layer;
  }

  void _discardReadyLayer() {
    final layer = _readyLayer;
    if (layer == null) return;
    _readyLayer = null;
    _owned.remove(layer);
    layer.dispose();
  }

  void _commitReadyLayer(_BackdropLayer? layer) {
    if (layer == null) {
      _disposeExcept(null);
      _current = null;
      _from = <_VisibleBackdropLayer>[];
      _target = null;
      _fading = false;
    } else {
      _disposeExcept(layer);
      _current = layer;
      _from = <_VisibleBackdropLayer>[];
      _target = null;
      _fading = false;
    }
    _fadeProgress = 1;
    _readyLayerWasRequested = false;
    _readyShouldAnimate = true;
    notifyListeners();
  }

  void _beginFade(_BackdropLayer? layer) {
    _from = _visibleLayers;
    _target = layer;
    _fading = true;
    _fadeProgress = 0;
    _current = null;
    _readyLayerWasRequested = false;
    _readyShouldAnimate = true;
    notifyListeners();
  }

  void _setFadeProgress(double value) {
    if (!_fading || _fadeProgress == value) return;
    _fadeProgress = value.clamp(0.0, 1.0).toDouble();
    notifyListeners();
    if (_fadeProgress >= 1) {
      _commitReadyLayer(_target);
    }
  }

  void _disposeExcept(_BackdropLayer? keep) {
    for (final layer in _owned.toList()) {
      if (layer != keep) {
        layer.dispose();
        _owned.remove(layer);
      }
    }
    if (keep != null) {
      _owned.add(keep);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _pendingImage?.dispose();
    _readyLayer = null;
    for (final layer in _owned) {
      layer.dispose();
    }
    _owned.clear();
    super.dispose();
  }
}

class _BackdropLayer {
  _BackdropLayer(this.image, this.blurred);

  final ui.Image image;
  final ui.Image blurred;

  void dispose() {
    uiGlassBackdropDebugDisposeCount++;
    image.dispose();
    blurred.dispose();
  }
}

class _VisibleBackdropLayer {
  const _VisibleBackdropLayer(this.layer, this.opacity);

  final _BackdropLayer layer;
  final double opacity;
}

class _GlassBackgroundPainter extends CustomPainter {
  _GlassBackgroundPainter(this.model) : super(repaint: model);
  final UiGlassBackdropModel model;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(bounds, Paint()..color = model._color);
    for (final visible in model._visibleLayers) {
      _paintImage(canvas, size, visible.layer.image, visible.opacity);
    }
    if (model._dim > 0) {
      canvas.drawRect(
        bounds,
        Paint()..color = ui.Color.fromARGB(255, 0, 0, 0).withValues(alpha: model._dim),
      );
    }
  }

  @override
  bool shouldRepaint(_GlassBackgroundPainter oldDelegate) =>
      oldDelegate.model != model;
}

void _paintBackground(
  Canvas canvas,
  Size size,
  ui.Image? image,
  Color color,
  double dim,
) {
  final bounds = Offset.zero & size;
  canvas.drawRect(bounds, Paint()..color = color);
  _paintImage(canvas, size, image, 1);
  if (dim > 0) {
    canvas.drawRect(
      bounds,
      Paint()..color = ui.Color.fromARGB(255, 0, 0, 0).withValues(alpha: dim),
    );
  }
}

void _paintImage(Canvas canvas, Size size, ui.Image? image, double opacity) {
  if (image != null && opacity > 0 && size.isFinite && !size.isEmpty) {
    final bounds = Offset.zero & size;
    final fitted = applyBoxFit(
      BoxFit.cover,
      Size(image.width.toDouble(), image.height.toDouble()),
      size,
    );
    final input = Alignment.center.inscribe(
      fitted.source,
      Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
    );
    final output = Alignment.center.inscribe(fitted.destination, bounds);
    canvas.drawImageRect(
      image,
      input,
      output,
      Paint()
        ..filterQuality = FilterQuality.high
        ..color = ui.Color.fromARGB(255, 255, 255, 255).withValues(alpha: opacity),
    );
  }
}

List<double> _saturationMatrix(double s) => <double>[
  0.213 + 0.787 * s,
  0.715 - 0.715 * s,
  0.072 - 0.072 * s,
  0,
  0,
  0.213 - 0.213 * s,
  0.715 + 0.285 * s,
  0.072 - 0.072 * s,
  0,
  0,
  0.213 - 0.213 * s,
  0.715 - 0.715 * s,
  0.072 + 0.928 * s,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
];

class UiGlassBackdropSlice extends StatelessWidget {
  const UiGlassBackdropSlice({
    super.key,
    required this.model,
    required this.radius,
    required this.strength,
    required this.child,
  });

  final UiGlassBackdropModel model;
  final BorderRadius radius;
  final UiCardGlassStrength strength;
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: radius,
    child: Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: 0,
              maxWidth: double.infinity,
              minHeight: 0,
              maxHeight: double.infinity,
              child: CompositedTransformFollower(
                link: model.link,
                showWhenUnlinked: false,
                child: SizedBox(
                  width: model.size.width,
                  height: model.size.height,
                  child: CustomPaint(
                    painter: _StaticBlurPainter(model, strength),
                  ),
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    ),
  );
}

class _StaticBlurPainter extends CustomPainter {
  _StaticBlurPainter(this.model, this.strength) : super(repaint: model);
  final UiGlassBackdropModel model;
  final UiCardGlassStrength strength;

  @override
  void paint(Canvas canvas, Size size) {
    final tokens = model._tokens;
    if (tokens == null) return;
    for (final visible in model._visibleLayers) {
      final image = visible.layer.blurred;
      final paint = Paint()
        ..filterQuality = FilterQuality.high
        ..color = ui.Color.fromARGB(255, 255, 255, 255).withValues(alpha: visible.opacity);
      if (strength == UiCardGlassStrength.clear) {
        paint.colorFilter = ui.ColorFilter.matrix(uiGlassCardMatrix(tokens));
      } else if (strength == UiCardGlassStrength.liquid) {
        paint.colorFilter = ui.ColorFilter.matrix(
          _saturationMatrix(tokens.glassLiquidSaturate),
        );
      }
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Offset.zero & size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StaticBlurPainter oldDelegate) =>
      oldDelegate.strength != strength || oldDelegate.model != model;
}
