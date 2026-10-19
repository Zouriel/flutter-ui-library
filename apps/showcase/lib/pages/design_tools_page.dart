import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../docs/doc.dart';

/// The pieces of a visual editor: transform box, path editor and helpers, sequencer, scrubber.
class DesignToolsPage extends StatelessWidget {
  const DesignToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DocPage(
      eyebrow: 'Flagship',
      title: 'Design tools',
      lead: 'The pieces of a visual editor, as used by the invites.blog designer: handles for placing things on a stage, a vector '
          'editor for drawing and reshaping outlines, a timeline for when things move, and a scrubber for phones. Built for tablets '
          'and touch first (48dp handles, pinch to zoom), and still usable on a phone.',
      children: [_TransformSection(), _PathEditorSection(), _HelpersSection(), _SequencerSection(), _ScrubberSection()],
    );
  }
}

// ----- Transform box ---------------------------------------------------------------------------------

class _TransformSection extends StatefulWidget {
  const _TransformSection();
  @override
  State<_TransformSection> createState() => _TransformSectionState();
}

class _TransformSectionState extends State<_TransformSection> {
  static const _others = [Rect.fromLTWH(24, 30, 90, 60), Rect.fromLTWH(200, 150, 110, 70)];
  UiBox _box = const UiBox(x: 120, y: 90, w: 120, h: 70);
  List<UiGuide> _guides = const [];

  /// Snaps a move to the other things and the stage centre, and shows the guides.
  UiBox _snap(UiBox b, double stageWidth) {
    if (b.w != _box.w || b.h != _box.h || b.rotate != _box.rotate) return b;
    final r = uiSnap(uiRotatedBounds(b.rect, b.rotate), _others, 6, vertical: [stageWidth / 2]);
    _guides = r.guides;
    return b.copyWith(x: b.x + r.dx, y: b.y + r.dy);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return DocSection(
      name: 'Transform box',
      widget: 'UiTransformBox',
      summary: 'Move, resize and rotate handles for an element on a stage (a Stack). It never changes the box: it reports every move '
          'and a final value, so the host decides between live preview and an undo step. Resizing respects rotation. Shift keeps '
          'proportions and snaps rotation to 15 degrees; Alt resizes from the centre. From the keyboard, arrows nudge (Shift for 10), '
          'Alt+arrow resizes and [ / ] rotate by 1 degree (15 with Shift); screen readers get move and rotate actions. On touch the '
          'handles are 48dp targets and two fingers pinch to scale about the point between them. Pair with uiSnap() and '
          'UiSnapGuides for alignment guides, as here.',
      demo: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth;
        Widget thing(Rect r, {Widget? child, double rotate = 0, bool mine = false}) => Positioned.fromRect(
              rect: r,
              child: Transform.rotate(
                angle: rotate * math.pi / 180,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: mine ? t.gradientFrost.toGradient() : null,
                    color: mine ? null : t.surfaceRaised,
                    borderRadius: BorderRadius.circular(t.radiusSm),
                    border: mine ? null : Border.all(color: t.borderStrong),
                  ),
                  child: child,
                ),
              ),
            );
        return Container(
          height: 300,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(color: t.surfaceSubtle, borderRadius: BorderRadius.circular(t.radius)),
          child: Stack(children: [
            for (final o in _others) thing(o),
            thing(_box.rect, rotate: _box.rotate, mine: true, child: UiText('Drag me', variant: UiTextVariant.label, color: t.text)),
            UiTransformBox(
              box: _box,
              showSize: true,
              label: 'Card',
              onTransform: (b) => setState(() => _box = _snap(b, w)),
              onTransformEnd: (b) => setState(() {
                _box = _snap(b, w);
                _guides = const [];
              }),
            ),
            UiSnapGuides(guides: _guides),
          ]),
        );
      }),
      code: 'Stack(children: [\n  MyThing(box),\n  UiTransformBox(\n    box: box,\n    showSize: true,\n'
          '    onTransform: (b) => setState(() => box = b),      // live\n'
          '    onTransformEnd: (b) => history.commit(b),         // once\n  ),\n  UiSnapGuides(guides: guides),\n])',
      api: const [
        ApiRow('box', 'UiBox', 'x, y, w, h and rotate (degrees) in stage units.'),
        ApiRow('scale', 'double', 'Layout pixels per stage unit. Pointer movement is measured in the stage\'s own space, so a zoomed stage needs nothing more.', def: '1'),
        ApiRow('resizable / rotatable', 'bool', 'Show the resize handles / the rotation knob.', def: 'true'),
        ApiRow('lockAspect', 'bool', 'Always keep proportions (Shift does it per drag).', def: 'false'),
        ApiRow('minSize', 'double', 'Smallest width and height, in units.', def: '4'),
        ApiRow('cornersOnly', 'bool', 'Only the four corners. Edge handles also hide when a side is too short on screen to fit them.', def: 'false'),
        ApiRow('showSize', 'bool', 'A W x H readout under the box.', def: 'false'),
        ApiRow('disabled', 'bool', 'Dashed outline; no handles, pointer, pinch or keys.', def: 'false'),
        ApiRow('label', 'String', "Accessible name; 'Selected element' when empty.", def: "''"),
        ApiRow('UiSnapGuides(guides, scale)', 'widget', 'Draws the guides uiSnap returns, over the stage.'),
        ApiRow('uiSnap(moving, targets, threshold, vertical:, horizontal:)', 'function', 'Edges-and-centres snapping: an offset and the guides.'),
        ApiRow('uiRotatedBounds(rect, degrees) / uiResizeBox(...)', 'function', 'Bounds of a rotated box to snap with; the rotated resize maths.'),
      ],
      callbacks: const [
        ApiRow('onTransformStart', 'ValueChanged<UiTransformMode>?', 'A drag or pinch began: move, resize or rotate.'),
        ApiRow('onTransform', 'ValueChanged<UiBox>?', 'Every pointer move.'),
        ApiRow('onTransformEnd', 'ValueChanged<UiBox>?', 'Once on release, or after a key nudge, resize or turn.'),
        ApiRow('onActivate', 'VoidCallback?', 'A double tap, e.g. to start editing text.'),
        ApiRow('onTap', 'ValueChanged<UiTransformTap>?', 'Pressed and released without moving, so a host can pass the tap to what is beneath.'),
        ApiRow('startPinch(a, pa, b, pb)', 'UiTransformBoxState', 'Start a pinch from two pointers that landed off the box.'),
      ],
      shapes: 'class UiBox { double x, y, w, h, rotate; }\nenum UiTransformMode { move, resize, rotate }\n'
          'class UiGuide { UiGuideOrientation orientation; double at, from, to; }',
    );
  }
}

