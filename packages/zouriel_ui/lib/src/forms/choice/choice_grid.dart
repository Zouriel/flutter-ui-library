import 'dart:math' as math;

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/interactive.dart';
import '../../core/types.dart';
import '../../theme/theme.dart';
import 'roving.dart';

/// One tile of a [UiChoiceGrid].
@immutable
class UiChoice<T> {
  const UiChoice({required this.value, required this.label, this.description, this.group, this.disabled = false});
  final T value;
  final String label;

  /// A second line under the label.
  final String? description;

  /// Tiles with the same group sit under that heading, in the order groups first appear.
  final String? group;
  final bool disabled;
}

/// `ui-choice-grid`: one of many options shown as tiles (presets, templates, effects). A radio group
/// underneath: the arrow keys (and Home/End) move through the enabled tiles in reading order and
/// choose as they go, only the chosen tile is in the tab order, Enter/Space choose.
///
/// Each tile shows its label (and description); [tileBuilder] draws a picture above it. [onPicked]
/// fires on every choice, including the selected tile again, for pickers where choosing is an action
/// ("add this") rather than a setting. Columns fill the width, each at least [minTile] wide.
class UiChoiceGrid<T> extends StatefulWidget {
  const UiChoiceGrid({
    super.key,
    required this.options,
    required this.value,
    this.onChanged,
    this.onPicked,
    this.enabled = true,
    this.label = 'Choices',
    this.minTile = 88,
    this.tileBuilder,
  });

  final List<UiChoice<T>> options;
  final T? value;
  final ValueChanged<T>? onChanged;
  final ValueChanged<UiChoice<T>>? onPicked;
  final bool enabled;

  /// The group's accessible name.
  final String label;

  /// Narrowest a tile may get, in logical pixels.
  final double minTile;

  /// Draws the art above a tile's label, in a 1.4:1 box.
  final Widget Function(BuildContext context, UiChoice<T> item, bool selected)? tileBuilder;

  @override
  State<UiChoiceGrid<T>> createState() => _UiChoiceGridState<T>();
}

class _UiChoiceGridState<T> extends State<UiChoiceGrid<T>> with UiRovingFocus<UiChoiceGrid<T>> {
  /// Options in display order: grouped, groups in order of first appearance.
  List<({String group, List<int> items})> get _sections {
    final out = <({String group, List<int> items})>[];
    for (var i = 0; i < widget.options.length; i++) {
      final g = widget.options[i].group ?? '';
      var s = out.where((x) => x.group == g).firstOrNull;
      if (s == null) out.add(s = (group: g, items: <int>[]));
      s.items.add(i);
    }
    return out;
  }

  bool _usable(int i) => widget.enabled && !widget.options[i].disabled;

  void _choose(int i) {
    if (!_usable(i)) return;
    final item = widget.options[i];
    widget.onChanged?.call(item.value);
    widget.onPicked?.call(item);
  }

  bool _onKey(LogicalKeyboardKey key, int at) {
    final order = _sections.expand((s) => s.items).where(_usable).toList();
    final pos = order.indexOf(at);
    if (pos < 0 || order.isEmpty) return false;
    final step = uiArrowStep(key, Directionality.of(context));
    int next;
    if (step != 0) {
      next = (pos + step).clamp(0, order.length - 1);
    } else if (key == LogicalKeyboardKey.home) {
      next = 0;
    } else if (key == LogicalKeyboardKey.end) {
      next = order.length - 1;
    } else {
      return false;
    }
    _choose(order[next]);
    rovingFocus(order[next]);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final opts = widget.options;
    final sections = _sections;
    final order = sections.expand((s) => s.items).where(_usable).toList();
    final chosen = opts.indexWhere((o) => o.value == widget.value);
    syncRoving(opts.length, order.contains(chosen) ? chosen : order.firstOrNull);

    return Semantics(
      container: true,
      role: SemanticsRole.radioGroup,
      label: widget.label,
      explicitChildNodes: true,
      child: rovingKeys(
        onKey: _onKey,
        child: LayoutBuilder(builder: (context, c) {
          final gap = t.space2;
          final cols = math.max(1, ((c.maxWidth + gap) / (widget.minTile + gap)).floor());
          final tileW = (c.maxWidth - gap * (cols - 1)) / cols;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: t.space2,
            children: [
              for (final s in sections) ...[
                if (s.group.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: t.space2),
                    child: Semantics(
                      header: true,
                      child: Text(s.group, style: context.uiText.body.copyWith(fontSize: t.fontSizeSm, fontWeight: FontWeight.w600, color: t.textMuted)),
                    ),
                  ),
                for (var r = 0; r < s.items.length; r += cols)
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: gap,
                      children: [
                        for (final i in s.items.skip(r).take(cols)) SizedBox(width: tileW, child: _tile(context, i)),
                      ],
                    ),
                  ),
              ],
            ],
          );
        }),
      ),
    );
  }

  Widget _tile(BuildContext context, int i) {
    final t = context.ui;
    final item = widget.options[i];
    final on = item.value == widget.value;
    final art = widget.tileBuilder;
    final rounded = context.uiTheme.config.radius;
    final r = rounded ? t.radius : 0.0;
    return UiInteractive(
      focusNode: rovingNode(i),
      enabled: _usable(i),
      onTap: _usable(i) ? () => _choose(i) : null,
      button: false,
      checked: on,
      padTouchTarget: false,
      builder: (context, s) {
        final hover = (s.hovered || s.pressed) && !on;
        return Semantics(
          inMutuallyExclusiveGroup: true,
          child: AnimatedOpacity(
            opacity: s.disabled ? 0.5 : 1,
            duration: t.motionBase,
            child: AnimatedContainer(
              duration: context.uiAnimate ? t.motionBase : Duration.zero,
              curve: t.easeStandard,
              constraints: BoxConstraints(minHeight: uiTouchPlatform(context) ? uiMinTouchTarget : 0),
              padding: EdgeInsets.all(t.space2),
              decoration: BoxDecoration(
                color: on ? t.selected : hover ? t.surfaceHover : t.surface,
                border: Border.all(color: on ? t.primary : hover ? uiMix(t.primary, 0.5, t.border) : t.border),
                borderRadius: BorderRadius.circular(r),
                boxShadow: s.focused ? t.focusRing : const [],
              ),
              child: Column(
                crossAxisAlignment: art == null ? CrossAxisAlignment.start : CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                spacing: t.space1,
                children: [
                  if (art != null)
                    AspectRatio(
                      aspectRatio: 1.4,
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(color: t.surfaceSubtle, borderRadius: BorderRadius.circular(math.max(0, r - 2))),
                        alignment: Alignment.center,
                        child: art(context, item, on),
                      ),
                    ),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: art == null ? TextAlign.start : TextAlign.center,
                    style: context.uiText.body.copyWith(fontSize: t.fontSizeSm, height: 1.25, color: t.text),
                  ),
                  if (item.description != null)
                    Text(
                      item.description!,
                      textAlign: art == null ? TextAlign.start : TextAlign.center,
                      style: context.uiText.body.copyWith(fontSize: t.fontSizeSm, height: 1.3, color: t.textMuted),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
