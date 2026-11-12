import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../theme/glass_rim.dart';
import '../theme/theme.dart';

/// Where a [UiAvatarTag] sits: [overlay] on a photo (a dark see-through pill), [plain] on an
/// ordinary surface.
enum UiAvatarTagVariant { overlay, plain }

/// [sm] (a 20dp picture) for a feed post, [xs] (16dp) for the corner of a small tile.
enum UiAvatarTagSize { sm, xs }

/// The first letter of a name, upper case, for the round fallback; '?' for no name.
String uiAvatarTagLetter(String? name) {
  final n = (name ?? '').trim();
  if (n.isEmpty) return '?';
  return n.characters.first.toUpperCase();
}

/// A tiny round picture and a name in small text (`ui-avatar-tag` on the web), for a venue or a
/// person on the corner of a photo tile or in a feed post. The picture is decorative; without one,
/// or when it fails to load, the circle shows the name's first letter on the primary colour. A
/// long name ends in an ellipsis inside the width the tag is given; it never grows past it.
///
/// [UiAvatarTagVariant.overlay] (the default) is the dark see-through pill of [UiLikeCount],
/// readable on any picture; with [glass] (the theme's `glass` config by default) it also blurs the
/// photo behind it and lights its rim. Read out as [prefix] + [name] ("At Coco Palm"). It takes no
/// tap of its own.
class UiAvatarTag extends StatelessWidget {
  const UiAvatarTag({
    super.key,
    required this.name,
    this.image,
    this.prefix,
    this.variant = UiAvatarTagVariant.overlay,
    this.size = UiAvatarTagSize.sm,
    this.glass,
  });

  /// The name shown; also the source of the fallback letter.
  final String name;

  /// The picture, usually a `NetworkImage` (the web's `src`). Decorative.
  final ImageProvider? image;

  /// Words read before the name, e.g. 'At' for "At Coco Palm". Not shown.
  final String? prefix;
  final UiAvatarTagVariant variant;
  final UiAvatarTagSize size;

  /// Blur what is behind the tag and light its rim; null follows the theme's `glass` config.
  final bool? glass;

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final isGlass = glass ?? theme.config.glass;
    final xs = size == UiAvatarTagSize.xs;
    final pic = xs ? 16.0 : 20.0;
    final overlay = variant == UiAvatarTagVariant.overlay;
    final fg = overlay ? t.mediaOnScrim : t.text;
    final shape = BorderRadius.circular(999);

    final letter = Center(
      child: Text(
        uiAvatarTagLetter(name),
        style: context.uiText.body.copyWith(fontSize: pic * 0.55, fontWeight: FontWeight.w600, height: 1, color: t.primaryContrast),
      ),
    );
    final circle = SizedBox.square(
      dimension: pic,
      child: ClipOval(
        child: DecoratedBox(
          decoration: BoxDecoration(color: t.primary),
          child: image == null
              ? letter
              : Image(
                  image: image!,
                  fit: BoxFit.cover,
                  width: pic,
                  height: pic,
                  excludeFromSemantics: true,
                  errorBuilder: (context, error, stack) => letter,
                ),
        ),
      ),
    );

    final Widget row = Padding(
      padding: EdgeInsetsDirectional.only(start: 2, top: 2, bottom: 2, end: xs ? t.space1 : t.space2),
      child: Row(mainAxisSize: MainAxisSize.min, spacing: t.space1, children: [
        circle,
        Flexible(
          child: Text(
            name,
            key: const ValueKey('ui-avatar-tag-name'),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: context.uiText.body.copyWith(
                fontSize: xs ? t.fontSizeSm * 0.85 : t.fontSizeSm, fontWeight: FontWeight.w600, height: 1.2, color: fg),
          ),
        ),
      ]),
    );

    final Color fill = overlay ? t.mediaScrim.withValues(alpha: 0.62) : (isGlass ? t.glassBg : t.surfaceRaised);
    Widget pill = DecoratedBox(
      key: const ValueKey('ui-avatar-tag-pill'),
      decoration: BoxDecoration(color: fill, borderRadius: shape),
      // Plain draws its edge over the content, like the web's inset box-shadow, so both variants
      // are the same size.
      position: DecorationPosition.background,
      child: overlay
          ? row
          : DecoratedBox(
              decoration: BoxDecoration(borderRadius: shape, border: Border.all(color: isGlass ? t.glassBorder : t.border)),
              position: DecorationPosition.foreground,
              child: row,
            ),
    );
    if (isGlass) {
      pill = ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: t.glassBlur / 2, sigmaY: t.glassBlur / 2),
          child: UiGlassRim(borderRadius: shape, inset: 0, child: pill),
        ),
      );
    }

    final label = [prefix?.trim() ?? '', name.trim()].where((s) => s.isNotEmpty).join(' ');
    return Semantics(
      image: true,
      label: label,
      excludeSemantics: true,
      child: pill,
    );
  }
}
