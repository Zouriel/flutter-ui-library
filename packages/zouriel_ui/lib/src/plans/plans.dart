import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../badge/badge.dart';
import '../core/icon.dart';
import '../core/interactive.dart';
import '../core/types.dart';
import '../forms/choice/marks.dart';
import '../theme/theme.dart';

/// `ui-plan-card`: one plan on a plans or billing page.
///
/// [name], [price] (already formatted, "MVR 499") and an optional [period] ("per event"), [note]
/// under the price ("about $32"), [tagline] and [features] (a check list). [tier] adds a slim strip of
/// the tier's metal along the top and a small tier dot after the name; the card itself stays on the
/// theme's surface. [highlight] ("Most popular") puts a ribbon on the top edge and a stronger border
/// (use it on at most one card per grid). [current] shows a "Your plan" badge ([currentLabel]); the
/// caller decides the [action]. [action] sits at the bottom, aligned across cards in a [UiPlanGrid];
/// [fineprint] is small muted text under it. Screen readers get a group named by the plan, and the
/// price read as one phrase ("MVR 499 per event").
///
/// [addOn] adds an optional extra under the features ("Add the AI designer", with [addOnNote]
/// "+MVR 77 a month" muted under it): a bordered row that ticks as a whole ([addOnValue],
/// [onAddOnChanged]; null disables it). Ticked, its border takes the tier's colour. The card doesn't
/// change its price; the caller shows the new total (on its button, say). Screen readers get one
/// checkbox named by the label and the note.
class UiPlanCard extends StatelessWidget {
  const UiPlanCard({
    super.key,
    required this.name,
    required this.price,
    this.period,
    this.note,
    this.tagline,
    this.features = const [],
    this.tier,
    this.highlight,
    this.current = false,
    this.currentLabel = 'Your plan',
    this.action,
    this.fineprint,
    this.radius,
    this.addOn,
    this.addOnNote,
    this.addOnValue = false,
    this.onAddOnChanged,
  });

  final String name;

  /// Already formatted ("MVR 499").
  final String price;

  /// After the price ("per event", "a month").
  final String? period;

  /// A small line under the price ("about $32").
  final String? note;
  final String? tagline;
  final List<String> features;
  final UiTier? tier;

  /// A ribbon on the top edge ("Most popular") and a stronger border.
  final String? highlight;

  /// Shows [currentLabel] as a badge by the name.
  final bool current;
  final String currentLabel;

  /// The plan's button(s), at the bottom of the card.
  final Widget? action;

  /// Small muted text under [action].
  final Widget? fineprint;

  /// Rounded corners; defaults to the library config.
  final bool? radius;

  /// An optional extra under the features, shown as a tick row ("Add the AI designer").
  /// Nothing shows without it.
  final String? addOn;

  /// A muted second line in the add-on row ("+MVR 77 a month, about $5").
  final String? addOnNote;

  /// Whether the add-on is ticked (the web `[(addOnChecked)]`).
  final bool addOnValue;

  /// Called with the new value when the row is tapped; null disables the add-on.
  final ValueChanged<bool>? onAddOnChanged;

  /// The price as screen readers hear it.
  String get priceLabel => period == null || period!.isEmpty ? price : '$price $period';

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final text = context.uiText;
    final r = (radius ?? theme.config.radius) ? t.radiusLg : 0.0;
    final metal = tier;
    final hl = highlight != null && highlight!.isNotEmpty;
    final edge = hl ? (metal?.border(t) ?? t.primary) : t.border;

