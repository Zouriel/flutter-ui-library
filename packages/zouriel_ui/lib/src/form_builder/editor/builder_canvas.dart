import 'dart:ui' show SemanticsRole;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/icon.dart';
import '../../core/interactive.dart';
import '../../overlay/anchored.dart';
import '../../overlay/menu.dart';
import '../../theme/theme.dart';
import '../engine/definition.dart';
import '../engine/field_types.dart';
import '../engine/js.dart';
import '../engine/schema.dart';
import 'builder_bits.dart';
import 'builder_dnd.dart';
import 'builder_store.dart';

const Map<String, int> _span = {'full': 12, 'two-thirds': 8, 'half': 6, 'third': 4};

/// One-tap starters for an empty form.
const List<(String, String)> _starters = [
  ('text', 'Short text'),
  ('email', 'Email'),
  ('select', 'Dropdown'),
  ('radio', 'Single choice'),
  ('date', 'Date'),
  ('group', 'Section'),
];

class _OpenIntent extends Intent {
  const _OpenIntent();
}

class _DeleteIntent extends Intent {
  const _DeleteIntent();
}

class _DuplicateIntent extends Intent {
  const _DuplicateIntent();
}

class _NudgeIntent extends Intent {
  const _NudgeIntent(this.delta);
  final int delta;
}

/// `ui-fb-canvas`: the form as it's being built: page tabs, then each question as a card (a small
/// preview of how it will look), with sections as drop zones.
///
/// A tap selects a card and shows its toolbar (settings, move up/down, duplicate, delete, more).
/// Holding a card (or Enter on it) opens its settings through [onOpen]. Drag a card by its grip to
/// move it, into or out of sections, or onto another page's tab. With a hardware keyboard,
/// Alt+Up/Down moves the focused card, Ctrl+D duplicates it and Delete removes it.
class UiFbCanvas extends StatefulWidget {
  const UiFbCanvas({
    super.key,
    this.dnd,
    this.onAddAt,
    this.onDeleteRequest,
    this.onPicked,
    this.onOpen,
    this.onOpenForm,
    this.paletteBeside = false,
    this.bottomPadding = 0,
  });

  /// The builder's drag and drop; the canvas makes its own when used alone.
  final FbDnd? dnd;

  /// Someone wants to add a field at a specific place (the builder shows the palette).
  final ValueChanged<UiFbDropTarget>? onAddAt;

  /// Delete was asked for (toolbar, Delete key, page menu); the builder confirms when needed.
  final ValueChanged<String>? onDeleteRequest;

  /// A card was chosen (selected, showing its toolbar); null for the form.
  final ValueChanged<String?>? onPicked;

  /// Open the settings of a card or page: its toolbar's settings button, a long press, or Enter.
  final ValueChanged<String>? onOpen;

  /// The form's own settings were asked for (holding the form title).
  final VoidCallback? onOpenForm;

  /// The palette sits beside the canvas (changes the empty page's hint).
  final bool paletteBeside;

  /// Room left under the last card (for a floating button over it).
  final double bottomPadding;

  @override
  State<UiFbCanvas> createState() => _UiFbCanvasState();
}

class _UiFbCanvasState extends State<UiFbCanvas> {
  final ScrollController _scroll = ScrollController();
  FbDnd? _own;

  FbDnd _dndFor(UiFormBuilderController store) => widget.dnd ?? (_own ??= FbDnd(store));

  @override
  void dispose() {
    _scroll.dispose();
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final store = UiFbBuilderScope.of(context);
    final dnd = _dndFor(store);
    dnd.scroller = _scroll;
    return ListenableBuilder(
      listenable: dnd,
      builder: (context, _) {
        final def = store.def;
        final page = store.page;
        final over = dnd.drop?.over;
        return ColoredBox(
          color: t.bg,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _PageTabs(store: store, dnd: dnd, over: over, onOpen: widget.onOpen),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  store.select(null);
                  widget.onPicked?.call(null);
                },
                child: SingleChildScrollView(
                  key: dnd.viewportKey,
                  controller: _scroll,
                  padding: EdgeInsets.fromLTRB(t.space3, t.space4, t.space3, t.space12 + widget.bottomPadding),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
                        _FormHead(store: store, onPicked: widget.onPicked, onOpenForm: widget.onOpenForm),
                        if (def.pages.length > 1) _PageHead(store: store, onOpen: widget.onOpen, onDelete: widget.onDeleteRequest),
                        _ListBox(
                          key: dnd.listKey(page.id),
                          over: over == page.id,
                          minHeight: 8,
                          child: _Items(elements: page.elements, cols: 1, host: this),
                        ),
                        if (page.elements.isEmpty)
                          _Empty(store: store, multiPage: def.pages.length > 1, paletteBeside: widget.paletteBeside)
                        else
                          _AddButton(
                            label: 'Add a field',
                            wide: true,
                            onTap: () => widget.onAddAt?.call(UiFbDropTarget(containerId: page.id, index: page.elements.length)),
                          ),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        );
      },
    );
  }

