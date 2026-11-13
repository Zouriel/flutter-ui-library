import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../docs/doc.dart';

/// Sortable: the section list and the reorder grid, plus the handle field and theme swatch made for
/// the same editor (a studio's portfolio page).
class SortablePage extends StatefulWidget {
  const SortablePage({super.key});

  @override
  State<SortablePage> createState() => _SortablePageState();
}

class _SortablePageState extends State<SortablePage> {
  var _sections = const [
    UiSectionListItem(id: 'cover', label: 'Cover', description: 'Always first', icon: HugeIcons.strokeRoundedImage01, locked: true, hideable: false, removable: false),
    UiSectionListItem(id: 'weddings', label: 'Weddings', description: '24 photos', icon: HugeIcons.strokeRoundedAlbum02),
    UiSectionListItem(id: 'about', label: 'About', icon: HugeIcons.strokeRoundedUserCircle, hidden: true),
    UiSectionListItem(id: 'packages', label: 'Packages & prices', icon: HugeIcons.strokeRoundedTag01),
    UiSectionListItem(id: 'contact', label: 'Contact', icon: HugeIcons.strokeRoundedCall02),
  ];
  String _said = 'Drag a handle, or use the eye, pencil and bin.';

  var _photos = [for (var i = 1; i <= 8; i++) UiReorderGridItem(id: 'p$i', src: '', alt: 'Photo $i')];
  String _cover = 'p1';

  String _handle = '';
  String _swatch = 'oxblood';

  static const _taken = {'studio', 'admin', 'lagoon'};

