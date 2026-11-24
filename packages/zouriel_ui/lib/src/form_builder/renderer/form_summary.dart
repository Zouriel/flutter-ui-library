import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/icon.dart';
import '../../theme/theme.dart';
import '../engine/conditions.dart';
import '../engine/engine.dart';
import '../engine/format.dart';
import '../engine/js.dart';
import '../engine/localize.dart';
import '../engine/schema.dart';

/// One answered, visible row in [UiFormSummary].
class UiFormSummaryRow {
  const UiFormSummaryRow({
    required this.path,
    required this.label,
    required this.value,
    required this.marked,
  });

  final String path;
  final String label;
  final String value;
  final bool marked;
}

/// One section of rows in [UiFormSummary].
class UiFormSummarySection {
  const UiFormSummarySection({required this.title, required this.rows});

  final String title;
  final List<UiFormSummaryRow> rows;
}

/// `ui-form-summary`: compact review card of a form's answered, visible fields in definition
/// order, keeping section headings and skipping fields hidden by conditions. Reuses [UiFormEngine]
/// and [formatValue] for condition evaluation, localization, and display formatting.
class UiFormSummary extends StatelessWidget {
  const UiFormSummary({
    super.key,
    required this.definition,
    this.answers = const {},
    this.language,
    this.marked = const [],
    this.markedLabel = 'Filled in by the assistant',
    this.subtitle,
    this.showTitle = true,
    this.footer,
  });

  final UiFormDefinition definition;
  final UiJson answers;
  final String? language;
  final List<String> marked;
  final String markedLabel;
  final String? subtitle;
  final bool showTitle;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final engine = UiFormEngine(
      definition: definition,
      values: answers,
      mode: UiFormMode.view,
      locale: language,
    );
    final dir = fbLocaleDir(definition, engine.locale) == UiFbDir.rtl ? TextDirection.rtl : TextDirection.ltr;
    final title = engine.text(definition.title);
    final markedSet = marked.toSet();

    final sections = <UiFormSummarySection>[];
    var pendingTop = <UiFormSummaryRow>[];

    void flush(String heading, List<UiFormSummaryRow> rows) {
      if (rows.isNotEmpty) sections.add(UiFormSummarySection(title: heading, rows: List.of(rows)));
    }
    void flushTop() {
      if (pendingTop.isNotEmpty) {
        sections.add(UiFormSummarySection(title: '', rows: pendingTop));
        pendingTop = <UiFormSummaryRow>[];
      }
    }

    void collect(List<UiFbElement> elements, String? row, List<UiFormSummaryRow>? bucket) {
      for (final el in elements) {
        if (el is UiFbStatic) continue;
        if (el is UiFbGroup) {
          if (bucket == null) flushTop();
          if (el.repeat != null) {
            for (final rowId in engine.rows(el.id)) {
              if (!engine.instanceState(el.id, rowId).visible) continue;
              final sub = <UiFormSummaryRow>[];
              collect(el.elements, rowId, sub);
              flush(engine.text(el.title), sub);
            }
          } else {
            if (!engine.instanceState(el.id, row).visible) continue;
            final sub = <UiFormSummaryRow>[];
            collect(el.elements, row, sub);
            flush(engine.text(el.title), sub);
          }
          continue;
        }
        if (el is! UiFbField || el.type == UiFbFieldType.hidden) continue;
        final st = engine.instanceState(el.id, row);
        if (!st.visible) continue;
        if (isEmptyValue(st.value)) continue;
        final display = formatValue(
          el,
          st.value,
          textLocale: engine.locale,
          defaultLocale: engine.defaultLocale,
          strings: engine.strings,
        );
        if (display.isEmpty) continue;
        final path = engine.valuePath(el.id, row);
        final isMarked = markedSet.contains(path) || (el.key.isNotEmpty && markedSet.contains(el.key));
        final lbl = engine.text(el.label);
        (bucket ?? pendingTop).add(UiFormSummaryRow(
          path: path,
          label: lbl.isNotEmpty ? lbl : (el.key.isNotEmpty ? el.key : el.id),
          value: display,
          marked: isMarked,
        ));
      }
    }

    for (final pageIdx in engine.path) {
      if (pageIdx < 0 || pageIdx >= definition.pages.length) continue;
      collect(definition.pages[pageIdx].elements, null, null);
    }
    flushTop();

    final hasMarked = sections.any((s) => s.rows.any((r) => r.marked));

    return Directionality(
      textDirection: dir,
      child: Semantics(
        container: true,
        label: title.isNotEmpty ? title : null,
        child: Container(
          decoration: BoxDecoration(
            color: t.surfaceRaised,
            border: Border.all(color: t.border),
            borderRadius: BorderRadius.circular(t.radiusLg),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showTitle && (title.isNotEmpty || (subtitle != null && subtitle!.isNotEmpty)))
                Container(
                  padding: EdgeInsets.fromLTRB(t.space3, t.space3, t.space3, 10),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.borderSubtle))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title.isNotEmpty)
                        Semantics(
                          header: true,
                          child: Text(title, style: context.uiText.label.copyWith(fontSize: t.fontSizeMd)),
                        ),
                      if (subtitle != null && subtitle!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            subtitle!,
                            style: context.uiText.body.copyWith(fontSize: t.fontSizeSm, color: t.textMuted),
                          ),
                        ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final sec in sections) ...[
                      if (sec.title.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: t.space2, bottom: 2),
                          child: Text(
                            sec.title.toUpperCase(),
                            style: context.uiText.label.copyWith(
                              fontSize: 11.5,
                              letterSpacing: 0.5,
                              color: t.textMuted,
                            ),
                          ),
                        ),
                      for (var i = 0; i < sec.rows.length; i++)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: i < sec.rows.length - 1
                              ? BoxDecoration(border: Border(bottom: BorderSide(color: t.borderSubtle)))
                              : null,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 10,
                            children: [
                              SizedBox(
                                width: 112,
                                child: Text(
                                  sec.rows[i].label,
                                  style: context.uiText.body.copyWith(
                                    fontSize: t.fontSizeSm,
                                    color: t.textSecondary,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  spacing: 6,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        sec.rows[i].value,
                                        style: context.uiText.body.copyWith(fontSize: t.fontSizeSm, color: t.text),
                                      ),
                                    ),
                                    if (sec.rows[i].marked) _marker(t),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              if (hasMarked)
                Container(
                  color: t.surfaceSubtle,
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: t.space2),
                  child: Row(
                    spacing: 6,
                    children: [
                      _marker(t),
                      Expanded(
                        child: Text(
                          markedLabel,
                          style: context.uiText.body.copyWith(fontSize: 12, color: t.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              if (footer != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(14, 10, 14, t.space3),
                  child: footer!,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _marker(UiTokens t) => Container(
        width: 18,
        height: 18,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: t.accent.withValues(alpha: 0.28),
          shape: BoxShape.circle,
        ),
        child: UiIcon(HugeIcons.strokeRoundedSparkles, size: 11, color: t.text),
      );
}