  // ── Card actions ──────────────────────────────────────────────────────────────────────────

  void pick(UiFormBuilderController store, String id) {
    store.select(id);
    widget.onPicked?.call(id);
  }

  void open(UiFormBuilderController store, String id) {
    store.select(id);
    widget.onOpen?.call(id);
  }

  List<UiMenuItem> moreItems(UiFormBuilderController store, UiFbElement el) {
    final entry = store.index[el.id];
    final items = <UiMenuItem>[];
    if (entry != null && store.index[entry.parentId]?.kind == 'group') items.add(const UiMenuItem(label: 'Move out of the section', value: 'out'));
    final pages = store.def.pages;
    for (var i = 0; i < pages.length; i++) {
      if (pages[i].id != entry?.page.id) items.add(UiMenuItem(label: 'Move to ${(pages[i].title ?? '').isNotEmpty ? pages[i].title : 'Page ${i + 1}'}', value: 'page:${pages[i].id}'));
    }
    items.add(el.archived == true ? const UiMenuItem(label: 'Restore', value: 'restore') : const UiMenuItem(label: 'Archive (hide, keep answers)', value: 'archive'));
    return items;
  }

  void more(UiFormBuilderController store, UiFbElement el, UiMenuItem item) {
    final v = item.value;
    final entry = store.index[el.id];
    if (entry == null) return;
    if (v == 'out') {
      final parent = store.index[entry.parentId]!;
      store.move(el.id, UiFbDropTarget(containerId: parent.parentId, index: parent.index + 1));
    } else if (v.startsWith('page:')) {
      final pageId = v.substring(5);
      final page = store.def.pages.where((p) => p.id == pageId).firstOrNull;
      if (store.move(el.id, UiFbDropTarget(containerId: pageId, index: page?.elements.length ?? 0))) store.select(el.id);
    } else if (v == 'archive') {
      store.setArchived(el.id, true);
    } else if (v == 'restore') {
      store.setArchived(el.id, false);
    }
  }

  Map<ShortcutActivator, Intent> get shortcuts => const {
    SingleActivator(LogicalKeyboardKey.enter): _OpenIntent(),
    SingleActivator(LogicalKeyboardKey.delete): _DeleteIntent(),
    SingleActivator(LogicalKeyboardKey.backspace): _DeleteIntent(),
    SingleActivator(LogicalKeyboardKey.arrowUp, alt: true): _NudgeIntent(-1),
    SingleActivator(LogicalKeyboardKey.arrowDown, alt: true): _NudgeIntent(1),
    SingleActivator(LogicalKeyboardKey.keyD, control: true): _DuplicateIntent(),
    SingleActivator(LogicalKeyboardKey.keyD, meta: true): _DuplicateIntent(),
  };

  Map<Type, Action<Intent>> actions(UiFormBuilderController store, String id) => {
    _OpenIntent: CallbackAction<_OpenIntent>(onInvoke: (_) => open(store, id)),
    _DeleteIntent: CallbackAction<_DeleteIntent>(onInvoke: (_) => widget.onDeleteRequest?.call(id)),
    _DuplicateIntent: CallbackAction<_DuplicateIntent>(onInvoke: (_) => store.duplicate(id)),
    _NudgeIntent: CallbackAction<_NudgeIntent>(onInvoke: (i) {
      store.select(id);
      store.nudge(id, i.delta);
      return null;
    }),
  };
}

/// A list (page or section body) that lights up while something is dragged over it.
class _ListBox extends StatelessWidget {
  const _ListBox({super.key, required this.over, required this.child, this.minHeight = 36});
  final bool over;
  final Widget child;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return AnimatedContainer(
      duration: context.uiAnimate ? t.motionFast : Duration.zero,
      constraints: BoxConstraints(minHeight: minHeight),
      decoration: BoxDecoration(color: over ? t.primary.withValues(alpha: 0.06) : const Color(0x00000000), borderRadius: BorderRadius.circular(t.radius)),
      child: child,
    );
  }
}

/// Cards laid out on the 12-column grid the renderer uses (one column on narrow screens).
class _Items extends StatelessWidget {
  const _Items({required this.elements, required this.cols, required this.host});
  final List<UiFbElement> elements;
  final num cols;
  final _UiFbCanvasState host;

