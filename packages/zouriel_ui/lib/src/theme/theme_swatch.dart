import 'package:flutter/widgets.dart';

import 'theme.dart';

/// The colours a [UiThemeSwatch] paints (the web `UiThemeSwatchColors`): a page, a card on it, text,
/// quieter text and the accent.
class UiThemeSwatchColors {
  const UiThemeSwatchColors({required this.bg, required this.surface, required this.text, required this.muted, required this.accent});
  final Color bg, surface, text, muted, accent;

  /// Reads `#rgb`, `#rrggbb` or `#rrggbbaa` (CSS order); null when it isn't one.
  static Color? parse(String? css) {
    if (css == null) return null;
    var h = css.trim();
    if (!h.startsWith('#')) return null;
    h = h.substring(1);
    if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
    if (h.length == 6) h = '${h}ff';
    if (h.length != 8) return null;
    final v = int.tryParse(h, radix: 16);
    if (v == null) return null;
    // CSS puts alpha last; Color wants it first.
    return Color(((v & 0xff) << 24) | (v >> 8));
  }

  /// From CSS colour strings (e.g. a server's theme options); null if any is missing or unreadable.
  static UiThemeSwatchColors? fromCss({required String? bg, required String? surface, required String? text, required String? muted, required String? accent}) {
    final b = parse(bg), s = parse(surface), t = parse(text), m = parse(muted), a = parse(accent);
    if (b == null || s == null || t == null || m == null || a == null) return null;
    return UiThemeSwatchColors(bg: b, surface: s, text: t, muted: m, accent: a);
  }
}

/// `ui-theme-swatch`: a small picture of a page in some colours (a card with two lines of text and
/// a button), for the picture in a [UiChoiceGrid] tile of a theme picker. [accent] replaces the
/// colours' accent (an accent picker over a theme). Decorative unless given a [label].
class UiThemeSwatch extends StatelessWidget {
  const UiThemeSwatch({super.key, required this.colors, this.accent, this.label});
  final UiThemeSwatchColors colors;
  final Color? accent;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final rounded = context.uiTheme.config.radius;
    final c = colors;
    final pill = accent ?? c.accent;
    Widget bar(double widthFactor, Color color, double h) => FractionallySizedBox(
          widthFactor: widthFactor,
          alignment: AlignmentDirectional.centerStart,
          child: Container(height: h, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(h / 2))),
        );
    final picture = AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
        decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(rounded ? t.radiusSm : 0), border: Border.all(color: c.muted.withValues(alpha: 0.35))),
        padding: EdgeInsets.all(t.space2),
        child: LayoutBuilder(builder: (context, box) {
          final unit = (box.maxHeight / 8).clamp(3.0, 12.0);
          return Container(
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(rounded ? t.radiusXs : 0), border: Border.all(color: c.muted.withValues(alpha: 0.3))),
            padding: EdgeInsets.all(unit),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              bar(0.7, c.text, unit),
              bar(0.5, c.muted, unit * 0.75),
              Container(width: unit * 6, height: unit * 2, decoration: BoxDecoration(color: pill, borderRadius: BorderRadius.circular(unit))),
            ]),
          );
        }),
      ),
    );
    return label == null ? ExcludeSemantics(child: picture) : Semantics(image: true, label: label, child: ExcludeSemantics(child: picture));
  }
}
