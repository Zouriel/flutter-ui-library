import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import 'docs/doc.dart' show DocGrid;
import 'pages/registry.dart';

const themeLabels = {
  UiThemeName.dark: 'Winter Dark',
  UiThemeName.light: 'Winter Light',
  UiThemeName.lightOrange: 'Light Orange',
  UiThemeName.lightPink: 'Light Pink',
  UiThemeName.lightTeal: 'Light Teal',
  UiThemeName.lightPurple: 'Light Purple',
  UiThemeName.lightPurpleGold: 'Light Purple Gold',
  UiThemeName.darkPink: 'Dark Pink',
  UiThemeName.darkTeal: 'Dark Teal',
  UiThemeName.darkPurple: 'Dark Purple',
  UiThemeName.goldBlack: 'Gold Black',
  UiThemeName.goldRed: 'Gold Red',
  UiThemeName.darkOrange: 'Dark Orange',
  UiThemeName.maldives: 'Maldives',
};

/// The showcase frame: a top bar (menu, title, theme picker) over the current page. On a wide
/// screen the page list stays open on the left.
class ShowcaseShell extends StatefulWidget {
  const ShowcaseShell({super.key, required this.controller});
  final UiThemeController controller;

  @override
  State<ShowcaseShell> createState() => _ShowcaseShellState();
}

class _ShowcaseShellState extends State<ShowcaseShell> {
  // On the web build, #/<page-id> opens that page (handy for links and screenshots).
  late ShowcasePage _page = showcasePageById(Uri.base.fragment.replaceFirst('/', '')) ?? showcasePages.first;
  final _menuOpen = ValueNotifier(false);

  void _go(ShowcasePage p) {
    setState(() => _page = p);
    _menuOpen.value = false;
  }

  @override
  void dispose() {
    _menuOpen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final padding = MediaQuery.paddingOf(context);
    final page = ShowcaseNav(
      go: (id) {
        final p = showcasePageById(id);
        if (p != null) _go(p);
      },
      // Its own traversal group: Tab walks the page in reading order and leaves it only at the end,
      // instead of jumping into the side menu whenever that sits closer on screen (the web's DOM order).
      child: FocusTraversalGroup(child: KeyedSubtree(key: ValueKey(_page.id), child: Builder(builder: _page.builder))),
    );

    final bar = Container(
      height: 52 + padding.top,
      padding: EdgeInsets.only(top: padding.top, left: t.space2, right: t.space2),
      decoration: BoxDecoration(color: t.bg, border: Border(bottom: BorderSide(color: t.border))),
      child: Row(spacing: t.space2, children: [
        if (!wide)
          UiIconButton(
            icon: const UiIcon(HugeIcons.strokeRoundedMenu01),
            label: 'Open menu',
            onPressed: () => _menuOpen.value = true,
          ),
        Expanded(child: wide ? const SizedBox() : Text(_page.label, style: context.uiText.label.copyWith(fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis)),
        _ThemeButton(controller: widget.controller),
      ]),
    );

    // Stretch, so every page gets the full width: a page that is a Stack of positioned layers (the
    // window system) has nothing to size itself by and would otherwise collapse to zero width.
    // The maldives theme's fx layer, like the web shell: the tide along the bottom, behind the page.
    // Always a Stack with a keyed page layer, so switching theme only adds or drops the waves: had the
    // page moved in the tree it would be rebuilt from scratch, and Find Doctor (which switches the
    // theme on opening and back on leaving) then flipped the theme every frame.
    final sea = widget.controller.theme == UiThemeName.maldives;
    final body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      bar,
      Expanded(child: Stack(children: [
        if (sea) const Positioned.fill(child: UiWaveFooter(height: 96, opacity: 0.35)),
        Positioned.fill(key: const ValueKey('page'), child: page),
      ])),
    ]);
    if (wide) {
      return Row(children: [
        SizedBox(width: 280, child: FocusTraversalGroup(child: _Menu(current: _page, onPick: _go))),
        Container(width: 1, color: t.border),
        Expanded(child: body),
      ]);
    }
    return Stack(children: [
      Positioned.fill(child: body),
      ValueListenableBuilder<bool>(
        valueListenable: _menuOpen,
        builder: (context, open, _) => _Drawer(open: open, onClose: () => _menuOpen.value = false, child: _Menu(current: _page, onPick: _go)),
      ),
    ]);
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Row(mainAxisSize: MainAxisSize.min, spacing: t.space2, children: [
      // The owner's portfolio mark, the same logo as the web showcase.
      SvgPicture.asset('assets/logo.svg', width: 24, height: 24, semanticsLabel: 'Zouriel'),
      Text('UI Library', style: context.uiText.label.copyWith(fontSize: 14)),
    ]);
  }
}