  int _spanOf(UiFbElement el) {
    final w = el is UiFbStatic && el.type != 'paragraph' ? null : switch (el) {
      UiFbField(:final layout) => layout?.width,
      UiFbGroup(:final layout) => layout?.width,
      UiFbStatic(:final layout) => layout?.width,
    };
    if (w != null) return _span[w] ?? 12;
    if (el is UiFbStatic && el.type != 'paragraph') return 12;
    return cols > 1 ? (12 / cols).round() : 12;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    if (elements.isEmpty) return const SizedBox(width: double.infinity);
    final gap = t.space2;
    return LayoutBuilder(builder: (context, box) {
      final narrow = box.maxWidth < 520;
      return Wrap(spacing: gap, runSpacing: gap, children: [
        for (final el in elements)
          SizedBox(
            key: host._dndFor(UiFbBuilderScope.of(context)).itemKey(el.id),
            width: narrow ? box.maxWidth : ((box.maxWidth + gap) * _spanOf(el) / 12 - gap - 0.01).clamp(0, box.maxWidth),
            child: _Card(el: el, host: host),
          ),
      ]);
    });
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.el, required this.host});
  final UiFbElement el;
  final _UiFbCanvasState host;

  @override
  Widget build(BuildContext context) {
    final store = UiFbBuilderScope.of(context);
    final dnd = host._dndFor(store);
    final moving = dnd.movingId == el.id;
    final card = el is UiFbGroup ? _GroupCard(g: el as UiFbGroup, host: host) : _ItemCard(el: el, host: host);
    return Opacity(opacity: moving ? 0.4 : (el.archived == true ? 0.55 : 1), child: card);
  }
}

/// The drag handle: dragging it moves the card at once (no hold needed).
class _Grip extends StatelessWidget {
  const _Grip({required this.el, required this.host, required this.visible});
  final UiFbElement el;
  final _UiFbCanvasState host;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final store = UiFbBuilderScope.of(context);
    final dnd = host._dndFor(store);
    final name = store.name(el.id);
    return Semantics(
      label: 'Drag $name to move it',
      child: FbDragSource(
        dnd: dnd,
        payload: () => FbDragPayload.move(id: el.id, label: name, icon: fbElementIcon(el)),
        child: SizedBox(
          width: 32,
          height: 40,
          child: Center(child: UiIcon(HugeIcons.strokeRoundedDragDropVertical, size: 16, color: t.textMuted.withValues(alpha: visible ? 1 : 0.6))),
        ),
      ),
    );
  }
}

/// Everything a card's chips say: archived, problems, rules, checks, data source.
List<Widget> _badges(UiFormBuilderController store, UiFbElement el) {
  final out = <Widget>[];
  if (el.archived == true) out.add(const FbChip('Archived', tone: FbTone.warn));
  if (store.problemIds.contains(el.id)) out.add(const FbChip('Needs attention', tone: FbTone.bad, tooltip: 'Something needs fixing. Select to see.'));
  final vis = el.visibility;
  if (vis != null) {
    final show = vis.action == 'show';
    out.add(FbChip(show ? 'Shown when…' : 'Hidden when…', tone: FbTone.logic, tooltip: '${show ? 'Shown when' : 'Hidden when'} ${store.describe(vis.when)}'));
  }
  if (el is UiFbField) {
    final r = el.required;
    if (r != null && r.isConditional) out.add(FbChip('Required when…', tone: FbTone.logic, tooltip: 'Required when ${store.describe(r.when)}'));
    final d = el.disabled;
    if (d != null && (d.isConditional || d.flag == true)) {
      out.add(FbChip(d.isConditional ? 'Locked when…' : 'Locked', tooltip: d.isConditional ? 'Locked when ${store.describe(d.when)}' : 'Can’t be changed'));
    }
    if ((el.setValue ?? const []).isNotEmpty) out.add(const FbChip('Fills itself', tone: FbTone.logic));
    final n = el.validators?.length ?? 0;
    if (n > 0) out.add(FbChip('$n check${n > 1 ? 's' : ''}'));
    if (el.source != null) {
      final name = _sourceName(store, el);
      out.add(FbChip('From $name', tooltip: 'Options come from the $name list'));
    }
  }
  if (el is UiFbGroup) {
    final d = el.disabled;
    if (d != null && (d.isConditional || d.flag == true)) out.add(FbChip(d.isConditional ? 'Locked when…' : 'Locked'));
  }
  return out;
}

String _sourceName(UiFormBuilderController store, UiFbField f) =>
    store.optionSourceDefs.where((d) => d.type == f.source?.type).firstOrNull?.label ?? f.source?.type ?? '';

