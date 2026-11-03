import 'dart:ui' show ImageFilter;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/icon.dart';
import '../core/interactive.dart';
import '../core/types.dart';
import '../theme/theme.dart';

/// A small dot over a poster's corner: something the grid must say without words (unread,
/// unfinished). Only [UiStatus.primary], [UiStatus.warning] and [UiStatus.neutral] are drawn, as on
/// the web.
@immutable
class UiPosterMark {
  const UiPosterMark({required this.tone, required this.label});
  final UiStatus tone;

  /// Read out with the poster's name; the dot itself has no text.
  final String label;
}

/// One tile of a [UiPosterGrid] (the web `UiPoster`).
@immutable
class UiPoster {
  const UiPoster({required this.label, this.image, this.colors, this.mark});

  /// The picture. Without one (or when it fails to load) the tile shows [colors] as a gradient.
  final ImageProvider? image;

  /// The tile's accessible name. Never drawn on it.
  final String label;

  /// Fallback gradient stops, e.g. a design's colours. Without them the theme's primary and accent.
  final List<Color>? colors;
  final UiPosterMark? mark;
}

/// Which part of a picture survives a poster's crop.
enum UiPosterFocus { top, center }

/// The gradient a poster without a picture shows, shared by [UiPosterGrid] and [UiPosterView].
Gradient uiPosterFallback(BuildContext context, List<Color>? colors) {
  final t = context.ui;
  final c = colors ?? const <Color>[];
  final stops = c.length >= 2
      ? c
      : c.length == 1
          ? [c.first, Color.lerp(c.first, t.bg, 0.45)!]
          : [Color.lerp(t.primary, t.bg, 0.3)!, Color.lerp(t.accent, t.bg, 0.4)!];
  // 160deg on the web: from the top, leaning a little to the right.
  return LinearGradient(begin: const Alignment(-0.35, -1), end: const Alignment(0.35, 1), colors: stops);
}

/// `ui-poster-grid`: a grid of pictures and nothing else. Every tile is the same shape ([ratio],
/// width / height), there are 2 columns on a phone, 3 from 544 wide, 4 from 992 and 5 from 1280 (of
/// the grid's own width), and a tile carries no text: its name is only its semantic label. A tile
/// with no picture shows a gradient. The one signal allowed on a tile is a small dot ([UiPoster.mark]),
/// named for screen readers. Tapping a tile calls [onSelect] with its index; what opens is the
/// caller's (usually [UiPosterView.show] with the details). It doesn't scroll: put it in a scroll view.
class UiPosterGrid extends StatelessWidget {
  const UiPosterGrid({super.key, required this.posters, required this.onSelect, this.ratio = 0.75, this.focus = UiPosterFocus.center});

  final List<UiPoster> posters;
  final ValueChanged<int> onSelect;

  /// Width / height of every tile. 3/4 by default: invitations are read upright.
  final double ratio;

  /// [UiPosterFocus.top] keeps a poster's heading.
  final UiPosterFocus focus;

  /// How many columns a grid [width] wide shows.
  static int columnsFor(double width) => width >= 1280 ? 5 : width >= 992 ? 4 : width >= 544 ? 3 : 2;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return LayoutBuilder(builder: (context, box) {
      final columns = columnsFor(box.maxWidth);
      final gap = box.maxWidth >= 544 ? t.space3 : t.space2;
      final width = (box.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(spacing: gap, runSpacing: gap, children: [
        for (var i = 0; i < posters.length; i++)
          SizedBox(
            width: width,
            child: AspectRatio(aspectRatio: ratio, child: _Tile(poster: posters[i], focus: focus, onTap: () => onSelect(i))),
          ),
      ]);
    });
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.poster, required this.focus, required this.onTap});
  final UiPoster poster;
  final UiPosterFocus focus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final r = BorderRadius.circular(context.uiTheme.radius());
    final mark = poster.mark;
    final fallback = DecoratedBox(decoration: BoxDecoration(gradient: uiPosterFallback(context, poster.colors)));
    return UiInteractive(
      onTap: onTap,
      padTouchTarget: false,
      semanticLabel: mark == null ? poster.label : '${poster.label}, ${mark.label}',
      excludeChildSemantics: true,
      builder: (context, s) => AnimatedContainer(
        duration: context.uiAnimate ? t.motionBase : Duration.zero,
        decoration: BoxDecoration(
          borderRadius: r,
          color: t.surfaceRaised,
          boxShadow: s.focused ? uiFocusRing(t, show: true) : s.hovered ? [BoxShadow(color: t.borderStrong, spreadRadius: 2)] : null,
        ),
        child: ClipRRect(
          borderRadius: r,
          child: Stack(fit: StackFit.expand, children: [
            if (poster.image case final image?)
              Image(
                image: image,
                fit: BoxFit.cover,
                alignment: focus == UiPosterFocus.top ? Alignment.topCenter : Alignment.center,
                excludeFromSemantics: true,
                // A stored URL can outlive its file: the gradient, never a broken-image icon.
                errorBuilder: (_, _, _) => fallback,
              )
            else
              fallback,
            if (mark != null)
              PositionedDirectional(top: t.space2, end: t.space2, child: UiPosterDot(tone: mark.tone)),
          ]),
        ),
      ),
    );
  }
}

/// The dot of a [UiPosterMark]: 10 across, ringed in the scrim colour so it shows on any picture.
class UiPosterDot extends StatelessWidget {
  const UiPosterDot({super.key, required this.tone});
  final UiStatus tone;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final fill = switch (tone) {
      UiStatus.primary => t.primary,
      UiStatus.warning => t.warning,
      _ => t.mediaOnScrim,
    };
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: t.mediaScrim.withValues(alpha: 0.55), spreadRadius: 2)],
      ),
    );
  }
}

