import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../button/button.dart';
import '../core/icon.dart';
import '../core/interactive.dart';
import '../core/types.dart';
import '../dialog/modal.dart';
import '../dialog/route.dart';
import '../theme/theme.dart';

/// One thing the palette can run, the web `UiCommand`.
@immutable
class UiCommand {
  const UiCommand({required this.label, required this.value, this.group, this.icon, this.shortcut, this.keywords});

  final String label;

  /// Unique; identifies the command to your handler.
  final String value;

  /// Shown at the end of the row and matched by the filter.
  final String? group;

  /// A leading icon (`UiIcon(HugeIcons...)`), or a short text such as a letter. Drawn muted.
  final Widget? icon;

  /// Display only, e.g. "Ctrl+S". The palette does not bind it.
  final String? shortcut;

  /// Extra words the filter matches but the row does not show.
  final String? keywords;

  /// The web filter: case-insensitive substring over label, group and keywords.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return '$label ${group ?? ''} ${keywords ?? ''}'.toLowerCase().contains(q);
  }
}

/// Opens a [UiCommandPalette] and completes with the command that was run, or null when it was
/// closed. [onRun] is called too, before it closes.
///
/// On a phone (narrower than [fullScreenBelow]) it is a full-screen search page: a back button
/// and the search field at the top, results filling the rest, the keyboard up. On wider screens it
/// is the web's centred dialog near the top. It binds no shortcut of its own: open it from your
/// own button, or from a Ctrl/Cmd+K handler on hardware keyboards.
Future<UiCommand?> showUiCommandPalette({
  required BuildContext context,
  required List<UiCommand> commands,
  ValueChanged<UiCommand>? onRun,
  String placeholder = 'Type a command or search…',
  double fullScreenBelow = 600,
  bool? glass,
  bool? radius,
  bool useRootNavigator = true,
}) {
  final full = MediaQuery.sizeOf(context).width < fullScreenBelow;
  return Navigator.of(context, rootNavigator: useRootNavigator).push<UiCommand>(UiDialogRoute<UiCommand>.themed(
    context,
    transitions: full ? _riseTransition : uiScaleTransition,
    builder: (context) => UiCommandPalette(
      commands: commands,
      placeholder: placeholder,
      fullScreen: full,
      glass: glass,
      radius: radius,
      onRun: (c) {
        onRun?.call(c);
        Navigator.pop(context, c);
      },
      onClose: () => Navigator.maybePop(context),
    ),
  ));
}

Widget _riseTransition(BuildContext context, Animation<double> animation, Widget child) {
  final t = context.ui;
  final curved = CurvedAnimation(parent: animation, curve: t.easeDecelerate, reverseCurve: t.easeAccelerate);
  return FadeTransition(
    opacity: curved,
    child: SlideTransition(position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(curved), child: child),
  );
}

/// `ui-command-palette`: a search-and-run list of commands. Open it with [showUiCommandPalette].
///
/// Typing filters by case-insensitive substring over label, group and keywords. ArrowUp/Down move
/// the highlight while the field keeps focus, Enter (or the keyboard's search key) runs it, and so
/// does a tap; Escape, the back button or the backdrop close it. Focus is trapped while it is
/// open and goes back where it was afterwards (the route does that).
class UiCommandPalette extends StatefulWidget {
  const UiCommandPalette({
    super.key,
    required this.commands,
    required this.onRun,
    required this.onClose,
    this.placeholder = 'Type a command or search…',
    this.fullScreen = false,
    this.glass,
    this.radius,
  });

  final List<UiCommand> commands;
  final ValueChanged<UiCommand> onRun;
  final VoidCallback onClose;
  final String placeholder;
  final bool fullScreen;
  final bool? glass;
  final bool? radius;

  @override
  State<UiCommandPalette> createState() => _UiCommandPaletteState();
}

class _UiCommandPaletteState extends State<UiCommandPalette> {
  final TextEditingController _query = TextEditingController();
  final FocusNode _field = FocusNode(debugLabel: 'UiCommandPalette field');
  final ScrollController _list = ScrollController();
  int _active = 0;
  bool _ran = false;

  List<UiCommand> get _filtered => [for (final c in widget.commands) if (c.matches(_query.text)) c];

