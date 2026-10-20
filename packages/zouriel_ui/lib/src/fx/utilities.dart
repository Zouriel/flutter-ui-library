import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'motion.dart';

// The web fx.css utility classes, with the maldives theme's signature motion from
// theme-animations.css. Only maldives' motion (day and night) is ported (the tide on the gradient, the shimmer on
// the glow); in the other themes these draw still. See docs/PORTING.md.

/// The themes with the sea signature motion: maldives and its night variant.
bool _seaMotion(UiThemeName name) => name == UiThemeName.maldives || name == UiThemeName.maldivesDark;

/// `.ui-gradient-text`: [text] filled with the theme's brand gradient. In maldives the gradient
/// washes slowly one way and back (the web `ui-fx-tide`, 14 seconds), at full motion only.
class UiGradientText extends StatefulWidget {
  const UiGradientText(this.text, {super.key, this.style, this.textAlign});

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  State<UiGradientText> createState() => _UiGradientTextState();
}

class _UiGradientTextState extends State<UiGradientText> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 14));

  bool _tide(BuildContext context) => _seaMotion(context.uiTheme.name) && uiFxMotion(context) == UiFxMotion.full;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_tide(context)) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.value = 0;
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
    final tide = _tide(context);
    final gradient = t.gradientBrand.toGradient();
    return Semantics(
      label: widget.text,
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          // The web sizes the gradient to 220% of the text and moves background-position 0% → 100% →
          // 0%, so at the far end the gradient's right edge meets the text's right edge.
          final v = _c.value, k = Curves.easeInOut.transform(v < 0.5 ? v * 2 : 2 - v * 2);
          return ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (b) {
              final w = tide ? b.width * 2.2 : b.width;
              return gradient.createShader(Rect.fromLTWH(b.left - (w - b.width) * k, b.top, w, b.height));
            },
            child: child,
          );
        },
        child: Text(widget.text, style: widget.style, textAlign: widget.textAlign),
      ),
    );
  }
}

/// `.ui-glow`: [child]'s text gets the theme's glow (`glowAmber`) as a text shadow. In maldives the
/// glow shimmers like light on water (the web `ui-fx-shimmer`, 8 seconds: a slow lift with a quick
/// glint), at full motion only; Flutter strengthens the glow rather than filtering brightness.
class UiGlow extends StatefulWidget {
  const UiGlow({super.key, required this.child});
  final Widget child;

  @override
  State<UiGlow> createState() => _UiGlowState();
}

class _UiGlowState extends State<UiGlow> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 8));

  bool _shimmer(BuildContext context) => _seaMotion(context.uiTheme.name) && uiFxMotion(context) == UiFxMotion.full;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_shimmer(context)) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// The web keyframes: brightness 1, 1.08 at 40%, 1.18 at 50%, 1.08 at 60%, back to 1.
  static double _lift(double v) {
    if (v <= 0.4) return 0.08 * (v / 0.4);
    if (v <= 0.5) return 0.08 + 0.10 * ((v - 0.4) / 0.1);
    if (v <= 0.6) return 0.18 - 0.10 * ((v - 0.5) / 0.1);
    return 0.08 * (1 - (v - 0.6) / 0.4);
  }

  @override
  Widget build(BuildContext context) {
    final glow = context.ui.glowAmber;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final gain = 1 + _lift(_c.value) / 0.18;
        final shadows = [
          for (final s in glow) Shadow(color: s.color.withValues(alpha: (s.color.a * gain).clamp(0, 1)), offset: s.offset, blurRadius: s.blurRadius),
        ];
        return DefaultTextStyle.merge(style: TextStyle(shadows: shadows), child: child!);
      },
    );
  }
}