    final top = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          spacing: t.space2,
          children: [
            Flexible(
              child: Semantics(
                header: true,
                child: Text(name, style: text.body.copyWith(fontSize: 18 * t.fontScale, fontWeight: FontWeight.w600, height: 1.3, color: t.text)),
              ),
            ),
            if (metal != null) ExcludeSemantics(child: UiBadge(dot: true, tier: metal)),
            if (current) ...[const Spacer(), UiBadge(label: currentLabel, tone: UiStatus.primary)],
          ],
        ),
        if (tagline != null) ...[
          SizedBox(height: t.space1),
          Text(tagline!, style: text.body.copyWith(fontSize: 13 * t.fontScale, height: 1.4, color: t.textSecondary)),
        ],
        SizedBox(height: t.space4),
        Semantics(
          label: priceLabel,
          excludeSemantics: true,
          // Wraps like the web's `flex-wrap: wrap`: a long price (or a store's, with its currency) and
          // its period never push past a narrow card; the period drops under the price instead.
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: t.space1,
            children: [
              Text(price, style: text.body.copyWith(fontSize: 28 * t.fontScale, fontWeight: FontWeight.w700, height: 1.15, color: t.text, letterSpacing: t.trackingTight * 28 * t.fontScale, fontFeatures: const [FontFeature.tabularFigures()])),
              if (period != null) Text(period!, style: text.body.copyWith(fontSize: 13 * t.fontScale, height: 1.4, color: t.textSecondary)),
            ],
          ),
        ),
        if (note != null) ...[
          SizedBox(height: t.space1),
          Text(note!, style: text.body.copyWith(fontSize: 13 * t.fontScale, height: 1.4, color: t.textMuted)),
        ],
        if (features.isNotEmpty) ...[
          SizedBox(height: t.space4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: t.space2,
            children: [
              for (final f in features)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: t.space2,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: ExcludeSemantics(child: UiIcon(HugeIcons.strokeRoundedTick02, size: 16, color: t.success)),
                    ),
                    Expanded(child: Text(f, style: text.body.copyWith(fontSize: 14 * t.fontScale, height: 1.45, color: t.text))),
                  ],
                ),
            ],
          ),
        ],
        if (addOn != null) ...[
          SizedBox(height: t.space4),
          _AddOn(
            label: addOn!,
            note: addOnNote,
            value: addOnValue,
            onChanged: onAddOnChanged,
            edge: metal?.border(t) ?? t.primary,
            radius: r > 0 ? t.radius : 0,
          ),
        ],
      ],
    );

    final bottom = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (action != null) ...[SizedBox(height: t.space6), action!],
        if (fineprint != null) ...[
          SizedBox(height: t.space2),
          DefaultTextStyle.merge(
            textAlign: TextAlign.center,
            style: text.body.copyWith(fontSize: 12, height: 1.4, color: t.textMuted),
            child: fineprint!,
          ),
        ],
      ],
    );

    final inner = r > 0 ? math.max(0.0, r - 1) : 0.0;
    final card = Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: edge),
        boxShadow: t.shadow1,
      ),
      // The highlight's second pixel is drawn inside, over the padding, so content doesn't shift.
      foregroundDecoration: hl ? BoxDecoration(borderRadius: BorderRadius.circular(r), border: Border.all(color: edge, width: 2)) : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(inner),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Padding(
              padding: EdgeInsets.all(t.space6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [top, bottom],
              ),
            ),
            if (metal != null)
              Positioned(
                key: const ValueKey('ui-plan-tier-edge'),
                top: 0,
                left: 0,
                right: 0,
                height: 4,
                child: DecoratedBox(decoration: BoxDecoration(gradient: metal.gradient(t).toGradient())),
              ),
          ],
        ),
      ),
    );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: name,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.passthrough,
        children: [
          card,
          if (hl)
            Positioned(
              top: -12,
              left: 0,
              right: 0,
              child: Center(child: _Ribbon(text: highlight!, tier: metal)),
            ),
        ],
      ),
    );
  }
}

