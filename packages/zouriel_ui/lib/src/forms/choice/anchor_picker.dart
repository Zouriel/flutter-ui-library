import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/interactive.dart';
import '../../theme/theme.dart';
import 'roving.dart';

/// A point of a box in fractions of its size: (0, 0) top left, (0.5, 0.5) centre, (1, 1) bottom right.
@immutable
class UiAnchor {
  const UiAnchor(this.x, this.y);
  final double x;
  final double y;

  static const centre = UiAnchor(0.5, 0.5);

  @override
  bool operator ==(Object other) => other is UiAnchor && other.x == x && other.y == y;
  @override
  int get hashCode => Object.hash(x, y);
  @override
  String toString() => 'UiAnchor($x, $y)';
}

const _names = [
  ['Top left', 'Top', 'Top right'],
  ['Left', 'Centre', 'Right'],
  ['Bottom left', 'Bottom', 'Bottom right'],
];

/// `ui-anchor-picker`: the nine-dot grid for choosing a point of a box (a pivot, an alignment), as
/// in Figma and Photoshop. A value between the dots shows no dot chosen. A radio group with one tab
/// stop; the arrow keys move the choice, and each dot is named ("Top left", "Centre"...).
///
/// The grid is physical (left stays left in right-to-left layouts), like the names.
class UiAnchorPicker extends StatefulWidget {
  const UiAnchorPicker({super.key, required this.value, required this.onChanged, this.label = 'Point'});

  /// Null means the centre.
  final UiAnchor? value;
  final ValueChanged<UiAnchor>? onChanged;

  /// The group's accessible name.
  final String label;

  @override
  State<UiAnchorPicker> createState() => _UiAnchorPickerState();
}

class _UiAnchorPickerState extends State<UiAnchorPicker> with UiRovingFocus<UiAnchorPicker> {
  bool get _enabled => widget.onChanged != null;

  /// Index 0-8 of the chosen dot, or null for a point between them.
  int? get _chosen {
    final v = widget.value ?? UiAnchor.centre;
    final c = const [0.0, 0.5, 1.0].indexWhere((p) => (p - v.x).abs() < 0.001);
    final r = const [0.0, 0.5, 1.0].indexWhere((p) => (p - v.y).abs() < 0.001);
    return c < 0 || r < 0 ? null : r * 3 + c;
  }

  void _pick(int c, int r) => widget.onChanged!(UiAnchor(c / 2, r / 2));

  bool _onKey(LogicalKeyboardKey key, int at) {
    final move = {
      LogicalKeyboardKey.arrowLeft: (-1, 0),
      LogicalKeyboardKey.arrowRight: (1, 0),
      LogicalKeyboardKey.arrowUp: (0, -1),
      LogicalKeyboardKey.arrowDown: (0, 1),
    }[key];
    if (move == null) return false;
    final c = (at % 3 + move.$1).clamp(0, 2);
    final r = (at ~/ 3 + move.$2).clamp(0, 2);
    _pick(c, r);
    rovingFocus(r * 3 + c);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final chosen = _chosen;
    syncRoving(9, _enabled ? (chosen ?? 4) : null);
    final cell = uiTouchPlatform(context) ? uiMinTouchTarget : t.sizeSm;
    final r = context.uiTheme.config.radius ? t.radius : 0.0;
    return Semantics(
      container: true,
      role: SemanticsRole.radioGroup,
      label: widget.label,
      explicitChildNodes: true,
      child: AnimatedOpacity(
        opacity: _enabled ? 1 : 0.5,
        duration: t.motionBase,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: rovingKeys(
            onKey: _onKey,
            child: Container(
              decoration: BoxDecoration(border: Border.all(color: t.border), borderRadius: BorderRadius.circular(r), color: t.surfaceSubtle),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var row = 0; row < 3; row++)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var col = 0; col < 3; col++) _dot(context, row, col, cell, r, chosen == row * 3 + col),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dot(BuildContext context, int row, int col, double cell, double radius, bool on) {
    final t = context.ui;
    return UiInteractive(
      focusNode: rovingNode(row * 3 + col),
      enabled: _enabled,
      onTap: _enabled ? () => _pick(col, row) : null,
      button: false,
      checked: on,
      semanticLabel: _names[row][col],
      padTouchTarget: false,
      pressScale: false,
      builder: (context, s) => Semantics(
        inMutuallyExclusiveGroup: true,
        child: Container(
          width: cell,
          height: cell,
          alignment: Alignment.center,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(radius), boxShadow: s.focused ? t.focusRing : const []),
          child: AnimatedScale(
            scale: on ? 1.5 : 1,
            duration: context.uiAnimate ? t.motionFast : Duration.zero,
            curve: t.easeStandard,
            child: AnimatedContainer(
              duration: context.uiAnimate ? t.motionFast : Duration.zero,
              width: 8,
              height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: on ? t.primary : s.hovered ? t.text : t.textMuted),
            ),
          ),
        ),
      ),
    );
  }
}