/// `ui-scrim`: a see-through layer that fades from clear at its top to the media scrim colour at its
/// bottom, with text and icons in the on-scrim colour. Lay it over a picture to put words on it: the
/// fade has reached 60% before the content starts (after `space12`) and 88% at the bottom, so
/// on-scrim text keeps at least 4.5:1 over any picture, white included.
class UiScrim extends StatelessWidget {
  const UiScrim({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return CustomPaint(
      painter: _ScrimPainter(color: t.mediaScrim, lead: t.space12),
      child: Padding(
        padding: EdgeInsets.fromLTRB(t.space4, t.space12, t.space4, t.space4),
        // As wide as there is room for, up to 640, centred: the web's max-width with margin auto.
        child: LayoutBuilder(builder: (context, box) => Align(
              alignment: Alignment.topCenter,
              heightFactor: 1,
              child: SizedBox(
                width: box.maxWidth.isFinite ? (box.maxWidth < 640 ? box.maxWidth : 640) : 640,
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: t.mediaOnScrim),
                  child: IconTheme.merge(data: IconThemeData(color: t.mediaOnScrim), child: child),
                ),
              ),
            )),
      ),
    );
  }
}

/// Clear at the top, 60% at [lead] down, 88% at the bottom: the same stops as the web's gradient.
class _ScrimPainter extends CustomPainter {
  _ScrimPainter({required this.color, required this.lead});
  final Color color;
  final double lead;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.height <= 0) return;
    final at = (lead / size.height).clamp(0.0, 1.0);
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0), color.withValues(alpha: 0.6), color.withValues(alpha: 0.88)],
          stops: [0, at, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_ScrimPainter old) => old.color != color || old.lead != lead;
}

class _Close extends Intent {
  const _Close();
}

/// `ui-poster-view`: one picture full-size, with [child] laid over its bottom on a [UiScrim] (the
/// details and the buttons for whatever the picture stands for). The picture is shown whole, over a
/// blurred copy of itself that fills the screen; without a picture it shows the gradient
/// [UiPosterGrid] gives the tile. Escape, back or the close button close it. Open it with [show].
class UiPosterView extends StatelessWidget {
  const UiPosterView({super.key, required this.label, required this.child, required this.onClose, this.image, this.colors});

  final ImageProvider? image;

  /// The view's semantic label and the picture's.
  final String label;
  final List<Color>? colors;
  final Widget child;
  final VoidCallback onClose;

  /// Pushes the view over everything as a route that fades in. [builder] gets the route's context,
  /// so its buttons can pop it (`Navigator.pop`) before going somewhere else.
  static Future<T?> show<T>(BuildContext context, {required String label, required WidgetBuilder builder, ImageProvider? image, List<Color>? colors}) {
    final animate = context.uiAnimate;
    final t = context.ui;
    return Navigator.of(context).push<T>(PageRouteBuilder<T>(
      opaque: false,
      barrierLabel: label,
      transitionDuration: animate ? t.motionBase : Duration.zero,
      reverseTransitionDuration: animate ? t.motionBase : Duration.zero,
      pageBuilder: (context, _, _) => UiPosterView(
        label: label,
        image: image,
        colors: colors,
        onClose: () => Navigator.of(context).maybePop(),
        child: Builder(builder: builder),
      ),
      transitionsBuilder: (context, a, _, child) => FadeTransition(opacity: CurvedAnimation(parent: a, curve: t.easeDecelerate), child: child),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final pad = MediaQuery.paddingOf(context);
    final fallback = DecoratedBox(decoration: BoxDecoration(gradient: uiPosterFallback(context, colors)));
    final pic = image;
    return Shortcuts(
      shortcuts: const {SingleActivator(LogicalKeyboardKey.escape): _Close()},
      child: Actions(
        actions: {_Close: CallbackAction<_Close>(onInvoke: (_) => onClose())},
        child: FocusScope(
          autofocus: true,
          child: Semantics(
            scopesRoute: true,
            namesRoute: true,
            explicitChildNodes: true,
            label: label,
            child: ColoredBox(
              color: t.mediaScrim,
              child: Stack(fit: StackFit.expand, children: [
                if (pic != null) ...[
                  ExcludeSemantics(
                    child: ClipRect(
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28, tileMode: TileMode.clamp),
                        child: ColorFiltered(
                          colorFilter: ColorFilter.mode(t.mediaScrim.withValues(alpha: 0.45), BlendMode.srcOver),
                          child: Image(image: pic, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback),
                        ),
                      ),
                    ),
                  ),
                  Image(image: pic, fit: BoxFit.contain, semanticLabel: label, errorBuilder: (_, _, _) => fallback),
                ] else
                  fallback,
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: LayoutBuilder(builder: (context, _) {
                    final max = MediaQuery.sizeOf(context).height * 0.7;
                    return ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: max),
                      child: SingleChildScrollView(
                        child: UiScrim(child: Padding(padding: EdgeInsets.only(bottom: pad.bottom), child: child)),
                      ),
                    );
                  }),
                ),
                PositionedDirectional(
                  top: pad.top + t.space4,
                  end: t.space4,
                  child: UiInteractive(
                    onTap: onClose,
                    semanticLabel: context.uiStrings.close,
                    builder: (context, s) => AnimatedContainer(
                      duration: context.uiAnimate ? t.motionBase : Duration.zero,
                      width: uiMinTouchTarget,
                      height: uiMinTouchTarget,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: t.mediaScrim.withValues(alpha: s.hovered || s.pressed ? 0.65 : 0.45),
                        boxShadow: uiFocusRing(t, show: s.focused),
                      ),
                      child: Center(child: UiIcon(HugeIcons.strokeRoundedCancel01, size: 18, color: t.mediaOnScrim, strokeWidth: 2)),
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
