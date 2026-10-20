import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/interactive.dart';
import '../../theme/theme.dart';

/// A text field's writing direction (the web `dir`): [auto] follows the text typed.
enum UiTextDir { ltr, rtl, auto }

// Right-to-left scripts: Hebrew, Arabic, Syriac, Thaana, NKo, Samaritan, Mandaic and the Arabic
// and Hebrew presentation forms, plus the RTL ranges of the supplementary planes.
final RegExp _rtl = RegExp(r'[֐-ࣿיִ-﷿ﹰ-﻿]|[\u{10800}-\u{10FFF}\u{1E800}-\u{1EFFF}]', unicode: true);
final RegExp _strong = RegExp(r'[\p{L}֐-ࣿיִ-﷿ﹰ-﻿]', unicode: true);

/// The direction of [text] by its first strongly directional character, as the web resolves
/// `dir="auto"`; null when it has none (no letters yet), so the field keeps the surrounding one.
TextDirection? uiTextDirection(String text) {
  for (final rune in text.runes) {
    final ch = String.fromCharCode(rune);
    if (!_strong.hasMatch(ch)) continue;
    return _rtl.hasMatch(ch) ? TextDirection.rtl : TextDirection.ltr;
  }
  return null;
}

/// What a field lays out in: an explicit [dir], [UiTextDir.auto] resolved from [text], or null to
/// keep the surrounding [Directionality].
TextDirection? uiResolvedDir(UiTextDir? dir, String text) => switch (dir) {
      UiTextDir.ltr => TextDirection.ltr,
      UiTextDir.rtl => TextDirection.rtl,
      UiTextDir.auto => uiTextDirection(text),
      null => null,
    };

/// Wraps [child] in the direction [dir] resolves to for [controller]'s text, rebuilding as it changes.
class UiFieldDirection extends StatelessWidget {
  const UiFieldDirection({super.key, required this.dir, required this.controller, required this.child});

  final UiTextDir? dir;
  final TextEditingController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (dir == null) return child;
    if (dir != UiTextDir.auto) return Directionality(textDirection: uiResolvedDir(dir, '')!, child: child);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) => Directionality(
        textDirection: uiTextDirection(controller.text) ?? Directionality.of(context),
        child: child!,
      ),
      child: child,
    );
  }
}

/// A field slot (`leading` / `trailing` on UiInput and UiTextarea): [child] centred in a box
/// [height] tall, where a tap that no button inside takes focuses the field.
class UiFieldSlot extends StatelessWidget {
  const UiFieldSlot({super.key, required this.child, required this.focusNode, this.height, this.enabled = true});

  final Widget child;
  final FocusNode focusNode;
  final double? height;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    Widget slot = IconTheme.merge(
      data: IconThemeData(size: 16, color: t.icon ?? t.textMuted),
      child: DefaultTextStyle.merge(style: TextStyle(color: t.textMuted), child: Center(widthFactor: 1, child: child)),
    );
    if (height != null) slot = SizedBox(height: height, child: slot);
    return IgnorePointer(
      ignoring: !enabled,
      // A tap on empty slot space (or a plain icon) focuses the field. Buttons inside are deeper in
      // the hit test, so their own tap recognizers win the arena and this one stays out of it.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: enabled ? focusNode.requestFocus : null,
        child: slot,
      ),
    );
  }
}

/// The vertical margin a multi-line field with slots lays out with on touch screens, so a slot
/// button's [uiMinTouchTarget] hit area, centred on the last line, stays inside the widget (hit
/// tests stop at a widget's bounds) while the visible box stays [lineBox] + border tall.
double uiSlotTouchMargin(BuildContext context, double lineBox) =>
    uiTouchPlatform(context) ? math.max(0.0, (uiMinTouchTarget - lineBox) / 2) : 0.0;

/// [base] with [extra] merged over it, keeping [extra]'s font family as given. A plain
/// [TextStyle.merge] would keep the base style's package and turn an app font such as
/// `'Faruma'` into `'packages/zouriel_ui/Faruma'`, which doesn't exist.
TextStyle uiMergeFieldStyle(TextStyle base, TextStyle? extra) {
  if (extra == null) return base;
  final m = base.merge(extra);
  if (extra.fontFamily == null && extra.fontFamilyFallback == null) return m;
  return TextStyle(
    inherit: m.inherit,
    color: m.color,
    backgroundColor: m.backgroundColor,
    fontSize: m.fontSize,
    fontWeight: m.fontWeight,
    fontStyle: m.fontStyle,
    letterSpacing: m.letterSpacing,
    wordSpacing: m.wordSpacing,
    textBaseline: m.textBaseline,
    height: m.height,
    leadingDistribution: m.leadingDistribution,
    locale: m.locale,
    foreground: m.foreground,
    background: m.background,
    shadows: m.shadows,
    fontFeatures: m.fontFeatures,
    fontVariations: m.fontVariations,
    decoration: m.decoration,
    decorationColor: m.decorationColor,
    decorationStyle: m.decorationStyle,
    decorationThickness: m.decorationThickness,
    overflow: m.overflow,
    // Getters return the full (package-prefixed where needed) names, so no package is set here.
    fontFamily: extra.fontFamily ?? base.fontFamily,
    fontFamilyFallback: extra.fontFamilyFallback ?? base.fontFamilyFallback,
  );
}