/// A field or static card.
class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.el, required this.host});
  final UiFbElement el;
  final _UiFbCanvasState host;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final store = UiFbBuilderScope.of(context);
    final selected = store.selectedId == el.id;
    final problem = store.problemIds.contains(el.id);
    final f = el is UiFbField ? el as UiFbField : null;
    final info = f == null ? null : fieldTypeInfo(f.type);
    final name = store.name(el.id);
    final label = f != null ? '${f.label.isNotEmpty ? f.label : info!.label}, ${info!.label} field' : name;
    final badges = _badges(store, el);

    Widget head;
    if (f != null) {
      head = Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: t.surfaceHover, borderRadius: BorderRadius.circular(t.radiusXs)),
          child: UiIcon(fbFieldIcon(f.type), size: 13, color: t.textMuted),
        ),
        Text.rich(
          TextSpan(
            text: f.label.isNotEmpty ? f.label : 'No label',
            children: [if (f.required?.flag == true) TextSpan(text: ' *', style: TextStyle(color: t.danger))],
          ),
          style: f.label.isNotEmpty
              ? context.uiText.label.copyWith(fontSize: 13, fontWeight: FontWeight.w500, color: t.text)
              : context.uiText.body.copyWith(fontSize: 13, fontStyle: FontStyle.italic, color: t.textMuted),
        ),
        ...badges,
      ]);
    } else {
      final s = el as UiFbStatic;
      final text = switch (s.type) {
        'heading' => Text((s.text ?? '').isNotEmpty ? s.text! : 'Heading', style: context.uiText.h6.copyWith(fontSize: 15, color: t.text)),
        'paragraph' => Text(
          (s.text ?? '').isNotEmpty ? s.text! : 'Text block',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.uiText.body.copyWith(fontSize: 12, height: 1.4, color: t.textSecondary),
        ),
        _ => Container(height: 1, constraints: const BoxConstraints(minWidth: 60), color: t.border),
      };
      head = s.type == 'divider'
          ? Row(spacing: 6, children: [Expanded(child: text), ...badges])
          : Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [text, ...badges]);
    }

    final body = UiInteractive(
      onTap: () => host.pick(store, el.id),
      onLongPress: () {
        HapticFeedback.selectionClick();
        host.open(store, el.id);
      },
      button: false,
      selected: selected,
      semanticLabel: label,
      semanticHint: badges.isEmpty ? null : _badgeWords(store, el),
      excludeChildSemantics: true,
      pressScale: false,
      padTouchTarget: false,
      shortcuts: host.shortcuts,
      actions: host.actions(store, el.id),
      builder: (context, s) => Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(0, t.space2, t.space2, t.space2),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(t.radius), boxShadow: s.focused ? t.focusRing : null),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 6, children: [
          head,
          if (f != null) _Mock(field: f, store: store),
          if (f?.help != null && f!.help!.isNotEmpty) Text(f.help!, style: context.uiText.body.copyWith(fontSize: 12, height: 1.35, color: t.textMuted)),
        ]),
      ),
    );

    return _CardFrame(
      selected: selected,
      problem: problem,
      dashed: el.archived == true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Grip(el: el, host: host, visible: selected),
          Expanded(child: body),
        ]),
        if (selected) _Toolbar(el: el, host: host),
      ]),
    );
  }
}

String _badgeWords(UiFormBuilderController store, UiFbElement el) {
  final words = <String>[];
  if (el.archived == true) words.add('archived');
  if (store.problemIds.contains(el.id)) words.add('needs attention');
  if (el.visibility != null) words.add('${el.visibility!.action == 'show' ? 'shown when' : 'hidden when'} ${store.describe(el.visibility!.when)}');
  return words.join(', ');
}

class _CardFrame extends StatelessWidget {
  const _CardFrame({required this.selected, required this.problem, required this.child, this.dashed = false, this.group = false, this.repeat = false});
  final bool selected;
  final bool problem;
  final bool dashed;
  final bool group;
  final bool repeat;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final border = selected ? t.primary : problem ? Color.lerp(t.danger, t.border, 0.4)! : t.borderSubtle;
    final bg = group ? Color.lerp(t.surface, t.bg, 0.45)! : t.surface;
    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border, width: selected ? 2 : 1),
        borderRadius: BorderRadius.circular(t.radius),
      ),
      foregroundDecoration: repeat
          ? BoxDecoration(
              border: Border(left: BorderSide(color: t.primary.withValues(alpha: 0.4), width: 2)),
              borderRadius: BorderRadius.circular(t.radius),
            )
          : null,
      // Keep the content still when the border thickens on selection.
      padding: EdgeInsets.all(selected ? 0 : 1),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// The selected card's actions.
class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.el, required this.host});
  final UiFbElement el;
  final _UiFbCanvasState host;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final store = UiFbBuilderScope.of(context);
    final name = store.name(el.id);
    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: t.borderSubtle))),
      padding: EdgeInsets.symmetric(horizontal: t.space1),
      child: Wrap(alignment: WrapAlignment.end, children: [
        FbIconButton(icon: HugeIcons.strokeRoundedSettings02, label: 'Settings for $name', onPressed: () => host.open(store, el.id)),
        FbIconButton(icon: HugeIcons.strokeRoundedArrowUp01, label: 'Move $name up', onPressed: () => store.nudge(el.id, -1)),
        FbIconButton(icon: HugeIcons.strokeRoundedArrowDown01, label: 'Move $name down', onPressed: () => store.nudge(el.id, 1)),
        FbIconButton(icon: HugeIcons.strokeRoundedCopy01, label: 'Duplicate $name', onPressed: () => store.duplicate(el.id)),
        FbIconButton(icon: HugeIcons.strokeRoundedDelete02, label: 'Delete $name', danger: true, onPressed: () => host.widget.onDeleteRequest?.call(el.id)),
        UiMenu(
          items: host.moreItems(store, el),
          onSelect: (item) => host.more(store, el, item),
          placement: UiPlacement.bottomEnd,
          builder: (context, toggle, open) => FbIconButton(icon: HugeIcons.strokeRoundedMoreHorizontal, label: 'More actions for $name', onPressed: toggle),
        ),
      ]),
    );
  }
}