/// The add-on row: one checkbox, the whole row its tap target.
class _AddOn extends StatelessWidget {
  const _AddOn({required this.label, required this.note, required this.value, required this.onChanged, required this.edge, required this.radius});
  final String label;
  final String? note;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color edge;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final text = context.uiText;
    final enabled = onChanged != null;
    return UiInteractive(
      key: const ValueKey('ui-plan-addon'),
      onTap: enabled ? () => onChanged!(!value) : null,
      enabled: enabled,
      button: false,
      checked: value,
      semanticLabel: note == null || note!.isEmpty ? label : '$label, $note',
      excludeChildSemantics: true,
      pressScale: false,
      builder: (context, s) => AnimatedOpacity(
        opacity: enabled ? 1 : 0.5,
        duration: t.motionBase,
        child: AnimatedContainer(
          duration: context.uiAnimate ? t.motionFast : Duration.zero,
          curve: t.easeStandard,
          padding: EdgeInsets.symmetric(vertical: t.space3, horizontal: t.space4),
          decoration: BoxDecoration(
            color: enabled && s.hovered ? t.surfaceHover : t.surfaceSubtle,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: value ? edge : t.border),
            boxShadow: s.focused ? t.focusRing : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: t.space3,
            children: [
              Padding(padding: const EdgeInsets.only(top: 1), child: UiCheckMark(value: value, states: s)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(label, style: text.body.copyWith(fontSize: 14 * t.fontScale, fontWeight: FontWeight.w600, height: 1.35, color: t.text)),
                    if (note != null && note!.isNotEmpty) Text(note!, style: text.body.copyWith(fontSize: 13 * t.fontScale, height: 1.35, color: t.textMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Ribbon extends StatelessWidget {
  const _Ribbon({required this.text, required this.tier});
  final String text;
  final UiTier? tier;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final metal = tier;
    return Container(
      key: const ValueKey('ui-plan-ribbon'),
      height: 24,
      padding: EdgeInsets.symmetric(horizontal: t.space3),
      decoration: BoxDecoration(
        color: metal == null ? t.primary : null,
        gradient: metal?.gradient(t).toGradient(),
        borderRadius: BorderRadius.circular(t.radiusPill),
        border: Border.all(color: metal?.border(t) ?? t.primary),
      ),
      child: Align(
        widthFactor: 1,
        child: Text(
          text,
          maxLines: 1,
          style: context.uiText.body.copyWith(fontSize: 12, fontWeight: FontWeight.w600, height: 1.2, color: metal?.contrast(t) ?? t.primaryContrast),
        ),
      ),
    );
  }
}

/// `ui-plan-grid`: lays out [UiPlanCard]s. One column under 600px, two under 912px, at most three
/// (never more than there are cards). Cards in a row share their height, so their actions line up at
/// the bottom; a little room on top keeps highlight ribbons clear.
class UiPlanGrid extends StatelessWidget {
  const UiPlanGrid({super.key, required this.children});

  final List<Widget> children;

  /// Columns for a grid [width] wide holding [count] cards.
  static int columnsFor(double width, int count) => math.max(1, math.min(count, width < 600 ? 1 : width < 912 ? 2 : 3));

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Padding(
      padding: EdgeInsets.only(top: t.space3),
      child: LayoutBuilder(builder: (context, box) {
        final cols = columnsFor(box.maxWidth, children.length);
        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += cols) {
          final chunk = children.sublist(i, math.min(i + cols, children.length));
          rows.add(cols == 1
              ? chunk.single
              : IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: t.space6,
                    children: [
                      for (final c in chunk) Expanded(child: c),
                      for (var k = chunk.length; k < cols; k++) const Expanded(child: SizedBox.shrink()),
                    ],
                  ),
                ));
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: t.space6,
          children: rows,
        );
      }),
    );
  }
}

/// A plan column in [UiPlanCompare] (the web `{ key, name, tier }`).
@immutable
class UiPlanColumn {
  const UiPlanColumn({required this.key, required this.name, this.tier});
  final String key;
  final String name;
  final UiTier? tier;
}

/// A row in [UiPlanCompare]: [values] by plan key, each a String, a bool or null.
@immutable
class UiPlanRow {
  const UiPlanRow({required this.label, required this.values});
  final String label;
  final Map<String, Object?> values;
}

/// `ui-plan-compare`: a plain table comparing [plans] over [rows]. `true` shows a check ("Included"
/// to screen readers, [includedLabel]), `false` or null a dash ([notIncludedLabel]), strings as text.
/// Column headers carry a slim underline of the plan's tier. [highlight] (a plan key) tints that
/// column. When narrower than the table it scrolls sideways inside itself with the first column
/// pinned. [caption] names the table for screen readers.
class UiPlanCompare extends StatefulWidget {
  const UiPlanCompare({
    super.key,
    required this.plans,
    required this.rows,
    this.highlight,
    this.caption,
    this.includedLabel = 'Included',
    this.notIncludedLabel = 'Not included',
  });

  final List<UiPlanColumn> plans;
  final List<UiPlanRow> rows;
  final String? highlight;
  final String? caption;
  final String includedLabel;
  final String notIncludedLabel;

  @override
  State<UiPlanCompare> createState() => _UiPlanCompareState();
}

class _UiPlanCompareState extends State<UiPlanCompare> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final text = context.uiText;
    final dir = Directionality.of(context);
    final reversed = dir == TextDirection.ltr ? TextDirection.rtl : TextDirection.ltr;
    final rowLine = Border(bottom: BorderSide(color: t.borderSubtle));
    final tint = Color.alphaBlend(t.selected, t.surface);
    final cellPad = EdgeInsets.symmetric(vertical: t.space3, horizontal: t.space4);

    return LayoutBuilder(builder: (context, box) {
      final avail = box.maxWidth.isFinite ? box.maxWidth : 720.0;
      final labelW = avail < 600 ? 160.0 : 220.0;
      final n = math.max(1, widget.plans.length);
      final colW = math.max(120.0, (avail - labelW) / n);
      final total = labelW + colW * widget.plans.length;

      // The label cell: opaque, and moved with the scroll so it stays where it is.
      Widget pinned(Widget cell) => ListenableBuilder(
            listenable: _scroll,
            builder: (context, child) {
              final off = _scroll.hasClients ? _scroll.offset : 0.0;
              return Transform.translate(offset: Offset(dir == TextDirection.ltr ? off : -off, 0), child: child);
            },
            child: cell,
          );

      // Built in the opposite direction with the cells reversed, so the label is the last child
      // (painted over the cells it slides across) and still the first column you see.
      Widget row(Widget label, List<Widget> cells) => IntrinsicHeight(
            child: Row(
              textDirection: reversed,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final c in cells.reversed) Directionality(textDirection: dir, child: c),
                Directionality(textDirection: dir, child: pinned(label)),
              ],
            ),
          );

      Widget cell({required double width, required Widget child, Color? color, AlignmentGeometry align = Alignment.center, Key? key}) => Container(
            key: key,
            width: width,
            padding: cellPad,
            alignment: align,
            // Every cell is opaque, so the pinned column covers what slides under it and reads as one panel.
            decoration: BoxDecoration(color: color ?? t.surface, border: rowLine),
            child: child,
          );

      final header = row(
        cell(width: labelW, color: t.surface, child: const SizedBox.shrink()),
        [
          for (final p in widget.plans)
            cell(
              key: ValueKey('ui-plan-compare-head-${p.key}'),
              width: colW,
              color: p.key == widget.highlight ? tint : null,
              child: Semantics(
                header: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: t.space2,
                  children: [
                    Text(p.name, textAlign: TextAlign.center, style: text.body.copyWith(fontSize: 14 * t.fontScale, fontWeight: FontWeight.w600, height: 1.35, color: t.text)),
                    Container(
                      key: ValueKey('ui-plan-compare-bar-${p.key}'),
                      height: 3,
                      decoration: BoxDecoration(
                        color: p.tier == null ? t.border : null,
                        gradient: p.tier?.gradient(t).toGradient(),
                        borderRadius: BorderRadius.circular(t.radiusPill),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );

      Widget value(Object? v) {
        if (v is bool && v) {
          return Semantics(label: widget.includedLabel, excludeSemantics: true, child: UiIcon(HugeIcons.strokeRoundedTick02, size: 16, color: t.success));
        }
        if (v == null || v == false || (v is String && v.isEmpty)) {
          return Semantics(label: widget.notIncludedLabel, excludeSemantics: true, child: UiIcon(HugeIcons.strokeRoundedMinusSign, size: 16, color: t.textMuted));
        }
        return Text('$v', textAlign: TextAlign.center, style: text.body.copyWith(fontSize: 14 * t.fontScale, height: 1.45, color: t.text));
      }

      final body = [
        for (final r in widget.rows)
          row(
            cell(
              width: labelW,
              color: t.surface,
              align: AlignmentDirectional.centerStart,
              child: Text(r.label, style: text.body.copyWith(fontSize: 14 * t.fontScale, fontWeight: FontWeight.w500, height: 1.45, color: t.text)),
            ),
            [
              for (final p in widget.plans)
                cell(width: colW, color: p.key == widget.highlight ? tint : null, child: value(r.values[p.key])),
            ],
          ),
      ];

      Widget table = SizedBox(
        width: total,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [header, ...body]),
      );
      table = SingleChildScrollView(controller: _scroll, scrollDirection: Axis.horizontal, child: table);
      return Semantics(container: true, explicitChildNodes: true, label: widget.caption, child: table);
    });
  }
}
