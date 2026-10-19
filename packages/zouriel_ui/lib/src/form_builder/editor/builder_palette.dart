import 'package:flutter/widgets.dart';

import '../../core/icon.dart';
import '../../core/interactive.dart';
import '../../core/types.dart';
import '../../forms/text/inputs.dart';
import '../../theme/theme.dart';
import '../engine/definition.dart';
import '../engine/field_types.dart';
import '../engine/schema.dart';
import 'builder_bits.dart';
import 'builder_dnd.dart';
import 'builder_store.dart';

class _PaletteItem {
  const _PaletteItem(this.id, this.label, this.description, this.icon, this.category, this.create);
  final String id;
  final String label;
  final String description;
  final UiIconData icon;
  final String category;
  final UiFbElement Function(UiFormDefinition def) create;
}

final List<_PaletteItem> _items = [
  for (final t in uiFbFieldTypes) _PaletteItem(t.type.name, t.label, t.description, fbFieldIcon(t.type), t.category, (d) => createField(t.type, def: d)),
  _PaletteItem('group', 'Section', 'Groups questions, with its own rules', fbGroupIcon, 'Layout', (d) => createGroup(def: d)),
  _PaletteItem('repeat', 'Repeating section', 'People can add it several times', fbRepeatIcon, 'Layout', (d) => createGroup(def: d, repeat: true)),
  for (final t in uiFbStaticTypes) _PaletteItem(t.type, t.label, t.description, fbStaticIcon(t.type), 'Layout', (_) => createStatic(t.type)),
];

const _order = ['Text', 'Choice', 'Number & date', 'Other', 'Layout'];

/// `ui-fb-palette`: the list of things to add. Tap to add (after the selection, or at [target]),
/// or, beside the canvas, hold and drag onto it.
class UiFbPalette extends StatefulWidget {
  const UiFbPalette({super.key, this.compact = false, this.target, this.onAdded, this.dnd, this.scrollController});

  /// Show descriptions in a roomier grid (sheets and dialogs).
  final bool compact;

  /// Where taps add to; defaults to after the selection.
  final UiFbDropTarget? target;
  final VoidCallback? onAdded;

  /// Lets items be dragged onto the canvas (the builder passes its own).
  final FbDnd? dnd;
  final ScrollController? scrollController;

  @override
  State<UiFbPalette> createState() => _UiFbPaletteState();
}

class _UiFbPaletteState extends State<UiFbPalette> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final store = UiFbBuilderScope.of(context);
    final q = _query.trim().toLowerCase();
    final hits = [for (final i in _items) if (q.isEmpty || i.label.toLowerCase().contains(q) || i.description.toLowerCase().contains(q)) i];
    final cats = [
      for (final name in _order)
        if (hits.where((i) => i.category == name).toList() case final list when list.isNotEmpty) (name: name, items: list),
    ];

    void add(_PaletteItem item) {
      store.add(item.create(store.def), widget.target);
      widget.onAdded?.call();
    }

    Widget tile(_PaletteItem item) {
      Widget w = UiInteractive(
        onTap: () => add(item),
        semanticLabel: item.label,
        semanticHint: item.description,
        excludeChildSemantics: true,
        pressScale: false,
        // Compact (the "Add a field" dialog and sheet): outlined tiles, as the workflow's "Add a step".
        builder: (context, s) => Container(
          constraints: BoxConstraints(minHeight: widget.compact ? 48 : 36),
          padding: widget.compact ? EdgeInsets.all(t.space2) : const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: s.hovered || s.pressed ? t.surfaceHover : null,
            border: widget.compact ? Border.all(color: t.borderSubtle) : null,
            borderRadius: BorderRadius.circular(widget.compact ? t.radius : t.radiusXs),
            boxShadow: s.focused ? t.focusRing : null,
          ),
          child: Row(spacing: t.space2, children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: t.surfaceSubtle, border: Border.all(color: t.borderSubtle), borderRadius: BorderRadius.circular(t.radiusXs)),
              child: UiIcon(item.icon, size: 15, color: t.textSecondary),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: context.uiText.body.copyWith(fontSize: 13, fontWeight: widget.compact ? FontWeight.w500 : null, color: t.text, height: 1.3)),
                if (widget.compact)
                  // Up to two lines: a description cut after a few words says nothing.
                  Text(item.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.uiText.body.copyWith(fontSize: 12, color: t.textSecondary, height: 1.3)),
              ]),
            ),
          ]),
        ),
      );
      final dnd = widget.dnd;
      if (dnd != null) {
        w = FbDragSource(
          dnd: dnd,
          delay: const Duration(milliseconds: 320),
          payload: () => FbDragPayload.add(label: item.label, icon: item.icon, create: () => item.create(store.def)),
          child: w,
        );
      }
      return w;
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      UiSearchInput(size: UiSize.sm, value: _query, placeholder: 'Find a field type…', label: 'Find a field type', onChanged: (v) => setState(() => _query = v)),
      SizedBox(height: t.space2),
      Expanded(
        child: ListView(
          controller: widget.scrollController,
          padding: EdgeInsets.only(bottom: t.space2),
          children: [
            if (cats.isEmpty) Padding(padding: EdgeInsets.all(t.space2), child: FbHint('Nothing matches “$_query”.')),
            for (final c in cats) ...[
              Padding(
                padding: widget.compact ? EdgeInsets.only(top: t.space2, bottom: t.space1) : EdgeInsets.fromLTRB(6, t.space2, 6, 2),
                child: Semantics(
                  header: true,
                  label: c.name,
                  child: ExcludeSemantics(
                    child: Text(
                      widget.compact ? c.name.toUpperCase() : c.name,
                      style: widget.compact
                          ? context.uiText.label.copyWith(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.44, color: t.textMuted)
                          : context.uiText.label.copyWith(fontSize: 11, color: t.textMuted),
                    ),
                  ),
                ),
              ),
              LayoutBuilder(builder: (context, box) {
                final cols = widget.compact ? (box.maxWidth / 220).floor().clamp(1, 4) : 1;
                final gap = widget.compact ? t.space1 : t.space2;
                final w = (box.maxWidth - (cols - 1) * gap) / cols;
                return Wrap(spacing: gap, runSpacing: widget.compact ? t.space1 : 2, children: [for (final i in c.items) SizedBox(width: w, child: tile(i))]);
              }),
            ],
            if (!widget.compact && widget.dnd != null)
              Padding(padding: EdgeInsets.fromLTRB(6, t.space2, 6, 0), child: const FbHint('Tap to add, or hold and drag onto the form.')),
            if (q.isNotEmpty) Semantics(liveRegion: true, label: '${hits.length} ${hits.length == 1 ? 'match' : 'matches'}', child: const SizedBox.shrink()),
          ],
        ),
      ),
    ]);
  }
}
