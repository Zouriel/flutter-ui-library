import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/icon.dart';
import '../core/interactive.dart';
import '../theme/theme.dart';

/// The page numbers [UiPagination] shows for [page] of [total] with [siblings] either side: the first
/// and last page always, `-1` for a gap. Exposed for tests and custom pagers.
List<int> uiPaginationItems(int page, int total, int siblings) {
  final out = <int>[1];
  final left = math.max(2, page - siblings);
  final right = math.min(total - 1, page + siblings);
  if (left > 2) out.add(-1);
  for (var i = left; i <= right; i++) {
    out.add(i);
  }
  if (right < total - 1) out.add(-1);
  if (total > 1) out.add(total);
  return out;
}

/// `ui-pagination`: previous/next buttons around page numbers, with gaps for long runs. [page] is
/// 1-based; [onChanged] reports the new page (clamped to 1..[total]).
///
/// It fits itself to its width: when the buttons don't fit, it shows fewer [siblings], and on a very
/// narrow screen it becomes "previous, Page 3 of 12, next". Buttons are 44px with a 48dp touch area on
/// touch screens (26px with a mouse).
class UiPagination extends StatelessWidget {
  const UiPagination({super.key, required this.page, required this.total, this.onChanged, this.siblings = 1, this.label});

  final int page;
  final int total;
  final ValueChanged<int>? onChanged;
  final int siblings;
  /// [UiStrings.pagination] when null.
  final String? label;

  void _go(int p) {
    final clamped = p.clamp(1, math.max(1, total)).toInt();
    if (clamped != page) onChanged?.call(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final touch = uiTouchPlatform(context);
    final dim = touch ? t.sizeTouch : t.sizeSm;
    final slot = touch ? uiMinTouchTarget : dim; // what one button takes in the row
    final style = context.uiText.body.copyWith(fontSize: t.fontSizeSm, height: 1.35, fontFeatures: const [FontFeature.tabularFigures()]);
    final scale = MediaQuery.textScalerOf(context);

    double width(List<int> items) {
      var w = 2 * slot;
      for (final n in items) {
        if (n == -1) {
          w += 16 + t.space1 * 2;
        } else {
          final p = TextPainter(text: TextSpan(text: '$n', style: style.copyWith(fontWeight: FontWeight.w600)), textDirection: TextDirection.ltr, textScaler: scale)..layout();
          w += math.max(slot, p.width + t.space2 * 2 + 2);
          p.dispose();
        }
      }
      return w + (items.length + 1) * t.space1;
    }

    return Semantics(
      container: true,
      explicitChildNodes: true,
      role: SemanticsRole.navigation,
      label: label ?? context.uiStrings.pagination,
      child: LayoutBuilder(builder: (context, box) {
        var sib = siblings;
        var items = uiPaginationItems(page, total, sib);
        while (box.maxWidth.isFinite && width(items) > box.maxWidth && sib > 0) {
          items = uiPaginationItems(page, total, --sib);
        }
        final compact = box.maxWidth.isFinite && width(items) > box.maxWidth;
        final prev = _PageButton(dim: dim, semanticLabel: context.uiStrings.previousPage, onTap: page > 1 ? () => _go(page - 1) : null, child: const UiIcon(HugeIcons.strokeRoundedArrowLeft01, size: 14, strokeWidth: 2, matchTextDirection: true));
        final next = _PageButton(dim: dim, semanticLabel: context.uiStrings.nextPage, onTap: page < total ? () => _go(page + 1) : null, child: const UiIcon(HugeIcons.strokeRoundedArrowRight01, size: 14, strokeWidth: 2, matchTextDirection: true));
        return Row(mainAxisSize: MainAxisSize.min, spacing: t.space1, children: [
          prev,
          if (compact)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: t.space2),
              child: Semantics(liveRegion: true, child: Text(uiFormatString(context.uiStrings.pageOf, {'n': page, 'total': total}), style: style.copyWith(color: t.text))),
            )
          else
            for (final n in items)
              if (n == -1)
                ExcludeSemantics(child: Padding(padding: EdgeInsets.symmetric(horizontal: t.space1), child: UiIcon(HugeIcons.strokeRoundedMoreHorizontal, size: 16, color: t.textMuted)))
              else
                _PageButton(
                  dim: dim,
                  active: n == page,
                  semanticLabel: uiFormatString(context.uiStrings.page, {'n': n}),
                  onTap: () => _go(n),
                  child: Text('$n', style: style.copyWith(color: t.text, fontWeight: n == page ? FontWeight.w600 : FontWeight.w400)),
                ),
          next,
        ]);
      }),
    );
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({required this.dim, required this.semanticLabel, required this.child, this.onTap, this.active = false});
  final double dim;
  final String semanticLabel;
  final Widget child;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return UiInteractive(
      onTap: onTap,
      enabled: onTap != null,
      semanticLabel: semanticLabel,
      selected: active,
      excludeChildSemantics: true,
      builder: (context, s) => Opacity(
        opacity: s.disabled ? 0.5 : 1,
        child: AnimatedContainer(
          duration: context.uiAnimate ? t.motionFast : Duration.zero,
          curve: t.easeStandard,
          constraints: BoxConstraints(minWidth: dim, minHeight: dim, maxHeight: dim),
          padding: EdgeInsets.symmetric(horizontal: t.space2),
          decoration: BoxDecoration(
            color: active ? t.selected : (s.hovered || s.pressed ? t.surfaceHover : null),
            border: Border.all(color: active ? t.borderFocus : t.border),
            borderRadius: BorderRadius.circular(context.uiTheme.radius()),
            boxShadow: s.focused ? t.focusRing : const [],
          ),
          child: IconTheme.merge(data: IconThemeData(color: t.icon ?? t.text), child: Center(widthFactor: 1, child: child)),
        ),
      ),
    );
  }
}
