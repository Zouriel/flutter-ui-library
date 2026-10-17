import 'package:flutter/widgets.dart';

import 'dnd.dart';
import 'store.dart';

/// How the builder lays itself out, by its own width (the web `WfLayout`).
enum UiWorkflowBuilderLayout {
  /// Under 720: canvas only; the step picker and the settings open in bottom sheets.
  narrow,

  /// 720 to 1100: canvas and settings; the step picker opens in a dialog.
  medium,

  /// 1100 and wider: step picker, canvas and settings side by side.
  wide,
}

/// Where a new step goes: a list and a position in it.
@immutable
class WfDropTarget {
  const WfDropTarget(this.listId, this.index);
  final String listId;
  final int index;

  @override
  bool operator ==(Object other) => other is WfDropTarget && other.listId == listId && other.index == index;
  @override
  int get hashCode => Object.hash(listId, index);
  @override
  String toString() => '$listId@$index';
}

/// UI requests shared by the builder's parts (the web `WfBuilderUi`): the layout, collapsed
/// columns, and what the builder does when a part asks to add a step, delete one, or show settings.
class WfBuilderUi extends ChangeNotifier {
  UiWorkflowBuilderLayout _layout = UiWorkflowBuilderLayout.wide;
  final Set<String> _collapsed = {};

  UiWorkflowBuilderLayout get layout => _layout;
  set layout(UiWorkflowBuilderLayout v) {
    if (v == _layout) return;
    _layout = v;
    notifyListeners();
  }

  /// Sets the layout while building, without telling anyone yet (see [announceLayout]).
  void setLayoutQuietly(UiWorkflowBuilderLayout v) => _layout = v;

  /// Tells listeners the layout changed.
  void announceLayout() => notifyListeners();

  /// Opens the step picker for a place (set by the builder).
  ValueChanged<WfDropTarget>? onAddRequest;

  /// Asks before deleting a step (set by the builder).
  ValueChanged<String>? onDeleteRequest;

  /// A card asked for its settings (on phones this opens the sheet).
  VoidCallback? onInspect;

  void requestAdd(WfDropTarget target) => onAddRequest?.call(target);
  void requestDelete(String stepId) => onDeleteRequest?.call(stepId);
  void inspect() => onInspect?.call();

  /// Collapsed branch columns on narrow screens, by list id.
  bool isCollapsed(String listId) => _collapsed.contains(listId);

  void toggleCollapsed(String listId) {
    if (!_collapsed.remove(listId)) _collapsed.add(listId);
    notifyListeners();
  }
}

/// What the builder's parts read from [WfBuilderScope].
class WfContext {
  const WfContext(this.store, this.ui, this.dnd);
  final UiWorkflowBuilderController store;
  final WfBuilderUi ui;
  final WfDnd? dnd;
}

/// Gives the builder's parts their controller, UI state and drag and drop, and rebuilds them on
/// every change (drag positions excepted: listen to [WfContext.dnd] for those). [UiWorkflowBuilder] puts one in place; wrap a part in your own to use it alone.
class WfBuilderScope extends StatefulWidget {
  const WfBuilderScope({super.key, required this.controller, this.ui, this.dnd, required this.child});

  final UiWorkflowBuilderController controller;
  final WfBuilderUi? ui;
  final WfDnd? dnd;
  final Widget child;

  /// The nearest scope; the caller rebuilds on every change.
  static WfContext of(BuildContext context) {
    final s = context.dependOnInheritedWidgetOfExactType<_WfInherited>();
    assert(s != null, 'No WfBuilderScope above this workflow builder part');
    return s!.ctx;
  }

  /// The nearest scope without depending on it (for callbacks).
  static WfContext read(BuildContext context) => context.getInheritedWidgetOfExactType<_WfInherited>()!.ctx;

  @override
  State<WfBuilderScope> createState() => _WfBuilderScopeState();
}

class _WfBuilderScopeState extends State<WfBuilderScope> {
  WfBuilderUi? _ownUi;
  int _epoch = 0;

  WfBuilderUi get _ui => widget.ui ?? (_ownUi ??= WfBuilderUi());

  @override
  void initState() {
    super.initState();
    _listen(widget.controller, _ui, widget.dnd);
  }

  void _listen(UiWorkflowBuilderController c, WfBuilderUi ui, WfDnd? dnd) {
    c.addListener(_changed);
    ui.addListener(_changed);
  }

  void _unlisten(UiWorkflowBuilderController c, WfBuilderUi ui, WfDnd? dnd) {
    c.removeListener(_changed);
    ui.removeListener(_changed);
  }

  @override
  void didUpdateWidget(WfBuilderScope old) {
    super.didUpdateWidget(old);
    final oldUi = old.ui ?? _ownUi!;
    if (old.controller != widget.controller || oldUi != _ui || old.dnd != widget.dnd) {
      _unlisten(old.controller, oldUi, old.dnd);
      _listen(widget.controller, _ui, widget.dnd);
    }
  }

  @override
  void dispose() {
    _unlisten(widget.controller, _ui, widget.dnd);
    _ownUi?.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() => _epoch++);
  }

  @override
  Widget build(BuildContext context) => _WfInherited(ctx: WfContext(widget.controller, _ui, widget.dnd), epoch: _epoch, child: widget.child);
}

class _WfInherited extends InheritedWidget {
  const _WfInherited({required this.ctx, required this.epoch, required super.child});
  final WfContext ctx;
  final int epoch;

  @override
  bool updateShouldNotify(_WfInherited old) => old.epoch != epoch || old.ctx.store != ctx.store;
}