/// A section: its header (a card of its own), the cards inside, and a way to add more.
class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.g, required this.host});
  final UiFbGroup g;
  final _UiFbCanvasState host;

  String _repeatText() {
    final min = g.repeat?.min ?? 0;
    final max = g.repeat?.max;
    if (max != null && max > 0) return min > 0 ? '${jsNumberToString(min)} to ${jsNumberToString(max)} entries' : 'Up to ${jsNumberToString(max)} entries';
    return min > 1 ? 'At least ${jsNumberToString(min)} entries' : 'Repeats';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final store = UiFbBuilderScope.of(context);
    final dnd = host._dndFor(store);
    final selected = store.selectedId == g.id;
    final title = (g.title ?? '').isNotEmpty ? g.title! : (g.repeat != null ? 'Repeating section' : 'Section');
    final badges = _badges(store, g);

    final head = UiInteractive(
      onTap: () => host.pick(store, g.id),
      onLongPress: () {
        HapticFeedback.selectionClick();
        host.open(store, g.id);
      },
      button: false,
      selected: selected,
      semanticLabel: '${store.name(g.id)}, ${g.repeat != null ? 'repeating section' : 'section'}',
      semanticHint: badges.isEmpty ? null : _badgeWords(store, g),
      excludeChildSemantics: true,
      pressScale: false,
      padTouchTarget: false,
      shortcuts: host.shortcuts,
      actions: host.actions(store, g.id),
      builder: (context, s) => Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 40),
        padding: EdgeInsets.fromLTRB(0, 4, t.space2, 4),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(boxShadow: s.focused ? t.focusRing : null),
        child: Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: t.surfaceHover, borderRadius: BorderRadius.circular(t.radiusXs)),
            child: UiIcon(g.repeat != null ? fbRepeatIcon : fbGroupIcon, size: 13, color: t.textMuted),
          ),
          Text(title, style: context.uiText.label.copyWith(fontSize: 13, color: t.text)),
          if (g.repeat != null) FbChip(_repeatText()),
          ...badges,
        ]),
      ),
    );

    return _CardFrame(
      selected: selected,
      problem: store.problemIds.contains(g.id),
      dashed: g.archived == true,
      group: true,
      repeat: g.repeat != null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.borderSubtle))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [_Grip(el: g, host: host, visible: selected), Expanded(child: head)]),
            if (selected) _Toolbar(el: g, host: host),
          ]),
        ),
        Padding(
          padding: EdgeInsets.all(t.space2),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
            _ListBox(
              key: dnd.listKey(g.id),
              over: dnd.drop?.over == g.id,
              child: g.elements.isEmpty
                  ? Container(
                      padding: EdgeInsets.all(t.space3),
                      decoration: BoxDecoration(border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radiusXs)),
                      child: Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: 4, children: [
                        Text('Drag fields here, or', style: context.uiText.body.copyWith(fontSize: 12, color: t.textMuted)),
                        FbLink(label: 'add one', fontSize: 12, onTap: () => host.widget.onAddAt?.call(UiFbDropTarget(containerId: g.id, index: 0))),
                      ]),
                    )
                  : _Items(elements: g.elements, cols: g.columns ?? 1, host: host),
            ),
            if (g.elements.isNotEmpty)
              _AddButton(
                label: 'Add to ${g.repeat != null ? 'each entry' : 'section'}',
                onTap: () => host.widget.onAddAt?.call(UiFbDropTarget(containerId: g.id, index: g.elements.length)),
              ),
          ]),
        ),
      ]),
    );
  }
}