// ----- Path editor -----------------------------------------------------------------------------------

class _PathEditorSection extends StatefulWidget {
  const _PathEditorSection();
  @override
  State<_PathEditorSection> createState() => _PathEditorSectionState();
}

class _PathEditorSectionState extends State<_PathEditorSection> {
  final _editor = GlobalKey<UiPathEditorState>();
  List<UiPathItem> _items = [
    UiPathItem(id: 'arch', name: 'Arch', contours: [archContour(40, 40, 120, 180)]),
    UiPathItem(id: 'star', name: 'Star', contours: [starContour(230, 60, 130, 130)]),
  ];
  final List<List<UiPathItem>> _history = [];
  UiPathEditorMode _mode = UiPathEditorMode.objects;
  UiBrushKind _brush = UiBrushKind.pen;
  String? _selected;
  UiPointRef? _point;
  List<UiPointRef> _points = const [];
  int _seq = 0;

  static const _hints = {
    UiPathEditorMode.objects: 'Tap a shape to select it; drag to move; corner knobs scale, the top knob rotates. Pinch to zoom.',
    UiPathEditorMode.points: 'Drag points and handles; tap an edge to add a point; double-tap a point for corner or curve; long-press to select several.',
    UiPathEditorMode.pen: 'Tap for corners, drag for curves; tap the first point to close, the last to finish.',
    UiPathEditorMode.draw: 'Draw with a finger or pen; hold still at the end to snap to a line, circle or rectangle.',
  };

