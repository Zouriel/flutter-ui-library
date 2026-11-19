import 'package:flutter/widgets.dart';

import '../core/fonts.dart';
import '../core/on_media.dart';
import '../theme/theme.dart';

/// Text styles, the web `TextVariant`.
enum UiTextVariant { h1, h2, h3, h4, h5, h6, body, caption, label, code, quote }

/// Colour tone on [UiText] (the web `UiTextTone`): default, muted, or high-contrast light ink over media.
enum UiTextTone { standard, muted, onMedia }

/// `ui-text`: themed text in one of the library's variants.
///
/// Heading variants are announced as headings (the web renders `<h1>`…`<h6>`); set [heading] to
/// false for a heading look that isn't a heading (the web `as` input), or true to make any
/// variant a heading. `h6` renders upper-case, as on the web.
class UiText extends StatelessWidget {
  const UiText(
    this.text, {
    super.key,
    this.variant = UiTextVariant.body,
    this.heading,
    this.fontFamily,
    this.fontPackage,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.truncate = false,
    this.tone = UiTextTone.standard,
  });

  final String text;
  final UiTextVariant variant;

  /// Override whether this is announced as a heading (defaults to h1–h6).
  final bool? heading;

  /// Font family override (the web `font` input): an app or system font, or a package font
  /// together with [fontPackage].
  final String? fontFamily;
  final String? fontPackage;
  final Color? color;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  /// Shorthand for single-line ellipsis truncation (`maxLines: 1, overflow: TextOverflow.ellipsis`).
  final bool truncate;

  /// Colour tone: standard, muted, or high-contrast light ink over photos/media.
  final UiTextTone tone;

  static TextStyle styleOf(BuildContext context, UiTextVariant v) {
    final ty = context.uiText;
    return switch (v) {
      UiTextVariant.h1 => ty.h1,
      UiTextVariant.h2 => ty.h2,
      UiTextVariant.h3 => ty.h3,
      UiTextVariant.h4 => ty.h4,
      UiTextVariant.h5 => ty.h5,
      UiTextVariant.h6 => ty.h6,
      UiTextVariant.body => ty.body,
      UiTextVariant.caption => ty.caption,
      UiTextVariant.label => ty.label,
      UiTextVariant.code => ty.code,
      UiTextVariant.quote => ty.quote,
    };
  }

  bool get _isHeadingVariant => variant.index <= UiTextVariant.h6.index;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    var style = styleOf(context, variant);
    // copyWith would keep the theme font's package prefix, so build the font afresh.
    if (fontFamily != null) style = uiApplyFont(style, TextStyle(fontFamily: fontFamily, package: fontPackage));
    if (color != null) {
      style = style.copyWith(color: color);
    } else if (tone == UiTextTone.muted) {
      style = style.copyWith(color: t.textMuted);
    } else if (tone == UiTextTone.onMedia || tone == UiTextTone.standard && UiOnMediaScope.active(context)) {
      final soft = variant == UiTextVariant.caption || variant == UiTextVariant.h6;
      style = style.copyWith(
        color: soft ? t.mediaOnScrim.withValues(alpha: 0.9) : t.mediaOnScrim,
        shadows: [Shadow(color: t.mediaScrim.withValues(alpha: 0.55), offset: const Offset(0, 1), blurRadius: soft ? 3 : 4)],
      );
    }
    final shown = variant == UiTextVariant.h6 ? text.toUpperCase() : text;
    final effectiveMaxLines = truncate ? (maxLines ?? 1) : maxLines;
    final effectiveOverflow = truncate ? (overflow ?? TextOverflow.ellipsis) : overflow;
    Widget w = Text(shown, style: style, textAlign: textAlign, maxLines: effectiveMaxLines, overflow: effectiveOverflow);

    if (variant == UiTextVariant.code) {
      w = DecoratedBox(
        decoration: BoxDecoration(
          color: t.surfaceRaised,
          border: Border.all(color: t.border),
          borderRadius: BorderRadius.circular(t.radiusXs),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: style.fontSize! * 0.35, vertical: style.fontSize! * 0.1),
          child: w,
        ),
      );
    } else if (variant == UiTextVariant.quote) {
      w = DecoratedBox(
        decoration: BoxDecoration(border: Border(left: BorderSide(color: t.borderStrong, width: 2))),
        child: Padding(padding: EdgeInsets.symmetric(vertical: t.space2, horizontal: t.space4), child: w),
      );
    }

    final isHeading = heading ?? _isHeadingVariant;
    if (isHeading) {
      final level = _isHeadingVariant ? variant.index + 1 : 2;
      w = Semantics(header: true, headingLevel: level, child: w);
    }
    return w;
  }
}
