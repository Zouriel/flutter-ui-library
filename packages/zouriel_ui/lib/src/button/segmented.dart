import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/interactive.dart';
import '../core/types.dart';
import '../forms/choice/roving.dart';
import '../behaviors/scrolling.dart';
import '../theme/theme.dart';

/// One option of a [UiSegmented].
@immutable
class UiSegmentedOption<T> {
  const UiSegmentedOption({required this.value, required this.label, this.glyph, this.icon, this.disabled = false});
  final T value;

  /// Shown, and always the accessible name.
  final String label;

  /// Short visible text instead of the label (the label stays the accessible name).
  final String? glyph;

  /// An icon instead of the label (the label stays the accessible name).
  final Widget? icon;
  final bool disabled;
}

/// `ui-segmented`: a row of mutually exclusive options, e.g. alignment or a preview mode. A radio
/// group underneath: the arrow keys move the choice (wrapping, skipping disabled options), only the
/// chosen option is in the tab order. Null [onChanged] disables it. Scrolls sideways if it doesn't fit.
///
/// On phones each option's touch area is 48dp tall (and at least 48 wide) while the track keeps its
/// compact look.
class UiSegmented<T> extends StatefulWidget {
  const UiSegmented({super.key, required this.options, required this.value, required this.onChanged, this.label = 'Options', this.size = UiSize.md});

  final List<UiSegmentedOption<T>> options;
  final T? value;
  final ValueChanged<T>? onChanged;

  /// The group's accessible name.
  final String label;
  final UiSize size;

  @override
  State<UiSegmented<T>> createState() => _UiSegmentedState<T>();
}

class _UiSegmentedState<T> extends State<UiSegmented<T>> with UiRovingFocus<UiSegmented<T>> {
  bool _usable(int i) => widget.onChanged != null && !widget.options[i].disabled;

  bool _onKey(LogicalKeyboardKey key, int at) {
    final step = uiArrowStep(key, Directionality.of(context));
    if (step == 0) return false;
    final n = widget.options.length;
    for (var k = 1; k <= n; k++) {
      final i = ((at + step * k) % n + n) % n;
      if (_usable(i)) {
        widget.onChanged!(widget.options[i].value);
        rovingFocus(i);
        return true;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final opts = widget.options;
    final chosen = opts.indexWhere((o) => o.value == widget.value);
    int? stop = chosen >= 0 && _usable(chosen) ? chosen : null;
    for (var i = 0; stop == null && i < opts.length; i++) {
      if (_usable(i)) stop = i;
    }
    syncRoving(opts.length, stop);

    final touch = uiTouchPlatform(context);
    final sm = widget.size == UiSize.sm, lg = widget.size == UiSize.lg;
    final pad = sm ? 1.0 : 2.0;
    // sm: the track is as tall as the other sm controls; the whole track height stays the hit area.
    final optH = sm ? t.sizeSm - 4 : (lg ? t.sizeLg : t.sizeMd) - 6;
    final trackH = optH + pad * 2 + 2;
    final rowH = touch && trackH < uiMinTouchTarget ? uiMinTouchTarget : trackH;
    final rounded = context.uiTheme.config.radius;
    final r = rounded ? t.radius : 0.0;

    final row = Padding(
      padding: EdgeInsets.symmetric(horizontal: pad + 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: pad,
        children: [for (var i = 0; i < opts.length; i++) _option(context, i, optH, rowH, r, touch, sm, lg)],
      ),
    );
    final track = SizedBox(
      height: rowH,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Center(
              child: Container(
                height: trackH,
                decoration: BoxDecoration(color: t.surfaceSubtle, border: Border.all(color: t.border), borderRadius: BorderRadius.circular(r)),
              ),
            ),
          ),
          row,
        ],
      ),
    );
    final fitted = LayoutBuilder(
      builder: (context, c) => c.hasBoundedWidth ? UiScrollFade(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: track)) : track,
    );
    return Semantics(
      container: true,
      role: SemanticsRole.radioGroup,
      label: widget.label,
      explicitChildNodes: true,
      child: rovingKeys(onKey: _onKey, child: fitted),
    );
  }

  Widget _option(BuildContext context, int i, double h, double rowH, double r, bool touch, bool sm, bool lg) {
    final t = context.ui;
    final o = widget.options[i];
    final on = o.value == widget.value;
    final style = context.uiText.body.copyWith(fontSize: lg ? t.fontSizeMd : t.fontSizeSm, fontWeight: FontWeight.w500, height: 1.2);
    final shownText = o.glyph ?? (o.icon == null ? o.label : null);
    return UiInteractive(
      focusNode: rovingNode(i),
      enabled: _usable(i),
      onTap: _usable(i) ? () => widget.onChanged!(o.value) : null,
      button: false,
      checked: on,
      semanticLabel: o.glyph != null || o.icon != null ? o.label : null,
      padTouchTarget: false,
      pressScale: false,
      builder: (context, s) {
        final fg = on || s.hovered ? t.text : t.textMuted;
        return Semantics(
          inMutuallyExclusiveGroup: true,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: touch ? uiMinTouchTarget : (sm ? 24 : 30), minHeight: rowH),
            child: Center(
              widthFactor: 1,
              child: AnimatedOpacity(
                opacity: s.disabled ? 0.5 : 1,
                duration: t.motionBase,
                child: AnimatedContainer(
                  duration: context.uiAnimate ? t.motionFast : Duration.zero,
                  curve: t.easeStandard,
                  height: h,
                  constraints: BoxConstraints(minWidth: touch ? uiMinTouchTarget : (sm ? 24 : 30)),
                  padding: EdgeInsets.symmetric(horizontal: sm ? t.space2 : lg ? t.space4 : t.space3),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: on ? t.surfaceRaised : s.hovered ? t.surfaceHover : null,
                    borderRadius: BorderRadius.circular(r == 0 ? 0 : r - 2),
                    boxShadow: on ? t.shadow1 : const [],
                  ),
                  // An inset ring: the track scrolls, which would clip an outset one.
                  foregroundDecoration: s.focused
                      ? BoxDecoration(border: Border.all(color: t.borderFocus, width: 2), borderRadius: BorderRadius.circular(r == 0 ? 0 : r - 2))
                      : null,
                  child: IconTheme.merge(
                    data: IconThemeData(color: fg, size: lg ? 18 : 16),
                    child: ExcludeSemantics(
                      excluding: o.glyph != null || o.icon != null,
                      child: shownText != null ? Text(shownText, maxLines: 1, style: style.copyWith(color: fg)) : o.icon!,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