  Future<UiHandleCheck> _check(String h) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (_taken.contains(h)) return UiHandleCheck(UiHandleState.taken, suggestion: '$h.mv');
    return const UiHandleCheck(UiHandleState.available);
  }

  static final _themes = {
    'oxblood': UiThemeSwatchColors.fromCss(bg: '#f6efe9', surface: '#ffffff', text: '#2a1215', muted: '#7d6a6c', accent: '#7a1f2b')!,
    'oxbloodDark': UiThemeSwatchColors.fromCss(bg: '#160b0d', surface: '#221316', text: '#f3e6e7', muted: '#a58f92', accent: '#c9a45c')!,
    'maldives': UiThemeSwatchColors.fromCss(bg: '#eef7f8', surface: '#ffffff', text: '#0e2a33', muted: '#5d7a83', accent: '#0f8c9c')!,
  };

  void _toggle(String id, bool hidden) => setState(() {
        _sections = [for (final s in _sections) s.id == id ? UiSectionListItem(id: s.id, label: s.label, description: s.description, icon: s.icon, hidden: hidden, locked: s.locked, hideable: s.hideable, removable: s.removable) : s];
        _said = '${hidden ? 'Hid' : 'Showed'} $id';
      });

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return DocPage(
      eyebrow: 'Components',
      title: 'Sortable',
      lead: 'Put things in order by dragging: page sections with hide, edit and remove, and photos in a grid. Plus the handle field and theme swatch made for the same kind of editor.',
      children: [
        DocSection(
          name: 'Section list',
          widget: 'UiSectionList',
          summary: 'Cards put in order by dragging their handle. The handle drags at once (it uses the device\'s touch slop, so it wins over the page\'s scroll, while a swipe anywhere else scrolls). Each card has an eye (hide/show), a pencil (edit) and a bin (remove); hidden cards are dimmed with a "Hidden" badge. Locked cards (a cover that is always first) cannot move and keep their place. Keyboard: focus a handle and press up or down; screen readers get Move up / Move down.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
            UiSectionList(
              items: _sections,
              onReorder: (ids) => setState(() {
                _sections = [for (final id in ids) _sections.firstWhere((s) => s.id == id)];
                _said = 'Order: ${ids.join(', ')}';
              }),
              onToggleHidden: _toggle,
              onEdit: (id) => setState(() => _said = 'Edit $id'),
              onRemove: (id) => setState(() {
                _sections = [for (final s in _sections) if (s.id != id) s];
                _said = 'Removed $id';
              }),
            ),
            UiText(_said, variant: UiTextVariant.caption),
          ]),
          code: '''UiSectionList(
  items: const [
    UiSectionListItem(id: 'cover', label: 'Cover', locked: true, hideable: false, removable: false),
    UiSectionListItem(id: 'weddings', label: 'Weddings', description: '24 photos'),
  ],
  onReorder: (ids) => save(ids),
  onToggleHidden: (id, hidden) => setHidden(id, hidden),
  onEdit: open,
  onRemove: remove,
)''',
          api: const [
            ApiRow('items', 'List<UiSectionListItem>', 'id, label, description, icon, hidden, locked, editable, removable, hideable.'),
            ApiRow('label', 'String', 'The list\'s accessible name.', def: "'Sections'"),
            ApiRow('moveLabel / hideLabel / showLabel / editLabel / removeLabel / hiddenLabel', 'String', 'Wording; button names end with the row\'s label.'),
          ],
          callbacks: const [
            ApiRow('onReorder', 'ValueChanged<List<String>>', 'The whole new order, only when it changed.'),
            ApiRow('onToggleHidden', 'void Function(String id, bool hidden)', 'The new hidden value. No eye without it.'),
            ApiRow('onEdit / onRemove', 'ValueChanged<String>', 'No pencil / bin without them.'),
          ],
        ),
        DocSection(
          name: 'Reorder grid',
          widget: 'UiReorderGrid',
          summary: 'Square photo tiles put in order by dragging. On touch a long press picks a tile up, so a swipe still scrolls the page; the others make room and the page scrolls when the tile is held near its edge. A tap calls onTileTap (open a menu: Make cover, Remove). onRemove adds a small remove button to every tile, and the cover tile carries a star. Keyboard: arrows move a focused tile (up/down by a row).',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
            UiReorderGrid(
              items: _photos,
              coverId: _cover,
              tileBuilder: (context, item) => ColoredBox(
                color: context.ui.surfaceRaised,
                child: Center(child: UiText(item.alt ?? item.id, variant: UiTextVariant.caption)),
              ),
              onReorder: (ids) => setState(() => _photos = [for (final id in ids) _photos.firstWhere((p) => p.id == id)]),
              onTileTap: (id) => setState(() => _cover = id),
              onRemove: (id) => setState(() => _photos = [for (final p in _photos) if (p.id != id) p]),
            ),
            UiText('Tap a tile to make it the cover.', variant: UiTextVariant.caption),
          ]),
          code: '''UiReorderGrid(
  items: [for (final p in photos) UiReorderGridItem(id: p.id, src: p.thumbUrl)],
  coverId: coverId,
  onReorder: saveOrder,
  onTileTap: openMenu,
  onRemove: remove,
)''',
          api: const [
            ApiRow('items', 'List<UiReorderGridItem>', 'id, src, alt.'),
            ApiRow('minTile', 'double', 'Smallest tile; columns fill the width.', def: '96'),
            ApiRow('coverId', 'String?', 'That tile shows a star.'),
            ApiRow('tileBuilder', 'Widget Function(BuildContext, UiReorderGridItem)?', 'Draw the picture yourself (a cached image); defaults to Image.network.'),
          ],
          callbacks: const [
            ApiRow('onReorder', 'ValueChanged<List<String>>', 'The whole new order.'),
            ApiRow('onTileTap', 'ValueChanged<String>?', 'A tap that never moved.'),
            ApiRow('onRemove', 'ValueChanged<String>?', 'Adds a remove button to each tile.'),
          ],
        ),
        DocSection(
          name: 'Handle field',
          widget: 'UiHandleField',
          summary: 'A field for an @handle (a public link name) that checks as you type whether it is free. Typing is lowercased and keeps only a-z, 0-9, dot and underscore. After a short pause it asks check (not when too short); an older answer never replaces a newer one. A suggestion shows as a "Use @x" chip. Try "studio".',
          demo: UiHandleField(value: _handle, onChanged: (v) => setState(() => _handle = v), check: _check, suggestion: 'lagoon.studio', hint: 'invites.blog/@yourname'),
          code: '''UiHandleField(
  value: handle,
  onChanged: (v) => setState(() => handle = v),
  check: (h) async => (await api.check(h)).free
      ? const UiHandleCheck(UiHandleState.available)
      : const UiHandleCheck(UiHandleState.taken),
  suggestion: 'lagoon.studio',
)''',
          api: const [
            ApiRow('value', 'String', 'The handle, without the prefix.'),
            ApiRow('check', 'Future<UiHandleCheck> Function(String)', 'available / taken / invalid, with an optional message and suggestion.'),
            ApiRow('prefix', 'String', 'Shown inside the field.', def: "'@'"),
            ApiRow('debounce', 'Duration', 'Pause before asking.', def: '400ms'),
            ApiRow('minLength / maxLength', 'int', 'Bounds.', def: '3 / 30'),
            ApiRow('suggestion / hint', 'String?', 'Offered while empty / shown before any check.'),
          ],
          callbacks: const [ApiRow('onChanged', 'ValueChanged<String>', 'Every cleaned change.'), ApiRow('onStatus', 'ValueChanged<UiHandleCheck>?', 'Where the check stands.')],
        ),
        DocSection(
          name: 'Theme swatch',
          widget: 'UiThemeSwatch',
          summary: 'A small picture of a page in some colours (a card, two lines of text and a button), for the picture in a choice grid tile of a theme picker. Colours come in as UiThemeSwatchColors (fromCss reads #hex strings from a server). accent replaces the colours\' accent.',
          demo: UiChoiceGrid<String>(
            value: _swatch,
            onChanged: (v) => setState(() => _swatch = v),
            options: [for (final e in _themes.entries) UiChoice(value: e.key, label: e.key)],
            tileBuilder: (context, option, selected) => UiThemeSwatch(colors: _themes[option.value]!),
            minTile: 120,
          ),
          code: '''UiThemeSwatch(
  colors: UiThemeSwatchColors.fromCss(bg: '#f6efe9', surface: '#fff', text: '#2a1215', muted: '#7d6a6c', accent: '#7a1f2b')!,
  accent: chosenAccent,
)''',
          api: const [
            ApiRow('colors', 'UiThemeSwatchColors', 'bg, surface, text, muted, accent.'),
            ApiRow('accent', 'Color?', 'Replaces colors.accent.'),
            ApiRow('label', 'String?', 'Makes it an image with this name; decorative without.'),
          ],
        ),
      ],
    );
  }
}
