import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../button/button.dart';
import '../core/icon.dart';
import '../core/types.dart';
import '../theme/theme.dart';
import 'modal.dart';

/// Toast tones, the web `UiToastTone`.
enum UiToastTone { info, success, warning, danger }

/// Where toasts stack, the web `UiToastPosition`: a corner, or centred on the top or bottom edge.
enum UiToastPosition { topRight, topLeft, topCenter, bottomRight, bottomLeft, bottomCenter }

/// One button in a toast, e.g. Undo. Running it dismisses the toast.
@immutable
class UiToastAction {
  const UiToastAction({required this.label, required this.run});
  final String label;
  final VoidCallback run;
}

/// A queued toast, the web `UiToast`.
@immutable
class UiToast {
  const UiToast({required this.id, required this.message, this.title, this.tone = UiToastTone.info, this.duration = const Duration(seconds: 4), this.action});

  final int id;
  final String message;
  final String? title;
  final UiToastTone tone;

  /// Auto-dismiss after this long; [Duration.zero] keeps it until dismissed.
  final Duration duration;
  final UiToastAction? action;
}

/// `UiToastService`: queues transient notifications for a [UiToastHost] to show.
///
/// Create one for the app, hand it to a [UiToastHost] near the root, and call [show] (or
/// [info] / [success] / [warning] / [danger]) from anywhere; [UiToastController.of] finds it from
/// a widget below the host. Each call returns an id for [dismiss]. Toasts leave on their own after
/// their duration; the countdown pauses while a pointer, a finger or focus is on one ([pause] /
/// [resume]) and resumes with the time that was left, at least one more second.
class UiToastController extends ChangeNotifier {
  final List<UiToast> _toasts = [];
  final Map<int, Duration> _remaining = {};
  final Set<int> _paused = {};
  Timer? _tick;
  int _seq = 0;

  static const Duration _step = Duration(milliseconds: 100);

  /// What is showing, oldest first.
  List<UiToast> get toasts => List.unmodifiable(_toasts);

  /// The controller of the nearest [UiToastHost].
  static UiToastController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_UiToastScope>();
    assert(scope != null, 'No UiToastHost above this context.');
    return scope!.controller;
  }

  static UiToastController? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_UiToastScope>()?.controller;

  int show(String message, {String? title, UiToastTone tone = UiToastTone.info, Duration duration = const Duration(seconds: 4), UiToastAction? action}) {
    final toast = UiToast(id: ++_seq, message: message, title: title, tone: tone, duration: duration, action: action);
    _toasts.add(toast);
    if (duration > Duration.zero) {
      _remaining[toast.id] = duration;
      _tick ??= Timer.periodic(_step, (_) => _onTick());
    }
    notifyListeners();
    return toast.id;
  }

  int info(String message, {String? title, Duration duration = const Duration(seconds: 4), UiToastAction? action}) =>
      show(message, title: title, duration: duration, action: action);
  int success(String message, {String? title, Duration duration = const Duration(seconds: 4), UiToastAction? action}) =>
      show(message, title: title, tone: UiToastTone.success, duration: duration, action: action);
  int warning(String message, {String? title, Duration duration = const Duration(seconds: 4), UiToastAction? action}) =>
      show(message, title: title, tone: UiToastTone.warning, duration: duration, action: action);
  int danger(String message, {String? title, Duration duration = const Duration(seconds: 4), UiToastAction? action}) =>
      show(message, title: title, tone: UiToastTone.danger, duration: duration, action: action);

  void _onTick() {
    final due = <int>[];
    for (final e in _remaining.entries) {
      if (_paused.contains(e.key)) continue;
      final left = e.value - _step;
      _remaining[e.key] = left;
      if (left <= Duration.zero) due.add(e.key);
    }
    for (final id in due) {
      dismiss(id);
    }
    if (_remaining.isEmpty) {
      _tick?.cancel();
      _tick = null;
    }
  }

  /// Holds a toast open (the pointer, a finger or focus is on it).
  void pause(int id) => _paused.add(id);

  /// Restarts its countdown with the time that was left, at least one more second.
  void resume(int id) {
    if (!_paused.remove(id)) return;
    final left = _remaining[id];
    if (left != null && left < const Duration(seconds: 1)) _remaining[id] = const Duration(seconds: 1);
  }

  /// Runs the toast's action, then dismisses it.
  void act(int id) {
    final t = _toasts.where((t) => t.id == id).firstOrNull;
    dismiss(id);
    t?.action?.run();
  }

  void dismiss(int id) {
    _remaining.remove(id);
    _paused.remove(id);
    final before = _toasts.length;
    _toasts.removeWhere((t) => t.id == id);
    if (_toasts.length != before) notifyListeners();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }
}

