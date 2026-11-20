import 'package:flutter/widgets.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../docs/doc.dart';

class _DemoEvent {
  const _DemoEvent({required this.id, required this.title, required this.count, this.locked = false});
  final String id;
  final String title;
  final int count;
  final bool locked;
}

const _initialEvents = [
  _DemoEvent(id: 'dinner', title: 'Friday dinner', count: 12),
  _DemoEvent(id: 'beach', title: 'Beach trip', count: 8),
  _DemoEvent(id: 'brunch', title: 'Sunday brunch', count: 5),
  _DemoEvent(id: 'archive', title: 'Locked archive', count: 19, locked: true),
];

/// Drag & drop: drag an item with a typed payload onto a matching target.
class DragPage extends StatefulWidget {
  const DragPage({super.key});

  @override
  State<DragPage> createState() => _DragPageState();
}

class _DragPageState extends State<DragPage> {
  List<_DemoEvent> _events = List.of(_initialEvents);
  String _log = 'Drag one event tile onto another (long-press on touch), or focus a tile and press Space.';

  void _merge(_DemoEvent from, _DemoEvent onto) {
    setState(() {
      _events = [
        for (final e in _events)
          if (e.id == onto.id)
            _DemoEvent(id: e.id, title: e.title, count: e.count + from.count, locked: e.locked)
          else if (e.id != from.id)
            e,
      ];
      _log = 'Merged "${from.title}" into "${onto.title}" (${onto.count + from.count} guests).';
    });
  }

  void _reset() {
    setState(() {
      _events = List.of(_initialEvents);
      _log = 'Reset events.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final radius = BorderRadius.circular(context.uiTheme.config.radius ? t.radius : 0);
    return DocPage(
      eyebrow: 'Components',
      title: 'Drag & drop',
      lead: 'Drag an item onto a matching target with a mouse, a long press on touch, or the keyboard. Built for merging tiles, moving cards into buckets, and any drop-onto-target action inside scrolling lists and grids.',
      children: [
        DocSection(
          name: 'Drag item & drop target',
          widget: 'UiDragItem<T> / UiDropTarget<T>',
          summary: 'Wrap any draggable widget in UiDragItem<T> and any drop target in UiDropTarget<T> — including around the same tile, so an event tile can be dragged onto another event tile to merge them. A mouse drag starts after a small movement; on touch, a long press (500ms) starts the drag so swiping still scrolls the list. A lifted ghost follows the pointer while the original dims; valid targets show an accent ring and invalid ones ignore the drag. Holding near a scroll container\'s edge auto-scrolls it; Escape cancels. Keyboard: focus an item, press Space or Enter to pick it up, Arrow keys to choose a valid target, Enter or Space to drop, and Escape to cancel.',
          demo: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: t.space3,
            children: [
              Wrap(
                spacing: t.space3,
                runSpacing: t.space3,
                children: [
                  for (final ev in _events)
                    SizedBox(
                      width: 220,
                      child: UiDropTarget<_DemoEvent>(
                        label: ev.title,
                        accepts: (payload) => !ev.locked && payload.id != ev.id,
                        onDropped: (payload) => _merge(payload, ev),
                        child: UiDragItem<_DemoEvent>(
                          data: ev,
                          label: ev.title,
                          enabled: !ev.locked,
                          child: Container(
                            padding: EdgeInsets.all(t.space3),
                            decoration: BoxDecoration(
                              color: t.surfaceRaised,
                              borderRadius: radius,
                              border: Border.all(color: t.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: t.space2,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(child: UiText(ev.title, variant: UiTextVariant.label)),
                                    UiBadge(
                                      label: ev.locked ? 'Locked' : '${ev.count} guests',
                                      tone: ev.locked ? UiStatus.neutral : UiStatus.primary,
                                    ),
                                  ],
                                ),
                                UiText(
                                  ev.locked ? 'Rejects drops (accepts returns false)' : 'Drag onto another event to merge',
                                  variant: UiTextVariant.caption,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: UiText(_log, variant: UiTextVariant.caption)),
                  UiButton(label: 'Reset', variant: UiButtonVariant.ghost, size: UiSize.sm, onPressed: _reset),
                ],
              ),
            ],
          ),
          code: '''UiDropTarget<Event>(
  label: ev.title,
  accepts: (payload) => !ev.locked && payload.id != ev.id,
  onDropped: (payload) => merge(payload, ev),
  child: UiDragItem<Event>(
    data: ev,
    label: ev.title,
    enabled: !ev.locked,
    child: EventTile(ev),
  ),
)''',
          api: const [
            ApiRow('data', 'T (required)', 'Payload carried by UiDragItem<T>.'),
            ApiRow('label', 'String', 'Item or target name announced by screen readers ("Dropped X on Y").', def: "''"),
            ApiRow('accepts', 'bool Function(T)?', 'Predicate on UiDropTarget<T>; only targets returning true highlight and accept drops.'),
            ApiRow('enabled', 'bool', 'Enables or disables dragging / dropping.', def: 'true'),
            ApiRow('description', 'String', 'Semantic hint on UiDragItem<T> explaining how to move the item.'),
            ApiRow('feedbackBuilder', 'Widget Function(BuildContext, T)?', 'Optional custom drag ghost widget; defaults to child.'),
          ],
          callbacks: const [
            ApiRow('onDropped', 'ValueChanged<T>?', 'Called on UiDropTarget<T> with the dragged payload.'),
            ApiRow('onHoverChanged', 'ValueChanged<bool>?', 'Called when a valid dragged item enters or leaves a target.'),
            ApiRow('onDragStart / onDragCancel / onDragEnd', 'ValueChanged<T>?', 'Lifecycle callbacks on UiDragItem<T>.'),
          ],
        ),
      ],
    );
  }
}
