import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../button/button.dart';
import '../core/icon.dart';
import '../feedback/spinner.dart';
import '../core/types.dart';
import '../forms/text/text_dir.dart';
import '../theme/theme.dart';
import 'blob_shape.dart';
import 'blob_toast.dart';
import 'modal.dart';
import 'snackbar.dart';

/// Toast tones, the web `UiToastTone`.
enum UiToastTone { info, success, warning, danger }

/// Where toasts stack, the web `UiToastPosition`: a corner, or centred on the top or bottom edge.
/// Left and right are physical; the start / end corners (0.46.0) follow the text direction
/// ([bottomEnd], the default, is the bottom right in left-to-right text and the bottom left in
/// right-to-left).
enum UiToastPosition {
  topRight,
  topLeft,
  topCenter,
  bottomRight,
  bottomLeft,
  bottomCenter,
  topStart,
  topEnd,
  bottomStart,
  bottomEnd;

  /// The physical position for [direction]: the start / end corners become left or right.
  UiToastPosition resolve(TextDirection direction) {
    final rtl = direction == TextDirection.rtl;
    return switch (this) {
      topStart => rtl ? topRight : topLeft,
      topEnd => rtl ? topLeft : topRight,
      bottomStart => rtl ? bottomRight : bottomLeft,
      bottomEnd => rtl ? bottomLeft : bottomRight,
      _ => this,
    };
  }
}

/// How a toast is drawn, the web `UiToastVariant`: [card], the bordered card with a tone edge, or
/// [blob] (0.88.0), a dark pill that grows a card beneath it as one shape ([UiBlobToast]).
enum UiToastVariant { card, blob }

/// When blob toasts open their card, the web `UiBlobExpand`: [auto], a lone blob toast opens by
/// itself and several stay pills that open under the pointer or on a tap; [always], each opens by
/// itself; [hover], never by itself.
enum UiBlobExpand { auto, always, hover }

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
  const UiToast({
    required this.id,
    this.message = '',
    this.title,
    this.tone = UiToastTone.info,
    this.duration = const Duration(seconds: 4),
    this.action,
    this.variant = UiToastVariant.card,
    this.loading = false,
    this.content,
  });

  final int id;

  /// The text; may be empty (0.88.0): a blob toast with only a title stays a pill.
  final String message;
  final String? title;
  final UiToastTone tone;

  /// Auto-dismiss after this long; [Duration.zero] keeps it until dismissed.
  final Duration duration;
  final UiToastAction? action;
  final UiToastVariant variant;

  /// Work in progress: a spinner in place of the tone's icon, and on a blob toast a muted title.
  final bool loading;

  /// Blob toasts only: your own content in the card, between the message and the action.
  /// [UiBlobToast.toneOf] gives it the tone's colour.
  final Widget? content;
}

/// One state of a [UiToastController.promise] toast, the web `UiToastState`: the title, and
/// anything else the toast should show in that state.
@immutable
class UiToastState {
  const UiToastState(this.title, {this.message = '', this.action, this.content, this.duration, this.tone});
  final String title;
  final String message;
  final UiToastAction? action;
  final Widget? content;

  /// How long the settled toast stays; 4 s when null. Ignored for the loading state.
  final Duration? duration;

  /// Overrides the tone the state has by itself (success, danger).
  final UiToastTone? tone;
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

  /// [duration] defaults to 4 s, or to zero (stay) while [loading].
  int show(
    String message, {
    String? title,
    UiToastTone tone = UiToastTone.info,
    Duration? duration,
    UiToastAction? action,
    UiToastVariant variant = UiToastVariant.card,
    bool loading = false,
    Widget? content,
  }) {
    final toast = UiToast(
      id: ++_seq,
      message: message,
      title: title,
      tone: tone,
      duration: duration ?? (loading ? Duration.zero : const Duration(seconds: 4)),
      action: action,
      variant: variant,
      loading: loading,
      content: content,
    );
    _toasts.add(toast);
    _arm(toast);
    notifyListeners();
    return toast.id;
  }

  void _arm(UiToast toast) {
    _paused.remove(toast.id);
    if (toast.duration > Duration.zero) {
      _remaining[toast.id] = toast.duration;
      _tick ??= Timer.periodic(_step, (_) => _onTick());
    } else {
      _remaining.remove(toast.id);
    }
  }

