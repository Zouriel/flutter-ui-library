import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../core/interactive.dart';
import '../core/types.dart';
import '../theme/theme.dart';

/// `ui-card`: a surface with optional [header] and [footer] (the web `[card-header]` /
/// `[card-footer]` slots). With [onTap] the whole card is the target: it lifts on hover and press
/// and shows the focus ring around the card.
class UiCard extends StatelessWidget {
  const UiCard({
    super.key,
    required this.child,
    this.header,
    this.footer,
    this.padding = UiSize.md,
    this.glass,
    this.radius,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final Widget? header;
  final Widget? footer;
  final UiSize padding;
  final bool? glass;
  final bool? radius;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final isGlass = glass ?? theme.config.glass;
    final r = (radius ?? theme.config.radius) ? t.radiusLg : 0.0;
    final pad = switch (padding) { UiSize.sm => t.space3, UiSize.md => t.space4, UiSize.lg => t.space6, UiSize.xl => t.space8 };

    Widget body(UiStates s) {
      final lifted = s.hovered || s.pressed;
      Widget card = AnimatedContainer(
        duration: context.uiAnimate ? t.motionBase : Duration.zero,
        curve: t.easeStandard,
        transform: context.uiAnimate && onTap != null && lifted ? Matrix4.translationValues(0, s.pressed ? -1 : -2, 0) : Matrix4.identity(),
        decoration: BoxDecoration(
          color: isGlass ? t.glassBg : t.surface,
          borderRadius: BorderRadius.circular(r),
          border: Border.all(color: isGlass ? t.glassBorder : (onTap != null && lifted ? t.borderStrong : t.border)),
          boxShadow: [...(onTap != null && lifted ? t.shadow2 : t.shadow1), if (s.focused) ...t.focusRing],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (header != null) _Section(pad: pad, border: Border(bottom: BorderSide(color: t.border)), child: header!),
              Padding(padding: EdgeInsets.all(pad), child: child),
              if (footer != null) _Section(pad: pad, border: Border(top: BorderSide(color: t.border)), child: footer!),
            ],
          ),
        ),
      );
      if (isGlass) {
        card = ClipRRect(
          borderRadius: BorderRadius.circular(r),
          child: BackdropFilter(filter: ImageFilter.blur(sigmaX: t.glassBlur / 2, sigmaY: t.glassBlur / 2), child: card),
        );
      }
      return card;
    }

    if (onTap == null) return body(const UiStates());
    return UiInteractive(
      onTap: onTap,
      button: true,
      semanticLabel: semanticLabel,
      padTouchTarget: false,
      pressScale: true,
      builder: (context, s) => body(s),
    );
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
