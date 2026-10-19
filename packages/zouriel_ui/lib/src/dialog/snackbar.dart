import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../core/interactive.dart';
import '../theme/theme.dart';

/// The one action a snackbar can carry, usually Undo. Running it dismisses the snackbar.
@immutable
class UiSnackbarAction {
  const UiSnackbarAction({required this.label, required this.run});
  final String label;
  final VoidCallback run;
}

/// The notice showing now, the web `UiSnack`.
@immutable
class UiSnack {
  const UiSnack({required this.id, required this.message, this.title, this.action, required this.duration});

  final int id;
  final String message;
  final String? title;
  final UiSnackbarAction? action;

  /// Auto-dismiss after this long; [Duration.zero] keeps it until dismissed.
  final Duration duration;
}

/// `UiSnackbarService`: one short notice at a time about something the person just did, shown by a
/// [UiSnackbarHost]. A new notice replaces the current one. It leaves after 4 s, or 10 s when it
/// has an action (time to reach Undo); the countdown holds while a pointer, a finger or focus is
/// on it and resumes with the time left, at least one more second.
///
/// Use toasts for messages that should stack or carry a tone, such as errors.
class UiSnackbarController extends ChangeNotifier {
  UiSnack? _current;
  int _seq = 0;
  Timer? _tick;
  Duration _remaining = Duration.zero;
  bool _paused = false;

  static const Duration _step = Duration(milliseconds: 100);

  /// The notice showing now.
  UiSnack? get current => _current;

  /// Where the shown bar sits on screen (global coordinates), set by the [UiSnackbarHost]; null
  /// while none shows. A [UiToastHost] reads it to move a bottom stack out of the bar's way.
  final ValueNotifier<Rect?> area = ValueNotifier<Rect?>(null);

  /// The controller of the nearest [UiSnackbarHost].
  static UiSnackbarController of(BuildContext context) {
    final c = maybeOf(context);
    assert(c != null, 'No UiSnackbarHost above this context.');
    return c!;
  }

  static UiSnackbarController? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_UiSnackbarScope>()?.controller;

  /// Shows a notice, replacing any current one; returns its id.
  int show(String message, {String? title, UiSnackbarAction? action, Duration? duration}) {
    _stop();
    final d = duration ?? Duration(seconds: action != null ? 10 : 4);
    _current = UiSnack(id: ++_seq, message: message, title: title, action: action, duration: d);
    _paused = false;
    if (d > Duration.zero) _arm(d);
    notifyListeners();
    return _current!.id;
  }

  /// Hides it; with an [id], only if that notice is still the one showing.
  void dismiss([int? id]) {
    if (_current == null || (id != null && _current!.id != id)) return;
    _stop();
    _current = null;
    _paused = false;
    notifyListeners();
  }

  /// Runs the action, then dismisses it.
  void act() {
    final s = _current;
    dismiss();
    s?.action?.run();
  }

  /// Holds it open (the pointer, a finger or focus is on it).
  void pause() {
    if (_tick != null) _paused = true;
  }

  /// Restarts the countdown with the time that was left, at least one more second.
  void resume() {
    if (!_paused || _current == null) return;
    _paused = false;
    if (_remaining < const Duration(seconds: 1)) _remaining = const Duration(seconds: 1);
  }

  void _arm(Duration d) {
    _remaining = d;
    _tick = Timer.periodic(_step, (_) {
      if (_paused) return;
      _remaining -= _step;
      if (_remaining <= Duration.zero) dismiss();
    });
  }

  void _stop() {
    _tick?.cancel();
    _tick = null;
    _paused = false;
  }

  @override
  void dispose() {
    _tick?.cancel();
    area.dispose();
    super.dispose();
  }
}

class _UiSnackbarScope extends InheritedWidget {
  const _UiSnackbarScope({required this.controller, required super.child});
  final UiSnackbarController controller;

  @override
  bool updateShouldNotify(_UiSnackbarScope oldWidget) => oldWidget.controller != controller;
}

/// `ui-snackbar-host`: shows a [UiSnackbarController]'s notice centred at the bottom of [child],
/// above the safe area and the keyboard. [offset] lifts it above a bottom bar or dock. It slides up
/// as it appears and is a live region, so screen readers announce each notice.
///
/// Wrap the app's content with it (e.g. in `UiApp.builder`). Without a [child] it is just the layer.
class UiSnackbarHost extends StatelessWidget {
  const UiSnackbarHost({super.key, required this.controller, this.offset = 0, this.child});

  final UiSnackbarController controller;