  double _rowHeight(BuildContext context) => widget.fullScreen || uiTouchPlatform(context) ? uiMinTouchTarget : 36;

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() => _active = 0));
    // The field's underline carries the keyboard focus cue.
    _field.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    _field.dispose();
    _list.dispose();
    super.dispose();
  }

  void _run(UiCommand c) {
    if (_ran) return;
    _ran = true;
    widget.onRun(c);
  }

  void _move(int by) {
    final n = _filtered.length;
    if (n == 0) return;
    setState(() => _active = (_active + by).clamp(0, n - 1));
    _reveal();
  }

  /// Keeps the highlighted row inside the scrolled list.
  void _reveal() {
    if (!_list.hasClients) return;
    final h = _rowHeight(context);
    final top = _active * h, bottom = top + h;
    final view = _list.position.viewportDimension;
    final pad = context.ui.space1;
    if (top < _list.offset) {
      _list.jumpTo(math.max(0, top));
    } else if (bottom + 2 * pad > _list.offset + view) {
      _list.jumpTo(math.min(_list.position.maxScrollExtent, bottom + 2 * pad - view));
    }
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowDown) {
      _move(1);
    } else if (k == LogicalKeyboardKey.arrowUp) {
      _move(-1);
    } else if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
      final f = _filtered;
      if (f.isNotEmpty) _run(f[_active.clamp(0, f.length - 1)]);
    } else if (k == LogicalKeyboardKey.escape) {
      widget.onClose();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final full = widget.fullScreen;
    final items = _filtered;
    // Every shortcut in view: rows reserve the widest one's width, so groups line up down the list.
    final shortcuts = {for (final c in items) ?c.shortcut}.toList();
    final rowH = _rowHeight(context);

    final field = _SearchField(
      controller: _query,
      focusNode: _field,
      placeholder: widget.placeholder,
      onKey: _onKey,
      onSubmitted: () {
        final f = _filtered;
        if (f.isNotEmpty) _run(f[_active.clamp(0, f.length - 1)]);
      },
    );
    final list = items.isEmpty
        ? Padding(
            padding: EdgeInsets.all(t.space4),
            child: Text('No results', textAlign: TextAlign.center, style: theme.typography.body.copyWith(color: t.textMuted, fontSize: t.fontSizeSm)),
          )
        : ListView.builder(
            controller: _list,
            shrinkWrap: !full,
            padding: EdgeInsets.all(t.space1),
            itemCount: items.length,
            itemExtent: rowH,
            itemBuilder: (context, i) => _Row(
              command: items[i],
              shortcuts: shortcuts,
              active: i == _active,
              onTap: () => _run(items[i]),
              onHover: () => setState(() => _active = i),
            ),
          );

    final header = Container(
      height: full ? 56 : 46,
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _field.hasFocus && FocusManager.instance.highlightMode == FocusHighlightMode.traditional ? t.borderFocus : t.border))),
      padding: EdgeInsetsDirectional.only(start: full ? t.space1 : t.space4, end: t.space4),
      child: Row(children: [
        if (full) UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedArrowLeft01), label: 'Close', size: UiSize.lg, onPressed: widget.onClose),
        Expanded(child: field),
      ]),
    );

    if (full) {
      final mq = MediaQuery.of(context);
      return UiDialogScope(
        label: 'Command palette',
        autofocus: false,
        onClose: widget.onClose,
        child: ColoredBox(
          color: t.surface,
          child: Padding(
            padding: EdgeInsets.only(top: mq.padding.top, bottom: mq.viewInsets.bottom),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [header, Expanded(child: list)]),
          ),
        ),
      );
    }

    final isGlass = widget.glass ?? theme.config.glass;
    final r = (widget.radius ?? theme.config.radius) ? t.radiusLg : 0.0;
    Widget panel = DecoratedBox(
      decoration: BoxDecoration(
        color: isGlass ? t.glassPanelBg : t.surfaceRaised,
        border: Border.all(color: isGlass ? t.glassBorder : t.border),
        borderRadius: BorderRadius.circular(r),
        boxShadow: t.shadow3,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          header,
          ConstrainedBox(constraints: const BoxConstraints(maxHeight: 320), child: list),
        ]),
      ),
    );
    if (isGlass) {
      panel = ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: t.glassBlur, sigmaY: t.glassBlur), child: panel),
      );
    }
    final size = MediaQuery.sizeOf(context);
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(top: size.height * 0.12),
        child: SizedBox(
          width: math.min(560, size.width * 0.92),
          child: UiDialogScope(label: 'Command palette', autofocus: false, onClose: widget.onClose, child: panel),
        ),
      ),
    );
  }
}