  void _commit(List<UiPathItem> next) => setState(() {
        _history.add(_items);
        _items = next;
      });

  void _add(String kind) {
    final id = 'shape${_seq++}';
    final c = switch (kind) {
      'rect' => rectContour(150, 120, 110, 80, 12),
      'ellipse' => ellipseContour(200, 140, 60, 45),
      _ => starContour(150, 90, 110, 110),
    };
    _commit([..._items, UiPathItem(id: id, contours: [c])]);
    setState(() => _selected = id);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return DocSection(
      name: 'Path editor',
      widget: 'UiPathEditor',
      summary: 'A vector surface for outlines, as in a shape tool. Objects selects, moves, scales and rotates; Points edits points '
          'and curve handles (tap an edge to add one, double-tap to switch corner and curve, long-press or Shift-tap to select '
          'several, Alt-drag or freeHandles to bend one side); Pen places points (drag for a curve, tap the first point to close); '
          'Draw paints with pressure-sensitive brushes, and holding still at the end of a stroke snaps it to a line, circle, '
          'rectangle or triangle. Once a pen is used, fingers pan instead of drawing. Pinch or Ctrl/Cmd + wheel zooms; a plain wheel scrolls the page. Keyboard: ] and [ step '
          'through the items, Escape clears points then the item, arrows nudge (Shift for 10), Delete removes selected points, '
          'Ctrl+A selects every point, and in Pen mode Enter or Escape finishes and Backspace takes back the last point. It never '
          'changes items itself: each finished edit comes back once through onItemsChanged, so the host owns undo.',
      demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
        UiSegmented<UiPathEditorMode>(
          label: 'Mode',
          size: UiSize.sm,
          value: _mode,
          onChanged: (m) => setState(() => _mode = m),
          options: [for (final m in UiPathEditorMode.values) UiSegmentedOption(value: m, label: '${m.name[0].toUpperCase()}${m.name.substring(1)}')],
        ),
        if (_mode == UiPathEditorMode.draw)
          UiSegmented<UiBrushKind>(
            label: 'Brush',
            size: UiSize.sm,
            value: _brush,
            onChanged: (b) => setState(() => _brush = b),
            options: [for (final b in UiBrushKind.values) UiSegmentedOption(value: b, label: '${b.name[0].toUpperCase()}${b.name.substring(1)}')],
          ),
        // One button style; the groups wrap as a whole on narrow screens, so the shapes stay together.
        Wrap(spacing: t.space2, runSpacing: t.space2, children: [
          Wrap(spacing: t.space2, children: [
            UiButton(label: 'Rectangle', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: () => _add('rect')),
            UiButton(label: 'Ellipse', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: () => _add('ellipse')),
            UiButton(label: 'Star', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: () => _add('star')),
          ]),
          Wrap(spacing: t.space2, children: [
            UiButton(
              label: 'Undo',
              size: UiSize.sm,
              variant: UiButtonVariant.outline,
              onPressed: _history.isEmpty ? null : () => setState(() => _items = _history.removeLast()),
            ),
            UiButton(label: 'Fit', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: () => _editor.currentState?.fit()),
          ]),
        ]),
        Container(
          height: 340,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radius)),
          child: UiPathEditor(
            key: _editor,
            label: 'Shape editor demo',
            items: _items,
            width: 400,
            height: 260,
            mode: _mode,
            brush: UiBrush(kind: _brush, size: _brush == UiBrushKind.marker ? 12 : 5),
            selectedId: _selected,
            onSelectedIdChanged: (v) => setState(() => _selected = v),
            selectedPoint: _point,
            onSelectedPointChanged: (v) => setState(() => _point = v),
            selectedPoints: _points,
            onSelectedPointsChanged: (v) => setState(() => _points = v),
            onItemsChanged: _commit,
            onStroke: (s) {
              // An eraser stroke draws nothing here; a real host would cut it out of what it covers.
              if (s.brush.kind == UiBrushKind.eraser) return;
              final contours = [for (final p in s.pieces) UiPathContour(closed: true, points: [for (final o in p) UiPathPoint.at(o)])];
              _commit([..._items, UiPathItem(id: 'ink${_seq++}', name: 'Drawing', contours: contours)]);
            },
          ),
        ),
        UiText(_hints[_mode]!, variant: UiTextVariant.caption),
      ]),
      code: 'UiPathEditor(\n  key: editorKey,\n  items: items,\n  width: 400, height: 260,\n  mode: UiPathEditorMode.points,\n'
          '  selectedId: selected,\n  onSelectedIdChanged: (v) => setState(() => selected = v),\n'
          '  onItemsChanged: (next) => history.commit(next),\n  onStroke: (stroke) => addInk(stroke),\n)\n'
          '// editorKey.currentState!.fit();',
      api: const [
        ApiRow('items', 'List<UiPathItem>', '{ id, contours, fill?, op?, name? }. Never changed by the editor.'),
        ApiRow('width / height', 'double', 'The artboard in editor units; the view fits it on first layout and on fit().', def: '100 / 100'),
        ApiRow('mode', 'UiPathEditorMode', 'objects, points, pen or draw.', def: 'objects'),
        ApiRow('selectedId / selectedPoint / selectedPoints', 'with on...Changed', 'The selected item, the point being worked on, and every selected point.'),
        ApiRow('brush', 'UiBrush', 'pen, marker, pencil, brush, calligraphy or eraser, and its width.', def: 'pen, 4'),
        ApiRow('fill', 'Color?', 'Paint for ink as it goes down and for items the pen makes.'),
        ApiRow('fingerDraws', 'bool?', 'null (auto): after a pen is seen, fingers pan instead of drawing.'),
        ApiRow('snapToShape / freeHandles / lockAspect', 'bool', 'Hold-to-snap strokes; handles move independently; keep proportions when scaling.', def: 'true / false / false'),
        ApiRow('showArtboard / label', 'bool / String', 'Draw the artboard; accessible name.', def: "true / 'Shape editor'"),
      ],
      callbacks: const [
        ApiRow('onItemsChanged', 'ValueChanged<List<UiPathItem>>?', 'A finished edit: the whole list, for the host to keep (and undo).'),
        ApiRow('onStroke', 'ValueChanged<UiInkStroke>?', 'A finished draw-mode stroke: samples, brush, painted pieces and the snapped shape, if any.'),
        ApiRow('onPointTap', 'ValueChanged<UiPointRef>?', 'A point was tapped (not dragged), e.g. to pick ends to join.'),
        ApiRow('onPenDetected / onPenCountChanged', 'callbacks', 'A pen touched the surface for the first time; points the pen has placed so far.'),
        ApiRow('fit() / zoomBy(f) / selectAllPoints()', 'UiPathEditorState', 'Frame the artboard and drawing; zoom about the centre; select every point.'),
        ApiRow('finishPen(closed) / undoPenPoint() / cancelPen()', 'UiPathEditorState', 'Pen controls for a toolbar.'),
      ],
      shapes: 'enum UiPathEditorMode { objects, points, pen, draw }\n'
          'class UiPathPoint { double x, y; Offset? handleIn, handleOut; }\n'
          'class UiPathContour { List<UiPathPoint> points; bool closed; }\n'
          'class UiPathItem { String id; List<UiPathContour> contours; UiPathOp? op; Color? fill; String? name; }\n'
          'class UiInkStroke { List<UiInkSample> samples; UiBrush brush; List<List<Offset>> pieces; UiInkShape? shape; }',
    );
  }
}

