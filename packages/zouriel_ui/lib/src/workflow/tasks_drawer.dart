import 'dart:async';

import 'package:flutter/widgets.dart';

import '../badge/badge.dart';
import '../button/button.dart';
import '../core/icon.dart';
import '../core/types.dart';
import '../dialog/drawer.dart';
import 'api.dart';
import 'icons.dart';
import 'runtime.dart';

/// `ui-workflow-tasks-drawer`: where people work through their approvals and tasks: a "My tasks"
/// button with the number of open tasks (red when any is overdue) that opens them in a drawer, open
/// or finished, each opening its decision. Put it in an app's header; with [scope] `all` admins see
/// everyone's.
///
/// Open it from code with [open] (and follow it with [onOpenChanged], the web `[(open)]`), or call
/// [UiWorkflowTasksDrawerState.show] through a `GlobalKey`. With [showButton] false only the drawer
/// is left, for apps that open it from their own control.
///
/// ```dart
/// UiWorkflowTasksDrawer(api: api)
/// UiWorkflowTasksDrawer(api: api, open: tasksOpen, onOpenChanged: (v) => setState(() => tasksOpen = v), label: 'Approvals')
/// UiWorkflowTasksDrawer(api: api, scope: 'all', label: 'All tasks')
/// ```
class UiWorkflowTasksDrawer extends StatefulWidget {
  const UiWorkflowTasksDrawer({
    super.key,
    required this.api,
    this.open,
    this.onOpenChanged,
    this.label = 'My tasks',
    this.side = UiDrawerSide.right,
    this.size = UiSize.sm,
    this.variant = UiButtonVariant.outline,
    this.showButton = true,
    this.refreshSeconds = 60,
    this.pageSize = 25,
    this.scope = 'mine',
    this.onDecided,
  });

  final UiWorkflowApi? api;

  /// Whether the drawer is open, when the host controls it; null leaves it to the button.
  final bool? open;

  /// When the drawer opens (from the button or [open]) or closes (in any way).
  final ValueChanged<bool>? onOpenChanged;

  /// The button's (and the drawer's) title.
  final String label;
  final UiDrawerSide side;
  final UiSize size;
  final UiButtonVariant variant;

  /// Show the built-in button. Off when the app opens the drawer from its own control.
  final bool showButton;

  /// How often to refresh the count, in seconds (0: only on start, open, close and decisions).
  final int refreshSeconds;
  final int pageSize;

  /// Whose tasks: the signed-in person's (`mine`), or everyone's (`all`, for admins who oversee the
  /// work; give it a [label] such as "All tasks"). The count follows it.
  final String scope;

  /// After a task was decided in the drawer.
  final ValueChanged<UiWfTask>? onDecided;

  @override
  State<UiWorkflowTasksDrawer> createState() => UiWorkflowTasksDrawerState();
}

/// How many open tasks one count asks for; overdue ones beyond this aren't seen.
const int _countTake = 100;

class UiWorkflowTasksDrawerState extends State<UiWorkflowTasksDrawer> with WidgetsBindingObserver {
  int _count = 0;
  int _overdue = 0;

  /// More tasks are open than one count looks at, so the overdue number is "at least".
  bool _capped = false;
  int _seq = 0;
  Timer? _timer;
  bool _shown = false;

  /// The drawer's own route, so closing it never pops something else on top.
  Route<void>? _drawerRoute;

  /// Whether the app is in view: polling pauses while it is in the background.
  bool _visible = true;

  /// Open tasks for the signed-in person.
  int get count => _count;

  /// How many of them are overdue (at least that many when more are open than one count reads).
  int get overdue => _overdue;

  /// The overdue number as shown: "100+" when only the first page was looked at.
  String get overdueText => '$_overdue${_capped ? '+' : ''}';

  /// Whether the drawer is showing.
  bool get isOpen => _shown;

