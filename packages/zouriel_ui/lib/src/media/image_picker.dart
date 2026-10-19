import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../behaviors/intersect.dart';
import '../core/icon.dart';
import '../core/interactive.dart';
import '../feedback/spinner.dart';
import '../layout/layout.dart';
import '../theme/theme.dart';

/// One tile of a [UiImagePicker].
@immutable
class UiImagePickerItem {
  const UiImagePickerItem({required this.id, required this.image, required this.label, this.badge, this.disabled = false, this.hint});

  final String id;

  /// The thumbnail.
  final ImageProvider image;

  /// Accessible name, and the caption with [UiImagePicker.captions].
  final String label;

  /// A short tag in the corner, such as "Moves".
  final String? badge;
  final bool disabled;

  /// Why it is disabled (shown on the tile, and read as the hint), or anything more to say.
  final String? hint;
}

/// `ui-image-picker`: a grid of image tiles to choose from (search results, stock art, uploads).
///
/// A tap (or Enter/Space) picks a tile ([onPick]). While [busyId] is set that tile shows a spinner
/// and every other tile is disabled. With [hasMore], scrolling within 240px of the end asks for the
/// next page ([onMore]), and asks again after a page loads if the end is still in view: no
/// "Load more" button to reach for with a thumb. Thumbnails that fail to load show the label on a
/// plain tile. Tiles sit on a faint checkerboard so white or transparent art shows.
///
/// With [draggable], a long press lifts a tile as a [LongPressDraggable] carrying its
/// [UiImagePickerItem], for a [DragTarget] elsewhere.
class UiImagePicker extends StatelessWidget {
  const UiImagePicker({
    super.key,
    required this.items,
    this.onPick,
    this.onMore,
    this.busyId,
    this.loading = false,
    this.hasMore = false,
    this.minThumb = 96,
    this.captions = false,
    this.emptyText = '',
    this.draggable = false,
  });

  final List<UiImagePickerItem> items;
  final ValueChanged<UiImagePickerItem>? onPick;
  final VoidCallback? onMore;

  /// The tile being fetched; the others wait while it is.
  final String? busyId;

  /// A page is loading.
  final bool loading;

  /// There is another page: reaching the end asks for it with [onMore].
  final bool hasMore;
  final double minThumb;
  final bool captions;

  /// Shown when there are no items and nothing is loading.
  final String emptyText;
  final bool draggable;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      UiGrid(
        minColumnWidth: minThumb,
        gap: 2,
        collapseEmptyColumns: false,
        children: [
          for (final item in items)
            _Cell(
              item: item,
              busy: busyId == item.id,
              blocked: item.disabled || (busyId != null && busyId != item.id),
              captions: captions,
              draggable: draggable,
              onPick: onPick,
            ),
        ],
      ),
      if (loading)
        Padding(padding: EdgeInsets.all(t.space3), child: const Center(child: UiSpinner(label: 'Loading…')))
      else if (items.isEmpty && emptyText.isNotEmpty)
        Padding(
          padding: EdgeInsets.all(t.space3),
          child: Text(emptyText, textAlign: TextAlign.center, style: context.uiText.caption),
        ),
      // The end of the list. A fresh observer per page (the key) reports where the end is now, so a
      // page that did not push it out of view still asks for the next.
      UiIntersect(
        key: ValueKey('${items.length}:$loading'),
        rootMargin: const EdgeInsets.all(240),
        onChange: (visible) {
          if (visible && hasMore && !loading && items.isNotEmpty) onMore?.call();
        },
        child: const SizedBox(height: 1),
      ),
    ]);
  }
}

class _Cell extends StatefulWidget {
  const _Cell({required this.item, required this.busy, required this.blocked, required this.captions, required this.draggable, required this.onPick});
  final UiImagePickerItem item;
  final bool busy, blocked, captions, draggable;
  final ValueChanged<UiImagePickerItem>? onPick;

  @override
  State<_Cell> createState() => _CellState();
}

class _CellState extends State<_Cell> {
  bool _broken = false;