// ----- Helpers -----------------------------------------------------------------------------------------

class _HelpersSection extends StatelessWidget {
  const _HelpersSection();

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final shapes = {
      'rectContour': rectContour(0, 10, 100, 80, 14),
      'ellipseContour': ellipseContour(50, 50, 50, 36),
      'polygonContour': polygonContour(0, 0, 100, 100, 6),
      'starContour': starContour(0, 0, 100, 100, 5, 0.45),
      'archContour': archContour(15, 0, 70, 100),
    };
    return DocSection(
      name: 'Path & ink helpers',
      widget: 'canvas/path.dart, ink.dart',
      summary: 'The pure functions under the editor, for building shapes in code, drawing them and reading hand-drawn strokes. An '
          'outline is a UiPathContour (points, closed), where each point may carry handleIn / handleOut curve handles; a UiPathItem '
          'is a list of them plus an optional fill and path operation (cut, intersect, exclude). Every function returns new values. '
          'The JSON shape (x, y, in, out) matches the web library.',
      demo: Wrap(spacing: t.space4, runSpacing: t.space3, children: [
        for (final e in shapes.entries)
          Column(mainAxisSize: MainAxisSize.min, spacing: t.space1, children: [
            SizedBox.square(dimension: 72, child: CustomPaint(painter: _ShapePainter(e.value, t.primary))),
            UiText(e.key, variant: UiTextVariant.caption),
          ]),
      ]),
      code: 'final star = starContour(0, 0, 100, 100, 5, 0.45);\n'
          'canvas.drawPath(uiContoursPath([star]), paint);  // or pathD([star]) for SVG\n'
          'final box = pathBounds([star]);                   // Rect?\n'
          'final shape = recognizeShape(samples);            // UiInkLine / UiInkEllipse / UiInkPolygon, or null',
      api: const [
        ApiRow('rectContour / polygonContour / starContour / archContour', '(x, y, w, h, ...)', 'Ready-made outlines in a box (rect takes a corner radius, polygon a side count, star spikes and inner ratio).'),
        ApiRow('ellipseContour(cx, cy, rx, ry)', 'UiPathContour', 'An ellipse from its centre and radii.'),
        ApiRow('uiContoursPath / pathD / segmentPathD', 'Path / String', 'A Flutter Path to draw, or SVG path data for export.'),
        ApiRow('pathBounds / flattenContour / contourArea / insideContour', 'measure', 'Bounds (null when empty), a polyline, signed area, point-in-outline.'),
        ApiRow('translateContours / scaleContours / rotateContours / mapContours', 'transform', 'Moved copies; inputs are never changed.'),
        ApiRow('insertPoint / deletePoint(s) / movePoint(s) / moveHandle / pullHandles', 'edit points', 'What the editor does on each gesture, for toolbars and shortcuts.'),
        ApiRow('toggleSmooth / toggleClosed / breakAt / joinEnds / reverseContour / orientContours', 'edit outlines', 'Corner or curve, open or closed, cut and join, winding for fill rules.'),
        ApiRow('nearestOnPath / pointOnSegment / segmentCount / allPoints / itemOp', 'query', 'Hit-testing and walking an outline.'),
        ApiRow('recognizeShape / shapeSamples / thinSamples', 'ink', 'Read a stroke as a shape and redraw it; merge samples closer than a spacing.'),
        ApiRow('inkArea / inkPath / inkD / inkRadii / inkRadiusAt / inkPiece / convexHull', 'ink', 'Turn pressure samples into a painted outline, piece by piece.'),
        ApiRow('brushSteadiness / brushUsesPressure / simulatedPressure', 'brush', 'How each brush smooths and responds; pressure from speed for a finger or mouse.'),
      ],
    );
  }
}