/// A slide-in drawer with a dimmed backdrop. Closes on backdrop tap and on Back.
class _Drawer extends StatelessWidget {
  const _Drawer({required this.open, required this.onClose, required this.child});
  final bool open;
  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final dur = context.uiAnimate ? t.motionSlow : Duration.zero;
    return IgnorePointer(
      ignoring: !open,
      child: Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            child: AnimatedOpacity(opacity: open ? 1 : 0, duration: dur, child: ColoredBox(color: t.overlay)),
          ),
        ),
        AnimatedPositioned(
          duration: dur,
          curve: t.easeStandard,
          top: 0,
          bottom: 0,
          left: open ? 0 : -300,
          width: 300,
          child: PopScope(
            canPop: !open,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) onClose();
            },
            child: Container(
              decoration: BoxDecoration(color: t.surface, boxShadow: open ? t.shadow3 : const []),
              child: SafeArea(right: false, child: child),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu({required this.current, required this.onPick});
  final ShowcasePage current;
  final ValueChanged<ShowcasePage> onPick;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final groups = <String, List<ShowcasePage>>{};
    for (final p in showcasePages) {
      groups.putIfAbsent(p.group, () => []).add(p);
    }
    return ColoredBox(
      color: t.surface,
      child: ListView(
        padding: EdgeInsets.symmetric(vertical: t.space4, horizontal: t.space3),
        children: [
          Padding(padding: EdgeInsets.only(left: t.space2, bottom: t.space4), child: const _Brand()),
          for (final g in groups.entries) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(t.space2, t.space3, 0, t.space1),
              child: Text(g.key.toUpperCase(), style: context.uiText.code.copyWith(fontSize: 11, letterSpacing: 11 * 0.2, color: t.textMuted)),
            ),
            for (final p in g.value) _MenuItem(page: p, selected: p.id == current.id, onTap: () => onPick(p)),
          ],
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.page, required this.selected, required this.onTap});
  final ShowcasePage page;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return UiInteractive(
      onTap: onTap,
      selected: selected,
      semanticLabel: page.label,
      excludeChildSemantics: true,
      pressScale: false,
      padTouchTarget: false,
      builder: (context, s) => AnimatedContainer(
        duration: t.motionFast,
        height: 44,
        padding: EdgeInsets.symmetric(horizontal: t.space3),
        decoration: BoxDecoration(
          color: selected ? t.selected : s.hovered || s.pressed ? t.surfaceHover : null,
          borderRadius: BorderRadius.circular(t.radius),
          boxShadow: s.focused ? t.focusRing : const [],
        ),
        child: Row(spacing: t.space3, children: [
          UiIcon(page.icon, size: 18, color: selected ? t.primary : t.textMuted),
          Expanded(
            child: Text(page.label, style: context.uiText.body.copyWith(fontSize: 14, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: selected ? t.text : t.textSecondary)),
          ),
        ]),
      ),
    );
  }
}

/// Opens a sheet listing all 14 themes, each with a swatch.
class _ThemeButton extends StatelessWidget {
  const _ThemeButton({required this.controller});
  final UiThemeController controller;

  @override
  Widget build(BuildContext context) {
    return UiButton(
      label: themeLabels[controller.theme]!,
      variant: UiButtonVariant.outline,
      size: UiSize.sm,
      icon: const UiIcon(HugeIcons.strokeRoundedPaintBrush02),
      onPressed: () => Navigator.of(context).push(PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: true,
        barrierLabel: 'Close themes',
        barrierColor: context.ui.overlay,
        transitionDuration: context.ui.motionSlow,
        pageBuilder: (context, a, b) => _ThemeSheet(controller: controller),
        transitionsBuilder: (context, a, b, child) => SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: const Cubic(0, 0, 0, 1))),
          child: child,
        ),
      )),
    );
  }
}

class _ThemeSheet extends StatelessWidget {
  const _ThemeSheet({required this.controller});
  final UiThemeController controller;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusLg)), boxShadow: t.shadow3),
        padding: EdgeInsets.fromLTRB(t.space4, t.space3, t.space4, t.space4 + MediaQuery.paddingOf(context).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: t.borderStrong, borderRadius: BorderRadius.circular(2)))),
          const UiText('Theme', variant: UiTextVariant.h4, heading: true),
          DocGrid(minWidth: 150, minColumns: 2, maxColumns: 3, children: [
            for (final th in UiThemeName.values)
              _ThemeTile(
                theme: th,
                selected: th == controller.theme,
                onTap: () {
                  controller.set(th);
                  Navigator.of(context).pop();
                },
              ),
          ]),
        ]),
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({required this.theme, required this.selected, required this.onTap});
  final UiThemeName theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final tok = uiThemeTokens[theme]!;
    return UiInteractive(
      onTap: onTap,
      selected: selected,
      semanticLabel: themeLabels[theme],
      excludeChildSemantics: true,
      padTouchTarget: false,
      builder: (context, s) => Container(
        padding: EdgeInsets.all(t.space2),
        decoration: BoxDecoration(
          color: tok.bg,
          borderRadius: BorderRadius.circular(t.radius),
          border: Border.all(color: selected ? t.primary : t.border, width: selected ? 2 : 1),
          boxShadow: s.focused ? t.focusRing : const [],
        ),
        // Swatches above the name, so the longest name ("Light Purple Gold") gets the tile's full width.
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space1, children: [
          Row(spacing: t.space1, children: [
            for (final c in [tok.primary, tok.surfaceRaised, tok.text]) Container(width: 12, height: 12, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: tok.border))),
          ]),
          Text(themeLabels[theme]!, style: context.uiText.caption.copyWith(color: tok.text), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}
