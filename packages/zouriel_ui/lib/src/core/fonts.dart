import 'package:flutter/widgets.dart';

/// [base] drawn in [font]'s family (e.g. from a font picker). Built as a complete,
/// non-inheriting style: merging a font from one package onto a style from another would prefix
/// the family twice.
TextStyle uiApplyFont(TextStyle base, TextStyle? font) {
  if (font == null) return base;
  return TextStyle(
    inherit: false,
    color: base.color,
    backgroundColor: base.backgroundColor,
    fontSize: base.fontSize,
    fontWeight: base.fontWeight,
    fontStyle: base.fontStyle,
    letterSpacing: base.letterSpacing,
    wordSpacing: base.wordSpacing,
    textBaseline: base.textBaseline ?? TextBaseline.alphabetic,
    height: base.height,
    leadingDistribution: base.leadingDistribution,
    decoration: base.decoration ?? TextDecoration.none,
    decorationColor: base.decorationColor,
    fontFeatures: base.fontFeatures,
    fontFamily: font.fontFamily,
    fontFamilyFallback: font.fontFamilyFallback,
    overflow: base.overflow,
  );
}