  /// A blob toast (0.88.0): a pill with [title], growing a card for the message, content and action.
  int blob(String title, {String message = '', UiToastTone tone = UiToastTone.info, Duration? duration, UiToastAction? action, bool loading = false, Widget? content}) =>
      show(message, title: title, tone: tone, duration: duration, action: action, variant: UiToastVariant.blob, loading: loading, content: content);

  /// Changes a showing toast in place (0.88.0): what is given replaces what it had, and
  /// [clearTitle] / [clearAction] / [clearContent] remove those. The countdown starts again with
  /// the new duration: [duration], else 4 s when the toast stops loading, else what it had. A blob
  /// toast closes to its pill, changes there, and opens again.
  void update(
    int id, {
    String? title,
    String? message,
    UiToastTone? tone,
    Duration? duration,
    UiToastAction? action,
    UiToastVariant? variant,
    bool? loading,
    Widget? content,
    bool clearTitle = false,
    bool clearAction = false,
    bool clearContent = false,
  }) {
    final i = _toasts.indexWhere((t) => t.id == id);
    if (i < 0) return;
    final old = _toasts[i];
    final nowLoading = loading ?? old.loading;
    final next = UiToast(
      id: id,
      message: message ?? old.message,
      title: clearTitle ? null : title ?? old.title,
      tone: tone ?? old.tone,
      duration: duration ?? (old.loading && !nowLoading ? const Duration(seconds: 4) : old.duration),
      action: clearAction ? null : action ?? old.action,
      variant: variant ?? old.variant,
      loading: nowLoading,
      content: clearContent ? null : content ?? old.content,
    );
    _toasts[i] = next;
    _arm(next);
    notifyListeners();
  }

  /// A blob toast that follows a future (0.88.0): a loading pill, which becomes the [success] toast
  /// when the future completes or the [error] toast when it fails. Returns the same future.
  Future<T> promise<T>(
    Future<T> future, {
    required UiToastState loading,
    required UiToastState Function(T value) success,
    required UiToastState Function(Object error) error,
  }) {
    final id = blob(loading.title, message: loading.message, tone: loading.tone ?? UiToastTone.info, action: loading.action, content: loading.content, loading: true);
    void settle(UiToastTone tone, UiToastState s) => update(
          id,
          tone: s.tone ?? tone,
          title: s.title,
          message: s.message,
          action: s.action,
          content: s.content,
          duration: s.duration,
          loading: false,
          clearAction: s.action == null,
          clearContent: s.content == null,
        );
    future.then((value) => settle(UiToastTone.success, success(value)), onError: (Object e) => settle(UiToastTone.danger, error(e)));
    return future;
  }

  int info(String message, {String? title, Duration? duration, UiToastAction? action}) =>
      show(message, title: title, duration: duration, action: action);
  int success(String message, {String? title, Duration? duration, UiToastAction? action}) =>
      show(message, title: title, tone: UiToastTone.success, duration: duration, action: action);
  int warning(String message, {String? title, Duration? duration, UiToastAction? action}) =>
      show(message, title: title, tone: UiToastTone.warning, duration: duration, action: action);
  int danger(String message, {String? title, Duration? duration, UiToastAction? action}) =>
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
///
/// A bottom stack moves up above a snackbar that would otherwise cover it (on a phone both sit at
/// the bottom): [snackbar], or the nearest [UiSnackbarHost]'s controller.
///
/// [textStyle] (0.44.2) is merged over every toast's text, as on the text fields: an app font,
/// e.g. `TextStyle(fontFamilyFallback: ['Faruma'])` so a Dhivehi name doesn't come out as boxes.
class UiToastHost extends StatefulWidget {
  const UiToastHost({super.key, required this.controller, this.position = UiToastPosition.bottomEnd, this.blobExpand = UiBlobExpand.auto, this.snackbar, this.textStyle, this.child});

  final UiToastController controller;
  final UiToastPosition position;

  /// When blob toasts open their card (0.88.0). [UiBlobExpand.auto]: one opens by itself; with more
  /// than one showing they stay pills and open under the pointer or on a tap.
  final UiBlobExpand blobExpand;

  /// Merged over each toast's title, message and action label: a font family or
  /// `fontFamilyFallback` (an app font such as Faruma for Thaana), kept as given (0.44.2).
  final TextStyle? textStyle;

