import 'package:flutter/widgets.dart';

import '../core/interactive.dart';
import '../theme/theme.dart';

/// `ui-skip-link` (0.87.0): "Skip to content", the first thing a keyboard reaches on a page. It takes
/// no room and shows nothing until it has keyboard focus; then a primary pill appears at the top-start
/// corner of the overlay. Activating it moves focus to [target] (the page's main content) and scrolls
/// that into view. Put it first in the page, before the navigation it skips.
class UiSkipLink extends StatefulWidget {
  const UiSkipLink({super.key, required this.target, this.label});

  /// The focus node of the page's main content.
  final FocusNode target;

  /// The link's words; null: [UiStrings.skipToContent].
  final String? label;

  @override
  State<UiSkipLink> createState() => _UiSkipLinkState();
}

class _UiSkipLinkState extends State<UiSkipLink> {
  final OverlayPortalController _overlay = OverlayPortalController();

  void _skip() {
    widget.target.requestFocus();
    final target = widget.target.context;
    if (target != null) Scrollable.ensureVisible(target, duration: context.uiAnimate ? context.ui.motionBase : Duration.zero);
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.label ?? context.uiStrings.skipToContent;
    return UiInteractive(
      onTap: _skip,
      button: false,
      link: true,
      semanticLabel: text,
      excludeChildSemantics: true,
      pressScale: false,
      padTouchTarget: false,
      onFocusChange: (focused) => focused ? _overlay.show() : _overlay.hide(),
      builder: (context, s) => OverlayPortal(
        controller: _overlay,
        overlayChildBuilder: (context) {
          final t = context.ui;
          return PositionedDirectional(
            top: MediaQuery.paddingOf(context).top + t.space2,
            start: t.space2,
            child: GestureDetector(
              onTap: _skip,
              excludeFromSemantics: true,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: t.space2, horizontal: t.space4),
                  decoration: BoxDecoration(
                    color: t.primary,
                    borderRadius: BorderRadius.circular(context.uiTheme.radius()),
                    boxShadow: [...t.shadow2, if (s.focused) ...t.focusRing],
                  ),
                  child: Text(text, style: context.uiText.body.copyWith(fontSize: t.fontSizeSm, fontWeight: FontWeight.w600, color: t.primaryContrast, decoration: TextDecoration.none)),
                ),
              ),
            ),
          );
        },
        child: const SizedBox.shrink(),
      ),
    );
  }
}
