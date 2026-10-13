import 'package:flutter/widgets.dart';

import '../../core/interactive.dart';
import '../../overlay/anchored.dart';
import '../../theme/theme.dart';
import 'bare_input.dart';

/// `#RGB`, `RRGGBB` and the like as lower-case `#rrggbb`, or null when it isn't a whole hex colour.
String? uiNormalizeHex(String raw) {
  final m = RegExp(r'^#?([0-9a-f]{3}|[0-9a-f]{6})$', caseSensitive: false).firstMatch(raw.trim());
  if (m == null) return null;
  var h = m.group(1)!.toLowerCase();
  if (h.length == 3) h = h.split('').map((c) => c + c).join();
  return '#$h';
}

/// The colour of a hex string (`#rgb` or `#rrggbb`), or null if it isn't one.
Color? uiHexToColor(String hex) {
  final n = uiNormalizeHex(hex);
  if (n == null) return null;
  return Color(0xFF000000 | int.parse(n.substring(1), radix: 16));
}

/// A colour as lower-case `#rrggbb` (alpha dropped).
String uiColorToHex(Color c) {
  final v = c.toARGB32() & 0xFFFFFF;
  return '#${v.toRadixString(16).padLeft(6, '0')}';
}

/// `ui-color-picker`: a colour well, a hex field and preset swatches. The value is a lower-case
/// `#rrggbb` string, like the web.
///
/// The hex field passes a colour on only once it is a whole `#rgb` or `#rrggbb` (the # optional);
/// leaving the field puts the current colour back. Phones have no native colour dialog, so the well
/// opens a hue / saturation-brightness panel next to it. Null [onChanged] disables everything.
class UiColorPicker extends StatefulWidget {
  const UiColorPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.swatches = const ['#1b3d59', '#6a97c0', '#b3d5f1', '#f3eed8', '#2e6b50', '#a83a3f'],
    this.radius,
  });

  final String value;
  final ValueChanged<String>? onChanged;

  /// Preset colours as hex strings.
  final List<String> swatches;

  /// Rounded corners; defaults to the library config.
  final bool? radius;

  @override
  State<UiColorPicker> createState() => _UiColorPickerState();
}

class _UiColorPickerState extends State<UiColorPicker> {
  late final TextEditingController _hex = TextEditingController(text: widget.value);
  final FocusNode _hexFocus = FocusNode(debugLabel: 'hex');
  final OverlayPortalController _panel = OverlayPortalController();

  bool get _enabled => widget.onChanged != null;