class _ShapePainter extends CustomPainter {
  _ShapePainter(this.contour, this.color);
  final UiPathContour contour;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100);
    final path = uiContoursPath([contour]);
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.18));
    canvas.drawPath(path, Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * 100 / size.width);
  }

  @override
  bool shouldRepaint(_ShapePainter old) => old.contour != contour || old.color != color;
}

// ----- Sequencer -------------------------------------------------------------------------------------

class _SequencerSection extends StatefulWidget {
  const _SequencerSection();
  @override
  State<_SequencerSection> createState() => _SequencerSectionState();
}

class _SequencerSectionState extends State<_SequencerSection> {
  static const _markers = [
    UiSequencerMarker(at: 0, label: 'Intro'),
    UiSequencerMarker(at: 300, label: 'Story'),
    UiSequencerMarker(at: 620, label: 'Gallery'),
    UiSequencerMarker(at: 860, label: 'RSVP'),
  ];
  List<UiSequencerRow> _rows = const [
    UiSequencerRow(id: 'title', label: 'Title', kind: 'Text', start: 0, end: 320, keyframes: [UiSequencerKeyframe(id: 't1', at: 0, label: 'In'), UiSequencerKeyframe(id: 't2', at: 0.8, label: 'Out')]),
    UiSequencerRow(id: 'photo', label: 'Couple photo', kind: 'Image', start: 120, end: 640, keyframes: [UiSequencerKeyframe(id: 'p1', at: 0.3, label: 'Zoom')]),
    UiSequencerRow(id: 'map', label: 'Venue map', kind: 'Map', start: 560, end: 900),
    UiSequencerRow(id: 'rsvp', label: 'RSVP button', kind: 'Button', start: 820, end: 1000, fixed: true),
    UiSequencerRow(id: 'bg', label: 'Background', kind: 'Shape', start: 0, end: 1000, locked: true),
  ];
  double _playhead = 180;
  double _zoom = 1;
  String? _selected;
  String? _keyframe;
  double _length = 1000;
  double _end = 700;

