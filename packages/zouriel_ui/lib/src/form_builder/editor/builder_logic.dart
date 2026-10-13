import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/icon.dart';
import '../../core/interactive.dart';
import '../../core/types.dart';
import '../../forms/text/inputs.dart';
import '../../theme/theme.dart';
import '../engine/definition.dart';
import '../engine/schema.dart';
import 'builder_bits.dart';
import 'builder_store.dart';

typedef _Line = ({String kind, String text});

/// `ui-fb-logic`: every rule in the form, in plain words, grouped by the question or page it
/// belongs to; plus anything that needs fixing. Tapping one goes to it ([onOpen]).
class UiFbLogicOverview extends StatefulWidget {
  const UiFbLogicOverview({super.key, this.onOpen});

  /// Someone picked a question or page to go and edit.
  final ValueChanged<String>? onOpen;

  @override
  State<UiFbLogicOverview> createState() => _UiFbLogicOverviewState();
}

class _UiFbLogicOverviewState extends State<UiFbLogicOverview> {
  String _query = '';

  List<_Line> _linesFor(UiFormBuilderController s, UiFbElement el) {
    final lines = <_Line>[];
    final vis = el.visibility;
    if (vis != null) lines.add((kind: vis.action == 'show' ? 'Shown' : 'Hidden', text: '${vis.action == 'show' ? 'Only when' : 'When'} ${s.describe(vis.when)}'));
    if (el is UiFbStatic) return lines;
    final d = el is UiFbField ? el.disabled : (el as UiFbGroup).disabled;
    if (d?.flag == true) {
      lines.add((kind: 'Read-only', text: 'Always'));
    } else if (d != null && d.isConditional) {
      lines.add((kind: 'Read-only', text: 'When ${s.describe(d.when)}'));
    }
    if (el is! UiFbField) return lines;
    final r = el.required;
    if (r != null && r.isConditional) lines.add((kind: 'Required', text: 'When ${s.describe(r.when)}'));
    if (el.type == UiFbFieldType.calculated) lines.add((kind: 'Calculated', text: s.describeCalcOf(el)));
    for (final sv in el.setValue ?? const <UiFbSetValue>[]) {
      final v = switch (sv.value) {
        UiFbConstOperand(:final value) => jsonEncode(value),
        UiFbRefOperand(:final ref) => 'the answer to “${s.name(ref)}”',
        _ => 'a date',
      };
      lines.add((kind: 'Fills in', text: '$v when ${s.describe(sv.when)}'));
    }
    for (final v in el.validators ?? const <UiFbValidatorRule>[]) {
      if (v.when == null) continue;
      final def = s.validatorDefs.where((x) => x.type == v.type).firstOrNull;
      lines.add((kind: 'Check', text: '${def?.label ?? v.type}, only when ${s.describe(v.when)}'));
    }
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final s = UiFbBuilderScope.of(context);
    final def = s.def;
    String pageName(UiFbPage p) => (p.title ?? '').isNotEmpty ? p.title! : 'Page ${def.pages.indexOf(p) + 1}';

    final entries = <({String id, String name, String where, List<_Line> lines})>[];
    for (final p in def.pages) {
      final lines = <_Line>[];
      final vis = p.visibility;
      if (vis != null) lines.add((kind: vis.action == 'show' ? 'Shown' : 'Skipped', text: '${vis.action == 'show' ? 'Only when' : 'When'} ${s.describe(vis.when)}'));
      for (final j in p.jumps ?? const <UiFbJump>[]) {
        lines.add((kind: 'Jump', text: 'Go to ${j.to == 'end' ? 'the end' : '“${s.name(j.to)}”'} when ${s.describe(j.when)}'));
      }
      if (lines.isNotEmpty) entries.add((id: p.id, name: pageName(p), where: 'Page', lines: lines));
    }
    for (final el in allElements(def)) {
      final lines = _linesFor(s, el);
      if (lines.isEmpty) continue;
      final entry = s.index[el.id];
      entries.add((id: el.id, name: s.name(el.id), where: entry != null ? pageName(entry.page) : '', lines: lines));
    }
    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty ? entries : [for (final e in entries) if (e.name.toLowerCase().contains(q) || e.lines.any((l) => l.text.toLowerCase().contains(q))) e];
    final problems = s.problems;

    Widget heading(String text) => Semantics(header: true, child: Text(text, style: context.uiText.label.copyWith(fontSize: 15, color: t.text)));

    return ColoredBox(
      color: t.bg,
      child: ListView(
        padding: EdgeInsets.fromLTRB(t.space3, t.space4, t.space3, t.space12),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space6, children: [
                if (problems.isNotEmpty)
                  Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 4, children: [
                    heading('Needs attention'),
                    SizedBox(height: t.space1),
                    for (final p in problems) _Problem(problem: p, onTap: () => widget.onOpen?.call(p.targetId)),
                  ]),
                Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 4, children: [
                  Wrap(spacing: t.space3, runSpacing: t.space2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    heading('Rules'),
                    Text(
                      '${entries.length} question${entries.length == 1 ? '' : 's'} and pages with rules',
                      style: context.uiText.body.copyWith(fontSize: 12, color: t.textMuted),
                    ),
                  ]),
                  SizedBox(height: t.space1),
                  UiInput(size: UiSize.sm, value: _query, placeholder: 'Find a question…', semanticLabel: 'Find a question', onChanged: (v) => setState(() => _query = v)),
                  SizedBox(height: t.space1),
                  if (shown.isEmpty)
                    Container(
                      padding: EdgeInsets.symmetric(vertical: t.space6, horizontal: t.space4),
                      decoration: BoxDecoration(border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radius)),
                      child: Text(
                        q.isNotEmpty
                            ? 'Nothing matches “$_query”.'
                            : 'No rules yet. Select a question and open its Logic tab to show it only sometimes, make it required under a condition, or fill it in automatically.',
                        textAlign: TextAlign.center,
                        style: context.uiText.body.copyWith(fontSize: 13, height: 1.5, color: t.textMuted),
                      ),
                    ),
                  for (final e in shown)
                    UiInteractive(
                      onTap: () => widget.onOpen?.call(e.id),
                      semanticLabel: '${e.name}, ${e.where}. ${[for (final l in e.lines) '${l.kind}: ${l.text}'].join('. ')}',
                      excludeChildSemantics: true,
                      pressScale: false,
                      builder: (context, st) => Container(
                        padding: EdgeInsets.symmetric(horizontal: t.space3, vertical: t.space2),
                        decoration: BoxDecoration(
                          color: t.surface,
                          border: Border.all(color: st.hovered ? t.borderStrong : t.borderSubtle),
                          borderRadius: BorderRadius.circular(t.radius),
                          boxShadow: st.focused ? t.focusRing : null,
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 6, children: [
                          Text.rich(
                            TextSpan(text: e.name, children: [TextSpan(text: '  ${e.where}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: t.textMuted))]),
                            style: context.uiText.label.copyWith(fontSize: 13, color: t.text),
                          ),
                          for (final l in e.lines)
                            Row(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space2, children: [
                              Padding(padding: const EdgeInsets.only(top: 1), child: FbChip(l.kind, tone: FbTone.logic)),
                              Expanded(child: Text(l.text, style: context.uiText.body.copyWith(fontSize: 13, height: 1.45, color: t.textSecondary))),
                            ]),
                        ]),
                      ),
                    ),
                ]),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _Problem extends StatelessWidget {
  const _Problem({required this.problem, required this.onTap});
  final UiFbProblem problem;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final err = problem.severity == 'error';
    final c = err ? t.danger : t.warning;
    return UiInteractive(
      onTap: onTap,
      semanticLabel: '${err ? 'Error' : 'Warning'}: ${problem.message}',
      excludeChildSemantics: true,
      pressScale: false,
      builder: (context, s) => Container(
        padding: EdgeInsets.all(t.space2),
        decoration: BoxDecoration(
          color: Color.alphaBlend(c.withValues(alpha: s.hovered ? 0.14 : 0.08), t.surface),
          border: Border.all(color: c.withValues(alpha: err ? 0.4 : 0.35)),
          borderRadius: BorderRadius.circular(t.radius),
          boxShadow: s.focused ? t.focusRing : null,
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space2, children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: UiIcon(err ? HugeIcons.strokeRoundedCancelCircle : HugeIcons.strokeRoundedAlert02, size: 15, color: c),
          ),
          Expanded(child: Text(problem.message, style: context.uiText.body.copyWith(fontSize: 13, color: t.text))),
        ]),
      ),
    );
  }
}
