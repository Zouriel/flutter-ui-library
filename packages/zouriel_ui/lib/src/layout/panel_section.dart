import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/icon.dart';
import '../core/interactive.dart';
import '../theme/theme.dart';

/// `ui-panel-section`: a compact, collapsible titled group for inspector and settings panels. Unlike
/// an accordion it is built for controls: dense spacing, full-contrast content, and [actions] in the
/// header (an Add button, say).
///
/// The heading is a button announced as expanded or collapsed. A collapsed body is not built. Leave
/// [open] null to let the section keep its own state (starting at [initiallyOpen]), or drive it with
/// [open] + [onOpenChanged].
class UiPanelSection extends StatefulWidget {
  const UiPanelSection({
    super.key,
    required this.title,
    required this.child,
    this.open,
    this.initiallyOpen = true,
    this.onOpenChanged,
    this.collapsible = true,
    this.badge,
    this.actions = const [],
  });

  final String title;
  final Widget child;
  final bool? open;
  final bool initiallyOpen;
  final ValueChanged<bool>? onOpenChanged;

  /// False shows a fixed heading and always shows the body.
  final bool collapsible;

  /// A small count or note after the title.
  final String? badge;

  /// Header controls, after the title.
  final List<Widget> actions;

  @override
  State<UiPanelSection> createState() => _UiPanelSectionState();
}

class _UiPanelSectionState extends State<UiPanelSection> {
  late bool _open = widget.open ?? widget.initiallyOpen;

  bool get _isOpen => !widget.collapsible || (widget.open ?? _open);

  void _toggle() {
    final next = !(widget.open ?? _open);
    if (widget.open == null) setState(() => _open = next);
    widget.onOpenChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final touch = uiTouchPlatform(context);
    final headH = touch ? uiMinTouchTarget : t.sizeLg;
    final titleStyle = context.uiText.label.copyWith(fontSize: 12, height: 1, letterSpacing: 12 * 0.04, color: t.text);

    Widget heading(UiStates s) {
      return AnimatedContainer(
        duration: context.uiAnimate ? t.motionFast : Duration.zero,
        height: headH,
        padding: EdgeInsets.symmetric(horizontal: t.space3),
        decoration: BoxDecoration(color: s.hovered && widget.collapsible ? t.surfaceHover : null),
        // Inset ring: the web uses `inset 0 0 0 2px border-focus`, since the row is full width.
        foregroundDecoration: BoxDecoration(border: s.focused ? Border.all(color: t.borderFocus, width: 2) : null),
        child: Row(spacing: t.space2, children: [
          if (widget.collapsible)
            AnimatedRotation(
              turns: _isOpen ? 0.25 : 0,
              duration: context.uiAnimate ? t.motionFast : Duration.zero,
              curve: t.easeStandard,
              child: UiIcon(HugeIcons.strokeRoundedArrowRight01, size: 12, color: t.textMuted),
            ),
          Flexible(child: Text(widget.title.toUpperCase(), style: titleStyle, maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (widget.badge != null)
            Container(
              padding: EdgeInsets.symmetric(horizontal: t.space1),
              decoration: BoxDecoration(color: t.surfaceSubtle, borderRadius: BorderRadius.circular(t.radiusPill)),
              child: Text(widget.badge!, style: titleStyle.copyWith(fontSize: 11, height: 16 / 11, letterSpacing: 0, color: t.textMuted, fontFeatures: const [FontFeature.tabularFigures()])),
            ),
        ]),
      );
    }

    final head = widget.collapsible
        ? UiInteractive(
            onTap: _toggle,
            padTouchTarget: false,
            pressScale: false,
            semanticLabel: widget.title,
            builder: (context, s) => Semantics(expanded: _isOpen, child: ExcludeSemantics(child: heading(s))),
          )
        : Semantics(header: true, label: widget.title, child: ExcludeSemantics(child: heading(const UiStates())));

    return DecoratedBox(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.border))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(child: head),
          if (widget.actions.isNotEmpty)
            Padding(padding: EdgeInsets.only(right: t.space2), child: Row(mainAxisSize: MainAxisSize.min, spacing: t.space1, children: widget.actions)),
        ]),
        if (_isOpen)
          Semantics(
            container: true,
            label: widget.title,
            child: Padding(
              padding: EdgeInsets.fromLTRB(t.space3, 2, t.space3, t.space3),
              child: DefaultTextStyle.merge(style: const TextStyle(height: 1.35), child: widget.child),
            ),
          ),
      ]),
    );
  }
}
