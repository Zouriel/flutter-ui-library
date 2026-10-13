import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Keyboard model shared by the radio-like groups (radio group, segmented, rating, choice grid,
/// anchor picker): one tab stop, arrow keys move between items. Not exported.
///
/// The state owns one [FocusNode] per item. Every node except the tab stop skips traversal, so Tab
/// enters and leaves the group in one step; arrow keys focus the next item programmatically.
mixin UiRovingFocus<T extends StatefulWidget> on State<T> {
  final List<FocusNode> _rovingNodes = [];

  /// The node for item [i]; call [syncRoving] in build first.
  FocusNode rovingNode(int i) => _rovingNodes[i];

  /// Makes sure there are [count] nodes and only [tabStop] (if any) is in the tab order.
  void syncRoving(int count, int? tabStop) {
    while (_rovingNodes.length < count) {
      _rovingNodes.add(FocusNode(debugLabel: 'roving ${_rovingNodes.length}'));
    }
    while (_rovingNodes.length > count) {
      _rovingNodes.removeLast().dispose();
    }
    for (var i = 0; i < count; i++) {
      _rovingNodes[i].skipTraversal = i != tabStop;
    }
  }

  /// Index of the item that has focus, or -1.
  int get rovingFocused => _rovingNodes.indexWhere((n) => n.hasFocus);

  /// Moves focus to item [i].
  void rovingFocus(int i) {
    if (i >= 0 && i < _rovingNodes.length) _rovingNodes[i].requestFocus();
  }

  /// Wraps the group so arrow keys (and Home/End) reach [onKey] with the focused item's index.
  /// [onKey] returns true when it handled the key.
  Widget rovingKeys({required Widget child, required bool Function(LogicalKeyboardKey key, int focused) onKey}) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (event is KeyUpEvent) return KeyEventResult.ignored;
        final at = rovingFocused;
        if (at < 0) return KeyEventResult.ignored;
        return onKey(event.logicalKey, at) ? KeyEventResult.handled : KeyEventResult.ignored;
      },
      child: child,
    );
  }

  @override
  void dispose() {
    for (final n in _rovingNodes) {
      n.dispose();
    }
    super.dispose();
  }
}

/// +1 / -1 for the arrow keys (Right/Down forward, Left/Up back), honouring RTL for left/right.
int uiArrowStep(LogicalKeyboardKey key, TextDirection dir) {
  final rtl = dir == TextDirection.rtl;
  if (key == LogicalKeyboardKey.arrowRight) return rtl ? -1 : 1;
  if (key == LogicalKeyboardKey.arrowLeft) return rtl ? 1 : -1;
  if (key == LogicalKeyboardKey.arrowDown) return 1;
  if (key == LogicalKeyboardKey.arrowUp) return -1;
  return 0;
}
