import 'dart:async';

import 'package:flutter/widgets.dart';

import '../overlay/hint.dart';
import 'guidance.dart';

/// `uiHintOnce`: a one-off [UiHint] that goes through the app's [UiGuidance]. It shows once [when]
/// is true (default: on first build), if tips are on, [id] isn't seen, no other tip is on screen
/// and the day's cap isn't reached; then [id] is seen for good, however it closed.
///
/// ```dart
/// UiHintOnce(
///   id: 'tip.me.settings',
///   message: 'Your plan, sign-in and tips live here.',
///   skipWhen: progress.hasEvent,
///   when: !loading,
///   child: settingsButton,
/// )
/// ```
///
/// [placement], [duration] and [dismissible] are [UiHint]'s, with its defaults. The controller is
/// [guidance], else the nearest [UiGuidanceScope]; without one it never shows.
class UiHintOnce extends StatefulWidget {
  const UiHintOnce({
    super.key,
    required this.id,
    required this.message,
    required this.child,
    this.placement = UiHintPlacement.top,
    this.duration = const Duration(milliseconds: 6000),
    this.dismissible = false,
    this.skipWhen = false,
    this.when = true,
    this.onDone,
    this.guidance,
  });

  /// The tip's id (shared with the other app).
  final String id;
  final String message;

  /// The anchor.
  final Widget child;
  final UiHintPlacement placement;
  final Duration duration;
  final bool dismissible;

  /// The tip's action is already done: never show it; it is marked seen silently.
  final bool skipWhen;

  /// Wait until this is true (the page has loaded, no dialog is open).
  final bool when;

  /// How it ended: [UiTourOutcome.closed], or null when it was not shown (refused or skipped).
  final ValueChanged<UiTourOutcome?>? onDone;
  final UiGuidance? guidance;

  @override
  State<UiHintOnce> createState() => _UiHintOnceState();
}

class _UiHintOnceState extends State<UiHintOnce> {
  bool _asked = false;
  bool _open = false;
  Completer<UiTourOutcome>? _settle;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeAsk();
  }

  @override
  void didUpdateWidget(UiHintOnce old) {
    super.didUpdateWidget(old);
    _maybeAsk();
  }

  @override
  void dispose() {
    _finish();
    super.dispose();
  }

  void _maybeAsk() {
    if (_asked || !widget.when) return;
    final g = widget.guidance ?? UiGuidanceScope.maybeOf(context);
    if (g == null) return;
    _asked = true;
    // Not during build: the controller notifies its listeners when it claims the screen.
    scheduleMicrotask(() async {
      final o = await g.requestTip(
        widget.id,
        () {
          final c = _settle = Completer<UiTourOutcome>();
          if (mounted) {
            setState(() => _open = true);
          } else {
            _finish();
          }
          return c.future;
        },
        skipWhen: widget.skipWhen,
      );
      if (mounted) widget.onDone?.call(o);
    });
  }

  void _finish() {
    final c = _settle;
    _settle = null;
    if (c != null && !c.isCompleted) c.complete(UiTourOutcome.closed);
  }

  @override
  Widget build(BuildContext context) {
    return UiHint(
      message: widget.message,
      open: _open,
      placement: widget.placement,
      duration: widget.duration,
      dismissible: widget.dismissible,
      onOpenChanged: (v) {
        if (!v) setState(() => _open = false);
      },
      onClosed: (_) => _finish(),
      child: widget.child,
    );
  }
}
