import 'dart:async';

import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'motion.dart';

/// `ui-intro-loader`: a full-screen veil with [child] (a logo or wordmark) over a progress line
/// that fills over [duration]; then it fades and lifts away and calls [onDone]. Put it at the top
/// of a [Stack] over the app. Setting [open] false removes it at once, without the fade.
///
/// Under reduced motion it holds for a third of [duration] and fades out without the lift; with the
/// library's animations off it is gone straight away. Announced as "Loading…".
class UiIntroLoader extends StatefulWidget {
  const UiIntroLoader({super.key, this.child, this.duration = const Duration(milliseconds: 1400), this.open = true, this.onDone});

  final Widget? child;
  final Duration duration;
  final bool open;
  final VoidCallback? onDone;

  @override
  State<UiIntroLoader> createState() => _UiIntroLoaderState();
}

class _UiIntroLoaderState extends State<UiIntroLoader> with TickerProviderStateMixin {
  AnimationController? _fill;
  AnimationController? _leave;
  bool _gone = false;
  bool _started = false;
  Timer? _hold;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started || !widget.open) return;
    _started = true;
    final motion = uiFxMotion(context);
    if (motion == UiFxMotion.none) {
      _gone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDone?.call());
      return;
    }
    final hold = motion == UiFxMotion.calm ? widget.duration ~/ 3 : widget.duration;
    _fill = AnimationController(vsync: this, duration: hold)..forward();
    _leave = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    _hold = Timer(hold, () {
      if (!mounted) return;
      _leave!.forward().whenComplete(() {
        if (!mounted) return;
        setState(() => _gone = true);
        widget.onDone?.call();
      });
    });
  }

  @override
  void dispose() {
    _hold?.cancel();
    _fill?.dispose();
    _leave?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_gone || !widget.open || _fill == null) return const SizedBox.shrink();
    final t = context.ui;
    final calm = uiFxMotion(context) == UiFxMotion.calm;
    final fill = CurvedAnimation(parent: _fill!, curve: uiEaseDramatic);
    final leave = CurvedAnimation(parent: _leave!, curve: uiEaseDramatic);
    return AnimatedBuilder(
      animation: leave,
      builder: (context, child) => IgnorePointer(
        ignoring: _leave!.value > 0,
        child: Opacity(
          opacity: 1 - leave.value,
          child: FractionalTranslation(translation: Offset(0, calm ? 0 : -0.03 * leave.value), child: child),
        ),
      ),
      child: Semantics(
        liveRegion: true,
        label: 'Loading…',
        child: ColoredBox(
          color: t.bg,
          child: Center(
            child: DefaultTextStyle(
              style: context.uiText.h2.copyWith(color: t.text),
              child: Column(mainAxisSize: MainAxisSize.min, spacing: t.space4, children: [
                ?widget.child,
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    width: 160,
                    height: 2,
                    child: ColoredBox(
                      color: t.border,
                      child: AnimatedBuilder(
                        animation: fill,
                        builder: (context, _) => FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: fill.value.clamp(0.0, 1.0),
                          child: DecoratedBox(decoration: BoxDecoration(gradient: t.gradientBrand.toGradient(), boxShadow: t.glowAmber)),
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// `ui-scroll-progress`: a 2px bar along the top of [child] (a scroll view) that fills with the
/// brand gradient and glow as it scrolls. Decorative: hidden from screen readers.
class UiScrollProgress extends StatefulWidget {
  const UiScrollProgress({super.key, required this.child});

  final Widget child;

  @override
  State<UiScrollProgress> createState() => _UiScrollProgressState();
}

class _UiScrollProgressState extends State<UiScrollProgress> {
  final ValueNotifier<double> _p = ValueNotifier(0);

  @override
  void dispose() {
    _p.dispose();
    super.dispose();
  }

  bool _onNotification(Notification n) {
    // Scrolls, plus metrics changes: the first layout (an initial offset) and content resizing.
    final (depth, m) = switch (n) {
      ScrollNotification() => (n.depth, n.metrics),
      ScrollMetricsNotification() => (n.depth, n.metrics),
      _ => (-1, null),
    };
    if (depth != 0 || m == null || m.axis != Axis.vertical) return false;
    final max = m.maxScrollExtent - m.minScrollExtent;
    _p.value = max > 0 ? ((m.pixels - m.minScrollExtent) / max).clamp(0.0, 1.0) : 0;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Stack(children: [
      NotificationListener<Notification>(onNotification: _onNotification, child: widget.child),
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: 2,
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: ColoredBox(
              color: t.scrollProgressTrack,
              child: ValueListenableBuilder<double>(
                valueListenable: _p,
                builder: (context, v, _) => FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: v,
                  child: DecoratedBox(decoration: BoxDecoration(gradient: t.gradientBrand.toGradient(), boxShadow: t.glowAmber)),
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

/// `ui-section-label`: an editorial mono section marker, `[ 00 · INDEX ]`, with a fading rule.
/// The index and its dot are left out when [index] is empty.
class UiSectionLabel extends StatelessWidget {
  const UiSectionLabel({super.key, required this.label, this.index = ''});

  final String label;
  final String index;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final base = context.uiText.code.copyWith(fontSize: 11, height: 1.35, letterSpacing: 11 * 0.4, color: t.textMuted);
    return Semantics(
      label: index.isEmpty ? label : '$index $label',
      child: ExcludeSemantics(
        child: Row(mainAxisSize: MainAxisSize.min, spacing: t.space3, children: [
          Text('[', style: base.copyWith(color: t.sectionLabelBracket)),
          if (index.isNotEmpty) ...[
            Text(index.toUpperCase(), style: base.copyWith(color: t.text)),
            Text('·', style: base),
          ],
          Text(label.toUpperCase(), style: base.copyWith(color: t.text)),
          Text(']', style: base.copyWith(color: t.sectionLabelBracket)),
          Container(
            width: 48,
            height: 1,
            decoration: BoxDecoration(gradient: LinearGradient(colors: [t.border, t.border.withValues(alpha: 0)])),
          ),
        ]),
      ),
    );
  }
}