  /// What a screen reader says after the label: ", 2 open, 1 overdue" or ", none open".
  String get countText => _count > 0 ? ', $_count open${_overdue > 0 ? ', $overdueText overdue' : ''}' : ', none open';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final now = WidgetsBinding.instance.lifecycleState;
    _visible = now == null || _inView(now);
    refresh();
    _startTimer();
    if (widget.open == true) WidgetsBinding.instance.addPostFrameCallback((_) => show());
  }

  @override
  void didUpdateWidget(UiWorkflowTasksDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget;
    if (old.api != widget.api || old.scope != widget.scope) refresh();
    if (old.refreshSeconds != widget.refreshSeconds) _startTimer();
    if (old.open != widget.open) {
      if (widget.open == true && !_shown) WidgetsBinding.instance.addPostFrameCallback((_) => show());
      if (widget.open == false && _shown) hide();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _seq++;
    super.dispose();
  }

  static bool _inView(AppLifecycleState s) => s == AppLifecycleState.resumed || s == AppLifecycleState.inactive;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final visible = _inView(state);
    if (visible == _visible) return;
    _visible = visible;
    _startTimer();
    // Back in view: the count may be stale, so refresh now rather than at the next tick.
    if (visible) refresh();
  }

  /// Whether the count is polled now (it is not while the app is in the background).
  bool get polling => _timer != null;

  void _startTimer() {
    _timer?.cancel();
    final s = widget.refreshSeconds;
    _timer = s > 0 && _visible ? Timer.periodic(Duration(seconds: s), (_) => refresh()) : null;
  }

  /// Reloads the count (also run on open, close and after a decision).
  Future<void> refresh() async {
    final api = widget.api;
    if (api == null) return;
    final n = ++_seq;
    try {
      final page = await api.tasks(UiWfTaskQuery(scope: widget.scope, status: const ['open'], take: _countTake));
      if (!mounted || n != _seq) return;
      setState(() {
        _count = page.total;
        _overdue = page.items.where((t) => t.overdue).length;
        _capped = page.total > page.items.length;
      });
    } catch (_) {
      // Not signed in or offline: keep the last count rather than flashing zero.
    }
  }

  /// Opens the drawer (nothing happens if it is already open).
  Future<void> show() async {
    if (_shown || !mounted) return;
    setState(() => _shown = true);
    widget.onOpenChanged?.call(true);
    refresh();
    await showUiDrawer<void>(
      context: context,
      side: widget.side,
      title: widget.label,
      builder: (ctx) {
        _drawerRoute = ModalRoute.of(ctx);
        return WfTaskInbox(
          api: widget.api,
          scope: widget.scope,
          pageSize: widget.pageSize,
          onDecided: (t) {
            widget.onDecided?.call(t);
            refresh();
          },
        );
      },
    );
    _drawerRoute = null;
    if (!mounted) return;
    setState(() => _shown = false);
    widget.onOpenChanged?.call(false);
    refresh();
  }

  /// Closes the drawer if it is open: its own route, even when something else (a decision dialog)
  /// is on top of it.
  void hide() {
    final route = _drawerRoute;
    if (!_shown || route == null || !route.isActive) return;
    if (route.isCurrent) {
      route.navigator?.pop();
    } else {
      route.navigator?.removeRoute(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showButton) return const SizedBox.shrink();
    return UiButton(
      size: widget.size,
      variant: widget.variant,
      icon: UiIcon(WfIcons.inbox, size: widget.size == UiSize.sm ? 14 : 16, strokeWidth: 1.8),
      // The badge is for eyes; the button's name carries the count for screen readers.
      semanticLabel: '${widget.label}$countText',
      trailingIcon: _count > 0 ? ExcludeSemantics(child: UiBadge(label: _count > 99 ? '99+' : '$_count', tone: _overdue > 0 ? UiStatus.danger : UiStatus.primary)) : null,
      onPressed: show,
      child: ExcludeSemantics(child: Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis)),
    );
  }
}