/// The palette's search field: a bare [EditableText] with a placeholder, keeping focus while the
/// arrow keys move the highlight.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.focusNode, required this.placeholder, required this.onKey, required this.onSubmitted});

  final TextEditingController controller;
  final FocusNode focusNode;
  final String placeholder;
  final FocusOnKeyEventCallback onKey;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final style = theme.typography.body.copyWith(fontSize: t.fontSizeMd, height: 1.35);
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: onKey,
      child: Semantics(
        hint: placeholder,
        child: Stack(
          alignment: AlignmentDirectional.centerStart,
          children: [
            ListenableBuilder(
              listenable: controller,
              builder: (context, _) => controller.text.isEmpty
                  ? IgnorePointer(child: ExcludeSemantics(child: Text(placeholder, maxLines: 1, overflow: TextOverflow.ellipsis, style: style.copyWith(color: t.textMuted))))
                  : const SizedBox.shrink(),
            ),
            EditableText(
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
              style: style,
              cursorColor: t.primary,
              backgroundCursorColor: t.textMuted,
              selectionColor: t.primary.withValues(alpha: 0.3),
              textInputAction: TextInputAction.search,
              autocorrect: false,
              enableSuggestions: false,
              onSubmitted: (_) => onSubmitted(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.command, required this.active, required this.onTap, required this.onHover, this.shortcuts = const []});

  final UiCommand command;

  /// The shortcuts of all rows in view; the shortcut slot is as wide as the widest of them.
  final List<String> shortcuts;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onHover;

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final small = theme.typography.body.copyWith(fontSize: t.fontSizeSm, height: 1.35);
    final c = command;
    // Not focusable: the field keeps focus and the arrow keys move the highlight, like the web.
    return ExcludeFocus(
      child: MouseRegion(
        onEnter: (_) => onHover(),
        child: UiInteractive(
          onTap: onTap,
          selected: active,
          padTouchTarget: false,
          pressScale: false,
          builder: (context, s) => AnimatedContainer(
            duration: context.uiAnimate ? t.motionFast : Duration.zero,
            padding: EdgeInsets.symmetric(horizontal: t.space3),
            decoration: BoxDecoration(
              color: active || s.pressed ? t.elevatedHover : null,
              borderRadius: BorderRadius.circular(theme.radius(t.radiusXs)),
            ),
            child: Row(
              spacing: t.space2,
              children: [
                if (c.icon != null)
                  SizedBox(
                    width: 16,
                    child: IconTheme.merge(
                      data: IconThemeData(color: t.textMuted, size: 16),
                      child: DefaultTextStyle.merge(style: small.copyWith(color: t.textMuted), child: Center(child: c.icon!)),
                    ),
                  ),
                Expanded(child: Text(c.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: small)),
                if (c.group != null) Text(c.group!, style: small.copyWith(color: t.textMuted)),
                // A slot as wide as the widest shortcut in view (each one laid out, only this row's
                // shown), so the group column sits at the same x with or without a shortcut.
                if (shortcuts.isNotEmpty)
                  Stack(alignment: AlignmentDirectional.centerEnd, children: [
                    for (final k in shortcuts)
                      Visibility(visible: k == c.shortcut, maintainSize: true, maintainAnimation: true, maintainState: true, child: _Kbd(k)),
                  ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A key hint, matching `ui-kbd`.
class _Kbd extends StatelessWidget {
  const _Kbd(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    return Container(
      constraints: const BoxConstraints(minWidth: 11 * 1.4),
      height: 11 * 1.5 + 3,
      padding: const EdgeInsets.symmetric(horizontal: 4.4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: BorderRadius.circular(t.radiusXs),
        border: Border(
          top: BorderSide(color: t.border),
          left: BorderSide(color: t.border),
          right: BorderSide(color: t.border),
          bottom: BorderSide(color: t.border, width: 2),
        ),
      ),
      child: Text(text, style: theme.typography.code.copyWith(fontSize: 11, height: 1, color: t.textMuted)),
    );
  }
}