/// A small preview of the field as people will see it.
class _Mock extends StatelessWidget {
  const _Mock({required this.field, required this.store});
  final UiFbField field;
  final UiFormBuilderController store;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final f = field;
    final muted = context.uiText.body.copyWith(fontSize: 12, color: t.textMuted, height: 1.2);
    final secondary = context.uiText.body.copyWith(fontSize: 12, color: t.textSecondary, height: 1.2);
    Widget box(String text, {double height = 28, Widget? trailing, bool dashed = false, Color? bg, TextStyle? style}) => Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: t.space2, vertical: height > 40 ? 6 : 0),
      alignment: height > 40 ? Alignment.topLeft : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: bg ?? t.bg,
        border: Border.all(color: dashed ? t.border : t.borderSubtle),
        borderRadius: BorderRadius.circular(t.radiusXs),
      ),
      child: Row(crossAxisAlignment: height > 40 ? CrossAxisAlignment.start : CrossAxisAlignment.center, spacing: 6, children: [
        Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style ?? muted)),
        if (trailing != null) ...[const Spacer(), trailing],
      ]),
    );
    Widget mark({required bool round}) => Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(border: Border.all(color: t.borderStrong, width: 1.5), borderRadius: BorderRadius.circular(round ? 6 : 3)),
    );
    Widget choice(Widget m, String label) => Row(mainAxisSize: MainAxisSize.min, spacing: 6, children: [m, Flexible(child: Text(label, style: secondary))]);
    Widget opts({required bool round}) {
      final live = [for (final o in f.options ?? const <UiFbOption>[]) if (o.archived != true) o];
      return Wrap(spacing: t.space3, runSpacing: 4, children: [
        for (final o in live.take(3)) choice(mark(round: round), o.label),
        if (live.length > 3) Text('+${live.length - 3} more', style: muted),
      ]);
    }

    final chevron = UiIcon(HugeIcons.strokeRoundedArrowDown01, size: 13, color: t.textMuted);
    final mock = switch (f.type.name) {
      'textarea' => box(f.placeholder ?? '', height: 52),
      'select' || 'multiselect' => box(
        f.source != null ? 'Search ${_sourceName(store, f).toLowerCase()}…' : ((f.placeholder ?? '').isNotEmpty ? f.placeholder! : 'Choose…'),
        trailing: chevron,
      ),
      'radio' => opts(round: true),
      'checkboxes' => opts(round: false),
      'checkbox' => choice(mark(round: false), f.props?.caption ?? f.label),
      'toggle' => choice(
        Container(
          width: 24,
          height: 14,
          padding: const EdgeInsets.all(2),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(color: t.track, borderRadius: BorderRadius.circular(7)),
          child: Container(width: 10, height: 10, decoration: BoxDecoration(color: t.textMuted, shape: BoxShape.circle)),
        ),
        f.props?.caption ?? 'Yes',
      ),
      'date' => box((f.placeholder ?? '').isNotEmpty ? f.placeholder! : 'Select a date', trailing: UiIcon(HugeIcons.strokeRoundedCalendar01, size: 13, color: t.textMuted)),
      'time' => box('--:--', trailing: UiIcon(HugeIcons.strokeRoundedClock02, size: 13, color: t.textMuted)),
      'rating' => Row(mainAxisSize: MainAxisSize.min, spacing: 2, children: [
        for (var i = 0; i < ((f.props?.maxRating ?? 5).toInt()).clamp(1, 10); i++) UiIcon(HugeIcons.strokeRoundedStar, size: 15, color: t.textMuted, strokeWidth: 1.6),
      ]),
      'slider' => SizedBox(
        height: 20,
        child: Row(spacing: t.space2, children: [
          Expanded(
            child: Stack(alignment: Alignment.centerLeft, children: [
              Container(height: 4, decoration: BoxDecoration(color: t.track, borderRadius: BorderRadius.circular(2))),
              FractionallySizedBox(
                widthFactor: 0.3,
                child: Align(alignment: Alignment.centerRight, child: Container(width: 12, height: 12, decoration: BoxDecoration(color: t.textMuted, shape: BoxShape.circle))),
              ),
            ]),
          ),
          Text('${jsNumberToString(f.props?.min ?? 0)} to ${jsNumberToString(f.props?.max ?? 10)}', style: muted.copyWith(fontSize: 11)),
        ]),
      ),
      'file' => Container(
        height: 36,
        decoration: BoxDecoration(color: t.bg, border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radiusXs)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, spacing: 6, children: [
          UiIcon(HugeIcons.strokeRoundedFileUpload, size: 14, color: t.textMuted),
          Text('Drop files or browse', style: muted),
        ]),
      ),
      'calculated' => box('= ${store.describeCalcOf(f)}', dashed: true, bg: const Color(0x00000000), style: secondary),
      'hidden' => Text(
        'Stored as “${f.key}”, never shown${f.defaultValue != null && f.defaultValue != '' ? ': ${jsString(f.defaultValue)}' : ''}',
        style: muted.copyWith(fontStyle: FontStyle.italic),
      ),
      'currency' => box(f.placeholder ?? '', trailing: Text(f.props?.currency ?? '', style: muted)),
      _ => box(f.placeholder ?? ''),
    };
    return ExcludeSemantics(child: mock);
  }
}

