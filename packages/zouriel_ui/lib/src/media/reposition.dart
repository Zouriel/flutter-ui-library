import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../button/button.dart';
import '../core/types.dart';
import '../theme/theme.dart';

@immutable
class UiRepositionPosition {
  const UiRepositionPosition({this.x = 50, this.y = 50});
  final double x;
  final double y;

  UiRepositionPosition clamped() => UiRepositionPosition(x: x.clamp(0, 100), y: y.clamp(0, 100));

  @override
  bool operator ==(Object other) => other is UiRepositionPosition && other.x == x && other.y == y;
  @override
  int get hashCode => Object.hash(x, y);
}

/// Flutter twin of `ui-reposition`: edits a cover-image focal point in place, without a route.
class UiReposition extends StatefulWidget {
  const UiReposition({
    super.key,
    required this.image,
    this.position = const UiRepositionPosition(),
    this.active = false,
    this.circle = false,
    this.semanticLabel = 'Photo',
    this.onSave,
    this.onCancel,
    this.onImageError,
    this.imageSize,
  });

  final ImageProvider image;
  final UiRepositionPosition position;
  final bool active;
  final bool circle;
  final String semanticLabel;
  final ValueChanged<UiRepositionPosition>? onSave;
  final VoidCallback? onCancel;
  final VoidCallback? onImageError;
  /// Known intrinsic size, useful for already-decoded/generated images; normally resolved automatically.
  final Size? imageSize;

  @override
  State<UiReposition> createState() => UiRepositionState();
}

class UiRepositionState extends State<UiReposition> {
  final _frameKey = GlobalKey();
  final _focusNode = FocusNode(debugLabel: 'UiReposition');
  OverlayEntry? _entry;
  ui.Image? _resolved;
  ImageStream? _stream;
  ImageStreamListener? _listener;
  UiRepositionPosition _draft = const UiRepositionPosition();
  int? _pointer;
  Offset _dragAt = Offset.zero;
  UiRepositionPosition _dragStart = const UiRepositionPosition();

  @visibleForTesting
  UiRepositionPosition get draftPosition => _draft;
  @visibleForTesting
  bool get editorOpen => _entry != null;
  @visibleForTesting
  bool get layoutReady => _layout() != null;
  @visibleForTesting
  bool get frameReady => _frameRect() != null;
  @visibleForTesting
  bool get renderImageReady => _resolved != null || _renderImage()?.image != null;

  @override
  void initState() {
    super.initState();
    _draft = widget.position.clamped();
    _resolve();
    if (widget.active) WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  @override
  void didUpdateWidget(UiReposition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) _resolve();
    if (!widget.active && oldWidget.position != widget.position) _draft = widget.position.clamped();
    if (!oldWidget.active && widget.active) {
      _draft = widget.position.clamped();
      WidgetsBinding.instance.addPostFrameCallback((_) => _open());
    } else if (oldWidget.active && !widget.active) {
      _close();
    }
    _entry?.markNeedsBuild();
  }