  @override
  void didUpdateWidget(_Cell old) {
    super.didUpdateWidget(old);
    if (old.item.image != widget.item.image) _broken = false;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final item = widget.item;
    final r = BorderRadius.circular(context.uiTheme.radius());

    // A disabled tile with a reason says why on the tile itself: the art dims, the reason sits on a
    // strip along the bottom at full strength.
    final reason = item.disabled && item.hint != null;
    Widget tile(UiStates s) {
      final content = _broken
          ? Column(mainAxisAlignment: MainAxisAlignment.center, spacing: t.space1, children: [
              UiIcon(HugeIcons.strokeRoundedImage01, size: 22, strokeWidth: 1.6, color: t.textMuted),
              Flexible(
                child: Text(item.label, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, style: context.uiText.caption.copyWith(height: 1.2)),
              ),
            ])
          : Image(
              image: item.image,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
              errorBuilder: (context, _, _) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && !_broken) setState(() => _broken = true);
                });
                return const SizedBox.expand();
              },
            );
      return AspectRatio(
        aspectRatio: 1,
        child: AnimatedOpacity(
          opacity: s.disabled && !widget.busy && !reason ? 0.5 : 1,
          duration: t.motionBase,
          child: AnimatedContainer(
            duration: context.uiAnimate ? t.motionBase : Duration.zero,
            decoration: BoxDecoration(
              borderRadius: r,
              border: Border.all(color: widget.busy || (s.hovered && !s.disabled) ? t.primary : t.border),
              boxShadow: uiFocusRing(t, show: s.focused),
            ),
            child: ClipRRect(
              borderRadius: r,
              child: CustomPaint(
                painter: _Checker(t.surface, t.surfaceSubtle),
                child: Stack(fit: StackFit.expand, children: [
                  Opacity(opacity: reason ? 0.45 : 1, child: Padding(padding: EdgeInsets.all(t.space2), child: content)),
                  if (item.badge != null)
                    Positioned(
                      top: t.space1,
                      right: t.space1,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: t.space1),
                        decoration: BoxDecoration(color: t.primary, borderRadius: BorderRadius.circular(t.radiusPill)),
                        child: Text(item.badge!, style: context.uiText.label.copyWith(fontSize: 11, height: 16 / 11, color: t.primaryContrast)),
                      ),
                    ),
                  if (reason)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: t.space1, vertical: 2),
                        color: t.surfaceRaised.withValues(alpha: 0.88),
                        child: Text(item.hint!, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: context.uiText.label.copyWith(fontSize: 11, height: 16 / 11, fontWeight: FontWeight.w500, color: t.text)),
                      ),
                    ),
                  if (widget.busy)
                    ColoredBox(
                      color: t.surface.withValues(alpha: 0.6),
                      child: Center(child: UiSpinner(label: 'Adding ${item.label}', color: t.text)),
                    ),
                ]),
              ),
            ),
          ),
        ),
      );
    }

    Widget cell = UiInteractive(
      onTap: widget.onPick == null ? null : () => widget.onPick!(item),
      enabled: !widget.blocked && !widget.busy,
      padTouchTarget: false,
      semanticLabel: item.label,
      semanticHint: item.hint,
      excludeChildSemantics: !widget.busy,
      builder: (context, s) => Semantics(liveRegion: widget.busy, child: tile(s)),
    );

    if (widget.draggable && !item.disabled) {
      cell = LongPressDraggable<UiImagePickerItem>(
        data: item,
        feedback: SizedBox.square(
          dimension: 72,
          child: Opacity(
            opacity: 0.85,
            child: DecoratedBox(
              decoration: BoxDecoration(borderRadius: r, boxShadow: t.shadow2),
              child: ClipRRect(borderRadius: r, child: Image(image: item.image, fit: BoxFit.cover)),
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.4, child: cell),
        child: cell,
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, spacing: t.space1, children: [
      cell,
      if (widget.captions)
        ExcludeSemantics(child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.uiText.caption)),
    ]);
  }
}

/// The faint 8px checkerboard tiles sit on.
class _Checker extends CustomPainter {
  _Checker(this.base, this.alt);
  final Color base, alt;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = base);
    final p = Paint()..color = alt;
    const s = 8.0;
    for (var y = 0.0; y < size.height; y += s) {
      for (var x = ((y / s).round().isOdd ? s : 0.0); x < size.width; x += s * 2) {
        canvas.drawRect(Rect.fromLTWH(x, y, s, s), p);
      }
    }
  }

  @override
  bool shouldRepaint(_Checker old) => old.base != base || old.alt != alt;
}
