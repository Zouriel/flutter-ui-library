import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../theme/glass_sheet.dart';
import '../theme/theme.dart';

@visibleForTesting
int uiGlassBackdropDebugBuildCount = 0;

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
    required this.child,
  });

  /// The background image. With no image, cards keep their tint and rim but do not blur.
  final ImageProvider? image;

  /// A black overlay over the background, from transparent to opaque.
  final double dim;

  /// The background colour, painted below [image].
  final Color color;
  final Widget child;

  @override
  State<UiGlassBackdrop> createState() => _UiGlassBackdropState();
}

class _UiGlassBackdropState extends State<UiGlassBackdrop> {
  late final UiGlassBackdropModel _model = UiGlassBackdropModel();
  ImageStream? _stream;
  late final ImageStreamListener _listener = ImageStreamListener((info, _) {
    _model.setImage(info.image.clone());
    info.dispose();
  }, onError: (_, _) => _model.setImage(null));

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

  void _resolveImage() {
    final next = widget.image?.resolve(createLocalImageConfiguration(context));
    if (next?.key == _stream?.key && next != null) return;
    _stream?.removeListener(_listener);
    _stream = next;
    if (next == null) {
      _model.setImage(null);
    } else {
      next.addListener(_listener);
    }
  }

  bool _onScroll(ScrollNotification _) {
    // A scroll can move a repaint boundary at composite time. Repaint slices, but never rebuild
    // or regenerate the cached image for a scroll-only movement.
    _model.invalidateSlices();
    return false;
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _model.setTokens(context.ui);
    _model.setStyle(widget.color, widget.dim);
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: UiGlassBackdropScope(
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
  final LayerLink link = LayerLink();
  ui.Image? _image;
  ui.Image? _blurred;
  UiTokens? _tokens;
  Color _color = const Color(0x00000000);
  double _dim = 0;
  Size _size = Size.zero;
  int _generation = 0;
  bool _building = false;
  RenderBox? host;

  bool get hasBlur => _blurred != null && _size.width > 0 && _size.height > 0;
  Size get size => _size;

  void setTokens(UiTokens value) {
    if (_tokens == value) return;
    _tokens = value;
    _scheduleBuild();
  }

  void setStyle(Color color, double dim) {
    final nextDim = dim.clamp(0.0, 1.0).toDouble();
    if (_color == color && _dim == nextDim) return;
    _color = color;
    _dim = nextDim;
    _scheduleBuild();
    notifyListeners();
  }

  void setImage(ui.Image? value) {
    if (identical(value, _image)) return;
    _image?.dispose();
    _image = value;
    _blurred?.dispose();
    _blurred = null;
    _scheduleBuild();
    notifyListeners();
  }

  void setSize(Size value) {
    if (_size == value) return;
    _size = value;
    _blurred?.dispose();
    _blurred = null;
    _scheduleBuild();
  }

  void invalidateSlices() {
    if (hasBlur) notifyListeners();
  }

  void _scheduleBuild() {
    if (_image == null || _tokens == null || _size.isEmpty) return;
    final generation = ++_generation;
    if (_building) return;
    _building = true;
    unawaited(_build(generation));
  }

  Future<void> _build(int generation) async {
    try {
      uiGlassBackdropDebugBuildCount++;
      // A quarter-size cache is enough for a frosted surface and makes the expensive blur cheap.
      final scale = 0.25;
      final width = math.max(1, (_size.width * scale).ceil());
      final height = math.max(1, (_size.height * scale).ceil());
      final source = _image;
      final tokens = _tokens;
      if (source == null || tokens == null || _size.isEmpty) return;

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

      if (generation != _generation || source != _image || _size.isEmpty) {
        result.dispose();
        return;
      }
      _blurred?.dispose();
      _blurred = result;
      notifyListeners();
    } finally {
      _building = false;
      if (_image != null && _blurred == null && generation != _generation) {
        _scheduleBuild();
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    _image?.dispose();
    _blurred?.dispose();
    super.dispose();
  }
}

class _GlassBackgroundPainter extends CustomPainter {
  _GlassBackgroundPainter(this.model) : super(repaint: model);
  final UiGlassBackdropModel model;

  @override
  void paint(Canvas canvas, Size size) =>
      _paintBackground(canvas, size, model._image, model._color, model._dim);

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
  if (image != null && size.isFinite && !size.isEmpty) {
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
      Paint()..filterQuality = FilterQuality.high,
    );
  }
  if (dim > 0) {
    canvas.drawRect(
      bounds,
      Paint()..color = ui.Color.fromARGB(255, 0, 0, 0).withValues(alpha: dim),
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
    final image = model._blurred;
    final tokens = model._tokens;
    if (image == null || tokens == null) return;
    final paint = Paint()..filterQuality = FilterQuality.high;
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

  @override
  bool shouldRepaint(_StaticBlurPainter oldDelegate) =>
      oldDelegate.strength != strength || oldDelegate.model != model;
}