  void _resolve() {
    if (_stream != null && _listener != null) _stream!.removeListener(_listener!);
    final stream = widget.image.resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener((info, _) {
      _resolved = info.image;
      _entry?.markNeedsBuild();
    }, onError: (error, stack) => widget.onImageError?.call());
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  void _open() {
    if (!mounted || !widget.active || _entry != null) return;
    _entry = OverlayEntry(builder: _buildEditor);
    Overlay.of(context, rootOverlay: true).insert(_entry!);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  void _close() { _entry?.remove(); _entry?.dispose(); _entry = null; }

  Rect? _frameRect() {
    final box = _frameKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  RenderImage? _renderImage() {
    final root = _frameKey.currentContext?.findRenderObject();
    RenderImage? found;
    void visit(RenderObject child) {
      if (child is RenderImage) { found = child; return; }
      child.visitChildren(visit);
    }
    if (root is RenderImage) return root;
    root?.visitChildren(visit);
    return found;
  }

  ({Rect frame, Rect photo})? _layout() {
    final frame = _frameRect();
    final image = _resolved ?? _renderImage()?.image;
    final intrinsic = widget.imageSize ?? (image == null ? null : Size(image.width.toDouble(), image.height.toDouble()));
    if (frame == null || intrinsic == null || frame.isEmpty) return null;
    final scale = math.max(frame.width / intrinsic.width, frame.height / intrinsic.height);
    final size = Size(intrinsic.width * scale, intrinsic.height * scale);
    final photo = Rect.fromLTWH(
      frame.left + (frame.width - size.width) * _draft.x / 100,
      frame.top + (frame.height - size.height) * _draft.y / 100,
      size.width, size.height,
    );
    return (frame: frame, photo: photo);
  }

  void _move(Offset delta) {
    final l = _layout(); if (l == null) return;
    final dx = l.photo.width > l.frame.width ? delta.dx / (l.frame.width - l.photo.width) * 100 : 0.0;
    final dy = l.photo.height > l.frame.height ? delta.dy / (l.frame.height - l.photo.height) * 100 : 0.0;
    _draft = UiRepositionPosition(
      x: l.photo.width > l.frame.width ? (_dragStart.x + dx).clamp(0, 100) : 50,
      y: l.photo.height > l.frame.height ? (_dragStart.y + dy).clamp(0, 100) : 50,
    );
    _entry?.markNeedsBuild();
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.enter) { widget.onSave?.call(_draft); return KeyEventResult.handled; }
    if (event.logicalKey == LogicalKeyboardKey.escape) { _draft = widget.position.clamped(); _entry?.markNeedsBuild(); widget.onCancel?.call(); return KeyEventResult.handled; }
    final l = _layout(); if (l == null) return KeyEventResult.ignored;
    final step = HardwareKeyboard.instance.isShiftPressed ? 10.0 : 1.0;
    var x = _draft.x, y = _draft.y, handled = false;
    if (l.photo.width > l.frame.width) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) { x -= step; handled = true; }
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) { x += step; handled = true; }
    }
    if (l.photo.height > l.frame.height) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) { y -= step; handled = true; }
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) { y += step; handled = true; }
    }
    if (handled) { _draft = UiRepositionPosition(x: x.clamp(0, 100), y: y.clamp(0, 100)); _entry?.markNeedsBuild(); }
    return handled ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  Widget _buildEditor(BuildContext context) {
    final l = _layout();
    if (l == null) return const SizedBox.shrink();
    final t = context.ui;
    final viewport = MediaQuery.sizeOf(context);
    final below = l.frame.bottom + t.space2;
    final actionsTop = below + 48 <= viewport.height ? below : math.max(t.space2, l.frame.top - 48 - t.space2);
    final clip = widget.circle ? ClipOval.new : ClipRect.new;
    final positionText = 'Photo position ${_draft.x.round()} percent horizontal, ${_draft.y.round()} percent vertical';
    Widget image(Rect rect) => Positioned.fromRect(rect: rect, child: Image(image: widget.image, fit: BoxFit.fill, excludeFromSemantics: true, errorBuilder: (context, error, stack) => const SizedBox.expand()));
    return Directionality(
      textDirection: Directionality.of(this.context),
      child: Focus(
        focusNode: _focusNode,
        onKeyEvent: _key,
        child: Semantics(
          liveRegion: true,
          label: 'Reposition photo',
          value: positionText,
          child: Stack(children: [
            Positioned.fill(child: Listener(behavior: HitTestBehavior.opaque, child: CustomPaint(painter: _RepositionScrim(t.overlay, l.frame, widget.circle)))),
            Opacity(opacity: .28, child: Stack(children: [image(l.photo)])),
            Positioned.fromRect(
              rect: l.frame,
              child: clip(
                child: Stack(clipBehavior: Clip.hardEdge, children: [
                  Positioned.fromRect(rect: l.photo.shift(-l.frame.topLeft), child: Image(image: widget.image, fit: BoxFit.fill, excludeFromSemantics: true, errorBuilder: (context, error, stack) => const SizedBox.expand())),
                  Positioned.fill(child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (e) { _pointer = e.pointer; _dragAt = e.position; _dragStart = _draft; },
                    onPointerMove: (e) { if (_pointer == e.pointer) _move(e.position - _dragAt); },
                    onPointerUp: (e) { if (_pointer == e.pointer) _pointer = null; },
                    onPointerCancel: (e) { if (_pointer == e.pointer) _pointer = null; },
                  )),
                ]),
              ),
            ),
            Positioned(
              top: actionsTop,
              left: 0,
              right: 0,
              child: Center(child: DecoratedBox(
                decoration: BoxDecoration(color: t.surfaceRaised, borderRadius: BorderRadius.circular(t.radius), boxShadow: t.shadow2),
                child: Padding(
                  padding: EdgeInsets.all(t.space2),
                  child: Row(mainAxisSize: MainAxisSize.min, spacing: t.space2, children: [
                    UiButton(label: 'Cancel', variant: UiButtonVariant.secondary, size: UiSize.sm, onPressed: () { _draft = widget.position.clamped(); _entry?.markNeedsBuild(); widget.onCancel?.call(); }),
                    UiButton(label: 'Save', size: UiSize.sm, onPressed: () => widget.onSave?.call(_draft)),
                  ]),
                ),
              )),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final alignment = Alignment(_draft.x / 50 - 1, _draft.y / 50 - 1);
    final image = Image(key: _frameKey, image: widget.image, fit: BoxFit.cover, alignment: alignment, width: double.infinity, height: double.infinity, semanticLabel: widget.semanticLabel,
      frameBuilder: (context, child, frame, synchronous) { if (frame != null) WidgetsBinding.instance.addPostFrameCallback((_) => _entry?.markNeedsBuild()); return child; },
      errorBuilder: (context, error, stack) { widget.onImageError?.call(); return const SizedBox.expand(); });
    return widget.circle ? ClipOval(child: image) : ClipRect(child: image);
  }

  @override
  void dispose() {
    _close();
    if (_stream != null && _listener != null) _stream!.removeListener(_listener!);
    _focusNode.dispose();
    super.dispose();
  }
}

class _RepositionScrim extends CustomPainter {
  const _RepositionScrim(this.color, this.frame, this.circle);
  final Color color;
  final Rect frame;
  final bool circle;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..fillType = PathFillType.evenOdd..addRect(Offset.zero & size);
    if (circle) { path.addOval(frame); } else { path.addRect(frame); }
    canvas.drawPath(path, Paint()..color = color);
  }
  @override
  bool shouldRepaint(_RepositionScrim old) => old.color != color || old.frame != frame || old.circle != circle;
}