  /// Extra space below the snackbar, e.g. the height of a bottom navigation bar.
  final double offset;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final mq = MediaQuery.of(context);
    final animate = context.uiAnimate;
    final layer = ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final s = controller.current;
        if (s == null) SchedulerBinding.instance.addPostFrameCallback((_) => controller.area.value = null);
        return IgnorePointer(
          ignoring: s == null,
          child: Padding(
            padding: EdgeInsets.fromLTRB(t.space4, 0, t.space4, t.space4 + offset + math.max(mq.padding.bottom, mq.viewInsets.bottom)),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedSwitcher(
                duration: animate ? t.motionBase : Duration.zero,
                reverseDuration: animate ? t.motionFast : Duration.zero,
                switchInCurve: t.easeDecelerate,
                switchOutCurve: t.easeAccelerate,
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: AnimatedBuilder(
                    animation: a,
                    builder: (context, c) => Transform.translate(offset: Offset(0, 8 * (1 - a.value)), child: c),
                    child: child,
                  ),
                ),
                child: s == null
                    ? const SizedBox.shrink()
                    : KeyedSubtree(
                        key: ValueKey(s.id),
                        child: MouseRegion(
                          onEnter: (_) => controller.pause(),
                          onExit: (_) => controller.resume(),
                          child: Listener(
                            onPointerDown: (_) => controller.pause(),
                            onPointerUp: (_) => controller.resume(),
                            onPointerCancel: (_) => controller.resume(),
                            child: Focus(
                              canRequestFocus: false,
                              skipTraversal: true,
                              onFocusChange: (f) => f ? controller.pause() : controller.resume(),
                              child: Semantics(
                                container: true,
                                liveRegion: true,
                                child: _ReportArea(
                                  controller: controller,
                                  id: s.id,
                                  child: UiSnackbar(message: s.message, title: s.title, actionLabel: s.action?.label, onAction: controller.act),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
    final c = child;
    return _UiSnackbarScope(
      controller: controller,
      child: c == null ? layer : Stack(children: [c, Positioned.fill(child: layer)]),
    );
  }
}

/// `ui-snackbar`: the notice itself, a compact inverted bar with a message and an optional
/// link-style action ("Deleted “Name” · Undo"), at most 560 wide. It has no position or timer of its
/// own: use [UiSnackbarController] with a [UiSnackbarHost] in an app, or place it yourself in an editor.
class UiSnackbar extends StatelessWidget {
  const UiSnackbar({super.key, required this.message, this.title, this.actionLabel, this.onAction});

  final String message;

  /// Optional bold first line.
  final String? title;

  /// Shows the action button when set with [onAction].
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final body = theme.typography.body.copyWith(fontSize: t.fontSizeSm, height: 1.35, color: t.bg);
    final r = theme.radius();
    final label = actionLabel;
    // On touch the bar is one touch target tall, with or without an action. The vertical padding
    // sits on the text, so Undo's 48dp touch area spans the bar instead of making it taller.
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 560, minHeight: uiTouchPlatform(context) ? uiMinTouchTarget : 0),
      child: DecoratedBox(
        decoration: BoxDecoration(color: t.text, borderRadius: BorderRadius.circular(r), boxShadow: t.shadow2),
        child: Padding(
          // The action's own 4px side padding makes up the end inset, so its label sits where it did.
          padding: EdgeInsetsDirectional.only(start: t.space3, end: label != null && onAction != null ? t.space3 - t.space1 : t.space3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: t.space3,
            children: [
              Flexible(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: t.space2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      if (title != null) Text(title!, style: body.copyWith(fontWeight: FontWeight.w600)),
                      Text(message, style: body),
                    ],
                  ),
                ),
              ),
              if (label != null && onAction != null)
                UiInteractive(
                  onTap: onAction,
                  semanticLabel: label,
                  excludeChildSemantics: true,
                  builder: (context, s) => DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(t.radiusXs),
                      border: s.focused ? Border.all(color: t.bg, width: 2) : null,
                    ),
                    // A 26px tall target (the toast action's height) with a pointer too, not just on touch.
                    // (A Center with height factor 1, not Container.alignment, which fills the bar's whole height.)
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: t.sizeSm),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: t.space1),
                        child: Center(
                          widthFactor: 1,
                          heightFactor: 1,
                          child: Text(
                            label,
                            style: body.copyWith(
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                              decorationColor: t.bg,
                              decorationThickness: s.hovered ? 2 : 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Publishes its child's on-screen rect to the controller's [UiSnackbarController.area] after each
/// paint that moves it, while its notice [id] is still the current one (not while it fades out).
class _ReportArea extends SingleChildRenderObjectWidget {
  const _ReportArea({required this.controller, required this.id, super.child});
  final UiSnackbarController controller;
  final int id;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderReportArea(controller, id);

  @override
  void updateRenderObject(BuildContext context, _RenderReportArea renderObject) => renderObject
    ..controller = controller
    ..id = id;
}

class _RenderReportArea extends RenderProxyBox {
  _RenderReportArea(this.controller, this.id);
  UiSnackbarController controller;
  int id;

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    final rect = localToGlobal(Offset.zero) & size;
    if (controller.area.value == rect) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (attached && controller.current?.id == id) controller.area.value = rect;
    });
  }
}
