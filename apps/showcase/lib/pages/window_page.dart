import 'package:flutter/widgets.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../docs/doc.dart';

/// The window system: floating windows, their manager, and the draggable / resizable primitives.
class WindowPage extends StatefulWidget {
  const WindowPage({super.key});

  @override
  State<WindowPage> createState() => _WindowPageState();
}

class _WindowPageState extends State<WindowPage> {
  final UiWindowManager _wm = UiWindowManager();
  bool _win1 = false, _win2 = false;
  Offset _drag = Offset.zero;
  Size _size = const Size(160, 90);

  @override
  void dispose() {
    _wm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return UiWindowScope(
      manager: _wm,
      // The windows sit beside the page, not in its list, so scrolling the demo away keeps them open.
      child: Stack(
        children: [
          Positioned.fill(
            child: DocPage(
              eyebrow: 'Flagship',
              title: 'Window system',
              lead:
                  'Floating, draggable, resizable windows coordinated by a manager, for tablets. Drag a title bar to a screen edge to snap '
                  '(left or right half, bottom half, maximize); resize from any edge or corner; minimize, maximize, restore and close; '
                  'the last window touched comes to the front. On a phone a window opens as a full-screen sheet.',
              children: [
                DocSection(
                  name: 'Window',
                  widget: 'UiWindow',
                  summary:
                      'A window that hosts any child, drawn in the nearest Overlay so it floats above the page wherever it sits in the tree. '
                      'It opens inside the viewport, shrinking and moving the initial bounds if they would reach past it. open with onOpenChanged '
                      'is two-way: Close reports false (and calls onClosed), and a closed window leaves the screen and the manager until it is '
                      'opened again. Drag the title bar with a finger, pen or mouse; let go within 24px of the top edge to maximize, the left or '
                      'right edge for that half, or the bottom edge for the bottom half (a translucent preview shows where it will go). A drag '
                      'always leaves 48px of the title bar on screen, never above the top or below the bottom, so it can be grabbed again. '
                      'Double-tap the title bar to maximize or restore. Resize from all eight edges and corners (at least 220 x 120); on touch '
                      'screens the grab zones widen and the chrome buttons are 48dp targets. Narrower than 600px, it opens as a full-screen '
                      'sheet that slides up, with only Close. Screen readers meet it as a named region (the title); moving and resizing are '
                      'pointer-only, as on the web.',
                  demo: Wrap(
                    spacing: t.space3,
                    runSpacing: t.space3,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      UiButton(label: 'Open window', onPressed: () => setState(() => _win1 = true)),
                      UiButton(label: 'Open second', variant: UiButtonVariant.outline, onPressed: () => setState(() => _win2 = true)),
                      ListenableBuilder(
                        listenable: _wm,
                        builder: (context, _) => UiBadge(label: '${_wm.count} open', tone: UiStatus.primary),
                      ),
                    ],
                  ),
                  code:
                      'UiWindow(\n  open: open,\n  onOpenChanged: (v) => setState(() => open = v),\n  title: \'Inspector\',\n'
                      '  initialX: 120, initialY: 120, initialWidth: 460, initialHeight: 300,\n  child: const InspectorPanel(),\n)',
                  api: const [
                    ApiRow(
                      'open / onOpenChanged',
                      'bool / ValueChanged<bool>?',
                      'Whether the window is shown; Close reports false. Without onOpenChanged it closes itself.',
                      def: 'true',
                    ),
                    ApiRow('title', 'String', 'Title bar text and the accessible name.', def: "'Window'"),
                    ApiRow('child', 'Widget', 'The content; scrolls when taller than the window.'),
                    ApiRow('draggable / resizable', 'bool', 'Title-bar dragging; edge and corner resizing.', def: 'true'),
                    ApiRow('initialX / initialY', 'double', 'Starting position in the viewport (px).', def: '80 / 80'),
                    ApiRow('initialWidth / initialHeight', 'double', 'Starting size (px).', def: '440 / 300'),
                    ApiRow('glass / radius', 'bool?', 'Frosted surface and rounded corners; default from UiConfig.'),
                    ApiRow('scrollable', 'bool', 'Scroll the body; turn off for content that scrolls itself.', def: 'true'),
                    ApiRow('sheetBreakpoint', 'double', 'Viewports narrower than this show a full-screen sheet.', def: '600'),
                  ],
                  callbacks: const [
                    ApiRow('onClosed', 'VoidCallback?', 'The Close button was pressed (open is now false).'),
                    ApiRow(
                      'dock(side)',
                      'UiWindowState',
                      'Dock to UiDockSide.left / right / top / bottom or maximize; null restores. top is only reachable this way.',
                    ),
                    ApiRow('restore() / minimize()', 'UiWindowState', 'Back to the bounds before docking; collapse to the title bar.'),
                    ApiRow('setBounds(rect) / bounds', 'UiWindowState', 'Set or read the window rectangle in its viewport.'),
                  ],
                ),
                DocSection(
                  name: 'Window manager',
                  widget: 'UiWindowManager',
                  summary:
                      'A ChangeNotifier every open window registers with. It keeps the stacking order (the last focused window in front), '
                      'count and focusedId, and runs bulk operations; tile() fills the viewport with a grid. Windows use the manager from the '
                      'nearest UiWindowScope, or UiWindowManager.instance when there is none.',
                  // Disabled while no window is open, when they would do nothing.
                  demo: ListenableBuilder(
                    listenable: _wm,
                    builder: (context, _) => Wrap(
                      spacing: t.space2,
                      runSpacing: t.space2,
                      children: [
                        UiButton(label: 'Tile', variant: UiButtonVariant.outline, size: UiSize.sm, onPressed: _wm.count == 0 ? null : () => _wm.tile()),
                        UiButton(label: 'Minimize all', variant: UiButtonVariant.outline, size: UiSize.sm, onPressed: _wm.count == 0 ? null : _wm.minimizeAll),
                        UiButton(label: 'Restore all', variant: UiButtonVariant.outline, size: UiSize.sm, onPressed: _wm.count == 0 ? null : _wm.restoreAll),
                      ],
                    ),
                  ),
                  code:
                      'final wm = UiWindowScope.of(context); // or UiWindowManager.instance\n'
                      'wm.tile();\nwm.minimizeAll();\nwm.restoreAll();\nwm.focus(id);\nwm.dock(id, UiDockSide.left);',
                  api: const [
                    ApiRow(
                      'count / focusedId / order',
                      'int / String? / List<String>',
                      'Open windows, the front-most, and back-to-front order. Listen to rebuild.',
                    ),
                    ApiRow('tile([viewport])', 'method', 'Arrange every open window in a grid covering the viewport.'),
                    ApiRow('minimizeAll() / restoreAll()', 'method', 'Minimize or restore every open window.'),
                    ApiRow('focus(id) / dock(id, side)', 'method', 'Bring a window to the front, or dock it.'),
                    ApiRow('register / unregister / bringToFront / nextId', 'method', 'Used by UiWindow; for a custom window implementing UiWindowHandle.'),
                    ApiRow('UiWindowScope(manager:)', 'widget', 'Gives the windows below it their own manager.'),
                  ],
                  shapes:
                      'enum UiDockSide { left, right, top, bottom, maximize }\n'
                      'abstract class UiWindowHandle { String get id; Size? get viewport; void minimize(); void restore();\n'
                      '  void dock(UiDockSide? side); void focus(); void setBounds(Rect bounds); }',
                ),
                DocSection(
                  name: 'Draggable',
                  widget: 'UiDraggable',
                  summary:
                      'Moves its child by a translation (so the layout around it is untouched) and keeps a two-way position. Works with '
                      'finger, pen and mouse; there is no keyboard move. With handleOnly, only a UiDragHandle inside the child starts a drag.',
                  demo: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: t.space2,
                    children: [
                      Container(
                        height: 120,
                        decoration: BoxDecoration(
                          border: Border.all(color: t.border),
                          borderRadius: BorderRadius.circular(t.radius),
                        ),
                        clipBehavior: Clip.hardEdge,
                        padding: EdgeInsets.all(t.space3),
                        alignment: Alignment.topLeft,
                        child: UiDraggable(
                          position: _drag,
                          onPositionChanged: (p) => setState(() => _drag = p),
                          child: Container(
                            width: 96,
                            height: 52,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: t.primary, borderRadius: BorderRadius.circular(t.radius)),
                            child: Text('Drag me', style: context.uiText.label.copyWith(color: t.primaryContrast)),
                          ),
                        ),
                      ),
                      UiText('Offset: ${_drag.dx.round()}, ${_drag.dy.round()}', variant: UiTextVariant.caption),
                    ],
                  ),
                  code:
                      'UiDraggable(\n  position: pos,\n  onPositionChanged: (p) => setState(() => pos = p),\n  handleOnly: true,\n'
                      "  child: Card(header: UiDragHandle(child: Text('Drag here')), ...),\n)",
                  api: const [
                    ApiRow(
                      'position / onPositionChanged',
                      'Offset? / ValueChanged<Offset>?',
                      'Offset from where the child sits in layout. Null keeps it internally.',
                    ),
                    ApiRow('handleOnly', 'bool', 'Only a UiDragHandle inside the child starts a drag.', def: 'false'),
                    ApiRow('enabled', 'bool', 'Turn dragging off.', def: 'true'),
                  ],
                  callbacks: const [
                    ApiRow(
                      'onDragStart / onDragMove / onDragEnd',
                      'ValueChanged<UiDragEvent>?',
                      'position and the pointer (global) at the start, on each move, and on release.',
                    ),
                  ],
                ),
                DocSection(
                  name: 'Resizable',
                  widget: 'UiResizable',
                  summary:
                      'Gives its child a right edge, a bottom edge and a bottom-right corner to drag, and sizes it from them (never below '
                      'minWidth x minHeight). On touch screens the grab zones widen to a finger without changing the look, and a small grip '
                      'marks the corner. No keyboard resize.',
                  demo: Align(
                    alignment: Alignment.centerLeft,
                    child: UiResizable(
                      size: _size,
                      minWidth: 120,
                      minHeight: 70,
                      onResized: (s) => setState(() => _size = s),
                      child: Container(
                        alignment: Alignment.bottomRight,
                        padding: EdgeInsets.all(t.space2),
                        decoration: BoxDecoration(
                          color: t.surfaceRaised,
                          border: Border.all(color: t.border),
                          borderRadius: BorderRadius.circular(t.radius),
                        ),
                        child: UiText('${_size.width.round()} x ${_size.height.round()}', variant: UiTextVariant.caption),
                      ),
                    ),
                  ),
                  code: 'UiResizable(\n  size: size,\n  minWidth: 120,\n  minHeight: 70,\n  onResized: (s) => setState(() => size = s),\n  child: const Panel(),\n)',
                  api: const [
                    ApiRow('size / onResized', 'Size? / ValueChanged<Size>?', 'The size, reported on every move. Null keeps it internally from initialSize.'),
                    ApiRow('initialSize', 'Size', 'Starting size when uncontrolled.', def: '160 x 90'),
                    ApiRow('minWidth / minHeight', 'double', 'Smallest size.', def: '80 / 48'),
                    ApiRow('enabled', 'bool', 'Turn resizing off.', def: 'true'),
                  ],
                ),
              ],
            ),
          ),
          UiWindow(
            open: _win1,
            onOpenChanged: (v) => setState(() => _win1 = v),
            title: 'Inspector',
            initialX: 140,
            initialY: 140,
            initialWidth: 440,
            initialHeight: 280,
            child: const UiText('Drag the title bar; snap to an edge; resize from the corners; use the chrome buttons.'),
          ),
          UiWindow(
            open: _win2,
            onOpenChanged: (v) => setState(() => _win2 = v),
            title: 'Activity',
            initialX: 230,
            initialY: 210,
            initialWidth: 360,
            initialHeight: 240,
            child: const UiText('A second floating window. Tap it to bring it to the front.'),
          ),
        ],
      ),
    );
  }
}