/// "Add a field" at the end of the page, "Add to section" under a section's cards.
class _AddButton extends StatelessWidget {
  const _AddButton({required this.label, required this.onTap, this.wide = false});
  final String label;
  final VoidCallback onTap;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final button = UiInteractive(
      onTap: onTap,
      semanticLabel: label,
      excludeChildSemantics: true,
      pressScale: false,
      builder: (context, s) {
        final c = s.hovered || s.pressed ? t.text : t.textMuted;
        return Container(
          height: wide ? 40 : 32,
          padding: EdgeInsets.symmetric(horizontal: t.space2),
          decoration: BoxDecoration(
            color: s.hovered || s.pressed ? t.surface : null,
            border: Border.all(color: wide || s.hovered ? t.borderSubtle : const Color(0x00000000)),
            borderRadius: BorderRadius.circular(t.radiusXs),
            boxShadow: s.focused ? t.focusRing : null,
          ),
          child: Row(mainAxisSize: wide ? MainAxisSize.max : MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, spacing: 6, children: [
            UiIcon(HugeIcons.strokeRoundedAdd01, size: 15, color: c),
            Text(label, style: context.uiText.body.copyWith(fontSize: wide ? 13 : 12, color: c)),
          ]),
        );
      },
    );
    return wide ? button : Align(alignment: Alignment.centerLeft, child: button);
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.store, required this.multiPage, required this.paletteBeside});
  final UiFormBuilderController store;
  final bool multiPage;
  final bool paletteBeside;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Container(
      padding: EdgeInsets.symmetric(vertical: t.space8, horizontal: t.space4),
      decoration: BoxDecoration(border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radius)),
      child: Column(spacing: t.space2, children: [
        Semantics(header: true, child: Text(multiPage ? 'This page is empty' : 'Start your form', style: context.uiText.label.copyWith(fontSize: 15, color: t.text))),
        Text(
          paletteBeside ? 'Drag a field from the left, or start with one of these.' : 'Add a field with the Add button, or start with one of these.',
          textAlign: TextAlign.center,
          style: context.uiText.body.copyWith(fontSize: 13, color: t.textSecondary),
        ),
        SizedBox(height: t.space2),
        Wrap(alignment: WrapAlignment.center, spacing: t.space2, runSpacing: t.space2, children: [
          for (final (type, label) in _starters)
            UiInteractive(
              onTap: () {
                final el = type == 'group' ? createGroup(def: store.def) : createField(UiFbFieldType(type), def: store.def);
                store.add(el, UiFbDropTarget(containerId: store.page.id, index: store.page.elements.length));
              },
              semanticLabel: label,
              excludeChildSemantics: true,
              builder: (context, s) => Container(
                height: 36,
                padding: EdgeInsets.symmetric(horizontal: t.space3),
                decoration: BoxDecoration(
                  color: s.hovered || s.pressed ? t.surfaceHover : t.surface,
                  border: Border.all(color: s.hovered ? t.borderStrong : t.border),
                  borderRadius: BorderRadius.circular(t.radius),
                  boxShadow: s.focused ? t.focusRing : null,
                ),
                child: Row(mainAxisSize: MainAxisSize.min, spacing: 6, children: [
                  UiIcon(type == 'group' ? fbGroupIcon : fbFieldIcon(UiFbFieldType(type)), size: 15, color: t.textSecondary),
                  Text(label, style: context.uiText.body.copyWith(fontSize: 13, color: t.text)),
                ]),
              ),
            ),
        ]),
      ]),
    );
  }
}

class _FormHead extends StatelessWidget {
  const _FormHead({required this.store, this.onPicked, this.onOpenForm});
  final UiFormBuilderController store;
  final ValueChanged<String?>? onPicked;
  final VoidCallback? onOpenForm;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final def = store.def;
    final selected = store.selectedId == null;
    return UiInteractive(
      onTap: () {
        store.select(null);
        onPicked?.call(null);
      },
      onLongPress: onOpenForm,
      selected: selected,
      semanticLabel: def.title.isNotEmpty ? def.title : 'Untitled form',
      semanticHint: 'Form settings',
      excludeChildSemantics: true,
      pressScale: false,
      builder: (context, s) => Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: t.space3, vertical: t.space2),
        decoration: BoxDecoration(
          border: Border.all(color: selected ? t.primary : s.hovered ? t.border : const Color(0x00000000)),
          borderRadius: BorderRadius.circular(t.radius),
          boxShadow: s.focused ? t.focusRing : null,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
          Text(def.title.isNotEmpty ? def.title : 'Untitled form', style: context.uiText.h4.copyWith(fontSize: 20, color: t.text)),
          if ((def.description ?? '').isNotEmpty) Text(def.description!, style: context.uiText.body.copyWith(fontSize: 13, color: t.textSecondary)),
        ]),
      ),
    );
  }
}

class _PageHead extends StatelessWidget {
  const _PageHead({required this.store, this.onOpen, this.onDelete});
  final UiFormBuilderController store;
  final ValueChanged<String>? onOpen;
  final ValueChanged<String>? onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final page = store.page;
    final i = store.pageIndex;
    final n = store.def.pages.length;
    final title = (page.title ?? '').isNotEmpty ? page.title! : 'Page ${i + 1}';
    final selected = store.selectedId == page.id;
    void open() {
      store.select(page.id);
      onOpen?.call(page.id);
    }