  /// The snackbar to keep clear of; defaults to [UiSnackbarController.maybeOf].
  final UiSnackbarController? snackbar;
  final Widget? child;

  @override
  State<UiToastHost> createState() => _UiToastHostState();
}

class _Entry {
  _Entry(this.toast, this.anim);
  UiToast toast;
  final AnimationController anim;
  bool leaving = false;
}

class _UiToastHostState extends State<UiToastHost> with TickerProviderStateMixin {
  final List<_Entry> _entries = [];
  final GlobalKey _stack = GlobalKey();
  UiSnackbarController? _snackbar;

  /// Extra bottom padding that keeps a bottom stack above an overlapping snackbar.
  double _lift = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _watch(widget.snackbar ?? UiSnackbarController.maybeOf(context));
  }

  void _watch(UiSnackbarController? c) {
    if (c == _snackbar) return;
    _snackbar?.area.removeListener(_clearSnackbar);
    _snackbar = c;
    c?.area.addListener(_clearSnackbar);
    _clearSnackbar();
  }

  /// Lifts a bottom stack whose column the bar overlaps, so its lowest toast sits 8px above the bar.
  void _clearSnackbar() {
    if (!mounted) return;
    final bar = _snackbar?.area.value;
    final pos = widget.position.resolve(Directionality.of(context));
    final bottom = pos == UiToastPosition.bottomLeft || pos == UiToastPosition.bottomRight || pos == UiToastPosition.bottomCenter;
    final box = _stack.currentContext?.findRenderObject() as RenderBox?;
    var lift = 0.0;
    if (bar != null && bottom && box != null && box.hasSize) {
      // The column's horizontal extent depends only on its position and the screen width.
      final r = box.localToGlobal(Offset.zero) & box.size;
      if (bar.left < r.right && bar.right > r.left) {
        final t = context.ui;
        // Where the lowest toast's bottom edge sits without a lift (the column hugs the bottom).
        final restingBottom = r.bottom - t.space4;
        lift = math.max(0, restingBottom - (bar.top - t.space2));
      }
    }
    if (lift != _lift) setState(() => _lift = lift);
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
    WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _sync() : null);
  }

  @override
  void didUpdateWidget(UiToastHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snackbar != widget.snackbar) _watch(widget.snackbar ?? UiSnackbarController.maybeOf(context));
    if (oldWidget.position != widget.position) WidgetsBinding.instance.addPostFrameCallback((_) => _clearSnackbar());
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_sync);
      widget.controller.addListener(_sync);
      _sync();
    }
  }

  @override
  void dispose() {
    _snackbar?.area.removeListener(_clearSnackbar);
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
    final live = {for (final x in widget.controller.toasts) x.id: x};
    setState(() {
      for (final e in _entries) {
        // update() replaced it: show the new one in the same place.
        if (!e.leaving && live[e.toast.id] != null) e.toast = live[e.toast.id]!;
        if (!e.leaving && !live.containsKey(e.toast.id)) {
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
    // The column's width follows its toasts (an empty one is narrow), so re-check the snackbar.
    WidgetsBinding.instance.addPostFrameCallback((_) => _clearSnackbar());
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
    final pos = widget.position.resolve(Directionality.of(context));
    final top = pos == UiToastPosition.topLeft || pos == UiToastPosition.topRight || pos == UiToastPosition.topCenter;
    final alignment = switch (pos) {
      UiToastPosition.topRight => Alignment.topRight,
      UiToastPosition.topLeft => Alignment.topLeft,
      UiToastPosition.topCenter => Alignment.topCenter,
      UiToastPosition.bottomLeft => Alignment.bottomLeft,
      UiToastPosition.bottomCenter => Alignment.bottomCenter,
      _ => Alignment.bottomRight,
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
            key: _stack,
            constraints: const BoxConstraints(maxWidth: 380),
            child: AnimatedPadding(
              duration: context.uiAnimate ? t.motionBase : Duration.zero,
              curve: t.easeStandard,
              padding: EdgeInsets.all(t.space4).copyWith(bottom: t.space4 + _lift),
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
                      side: switch (pos) {
                        UiToastPosition.topLeft || UiToastPosition.bottomLeft => UiBlobSide.left,
                        UiToastPosition.topCenter || UiToastPosition.bottomCenter => UiBlobSide.center,
                        _ => UiBlobSide.right,
                      },
                      expanded: widget.blobExpand == UiBlobExpand.always ||
                          (widget.blobExpand == UiBlobExpand.auto && _entries.where((x) => !x.leaving && x.toast.variant == UiToastVariant.blob).length <= 1),
                      onSwiped: () => _swiped(e),
                      controller: widget.controller,
                      textStyle: widget.textStyle,
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
  const _AnimatedToast({super.key, required this.entry, required this.from, required this.side, required this.expanded, required this.onSwiped, required this.controller, this.textStyle, this.first = false});

  final UiBlobSide side;
  final bool expanded;

  final TextStyle? textStyle;
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
    final blob = entry.toast.variant == UiToastVariant.blob;
    final size = CurvedAnimation(parent: a, curve: const Interval(0, 0.01), reverseCurve: t.easeStandard);
    // Collapses the gap as it leaves, so the rest slide into place (a SizeTransition, written out).
    // A blob paints its shadow outside its box, so it is clipped only while the gap collapses;
    // clipped at rest, its shadow showed a faint box on a light page (0.88.1).
    return AnimatedBuilder(
      animation: a,
      builder: (context, child) => ClipRect(
        clipBehavior: !blob || a.status == AnimationStatus.reverse ? Clip.hardEdge : Clip.none,
        child: Align(alignment: Alignment.topCenter, heightFactor: math.max(size.value, 0), child: child),
      ),
      child: Padding(
        padding: EdgeInsets.only(top: first ? 0 : t.space2),
        child: AnimatedBuilder(
          animation: curved,
          builder: (context, child) => Opacity(
            opacity: curved.value.clamp(0.0, 1.0),
            // A blob toast scales in and out where it is; a card slides from its edge.
            child: blob
                ? Transform.scale(scale: 0.96 + 0.04 * curved.value, child: child)
                : Transform.translate(offset: from * (1 - curved.value), child: child),
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
                  child: blob
                      ? Align(
                          alignment: switch (side) { UiBlobSide.left => Alignment.centerLeft, UiBlobSide.right => Alignment.centerRight, UiBlobSide.center => Alignment.center },
                          child: UiBlobToast(
                            toast: entry.toast,
                            side: side,
                            expanded: expanded,
                            textStyle: textStyle,
                            onAction: () => controller.act(id),
                            onDismiss: () => controller.dismiss(id),
                          ),
                        )
                      : UiToastView(
                          toast: entry.toast,
                          textStyle: textStyle,
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
  const UiToastView({super.key, required this.toast, this.onAction, this.onDismiss, this.textStyle});

  final UiToast toast;

  /// Merged over the title, message and action label (see [UiToastHost.textStyle]).
  final TextStyle? textStyle;
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
    // The app's textStyle over the library's, as a complete style (inherit: false): merged into the
    // ambient DefaultTextStyle, an app family would pick up the library font package and turn
    // 'Faruma' into 'packages/zouriel_ui/Faruma', which doesn't exist (0.44.2).
    TextStyle font(TextStyle s) => textStyle == null ? s : uiMergeFieldStyle(s, textStyle).copyWith(inherit: false);
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
                      SizedBox(
                        height: body.fontSize! * 1.35,
                        child: Center(child: toast.loading ? UiSpinner(size: 14, strokeWidth: 2, color: t.textMuted, decorative: true) : UiIcon(icon, size: 16, color: c, strokeWidth: 2)),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 2,
                          children: [
                            if (toast.title != null) Text(toast.title!, style: font(body.copyWith(fontWeight: FontWeight.w600))),
                            Text(toast.message, style: font(body.copyWith(color: t.textMuted))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (toast.action != null)
                  UiButton(
                    label: toast.action!.label,
                    variant: UiButtonVariant.outline,
                    size: UiSize.sm,
                    onPressed: onAction,
                    // The label in the app font too, over the button's own label style.
                    child: textStyle == null
                        ? null
                        : Builder(
                            builder: (context) => Text(toast.action!.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: font(DefaultTextStyle.of(context).style)),
                          ),
                  ),
                if (onDismiss != null) UiDialogCloseButton(label: context.uiStrings.dismiss, onPressed: onDismiss!, edgePadding: t.space3, outset: t.space1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
