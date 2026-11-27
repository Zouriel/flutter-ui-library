import 'dart:ui' as ui;
import 'dart:ui' show ImageFilter, TileMode;

import 'package:flutter/widgets.dart';

import '../core/interactive.dart';
import '../core/types.dart';
import '../layout/layout.dart';
import '../theme/glass_rim.dart';
import '../theme/glass_sheet.dart';
import '../theme/theme.dart';
import 'glass_backdrop.dart';

export 'glass_backdrop.dart' hide UiGlassBackdropModel, UiGlassBackdropScope, UiGlassBackdropSlice, uiGlassBackdropDebugBuildCount, uiGlassBackdropDebugDisposeCount;

/// `ui-card`: a surface with optional [header] and [footer] (the web `[card-header]` /
/// `[card-footer]` slots). Pass either [child] or [children] (laid out in a vertical column with
/// [gap] and [align]). With [onTap] the whole card is the target: it lifts on hover and press
/// and shows the focus ring around the card; set [enabled] false to disable it.
class UiCard extends StatelessWidget {
  const UiCard({
    super.key,
    this.child,
    this.children,
    this.header,
    this.footer,
    this.padding = UiSize.md,
    this.gap = 0,
    this.align = UiStackAlign.stretch,
    this.glass,
    this.glassStrength = UiCardGlassStrength.frosted,
    this.radius,
    this.onTap,
    this.enabled = true,
    this.semanticLabel,
  }) : assert((child == null) != (children == null), 'Provide either child or children.');

  final Widget? child;
  final List<Widget>? children;
  final Widget? header;
  final Widget? footer;
  final UiSize padding;

  /// Vertical spacing step between [children] (see [uiSpace]).
  final int gap;

  /// Cross-axis alignment for the card body.
  final UiStackAlign align;
  final bool? glass;
  /// How see-through a glass card is: frosted, AA-preserving clear, or Apple-style liquid glass.
  final UiCardGlassStrength glassStrength;
  final bool? radius;
  final VoidCallback? onTap;
  final bool enabled;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final isGlass = glass ?? theme.config.glass;
    final reducedTransparency = uiGlassSheetSolid(context);
    final strength = reducedTransparency && glassStrength == UiCardGlassStrength.liquid ? UiCardGlassStrength.frosted : glassStrength;
    final solid = isGlass && reducedTransparency && strength == UiCardGlassStrength.clear;
    final filteredGlass = isGlass && !solid;
    final liquid = filteredGlass && strength == UiCardGlassStrength.liquid;
    final r = (radius ?? theme.config.radius) ? t.radiusLg : 0.0;
    final pad = switch (padding) { UiSize.sm => t.space3, UiSize.md => t.space4, UiSize.lg => t.space6, UiSize.xl => t.space8 };
    final active = onTap != null && enabled;

