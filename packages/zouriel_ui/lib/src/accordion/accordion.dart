import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/icon.dart';
import '../core/interactive.dart';
import '../theme/theme.dart';

/// `ui-accordion`: a stack of [UiAccordionItem]s. Opening one closes the others unless [multiple].
/// [initiallyOpen] lists the items open at first; [onChanged] reports the open set after each toggle.
class UiAccordion extends StatefulWidget {
  const UiAccordion({super.key, required this.children, this.multiple = false, this.initiallyOpen = const {}, this.onChanged});

  final List<UiAccordionItem> children;
  final bool multiple;
  final Set<int> initiallyOpen;
  final ValueChanged<Set<int>>? onChanged;

  @override
  State<UiAccordion> createState() => _UiAccordionState();
}

class _UiAccordionState extends State<UiAccordion> {
  late Set<int> _open = {...widget.initiallyOpen};

  void _toggle(int i) {
    setState(() {
      if (_open.contains(i)) {
        _open = {..._open}..remove(i);
      } else {
        _open = widget.multiple ? {..._open, i} : {i};
      }
    });
    widget.onChanged?.call(_open);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: t.border))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < widget.children.length; i++)
            _AccordionScope(open: _open.contains(i), toggle: () => _toggle(i), child: widget.children[i]),
        ],
      ),
    );
  }
}

class _AccordionScope extends InheritedWidget {
  const _AccordionScope({required this.open, required this.toggle, required super.child});
  final bool open;
  final VoidCallback toggle;

  @override
  bool updateShouldNotify(_AccordionScope old) => old.open != open;
}

/// `ui-accordion-item`: a titled panel that opens and closes. Inside a [UiAccordion] the accordion
/// decides what's open; on its own it toggles itself (starting at [initiallyOpen]).
///
/// The title row is a heading and an expandable button (at least 38px, 48dp on touch). A closed
/// panel is hidden from screen readers and focus, like the web's `inert`.
class UiAccordionItem extends StatefulWidget {
  const UiAccordionItem({super.key, required this.title, required this.child, this.initiallyOpen = false});

  final String title;
  final Widget child;
  final bool initiallyOpen;

  @override
  State<UiAccordionItem> createState() => _UiAccordionItemState();
}

class _UiAccordionItemState extends State<UiAccordionItem> with SingleTickerProviderStateMixin {
  late bool _selfOpen = widget.initiallyOpen;
  late final AnimationController _c = AnimationController(vsync: this);
  _AccordionScope? _scope;
  bool? _shown;

  bool get _open => _scope?.open ?? _selfOpen;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope = context.dependOnInheritedWidgetOfExactType<_AccordionScope>();
    _sync();
  }

  /// Runs the open/close animation when the open state changes (first time: jump).
  void _sync() {
    final open = _open;
    if (_shown == open) return;
    if (_shown == null) {
      _c.value = open ? 1 : 0;
    } else {
      _c.duration = context.uiAnimate ? context.ui.motionBase : Duration.zero;
      open ? _c.forward() : _c.reverse();
    }
    _shown = open;
  }

  void _toggle() {
    final scope = context.getInheritedWidgetOfExactType<_AccordionScope>();
    if (scope != null) {
      scope.toggle();
    } else {
      setState(() => _selfOpen = !_selfOpen);
      _sync();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final open = _open;
    final touch = uiTouchPlatform(context);
    void toggle() => _toggle();

    return DecoratedBox(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.border))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UiInteractive(
            onTap: toggle,
            pressScale: false,
            padTouchTarget: false,
            builder: (context, s) => Semantics(
              header: true,
              expanded: open,
              onExpand: open ? null : toggle,
              onCollapse: open ? toggle : null,
              child: AnimatedContainer(
                duration: context.uiAnimate ? t.motionFast : Duration.zero,
                curve: t.easeStandard,
                constraints: BoxConstraints(minHeight: touch ? uiMinTouchTarget : t.sizeLg),
                padding: EdgeInsets.all(t.space2),
                decoration: BoxDecoration(color: s.hovered || s.pressed ? t.surfaceHover : null, borderRadius: BorderRadius.circular(t.radiusXs)),
                // Full-width row: an inset ring, so the item borders don't cover it.
                foregroundDecoration: s.focused
                    ? BoxDecoration(border: Border.all(color: t.borderFocus, width: 2), borderRadius: BorderRadius.circular(t.radiusXs))
                    : null,
                child: Row(spacing: t.space3, children: [
                  Expanded(child: Text(widget.title, style: context.uiText.body.copyWith(fontWeight: FontWeight.w500, height: 1.35))),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: context.uiAnimate ? t.motionBase : Duration.zero,
                    curve: t.easeStandard,
                    child: UiIcon(HugeIcons.strokeRoundedArrowDown01, size: 16, color: t.textMuted, strokeWidth: 2),
                  ),
                ]),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _c,
            builder: (context, child) {
              final shown = _c.value > 0;
              return ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: t.easeStandard.transform(_c.value),
                  child: SizedBox(
                    width: double.infinity,
                    child: Visibility(visible: shown, maintainState: true, child: ExcludeFocus(excluding: !open, child: ExcludeSemantics(excluding: !open, child: child!))),
                  ),
                ),
              );
            },
            child: Padding(
              padding: EdgeInsets.fromLTRB(t.space2, 0, t.space2, t.space3),
              child: DefaultTextStyle.merge(style: context.uiText.body.copyWith(color: t.textMuted, height: 1.45), child: widget.child),
            ),
          ),
        ],
      ),
    );
  }
}
