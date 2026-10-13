import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// Text styles, the web `TextVariant`.
enum UiTextVariant { h1, h2, h3, h4, h5, h6, body, caption, label, code, quote }

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
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final UiTextVariant variant;

  /// Override whether this is announced as a heading (defaults to h1–h6).
  final bool? heading;

  /// Font family override (the web `font` input).
  final String? fontFamily;
  final Color? color;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

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
    if (fontFamily != null) style = style.copyWith(fontFamily: fontFamily, package: null);
    if (color != null) style = style.copyWith(color: color);
    final shown = variant == UiTextVariant.h6 ? text.toUpperCase() : text;
    Widget w = Text(shown, style: style, textAlign: textAlign, maxLines: maxLines, overflow: overflow);

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