    final crossAxis = switch (align) {
      UiStackAlign.start => CrossAxisAlignment.start,
      UiStackAlign.center => CrossAxisAlignment.center,
      UiStackAlign.end => CrossAxisAlignment.end,
      UiStackAlign.stretch => CrossAxisAlignment.stretch,
    };
    final bodyAlign = switch (align) {
      UiStackAlign.start => TextAlign.start,
      UiStackAlign.center => TextAlign.center,
      UiStackAlign.end => TextAlign.end,
      UiStackAlign.stretch => null,
    };
    Widget content = children != null
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: crossAxis,
            spacing: uiSpace(t, gap),
            children: children!,
          )
        : align == UiStackAlign.stretch
            ? child!
            : Align(
                alignment: switch (align) {
                  UiStackAlign.start => AlignmentDirectional.centerStart,
                  UiStackAlign.center => Alignment.center,
                  UiStackAlign.end => AlignmentDirectional.centerEnd,
                  UiStackAlign.stretch => AlignmentDirectional.centerStart,
                },
                child: child!,
              );
    if (bodyAlign != null) {
      content = DefaultTextStyle.merge(textAlign: bodyAlign, child: content);
    }

    Widget body(UiStates s) {
      final staticBackdrop = UiGlassBackdropScope.maybeOf(context);
      final lifted = active && (s.hovered || s.pressed);
      final fill = !filteredGlass
          ? t.surface
          : strength == UiCardGlassStrength.frosted
              ? t.glassBg
              : strength == UiCardGlassStrength.clear
                  ? t.surface.withValues(alpha: t.glassCardClearTint)
                  : t.glassLiquidBg;
      final border = liquid ? t.glassLiquidEdge : filteredGlass ? t.glassBorder : t.border;
      Widget card = AnimatedContainer(
        duration: context.uiAnimate ? t.motionBase : Duration.zero,
        curve: t.easeStandard,
        transform: context.uiAnimate && lifted ? Matrix4.translationValues(0, s.pressed ? -1 : -2, 0) : Matrix4.identity(),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(r),
          border: Border.all(color: border),
          boxShadow: [...(liquid ? const <BoxShadow>[] : lifted ? t.shadow2 : t.shadow1), if (s.focused) ...t.focusRing],
        ),
        // The rim inside the border, so it lifts with the card.
        child: liquid
            ? _LiquidSurface(
                borderRadius: BorderRadius.circular(r > 1 ? r - 1 : 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(r),
                  child: _halo(t, Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (header != null) _Section(pad: pad, border: Border(bottom: BorderSide(color: border)), child: header!),
                      Padding(padding: EdgeInsets.all(pad), child: content),
                      if (footer != null) _Section(pad: pad, border: Border(top: BorderSide(color: border)), child: footer!),
                    ],
                  )),
                ),
              )
            : UiGlassRim(
                enabled: filteredGlass,
                inset: 0,
                borderRadius: BorderRadius.circular(r > 1 ? r - 1 : 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(r),
                  child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (header != null) _Section(pad: pad, border: Border(bottom: BorderSide(color: t.border)), child: header!),
              Padding(padding: EdgeInsets.all(pad), child: content),
              if (footer != null) _Section(pad: pad, border: Border(top: BorderSide(color: t.border)), child: footer!),
            ],
          ),
        ),
        ),
      );
      if (filteredGlass) {
        if (staticBackdrop != null) {
          if (staticBackdrop.hasBlur) {
            // Static glass deliberately skips the liquid refraction shader: the backdrop copy is
            // already rasterized and aligned, so a live shader would put the per-card work back.
            card = UiGlassBackdropSlice(model: staticBackdrop, radius: BorderRadius.circular(r), strength: strength, child: card);
          }
        } else {
          final filter = strength == UiCardGlassStrength.clear
              ? uiGlassCardFilter(t)
              : strength == UiCardGlassStrength.liquid
                  ? _liquidFilter(t)
                  : ImageFilter.blur(sigmaX: t.glassBlur / 2, sigmaY: t.glassBlur / 2, tileMode: TileMode.clamp);
          card = ClipRRect(
            borderRadius: BorderRadius.circular(r),
            child: liquid ? _LiquidBackdropFilter(filter: filter, child: card) : BackdropFilter(filter: filter, child: card),
          );
        }
      }
      if (onTap != null && !enabled) {
        card = Opacity(opacity: 0.5, child: card);
      }
      return card;
    }

    if (onTap == null) return body(const UiStates());
    return UiInteractive(
      onTap: onTap,
      enabled: enabled,
      button: true,
      semanticLabel: semanticLabel,
      padTouchTarget: false,
      pressScale: true,
      builder: (context, s) => body(s),
    );
  }
}

List<double> _saturationMatrix(double s) => <double>[
      0.213 + 0.787 * s, 0.715 - 0.715 * s, 0.072 - 0.072 * s, 0, 0,
      0.213 - 0.213 * s, 0.715 + 0.285 * s, 0.072 - 0.072 * s, 0, 0,
      0.213 - 0.213 * s, 0.715 - 0.715 * s, 0.072 + 0.928 * s, 0, 0,
      0, 0, 0, 1, 0,
    ];

ImageFilter _liquidFilter(UiTokens t) => ImageFilter.compose(
      outer: ui.ColorFilter.matrix(_saturationMatrix(t.glassLiquidSaturate)),
      inner: ImageFilter.blur(sigmaX: t.glassLiquidBlur / 2, sigmaY: t.glassLiquidBlur / 2, tileMode: TileMode.clamp),
    );

Widget _halo(UiTokens t, Widget child) => DefaultTextStyle.merge(
      style: TextStyle(shadows: [
        Shadow(color: t.bg.withValues(alpha: 0.7), blurRadius: 1),
        Shadow(color: t.bg.withValues(alpha: 0.65), blurRadius: 8),
        Shadow(color: t.bg.withValues(alpha: 0.4), blurRadius: 18),
      ]),
      child: child,
    );

class _LiquidSurface extends StatelessWidget {
  const _LiquidSurface({required this.borderRadius, required this.child});
  final BorderRadius borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return CustomPaint(
      painter: _LiquidSurfacePainter(t, borderRadius),
      child: child,
    );
  }
}

class _LiquidSurfacePainter extends CustomPainter {
  _LiquidSurfacePainter(this.t, this.radius);
  final UiTokens t;
  final BorderRadius radius;

  @override
  void paint(Canvas canvas, Size size) {
    final box = radius.toRRect(Offset.zero & size);
    canvas.save();
    canvas.clipRRect(box);
    canvas.drawRect(Offset.zero & size, Paint()..shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [t.glassLiquidSheen, t.glassLiquidSheen.withValues(alpha: 0), t.glassLiquidRimShade.withValues(alpha: 0.12)],
      stops: const [0, 0.42, 1],
    ).createShader(Offset.zero & size));
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [t.glassLiquidRim, t.glassLiquidEdge, t.glassLiquidRimShade],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(box.deflate(0.75), rim);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LiquidSurfacePainter old) => old.t != t || old.radius != radius;
}

class _LiquidBackdropFilter extends StatefulWidget {
  const _LiquidBackdropFilter({required this.filter, required this.child});
  final ImageFilter filter;
  final Widget child;