  void _range(UiSequencerRangeChange c) =>
      setState(() => _rows = [for (final r in _rows) r.id == c.rowId ? r.copyWith(start: c.start, end: c.end) : r]);

  void _keyframeChange(UiSequencerKeyframeChange c) => setState(() => _rows = [
        for (final r in _rows)
          r.id == c.rowId ? r.copyWith(keyframes: [for (final k in r.keyframes) k.id == c.keyframeId ? k.copyWith(at: c.at) : k]) : r,
      ]);

  void _delete(String rowId, String keyframeId) =>
      setState(() => _rows = [for (final r in _rows) r.id == rowId ? r.copyWith(keyframes: [for (final k in r.keyframes) if (k.id != keyframeId) k]) : r]);

  void _reorder(String id, int to) => setState(() {
        final list = [..._rows];
        final row = list.firstWhere((r) => r.id == id);
        list.remove(row);
        list.insert(to.clamp(0, list.length), row);
        _rows = list;
      });

  void _toggle(String id, {required bool mute}) =>
      setState(() => _rows = [for (final r in _rows) r.id == id ? (mute ? r.copyWith(muted: !r.muted) : r.copyWith(locked: !r.locked)) : r]);

  Widget _seq({required bool labels, required bool narrow}) => UiSequencer(
        rows: _rows,
        length: labels ? 1000 : _length,
        markers: _markers,
        showLabels: labels,
        compact: narrow,
        labelWidth: narrow ? 140 : 200,
        rowHeight: labels ? 34 : 30,
        end: labels ? null : _end,
        endDraggable: !labels,
        playhead: _playhead,
        onPlayheadChanged: (v) => setState(() => _playhead = v),
        zoom: _zoom,
        onZoomChanged: (z) => setState(() => _zoom = z),
        selectedRowId: _selected,
        onSelectedRowIdChanged: (v) => setState(() => _selected = v),
        selectedKeyframeId: _keyframe,
        onSelectedKeyframeIdChanged: (v) => setState(() => _keyframe = v),
        onRangeChange: _range,
        onKeyframeChange: _keyframeChange,
        onKeyframeDelete: _delete,
        onRowReorder: _reorder,
        onMuteToggle: (id) => _toggle(id, mute: true),
        onLockToggle: (id) => _toggle(id, mute: false),
        onEndChange: (e, isFinal) => setState(() {
          _end = e.clamp(50, 4000);
          // Pulled to the edge: the timeline grows so the End keeps following.
          if (_end > _length - 20) _length = _end + 200;
          if (isFinal) _length = math.max(1000, _end + 100);
        }),
      );

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final narrow = MediaQuery.sizeOf(context).width < 600;
    Widget frame(Widget child, double h) => Container(
          height: h,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radius)),
          child: child,
        );
    return DocSection(
      name: 'Sequencer',
      widget: 'UiSequencer',
      summary: 'A timeline: a bar per layer for when it is active, diamonds for its keyframes, markers along a ruler and a playhead. '
          'Drag a bar to move it, its edges to trim it, a diamond to retime it (clamped to its bar). Bars, edges and diamonds snap to '
          'markers, the playhead and other bars (hold Alt to place freely). Rows reorder by their grip. Keyboard: a focused bar moves '
          'with the arrows (Shift for a larger step) and trims with [ and ]; a focused diamond retimes with the arrows, Delete '
          'removes it, and the menu key (or a long press, or a right-click) asks for its menu. Bars are at least 24px tall and '
          'diamonds have a 24px target (48dp wide on touch). Without labels it works like a phone video editor: tap a bar for its '
          'name (with hide and lock), hold it to lift it and drag it along or up and down, swipe to scroll, pinch to zoom. compact '
          'keeps only the grip, name and visibility toggle for narrow screens. It reports every change and mutates nothing.',
      demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
        frame(_seq(labels: true, narrow: narrow), 230),
        UiText('Playhead: ${_playhead.round()}', variant: UiTextVariant.caption),
        SizedBox(height: t.space2),
        UiText('Bars only: tap a bar for its name, hold it to drag it anywhere, pinch to zoom. Past the End is shaded; drag the End '
            'grip (to the edge to keep going) or use the arrow keys.', variant: UiTextVariant.caption),
        frame(_seq(labels: false, narrow: narrow), 200),
      ]),
      code: 'UiSequencer(\n  rows: rows,\n  length: 1000,\n  markers: markers,\n  compact: narrow,\n  playhead: playhead,\n'
          '  onPlayheadChanged: (v) => setState(() => playhead = v),\n'
          '  onRangeChange: (c) => setState(() => rows = applyRange(rows, c)),\n'
          '  onKeyframeChange: (c) => setState(() => rows = applyKeyframe(rows, c)),\n)',
      api: const [
        ApiRow('rows', 'List<UiSequencerRow>', 'id, label, start, end, keyframes (at 0..1 within the bar), depth, muted, locked, kind, fixed (no trim edges).'),
        ApiRow('length / markers', 'double / List<UiSequencerMarker>', 'Timeline length in units; ruler markers (also snap targets).', def: '100 / []'),
        ApiRow('showLabels / compact', 'bool', 'Off: bars only, names on tap. compact: grip, name and visibility toggle only.', def: 'true / false'),
        ApiRow('end / endDraggable / endLabel', 'double? / bool / String', 'Where the content ends (the rest is shaded); give the End a grip.'),
        ApiRow('title / emptyText', 'String', 'Label column heading and the empty message.', def: "'Layers' / 'Nothing here yet'"),
        ApiRow('labelWidth / rowHeight', 'double', 'Label column width; row height (never below 25).', def: '200 / 30'),
        ApiRow('snapPixels / keyStep', 'double', 'Snap distance in px; keyboard step as a fraction of length.', def: '6 / 0.01'),
        ApiRow('reorderable / maxZoom', 'bool / double', 'Rows reorder by their grip; largest zoom.', def: 'true / 16'),
        ApiRow('playhead / zoom', 'double, with on...Changed', 'Playhead in units; 1 fits the width, larger zooms in and scrolls.'),
        ApiRow('selectedRowId / selectedKeyframeId', 'String?, with on...Changed', 'The selected bar and diamond.'),
      ],
      callbacks: const [
        ApiRow('onRangeChange', 'UiSequencerRangeChange', 'A bar moved or trimmed; isFinal once, on release.'),
        ApiRow('onKeyframeChange', 'UiSequencerKeyframeChange', 'A diamond retimed; isFinal once, on release.'),
        ApiRow('onKeyframeDelete / onKeyframeMenu', '(rowId, keyframeId) / UiSequencerKeyframeRef', 'Delete on a focused diamond; its menu was asked for, and where.'),
        ApiRow('onRowReorder', '(rowId, toIndex)', 'A row was dropped at a new index.'),
        ApiRow('onMuteToggle / onLockToggle', 'ValueChanged<String>', 'The eye or lock button of a row.'),
        ApiRow('onScrub / onEndChange', 'double / (end, isFinal)', 'A tap on a lane or the ruler moved the playhead; the End was dragged or keyed.'),
      ],
    );
  }
}

