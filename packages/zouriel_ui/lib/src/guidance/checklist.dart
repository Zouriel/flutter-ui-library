import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/icon.dart';
import '../core/interactive.dart';
import '../core/types.dart';
import '../feedback/alert.dart';
import '../theme/theme.dart';

/// One row of a [UiChecklist] (the web `UiChecklistItem`).
@immutable
class UiChecklistItem {
  const UiChecklistItem({required this.id, required this.label, this.description, this.done = false});
  final String id;
  final String label;
  final String? description;
  final bool done;
}

/// `ui-checklist`: a short "Getting started" list. The header shows the title, "2 of 5" and a
/// progress bar; each item is a row button with a round check that fills when it is done (done rows
/// go quiet). Items can be done in any order; the app sets [UiChecklistItem.done] and the list
/// follows. When every item is done it shows its finished state ([allDoneText]) instead of the rows.
class UiChecklist extends StatelessWidget {
  const UiChecklist({super.key, required this.heading, this.items = const [], this.onItemTap, this.onDismiss, this.allDoneText});

  final String heading;
  final List<UiChecklistItem> items;

  /// A row was pressed (done or not): open the page where that step is done.
  final ValueChanged<UiChecklistItem>? onItemTap;

  /// Shows the × ("Dismiss") when set.
  final VoidCallback? onDismiss;

  /// The finished state's words; [UiStrings.checklistAllDone] when null.
  final String? allDoneText;

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final ty = context.uiText;
    final strings = context.uiStrings;
    final done = items.where((i) => i.done).length;
    final allDone = items.isNotEmpty && done == items.length;
    final count = uiFormatString(strings.checklistCount, {'done': done, 'total': items.length});
    final md = ty.body.copyWith(fontSize: t.fontSizeMd, height: 1.4, color: t.text);
    final sm = ty.body.copyWith(fontSize: t.fontSizeSm, height: 1.4, color: t.textMuted);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Container(
        // Rows reach into the side padding a little, so their hover fill has room round the text.
        padding: EdgeInsets.symmetric(horizontal: t.space2, vertical: t.space4),
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(color: t.border),
          borderRadius: BorderRadius.circular(theme.radius(t.radiusLg)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: t.space2),
            child: Stack(clipBehavior: Clip.none, children: [
              Padding(
                // Room for the × at the end of the heading line.
                padding: EdgeInsetsDirectional.only(end: onDismiss != null ? 28 : 0),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: t.space3,
                  runSpacing: t.space1,
                  children: [
                    Semantics(header: true, child: Text(heading, style: md.copyWith(fontWeight: FontWeight.w600))),
                    Text(count, style: sm.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                  ],
                ),
              ),
              if (onDismiss != null)
                PositionedDirectional(
                  // Drawn 28px a little past the corner; on touch screens its 48px tap area is centred on it.
                  top: -t.space1 - _xPad(context),
                  end: -t.space1 - _xPad(context),
                  child: UiInteractive(
                    onTap: onDismiss,
                    semanticLabel: strings.dismiss,
                    excludeChildSemantics: true,
                    builder: (context, s) => Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: s.hovered || s.pressed ? t.surfaceHover : null,
                        borderRadius: BorderRadius.circular(t.radiusPill),
                        boxShadow: s.focused ? t.focusRing : null,
                      ),
                      child: Center(child: UiIcon(HugeIcons.strokeRoundedCancel01, size: 16, strokeWidth: 2, color: s.hovered ? t.text : t.textMuted)),
                    ),
                  ),
                ),
            ]),
          ),
          SizedBox(height: t.space3),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: t.space2),
            child: UiProgressBar(value: items.isEmpty ? 0 : done / items.length * 100, tone: allDone ? UiStatus.success : UiStatus.primary, label: count),
          ),
          SizedBox(height: t.space3),
          if (allDone)
            Semantics(
              liveRegion: true,
              child: Padding(padding: EdgeInsets.symmetric(horizontal: t.space2), child: Row(children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: t.success, borderRadius: BorderRadius.circular(t.radiusPill)),
                  child: Center(child: ExcludeSemantics(child: UiIcon(HugeIcons.strokeRoundedTick02, size: 18, strokeWidth: 2.4, color: t.successContrast))),
                ),
                SizedBox(width: t.space3),
                Expanded(child: Text(allDoneText ?? strings.checklistAllDone, style: md.copyWith(fontWeight: FontWeight.w500))),
              ])),
            )
          else
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final item in items) _Row(item: item, onTap: onItemTap == null ? null : () => onItemTap!(item)),
            ]),
        ]),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item, required this.onTap});
  final UiChecklistItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final ty = context.uiText;
    final strings = context.uiStrings;
    final state = item.done ? strings.checklistItemDone : strings.checklistItemToDo;
    return UiInteractive(
      onTap: onTap ?? () {},
      semanticLabel: '${item.label}, $state',
      semanticHint: item.description,
      excludeChildSemantics: true,
      pressScale: false,
      builder: (context, s) => Container(
        constraints: const BoxConstraints(minHeight: uiMinTouchTarget),
        padding: EdgeInsets.symmetric(horizontal: t.space2, vertical: t.space2),
        decoration: BoxDecoration(
          color: s.hovered || s.pressed ? t.surfaceHover : null,
          borderRadius: BorderRadius.circular(theme.radius(t.radius)),
          boxShadow: s.focused ? t.focusRing : null,
        ),
        child: Row(children: [
          AnimatedContainer(
            duration: context.uiAnimate ? t.motionFast : Duration.zero,
            curve: t.easeStandard,
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: item.done ? t.primary : null,
              border: Border.all(color: item.done ? t.primary : t.borderStrong, width: 2),
              borderRadius: BorderRadius.circular(t.radiusPill),
            ),
            child: item.done ? Center(child: UiIcon(HugeIcons.strokeRoundedTick02, size: 14, strokeWidth: 2.4, color: t.primaryContrast)) : null,
          ),
          SizedBox(width: t.space3),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(
                item.label,
                style: ty.body.copyWith(
                  fontSize: t.fontSizeMd,
                  height: 1.4,
                  fontWeight: item.done ? FontWeight.w400 : FontWeight.w500,
                  color: item.done ? t.textMuted : t.text,
                  decoration: item.done ? TextDecoration.lineThrough : null,
                  decorationColor: t.textMuted,
                ),
              ),
              if (item.description != null) ...[
                const SizedBox(height: 2),
                Text(item.description!, style: ty.body.copyWith(fontSize: t.fontSizeSm, height: 1.4, color: t.textMuted)),
              ],
            ]),
          ),
          if (!item.done) ...[
            SizedBox(width: t.space3),
            UiIcon(HugeIcons.strokeRoundedArrowRight01, size: 16, strokeWidth: 2, color: t.textMuted, matchTextDirection: true),
          ],
        ]),
      ),
    );
  }
}

/// How far a 28px button's touch padding reaches past it on each side.
double _xPad(BuildContext context) => uiTouchPlatform(context) ? (uiMinTouchTarget - 28) / 2 : 0;