  @override
  State<_LiquidBackdropFilter> createState() => _LiquidBackdropFilterState();
}

class _LiquidBackdropFilterState extends State<_LiquidBackdropFilter> {
  ui.FragmentProgram? _program;
  ui.FragmentShader? _shader;
  Size? _size;

  @override
  void initState() {
    super.initState();
    if (ui.ImageFilter.isShaderFilterSupported) _loadShader();
  }

  Future<void> _loadShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset('packages/zouriel_ui/shaders/liquid_glass.frag');
      if (!mounted) return;
      _program = program;
      setState(() {});
    } catch (_) {
      // A backend without runtime effects, or a web build without shader assets, keeps liquid glass
      // with its blur, saturation, rim and sheen; refraction is only an enhancement.
    }
  }

  void _measure() {
    final object = context.findRenderObject();
    if (object is! RenderBox || !object.hasSize || object.size == _size) return;
    _size = object.size;
    if (_program != null) setState(() {});
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    ImageFilter filter = widget.filter;
    if (_program != null && _size != null) {
      _shader ??= _program!.fragmentShader();
      _shader!
        ..setFloat(0, _size!.width)
        ..setFloat(1, _size!.height)
        ..setFloat(2, context.ui.radiusLg)
        ..setFloat(3, 24)
        ..setFloat(4, 0.55);
      try {
        filter = ImageFilter.compose(outer: ui.ImageFilter.shader(_shader!), inner: widget.filter);
      } catch (_) {
        filter = widget.filter;
      }
    }
    return BackdropFilter(filter: filter, child: widget.child);
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.pad, required this.border, required this.child});
  final double pad;
  final Border border;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(border: border),
        child: Padding(padding: EdgeInsets.symmetric(horizontal: pad, vertical: context.ui.space3), child: child),
      );
}

/// `ui-divider`: a 1px rule, horizontal or vertical, optionally with a centred [label].
class UiDivider extends StatelessWidget {
  const UiDivider({super.key, this.label, this.axis = Axis.horizontal, this.spacing});

  final String? label;
  final Axis axis;

  /// Space on both sides of the rule (defaults to the 12px token).
  final double? spacing;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final gap = spacing ?? t.space3;
    final line = ColoredBox(color: t.border);
    if (axis == Axis.vertical) {
      return Semantics(
        container: true,
        // Fills the row's height; in an unbounded column it falls back to one line of text.
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: gap),
          child: LayoutBuilder(builder: (context, box) => SizedBox(width: 1, height: box.maxHeight.isFinite ? box.maxHeight : t.fontSizeMd * 1.35, child: line)),
        ),
      );
    }
    if (label == null) {
      return Padding(padding: EdgeInsets.symmetric(vertical: gap), child: SizedBox(height: 1, width: double.infinity, child: line));
    }
    return Padding(
      padding: EdgeInsets.symmetric(vertical: gap),
      child: Row(spacing: t.space3, children: [
        Expanded(child: SizedBox(height: 1, child: line)),
        Text(label!, style: context.uiText.caption),
        Expanded(child: SizedBox(height: 1, child: line)),
      ]),
    );
  }
}

/// Skeleton shapes, the web `ui-skeleton` `shape`.
enum UiSkeletonShape { rect, circle, text }

/// `ui-skeleton`: a shimmering placeholder. Hidden from screen readers (announce loading elsewhere).
/// The shimmer stops under reduced motion.
class UiSkeleton extends StatefulWidget {
  const UiSkeleton({super.key, this.width, this.height, this.shape = UiSkeletonShape.rect});

  final double? width;
  final double? height;
  final UiSkeletonShape shape;

  @override
  State<UiSkeleton> createState() => _UiSkeletonState();
}

class _UiSkeletonState extends State<UiSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.uiAnimate) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final fontSize = DefaultTextStyle.of(context).style.fontSize ?? t.fontSizeMd;
    final h = widget.height ?? (widget.shape == UiSkeletonShape.text ? fontSize * 0.85 : widget.shape == UiSkeletonShape.circle ? widget.width ?? 40 : 16);
    final r = switch (widget.shape) {
      UiSkeletonShape.circle => BorderRadius.circular(9999),
      UiSkeletonShape.text => BorderRadius.circular(t.radiusXs),
      UiSkeletonShape.rect => BorderRadius.circular(t.radius),
    };
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          // The web background is 400% wide and slides from 100% to 0%: a highlight band moving
          // left to right across the shape.
          final p = Curves.ease.transform(_c.value);
          final shift = 1.5 - p * 3; // -1.5 .. 1.5 in alignment units
          return Container(
            width: widget.width,
            height: h,
            decoration: BoxDecoration(
              borderRadius: r,
              gradient: LinearGradient(
                begin: Alignment(-1 - shift, 0),
                end: Alignment(1 - shift, 0),
                colors: [t.skeletonBase, t.skeletonHighlight, t.skeletonBase],
                stops: const [0.25, 0.37, 0.63],
              ),
            ),
          );
        },
      ),
    );
  }
}