// ----- Scrubber --------------------------------------------------------------------------------------

class _ScrubberSection extends StatefulWidget {
  const _ScrubberSection();
  @override
  State<_ScrubberSection> createState() => _ScrubberSectionState();
}

class _ScrubberSectionState extends State<_ScrubberSection> {
  static const _markers = [
    UiScrubberMarker(at: 0, label: 'Intro'),
    UiScrubberMarker(at: 700, label: 'Story'),
    UiScrubberMarker(at: 1500, label: 'Gallery'),
    UiScrubberMarker(at: 2600, label: 'RSVP'),
  ];
  static const _lanes = [
    UiScrubberLane(start: 0, end: 900),
    UiScrubberLane(start: 300, end: 1700, selected: true),
    UiScrubberLane(start: 1000, end: 2400),
    UiScrubberLane(start: 2500, end: 3300, muted: true),
  ];
  double _at = 900;
  double _zoom = 0.25;
  int _presses = 0;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final ticks = [for (final at in const [820.0, 1240.0, 1900.0]) UiScrubberTick(at: at, active: (at - _at).abs() < 20)];
    return DocSection(
      name: 'Scrubber',
      widget: 'UiScrubber',
      summary: 'The phone answer to a timeline ruler: the strip slides under a playhead fixed at its centre, so the finger drags '
          'content rather than a tiny handle. Flicks glide and slow down, two fingers pinch to zoom, a mouse drags or uses the '
          'wheel, and holding still reports a long press (the value is put back). It is a slider to the keyboard and to screen '
          'readers: arrows (Shift for bigger steps), Page Up/Down and Home/End.',
      demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
        UiScrubber(
          length: 3376,
          markers: _markers,
          ticks: ticks,
          value: _at,
          onChanged: (v) => setState(() => _at = v),
          zoom: _zoom,
          onZoomChanged: (z) => setState(() => _zoom = z),
          label: 'Scroll position',
        ),
        // Plain muted readouts, as on the web page (a code block would box them).
        Text('${_at.round()} · zoom ${_zoom.toStringAsFixed(2)}', style: context.uiText.code.copyWith(fontSize: t.fontSizeSm, color: t.textMuted)),
        UiScrubber(
          length: 3376,
          lanes: _lanes,
          end: 2600,
          value: _at,
          onChanged: (v) => setState(() => _at = v),
          zoom: _zoom,
          onZoomChanged: (z) => setState(() => _zoom = z),
          label: 'Layers, flattened (hold to open)',
          onLongPress: () => setState(() => _presses++),
        ),
        Text('Long presses: $_presses', style: context.uiText.code.copyWith(fontSize: t.fontSizeSm, color: t.textMuted)),
      ]),
      code: 'UiScrubber(\n  length: 3376,\n  markers: markers,\n  ticks: ticks,\n  value: at,\n  onChanged: (v) => setState(() => at = v),\n'
          '  zoom: zoom,\n  onZoomChanged: (z) => setState(() => zoom = z),\n  onLongPress: openTimeline,\n)',
      api: const [
        ApiRow('value / onChanged', 'double / ValueChanged<double>?', 'Position under the playhead, 0..length.'),
        ApiRow('zoom / onZoomChanged', 'double', 'Pixels per unit; a pinch changes it.', def: '0.25'),
        ApiRow('length', 'double', 'Length in units.', def: '100'),
        ApiRow('minZoom / maxZoom', 'double', 'Pinch limits.', def: '0.02 / 4'),
        ApiRow('markers / ticks / lanes', 'lists', 'Labelled sections; points of interest (keyframes); layers as thin stacked lines.'),
        ApiRow('end', 'double?', 'Where the content ends; shaded after.'),
        ApiRow('label / valueText', 'String', 'Slider name and spoken value.', def: "'Position' / ''"),
      ],
      callbacks: const [
        ApiRow('onSettle', 'ValueChanged<double>?', 'Once, when a drag, glide, wheel or key change comes to rest.'),
        ApiRow('onLongPress', 'VoidCallback?', 'Held still; the value is put back. E.g. open the full timeline.'),
        ApiRow('uiPackScrubberLanes(lanes)', 'function', 'How lanes stack into rows (non-overlapping lanes share a row, at most six).'),
      ],
    );
  }
}