class _UiToastScope extends InheritedWidget {
  const _UiToastScope({required this.controller, required super.child});
  final UiToastController controller;

  @override
  bool updateShouldNotify(_UiToastScope oldWidget) => oldWidget.controller != controller;
}

/// `ui-toast-host`: shows a [UiToastController]'s toasts over [child], stacked at [position]
/// (newest last) inside the safe area, at most 380px wide. Toasts slide in from the edge they sit
/// against and back out that way, and can be swiped sideways to dismiss on touch. Each toast is a
/// live region, so screen readers announce it when it appears.
///
/// Wrap the app's content with it (e.g. in `UiApp.builder`) so toasts float above every route.
/// Without a [child] it is just the toast layer, filling its parent.
class UiToastHost extends StatefulWidget {
  const UiToastHost({super.key, required this.controller, this.position = UiToastPosition.bottomRight, this.child});

  final UiToastController controller;
  final UiToastPosition position;
  final Widget? child;

  @override
  State<UiToastHost> createState() => _UiToastHostState();
}

class _Entry {
  _Entry(this.toast, this.anim);
  final UiToast toast;
  final AnimationController anim;
  bool leaving = false;
}

class _UiToastHostState extends State<UiToastHost> with TickerProviderStateMixin {
  final List<_Entry> _entries = [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
    WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _sync() : null);
  }

  @override
  void didUpdateWidget(UiToastHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_sync);
      widget.controller.addListener(_sync);
      _sync();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    for (final e in _entries) {
      e.anim.dispose();
    }
    super.dispose();
  }

  void _sync() {
    if (!mounted) return;
    final t = context.ui;
    final animate = context.uiAnimate;
    final live = {for (final x in widget.controller.toasts) x.id};
    setState(() {
      for (final e in _entries) {
        if (!e.leaving && !live.contains(e.toast.id)) {
          e.leaving = true;
          e.anim.reverseDuration = animate ? t.motionFast : Duration.zero;
          e.anim.reverse().whenComplete(() {
            if (!mounted) return;
            setState(() => _entries.remove(e));
            e.anim.dispose();
          });
        }
      }
      final known = {for (final e in _entries) e.toast.id};
      for (final x in widget.controller.toasts) {
        if (known.contains(x.id)) continue;
        final c = AnimationController(vsync: this, duration: animate ? t.motionBase : Duration.zero);
        _entries.add(_Entry(x, c));
        c.forward();
      }
    });
  }

  /// A toast swiped away is gone at once (no exit animation: it already left).
  void _swiped(_Entry e) {
    setState(() => _entries.remove(e));
    e.anim.dispose();
    widget.controller.dismiss(e.toast.id);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final pos = widget.position;
    final top = pos == UiToastPosition.topLeft || pos == UiToastPosition.topRight || pos == UiToastPosition.topCenter;
    final alignment = switch (pos) {
      UiToastPosition.topRight => Alignment.topRight,
      UiToastPosition.topLeft => Alignment.topLeft,
      UiToastPosition.topCenter => Alignment.topCenter,
      UiToastPosition.bottomRight => Alignment.bottomRight,
      UiToastPosition.bottomLeft => Alignment.bottomLeft,
      UiToastPosition.bottomCenter => Alignment.bottomCenter,
    };
    // The edge each toast slides from: its own side, or the top/bottom edge when centred.
    final from = switch (pos) {
      UiToastPosition.topLeft || UiToastPosition.bottomLeft => const Offset(-8, 0),
      UiToastPosition.topCenter => const Offset(0, -8),
      UiToastPosition.bottomCenter => const Offset(0, 8),
      _ => const Offset(8, 0),
    };
    final mq = MediaQuery.of(context);
    final layer = IgnorePointer(
      ignoring: _entries.isEmpty,
      child: Padding(
        padding: EdgeInsets.only(top: top ? mq.padding.top : 0, bottom: top ? 0 : math.max(mq.padding.bottom, mq.viewInsets.bottom)),
        child: Align(
          alignment: alignment,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: EdgeInsets.all(t.space4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, e) in _entries.indexed)
                    _AnimatedToast(
                      key: ValueKey(e.toast.id),
                      first: i == 0,
                      entry: e,
                      from: from,
                      onSwiped: () => _swiped(e),
                      controller: widget.controller,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final child = widget.child;
    return _UiToastScope(
      controller: widget.controller,
      child: child == null ? layer : Stack(children: [child, Positioned.fill(child: layer)]),
    );
  }
}

class _AnimatedToast extends StatelessWidget {
  const _AnimatedToast({super.key, required this.entry, required this.from, required this.onSwiped, required this.controller, this.first = false});

  final _Entry entry;
  final bool first;
  final Offset from;
  final VoidCallback onSwiped;
  final UiToastController controller;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final id = entry.toast.id;
    final a = entry.anim;
    final curved = CurvedAnimation(parent: a, curve: t.easeDecelerate, reverseCurve: t.easeAccelerate);
    return SizeTransition(
      // Collapses the gap as it leaves, so the rest slide into place.
      sizeFactor: CurvedAnimation(parent: a, curve: const Interval(0, 0.01), reverseCurve: t.easeStandard),
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(top: first ? 0 : t.space2),
        child: AnimatedBuilder(
          animation: curved,
          builder: (context, child) => Opacity(
            opacity: curved.value.clamp(0.0, 1.0),
            child: Transform.translate(offset: from * (1 - curved.value), child: child),
          ),
          child: Dismissible(
            key: ValueKey('dismiss$id'),
            direction: DismissDirection.horizontal,
            onDismissed: (_) => onSwiped(),
            child: MouseRegion(
              onEnter: (_) => controller.pause(id),
              onExit: (_) => controller.resume(id),
              child: Listener(
                onPointerDown: (_) => controller.pause(id),
                onPointerUp: (_) => controller.resume(id),
                onPointerCancel: (_) => controller.resume(id),
                child: Focus(
                  canRequestFocus: false,
                  skipTraversal: true,
                  onFocusChange: (f) => f ? controller.pause(id) : controller.resume(id),
                  child: UiToastView(
                    toast: entry.toast,
                    onAction: () => controller.act(id),
                    onDismiss: () => controller.dismiss(id),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// How one toast looks (the web `.toast`): raised surface with a tone edge on the start side, the
/// tone's icon, title and message, an optional action button and a dismiss button.
class UiToastView extends StatelessWidget {
  const UiToastView({super.key, required this.toast, this.onAction, this.onDismiss});

  final UiToast toast;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final c = switch (toast.tone) { UiToastTone.info => t.info, UiToastTone.success => t.success, UiToastTone.warning => t.warning, UiToastTone.danger => t.danger };
    final icon = switch (toast.tone) {
      UiToastTone.info => HugeIcons.strokeRoundedInformationCircle,
      UiToastTone.success => HugeIcons.strokeRoundedCheckmarkCircle02,
      UiToastTone.warning => HugeIcons.strokeRoundedAlert02,
      UiToastTone.danger => HugeIcons.strokeRoundedCancelCircle,
    };
    final body = theme.typography.body.copyWith(fontSize: t.fontSizeSm, height: 1.35);
    final r = theme.radius();
    // A live region, which is what Android announces. Flutter treats the status/alert roles as
    // live regions of their own and won't take both, and TalkBack reads the flag, so the web's
    // alert/status split isn't carried over.
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(r), boxShadow: t.shadow2),
        // Flutter can't paint a rounded border with sides of different colours, so the box is
        // clipped to the radius and the tone edge drawn as a plain 3px start border inside it.
        child: ClipRRect(
          borderRadius: BorderRadius.circular(r),
          child: Container(
            decoration: BoxDecoration(
              color: t.surfaceRaised,
              border: BorderDirectional(
                start: BorderSide(color: c, width: 3),
                top: BorderSide(color: t.border),
                end: BorderSide(color: t.border),
                bottom: BorderSide(color: t.border),
              ),
            ),
            padding: EdgeInsets.symmetric(vertical: t.space2, horizontal: t.space3),
            // Centred, so text sits level with the buttons when their 48dp touch areas make the
            // row taller than the text; the icon still lines up with the first line.
            child: Row(
              spacing: t.space2,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: t.space2,
                    children: [
                      SizedBox(height: body.fontSize! * 1.35, child: Center(child: UiIcon(icon, size: 16, color: c, strokeWidth: 2))),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 2,
                          children: [
                            if (toast.title != null) Text(toast.title!, style: body.copyWith(fontWeight: FontWeight.w600)),
                            Text(toast.message, style: body.copyWith(color: t.textMuted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (toast.action != null)
                  UiButton(label: toast.action!.label, variant: UiButtonVariant.outline, size: UiSize.sm, onPressed: onAction),
                if (onDismiss != null) UiDialogCloseButton(label: 'Dismiss', onPressed: onDismiss!, edgePadding: t.space3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