  @override
  void initState() {
    super.initState();
    _hexFocus.addListener(() {
      // Leaving the field shows the current colour again, replacing any half-typed text.
      if (!_hexFocus.hasFocus) _hex.text = widget.value;
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(UiColorPicker old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && !_hexFocus.hasFocus) _hex.text = widget.value;
  }

  @override
  void dispose() {
    _hex.dispose();
    _hexFocus.dispose();
    super.dispose();
  }

  void _set(String hex) {
    if (hex.toLowerCase() != widget.value.toLowerCase()) widget.onChanged?.call(hex);
  }

  void _typed(String raw) {
    final hex = uiNormalizeHex(raw);
    if (hex != null) _set(hex);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final r = (widget.radius ?? theme.config.radius) ? t.radius : 0.0;
    final current = uiHexToColor(widget.value);
    final touch = uiTouchPlatform(context);

    final well = UiAnchoredOverlay(
      controller: _panel,
      onDismiss: () => setState(_panel.hide),
      panelBuilder: (context, anchor) => _HsvPanel(
        color: current ?? t.primary,
        onChanged: (c) => _set(uiColorToHex(c)),
      ),
      child: UiInteractive(
        onTap: _enabled ? () => setState(_panel.toggle) : null,
        enabled: _enabled,
        semanticLabel: 'Pick colour',
        semanticHint: widget.value,
        excludeChildSemantics: true,
        builder: (context, s) => AnimatedOpacity(
          opacity: s.disabled ? 0.5 : 1,
          duration: t.motionBase,
          child: Container(
            // As tall as the hex field beside it (48 on phones).
            width: touch ? uiMinTouchTarget : t.sizeMd,
            height: touch ? uiMinTouchTarget : t.sizeMd,
            decoration: BoxDecoration(
              color: current,
              border: Border.all(color: t.controlBorder),
              borderRadius: BorderRadius.circular(r),
              boxShadow: s.focused ? t.focusRing : const [],
            ),
          ),
        ),
      ),
    );

    final focused = _hexFocus.hasFocus;
    final field = AnimatedOpacity(
      opacity: _enabled ? 1 : 0.5,
      duration: t.motionBase,
      child: AnimatedContainer(
        duration: context.uiAnimate ? t.motionBase : Duration.zero,
        width: 92,
        height: touch ? uiMinTouchTarget : t.sizeMd,
        padding: EdgeInsets.symmetric(horizontal: t.space3),
        alignment: AlignmentDirectional.centerStart,
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(color: focused ? t.primary : t.controlBorder),
          borderRadius: BorderRadius.circular(r),
          boxShadow: focused ? t.focusRing : const [],
        ),
        child: UiBareInput(
          controller: _hex,
          focusNode: _hexFocus,
          enabled: _enabled,
          semanticLabel: 'Hex colour',
          style: context.uiText.code.copyWith(fontSize: t.fontSizeSm, color: t.text),
          onChanged: _typed,
          onSubmitted: (_) => _hexFocus.unfocus(),
        ),
      ),
    );

    final cell = touch ? uiMinTouchTarget : 24.0;
    final swatches = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final hex in widget.swatches)
          UiInteractive(
            onTap: _enabled ? () => _set(uiNormalizeHex(hex) ?? hex) : null,
            enabled: _enabled,
            selected: hex.toLowerCase() == widget.value.toLowerCase(),
            semanticLabel: hex,
            excludeChildSemantics: true,
            padTouchTarget: false,
            pressScale: false,
            builder: (context, s) {
              final on = hex.toLowerCase() == widget.value.toLowerCase();
              return AnimatedOpacity(
                opacity: s.disabled ? 0.5 : 1,
                duration: t.motionBase,
                child: Container(
                  width: cell,
                  height: cell,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: s.focused ? t.focusRing : const []),
                  child: AnimatedScale(
                    scale: s.hovered ? 1.1 : 1,
                    duration: t.motionFast,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: uiHexToColor(hex),
                        shape: BoxShape.circle,
                        border: Border.all(color: t.border),
                        // A gap in the background colour, then a 1px ring in the text colour.
                        boxShadow: on ? [BoxShadow(color: t.text, spreadRadius: 3), BoxShadow(color: t.bg, spreadRadius: 2)] : const [],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );

    return Wrap(
      spacing: t.space2,
      runSpacing: t.space2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [well, field, swatches],
    );
  }
}

/// The well's panel: a saturation/brightness square over a hue strip.
class _HsvPanel extends StatefulWidget {
  const _HsvPanel({required this.color, required this.onChanged});
  final Color color;
  final ValueChanged<Color> onChanged;

  @override
  State<_HsvPanel> createState() => _HsvPanelState();
}

class _HsvPanelState extends State<_HsvPanel> {
  late HSVColor _hsv = HSVColor.fromColor(widget.color);

  @override
  void didUpdateWidget(_HsvPanel old) {
    super.didUpdateWidget(old);
    // Keep the hue while dragging through greys, where the colour alone can't say what it was.
    if (widget.color != _hsv.toColor()) {
      final next = HSVColor.fromColor(widget.color);
      _hsv = next.saturation == 0 || next.value == 0 ? next.withHue(_hsv.hue) : next;
    }
  }

  void _emit(HSVColor h) {
    setState(() => _hsv = h);
    widget.onChanged(h.toColor());
  }

  static const double _w = 216, _h = 144;

  void _sv(Offset p) => _emit(_hsv.withSaturation((p.dx / _w).clamp(0.0, 1.0)).withValue(1 - (p.dy / _h).clamp(0.0, 1.0)));
  void _hue(double x) => _emit(_hsv.withHue((x / _w).clamp(0.0, 1.0) * 360));

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final r = context.uiTheme.config.radius ? t.radius : 0.0;
    final hueColor = HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor();
    final transparent = const Color(0x00000000);
    Widget knob(Color fill) => Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(shape: BoxShape.circle, color: fill, border: Border.all(color: t.sliderThumb, width: 2), boxShadow: t.shadow1),
        );
    return Container(
      padding: EdgeInsets.all(t.space3),
      decoration: BoxDecoration(color: t.surfaceRaised, border: Border.all(color: t.border), borderRadius: BorderRadius.circular(r), boxShadow: t.shadow2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: t.space3,
        children: [
          ExcludeSemantics(
            child: GestureDetector(
              onPanDown: (d) => _sv(d.localPosition),
              onPanUpdate: (d) => _sv(d.localPosition),
              child: SizedBox(
                width: _w,
                height: _h,
                child: Stack(clipBehavior: Clip.none, children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(t.radiusSm),
                        gradient: LinearGradient(colors: [HSVColor.fromAHSV(1, 0, 0, 1).toColor(), hueColor]),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(t.radiusSm),
                        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [transparent, HSVColor.fromAHSV(1, 0, 0, 0).toColor()]),
                      ),
                    ),
                  ),
                  Positioned(left: _hsv.saturation * _w - 8, top: (1 - _hsv.value) * _h - 8, child: knob(_hsv.toColor())),
                ]),
              ),
            ),
          ),
          Semantics(
            container: true,
            slider: true,
            label: 'Hue',
            value: '${_hsv.hue.round()}',
            increasedValue: '${((_hsv.hue + 10) % 360).round()}',
            decreasedValue: '${((_hsv.hue - 10) % 360).round()}',
            onIncrease: () => _emit(_hsv.withHue((_hsv.hue + 10) % 360)),
            onDecrease: () => _emit(_hsv.withHue((_hsv.hue - 10) % 360)),
            child: GestureDetector(
              onHorizontalDragDown: (d) => _hue(d.localPosition.dx),
              onHorizontalDragUpdate: (d) => _hue(d.localPosition.dx),
              child: SizedBox(
                width: _w,
                height: 24,
                child: Stack(alignment: Alignment.centerLeft, clipBehavior: Clip.none, children: [
                  Container(
                    height: 12,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(t.radiusPill),
                      gradient: LinearGradient(colors: [for (var h = 0; h <= 360; h += 60) HSVColor.fromAHSV(1, h.toDouble() % 360, 1, 1).toColor()]),
                    ),
                  ),
                  Positioned(left: _hsv.hue / 360 * _w - 8, child: knob(hueColor)),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
