import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../docs/doc.dart';

class BehaviorsPage extends StatefulWidget {
  const BehaviorsPage({super.key});

  @override
  State<BehaviorsPage> createState() => _BehaviorsPageState();
}

class _BehaviorsPageState extends State<BehaviorsPage> {
  int _tab = 0;
  final List<int> _rows = List.generate(20, (i) => i + 1);
  bool _loading = false;
  bool _visible = false;
  Size? _size;
  double _boxW = 160;
  Offset _drag = Offset.zero;

  Future<void> _more() async {
    if (_loading || _rows.length >= 80) return;
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _rows.addAll(List.generate(20, (i) => _rows.length + i + 1));
      _loading = false;
    });
  }

  /// The bordered, clipped frame the scrolling demos sit in (the same one the virtual list draws).
  Widget _box(BuildContext context, Widget child) {
    final t = context.ui;
    return DecoratedBox(
      decoration: BoxDecoration(border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radius)),
      child: ClipRRect(borderRadius: BorderRadius.circular(t.radius), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    const tabs = ['Inbox', 'Sent', 'Archive'];
    return DocPage(
      eyebrow: 'Motion',
      title: 'Behaviors',
      lead: 'Swipe, infinite scroll, virtual list, intersect, copy, resize observer, ripple and drag helpers. Where Flutter already does the job these are thin wrappers that keep the web names and rules.',
      children: [
        DocSection(
          name: 'Swipe',
          widget: 'UiSwipe · UiNoSwipe',
          summary: 'Reports a sideways swipe, e.g. to move between tabs. It reads raw pointers and never takes the drag from anything, so the page still scrolls under the same finger. It fires while the finger is moving, as soon as the drag qualifies, and declines mostly vertical drags, a second finger, starts within 24px of the screen edge (the system back gesture), anything under the finger that scrolls sideways, and the mouse unless mouse is set. Wrap any subtree in UiNoSwipe to opt it out.',
          demo: UiSwipe(
            onSwipeLeft: () => setState(() => _tab = (_tab + 1).clamp(0, 2)),
            onSwipeRight: () => setState(() => _tab = (_tab - 1).clamp(0, 2)),
            child: Container(
              height: 120,
              padding: EdgeInsets.symmetric(horizontal: t.space4),
              decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radius)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, spacing: t.space2, children: [
                UiText(tabs[_tab], variant: UiTextVariant.h4),
                const UiText('Swipe left or right across this box', variant: UiTextVariant.caption),
              ]),
            ),
          ),
          code: 'UiSwipe(\n  onSwipeLeft: next,\n  onSwipeRight: previous,\n  child: page,\n)',
          api: const [
            ApiRow('onSwipeLeft / onSwipeRight', 'VoidCallback?', 'Finger travelled left (next) or right (previous).'),
            ApiRow('enabled', 'bool', 'Turn it off without unmounting.', def: 'true'),
            ApiRow('mouse', 'bool', 'Count mouse drags too.', def: 'false'),
          ],
          shapes: 'UiGestures.isSwipe(dx, dy, ms, width)  // the shared thresholds\nUiGestures.resist(dx, width, blocked: true)\nUiGestures.clampOffset(offset, content, stage, zoom)',
        ),
        DocSection(
          name: 'Infinite scroll',
          widget: 'UiInfiniteScroll',
          summary: 'Wrap a vertical scrollable: onScrolledToEnd fires once when a scroll brings it within threshold px of the end, and again only after it has been scrolled back above that line. It also re-arms when new rows arrive after a load and checks again, so a scroll that jumps straight to the new end still loads. Content shorter than the viewport never triggers it on its own.',
          // Bordered like the virtual list below, so the scrolling box is visible.
          demo: _box(context, SizedBox(
            height: 200,
            child: UiInfiniteScroll(
              onScrolledToEnd: _more,
              child: ListView.builder(
                itemCount: _rows.length + 1,
                itemBuilder: (context, i) => i == _rows.length
                    ? Padding(padding: EdgeInsets.all(t.space3), child: Center(child: _loading ? const UiSpinner() : UiText(_rows.length >= 80 ? 'That is everything' : 'Scroll for more', variant: UiTextVariant.caption)))
                    : Padding(padding: EdgeInsets.symmetric(horizontal: t.space3, vertical: t.space2), child: UiText('Message ${_rows[i]}')),
              ),
            ),
          )),
          code: 'UiInfiniteScroll(\n  threshold: 120,\n  onScrolledToEnd: loadMore,\n  child: ListView.builder(...),\n)',
          api: const [
            ApiRow('onScrolledToEnd', 'VoidCallback', 'Near the end.'),
            ApiRow('threshold', 'double', 'Distance from the end, px.', def: '120'),
            ApiRow('enabled', 'bool', 'Stop asking (while loading, at the end).', def: 'true'),
          ],
        ),
        DocSection(
          name: 'Scroll fade',
          widget: 'UiScrollFade',
          summary: 'Wrap a sideways scroll view: each edge with more content past it fades out, so a cut-off row reads as one that scrolls on. Nothing changes while the content fits. UiTable and UiSegmented use it.',
          // Framed like the other scrolling demos, so the faded edge reads as more to scroll, not a cut.
          demo: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _box(context, Padding(padding: EdgeInsets.symmetric(horizontal: t.space3, vertical: t.space2), child: UiScrollFade(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(spacing: t.space2, children: [for (var i = 1; i <= 16; i++) UiBadge(label: 'Tag $i')]),
              ),
            ))),
          ),
          code: 'UiScrollFade(\n  child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: row),\n)',
          api: const [
            ApiRow('child', 'Widget', 'A horizontal scroll view.'),
            ApiRow('size', 'double', 'Width of the fade, px.', def: '24'),
          ],
        ),
        DocSection(
          name: 'Virtual list',
          widget: 'UiVirtualList',
          summary: 'Builds only the rows in view of a long list. Every row is exactly itemExtent tall. (ListView.builder already does this; UiVirtualList is that with the web component\'s sizing.)',
          demo: DecoratedBox(
            decoration: BoxDecoration(border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radius)),
            child: UiVirtualList<int>(
              items: List.generate(10000, (i) => i),
              height: 160,
              itemExtent: 32,
              itemBuilder: (context, item, i) => Padding(padding: EdgeInsets.symmetric(horizontal: t.space3), child: Align(alignment: Alignment.centerLeft, child: UiText('Row ${item + 1} of 10,000'))),
            ),
          ),
          code: 'UiVirtualList<User>(\n  items: users,\n  itemExtent: 32,\n  height: 320,\n  itemBuilder: (context, user, i) => Text(user.name),\n)',
          api: const [
            ApiRow('items', 'List<T>', 'The data.'),
            ApiRow('itemBuilder', 'Widget Function(context, T, int)', 'One row.'),
            ApiRow('itemExtent', 'double', 'Row height.', def: '32'),
            ApiRow('height', 'double', 'The list\'s height.', def: '320'),
          ],
        ),
        DocSection(
          name: 'Intersect',
          widget: 'UiIntersect',
          summary: 'Reports whether its child is on screen: the first state once laid out (false when it starts out of view), then each change as the scroll views around it move. threshold asks for a share of it to be visible, rootMargin grows or shrinks the visible area, once stops after the first true.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
            UiText(_visible ? 'The marker is in view' : 'Scroll the box until the marker shows', variant: UiTextVariant.label, color: _visible ? t.success : t.textMuted),
            _box(context, SizedBox(
              height: 120,
              child: ListView(children: [
                const SizedBox(height: 200, child: Center(child: UiText('Keep scrolling', variant: UiTextVariant.caption))),
                UiIntersect(
                  threshold: 0.5,
                  onChange: (v) => setState(() => _visible = v),
                  child: Container(height: 40, margin: EdgeInsets.symmetric(horizontal: t.space8), decoration: BoxDecoration(color: t.primary, borderRadius: BorderRadius.circular(t.radius))),
                ),
                const SizedBox(height: 200),
              ]),
            )),
          ]),
          code: 'UiIntersect(\n  threshold: 0.5,\n  onChange: (visible) => ...,\n  child: marker,\n)',
          api: const [
            ApiRow('onChange', 'ValueChanged<bool>', 'Visible or not.'),
            ApiRow('threshold', 'double', 'Share that must be visible (0 = any).', def: '0'),
            ApiRow('rootMargin', 'EdgeInsets', 'Grow (or shrink, negative) the visible area.', def: 'zero'),
            ApiRow('once', 'bool', 'Stop after the first true.', def: 'false'),
          ],
        ),
        DocSection(
          name: 'Copy to clipboard',
          widget: 'UiCopyToClipboard',
          summary: 'Copies text when its builder\'s copy is called; for 1.5s after a copy the builder gets copied true. The result is announced to screen readers, including a hint to copy by hand if the clipboard refuses.',
          demo: Row(spacing: t.space3, children: [
            // A read-only field at the button's height, so the command reads as a value next to its action.
            const Expanded(child: UiInput(value: 'flutter pub add zouriel_ui', readOnly: true, size: UiSize.sm, semanticLabel: 'Install command')),
            UiCopyToClipboard(
              text: 'flutter pub add zouriel_ui',
              builder: (context, copied, copy) => UiButton(
                label: copied ? 'Copied' : 'Copy',
                icon: UiIcon(copied ? HugeIcons.strokeRoundedTick02 : HugeIcons.strokeRoundedCopy01),
                variant: UiButtonVariant.outline,
                size: UiSize.sm,
                onPressed: copy,
              ),
            ),
          ]),
          code: 'UiCopyToClipboard(\n  text: command,\n  builder: (context, copied, copy) =>\n      UiButton(label: copied ? \'Copied\' : \'Copy\', onPressed: copy),\n)',
          api: const [
            ApiRow('text', 'String', 'What to copy.'),
            ApiRow('builder', '(context, bool copied, VoidCallback copy)', 'Builds the trigger.'),
            ApiRow('onCopied / onCopyFailed', 'ValueChanged', 'The result.'),
          ],
        ),
        DocSection(
          name: 'Resize observer',
          widget: 'UiResizeObserver',
          summary: 'Calls onResize with its child\'s size once laid out and whenever it changes, for reporting a size out to a parent. (Inside one build, LayoutBuilder is simpler.)',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space2, children: [
            AnimatedContainer(
              duration: t.motionBase,
              width: _boxW,
              child: UiResizeObserver(
                onResize: (s) => setState(() => _size = s),
                child: Container(height: 48, decoration: BoxDecoration(color: t.surfaceRaised, border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radius))),
              ),
            ),
            Row(spacing: t.space2, children: [
              UiButton(label: 'Resize', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: () => setState(() => _boxW = _boxW == 160 ? 280 : 160)),
              UiText(_size == null ? '' : '${_size!.width.round()} × ${_size!.height.round()}', variant: UiTextVariant.caption),
            ]),
          ]),
          code: 'UiResizeObserver(onResize: (size) => ..., child: panel)',
          api: const [ApiRow('onResize', 'ValueChanged<Size>', 'The child\'s size.')],
        ),
        DocSection(
          name: 'Ripple',
          widget: 'UiRipple',
          summary: 'An ink ripple from where the child is pressed (finger, mouse or pen; a keyboard press shows none), clipped to borderRadius. Skipped under reduced motion: the control\'s own pressed state is feedback enough.',
          demo: UiRipple(
            borderRadius: BorderRadius.circular(t.radiusLg),
            color: t.primary,
            child: Container(
              height: 90,
              alignment: Alignment.center,
              decoration: BoxDecoration(border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radiusLg)),
              child: const UiText('Press anywhere'),
            ),
          ),
          code: 'UiRipple(\n  borderRadius: BorderRadius.circular(12),\n  child: tile,\n)',
          api: const [
            ApiRow('color', 'Color?', 'Defaults to the text colour.'),
            ApiRow('enabled', 'bool', 'Turn it off.', def: 'true'),
            ApiRow('borderRadius', 'BorderRadius', 'Clip shape.', def: 'zero'),
          ],
        ),
        DocSection(
          name: 'Draggable',
          widget: 'UiDragMove',
          summary: 'Moves something by hand: the child is drawn at offset, and dragging it (or, focused, the arrow keys: 8px, Shift 32px) reports the new offset, kept inside bounds. Pair with UiResizeHandle for resizable panels.',
          demo: SizedBox(
            height: 140,
            child: DecoratedBox(
              decoration: BoxDecoration(color: t.surfaceSubtle, border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radius)),
              child: LayoutBuilder(builder: (context, box) => Align(
                alignment: Alignment.topLeft,
                child: UiDragMove(
                  offset: _drag,
                  bounds: Rect.fromLTWH(0, 0, box.maxWidth - 110, box.maxHeight - 48),
                  onChanged: (o) => setState(() => _drag = o),
                  child: Container(
                    width: 110,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: t.surfaceRaised, border: Border.all(color: t.borderStrong), borderRadius: BorderRadius.circular(t.radius), boxShadow: t.shadow1),
                    child: const UiText('Drag me'),
                  ),
                ),
              )),
            ),
          ),
          code: 'UiDragMove(\n  offset: at,\n  bounds: area,\n  onChanged: (o) => setState(() => at = o),\n  child: card,\n)',
          api: const [
            ApiRow('offset / onChanged', 'Offset / ValueChanged<Offset>', 'Where it is drawn.'),
            ApiRow('bounds', 'Rect?', 'Keep the offset inside.'),
            ApiRow('label', 'String', 'Accessible name.', def: "'Move'"),
            ApiRow('onDragEnd', 'ValueChanged<Offset>?', 'After a drag.'),
          ],
        ),
      ],
    );
  }
}
