import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../theme/theme.dart';

/// A Hugeicons icon: `HugeIcons.strokeRoundedHome01` and friends.
typedef UiIconData = List<List<dynamic>>;

/// Draws a Hugeicons icon that follows the surrounding [IconTheme] (size and colour) like a
/// native icon, so buttons, chips and menus can size and colour the icons they're given.
/// Decorative unless [semanticLabel] is set.
class UiIcon extends StatelessWidget {
  const UiIcon(this.icon, {super.key, this.size, this.color, this.strokeWidth, this.semanticLabel, this.matchTextDirection = false});

  final UiIconData icon;
  final double? size;
  final Color? color;

  /// Line weight; the library draws icons at 1.8 like the web components.
  final double? strokeWidth;
  final String? semanticLabel;

  /// Mirrors the icon in right-to-left text (0.46.0), for icons that mean a direction (back /
  /// forward chevrons and arrows). Icons that don't (play, check, search, logos) leave it off.
  final bool matchTextDirection;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    // Compact density draws every icon 10% smaller (a 20 icon at 18), like the web's
    // hugeicons-icon zoom: var(--ui-density-scale).
    final s = (size ?? theme.size ?? 20) * UiTheme.of(context).tokens.densityScale;
    Widget drawn = SizedBox.square(
      dimension: s,
      child: HugeIcon(icon: icon, size: s, color: color ?? theme.color ?? DefaultTextStyle.of(context).style.color, strokeWidth: strokeWidth ?? 1.8),
    );
    if (matchTextDirection && Directionality.maybeOf(context) == TextDirection.rtl) drawn = Transform.flip(flipX: true, child: drawn);
    return semanticLabel == null ? ExcludeSemantics(child: drawn) : Semantics(label: semanticLabel, image: true, child: ExcludeSemantics(child: drawn));
  }
}
