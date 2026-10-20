import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../core/icon.dart';
import '../core/types.dart';
import '../theme/theme.dart';

/// A timeline item's place in a flow (the web `UiTimelineState`).
enum UiTimelineItemState { done, current, upcoming }

/// An event in a [UiTimeline].
@immutable
class UiTimelineItem {
  const UiTimelineItem({required this.title, this.description, this.meta, this.tone = UiStatus.primary, this.icon, this.state});

  /// Where it stands in a flow (a booking's steps). [UiTimelineItemState.done] and null look as they
  /// always have; current is announced as the current step and gets a halo; upcoming is muted with
  /// a hollow dot.
  final UiTimelineItemState? state;

  final String title;
  final String? description;

  /// A short aside after the title, usually a time ("2h ago").
  final String? meta;
  final UiStatus tone;

  /// Replaces the dot with a tone-coloured 20px marker holding this Hugeicons icon.
  final UiIconData? icon;
}

/// `ui-timeline`: a vertical sequence of events joined by a line. Each event has a tone-coloured dot
/// (or an icon marker), a title with optional meta, and a description. Read as a list.
///
/// The markers carry a ring in [ringColor] (default: the surface colour) so the line looks broken
/// around them; set it to the colour behind the timeline.
class UiTimeline extends StatelessWidget {
  const UiTimeline({super.key, required this.items, this.ringColor});

  final List<UiTimelineItem> items;
  final Color? ringColor;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final ring = ringColor ?? t.surface;
    // The marker column is as wide as the widest marker.
    final mark = items.any((i) => i.icon != null) ? 20.0 : 11.0;
    Color fill(UiStatus s) => s == UiStatus.neutral ? t.secondary : s.color(t);
    Color on(UiStatus s) => s == UiStatus.neutral ? t.secondaryContrast : s.contrast(t);

    return Semantics(
      container: true,
      explicitChildNodes: true,
      role: SemanticsRole.list,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++)
            Semantics(
              container: true,
              role: SemanticsRole.listItem,
              // The web's aria-current="step": Flutter has no such flag, so the state is read out.
              hint: switch (items[i].state) {
                UiTimelineItemState.current => 'Current step',
                UiTimelineItemState.upcoming => 'Upcoming',
                _ => null,
              },
              child: IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SizedBox(
                    width: mark,
                    child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
                      if (i < items.length - 1) Positioned(top: t.space4, bottom: 0, width: 1, child: ColoredBox(color: t.border)),
                      Positioned(
                        top: items[i].icon != null ? 0 : 4,
                        child: Container(
                          width: items[i].icon != null ? 20 : 11,
                          height: items[i].icon != null ? 20 : 11,
                          decoration: BoxDecoration(
                            color: items[i].state == UiTimelineItemState.upcoming ? t.surface : fill(items[i].tone),
                            shape: BoxShape.circle,
                            border: items[i].state == UiTimelineItemState.upcoming ? Border.all(color: t.borderStrong, width: items[i].icon != null ? 1.5 : 2) : null,
                            boxShadow: [
                              BoxShadow(color: ring, spreadRadius: 2),
                              if (items[i].state == UiTimelineItemState.current) BoxShadow(color: t.primary.withValues(alpha: 0.3), spreadRadius: 5),
                            ],
                          ),
                          child: items[i].icon == null
                              ? null
                              : Center(child: UiIcon(items[i].icon!, size: 12, strokeWidth: 2, color: items[i].state == UiTimelineItemState.upcoming ? t.textMuted : on(items[i].tone))),
                        ),
                      ),
                    ]),
                  ),
                  SizedBox(width: t.space3),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: i < items.length - 1 ? t.space4 : 0),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text.rich(
                          TextSpan(children: [
                            TextSpan(
                              text: items[i].title,
                              style: context.uiText.body.copyWith(
                                height: 1.35,
                                fontWeight: switch (items[i].state) {
                                  UiTimelineItemState.current => FontWeight.w600,
                                  UiTimelineItemState.upcoming => FontWeight.w400,
                                  _ => FontWeight.w500,
                                },
                                color: items[i].state == UiTimelineItemState.upcoming ? t.textMuted : null,
                              ),
                            ),
                            if (items[i].meta != null)
                              TextSpan(
                                text: '  ${items[i].meta}',
                                style: context.uiText.caption.copyWith(fontSize: 12, height: 1.35, fontFeatures: const [FontFeature.tabularFigures()]),
                              ),
                          ]),
                        ),
                        if (items[i].description != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(items[i].description!, style: context.uiText.caption.copyWith(height: 1.35)),
                          ),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}