    return Container(
      decoration: BoxDecoration(border: Border.all(color: selected ? t.primary : const Color(0x00000000)), borderRadius: BorderRadius.circular(t.radius)),
      child: Row(children: [
        Expanded(
          child: UiInteractive(
            onTap: open,
            semanticLabel: '$title, page settings',
            excludeChildSemantics: true,
            pressScale: false,
            builder: (context, s) => Container(
              padding: EdgeInsets.symmetric(horizontal: t.space3, vertical: 4),
              decoration: BoxDecoration(boxShadow: s.focused ? t.focusRing : null, borderRadius: BorderRadius.circular(t.radius)),
              child: Wrap(spacing: t.space2, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(title, style: context.uiText.label.copyWith(fontSize: 15, color: t.text)),
                if (page.visibility != null) FbChip(page.visibility!.action == 'show' ? 'Shown when…' : 'Skipped when…', tone: FbTone.logic),
                if ((page.jumps ?? const []).isNotEmpty) FbChip('${page.jumps!.length} jump${page.jumps!.length > 1 ? 's' : ''}', tone: FbTone.logic),
              ]),
            ),
          ),
        ),
        UiMenu(
          items: [
            const UiMenuItem(label: 'Page settings', value: 'settings'),
            UiMenuItem(label: 'Move earlier', value: 'earlier', disabled: i == 0),
            UiMenuItem(label: 'Move later', value: 'later', disabled: i == n - 1),
            UiMenuItem(label: 'Delete page', value: 'delete', danger: true, disabled: n < 2),
          ],
          placement: UiPlacement.bottomEnd,
          onSelect: (item) {
            switch (item.value) {
              case 'settings':
                open();
              case 'earlier':
                store.movePage(page.id, -1);
              case 'later':
                store.movePage(page.id, 1);
              case 'delete':
                onDelete?.call(page.id);
            }
          },
          builder: (context, toggle, open) => FbIconButton(icon: HugeIcons.strokeRoundedMoreHorizontal, label: 'Actions for $title', onPressed: toggle),
        ),
      ]),
    );
  }
}

class _PageTabs extends StatelessWidget {
  const _PageTabs({required this.store, required this.dnd, required this.over, this.onOpen});
  final UiFormBuilderController store;
  final FbDnd dnd;
  final String? over;
  final ValueChanged<String>? onOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final pages = store.def.pages;
    return Container(
      padding: EdgeInsets.fromLTRB(t.space3, t.space2, t.space3, 0),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.borderSubtle))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, spacing: 2, children: [
          Semantics(
            role: SemanticsRole.tabBar,
            label: 'Pages',
            container: true,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, spacing: 2, children: [
              for (var i = 0; i < pages.length; i++)
                KeyedSubtree(
                  key: dnd.tabKey(pages[i].id),
                  child: _Tab(
                    label: (pages[i].title ?? '').isNotEmpty ? pages[i].title! : 'Page ${i + 1}',
                    on: i == store.pageIndex,
                    over: over == 'tab:${pages[i].id}',
                    hasRules: pages[i].visibility != null || (pages[i].jumps ?? const []).isNotEmpty,
                    onTap: () {
                      if (store.pageIndex == i) {
                        store.select(pages[i].id);
                        onOpen?.call(pages[i].id);
                      } else {
                        store.showPage(i);
                      }
                    },
                  ),
                ),
            ]),
          ),
          _Tab(label: 'Page', icon: HugeIcons.strokeRoundedAdd01, semantic: 'Add a page (a new step)', onTap: store.addPage),
        ]),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.onTap, this.on = false, this.over = false, this.hasRules = false, this.icon, this.semantic});
  final String label;
  final VoidCallback onTap;
  final bool on;
  final bool over;
  final bool hasRules;
  final UiIconData? icon;
  final String? semantic;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final isTab = icon == null;
    return UiInteractive(
      onTap: onTap,
      button: !isTab,
      selected: isTab ? on : null,
      semanticLabel: semantic ?? (hasRules ? '$label, has rules' : label),
      excludeChildSemantics: true,
      pressScale: false,
      minTouchSize: const Size(0, uiMinTouchTarget),
      builder: (context, s) => Semantics(
        role: isTab ? SemanticsRole.tab : null,
        child: Container(
          height: 34,
          constraints: const BoxConstraints(maxWidth: 200),
          padding: EdgeInsets.symmetric(horizontal: t.space3),
          decoration: BoxDecoration(
            color: on ? t.surface : (s.hovered ? t.surfaceHover : null),
            border: on ? Border(top: BorderSide(color: t.borderSubtle), left: BorderSide(color: t.borderSubtle), right: BorderSide(color: t.borderSubtle)) : null,
            borderRadius: BorderRadius.vertical(top: Radius.circular(t.radius)),
            boxShadow: s.focused ? t.focusRing : null,
          ),
          foregroundDecoration: over
              ? BoxDecoration(border: Border.all(color: t.primary, width: 2), borderRadius: BorderRadius.vertical(top: Radius.circular(t.radius)))
              : null,
          child: Row(mainAxisSize: MainAxisSize.min, spacing: 6, children: [
            if (icon != null) UiIcon(icon!, size: 14, color: t.textMuted),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.uiText.body.copyWith(
                  fontSize: 13,
                  fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                  color: on || s.hovered ? t.text : (icon != null ? t.textMuted : t.textSecondary),
                ),
              ),
            ),
            if (hasRules) Container(width: 6, height: 6, decoration: BoxDecoration(color: t.primary, shape: BoxShape.circle)),
          ]),
        ),
      ),
    );
  }
}
