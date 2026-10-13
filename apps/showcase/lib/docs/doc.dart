import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

/// One row of an API table: a constructor parameter, callback or method.
class ApiRow {
  const ApiRow(this.name, this.type, this.desc, {this.def});
  final String name;
  final String type;
  final String? def;
  final String desc;
}

/// A docs page: eyebrow, title, lead, then sections. Scrolls, and keeps a readable width on tablets.
class DocPage extends StatelessWidget {
  const DocPage({super.key, required this.eyebrow, required this.title, required this.lead, required this.children});

  final String eyebrow;
  final String title;
  final String lead;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return ListView(
      padding: EdgeInsets.fromLTRB(t.space4, t.space6, t.space4, t.space12),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionLabel(eyebrow),
                SizedBox(height: t.space2),
                UiText(title, variant: UiTextVariant.h1),
                SizedBox(height: t.space2),
                UiText(lead, color: t.textMuted),
                SizedBox(height: t.space4),
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) Container(height: 1, color: t.border),
                  children[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The web showcase's "[ SECTION ]" eyebrow.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final style = context.uiText.code.copyWith(fontSize: 11, letterSpacing: 11 * 0.4, color: t.textMuted);
    return Row(spacing: t.space2, children: [
      Text('[ ${text.toUpperCase()} ]', style: style),
      Container(width: 40, height: 1, color: t.sectionLabelBracket),
    ]);
  }
}

/// A documented component: heading, class name, summary, live demo, code, API.
class DocSection extends StatelessWidget {
  const DocSection({
    super.key,
    required this.name,
    this.widget,
    required this.summary,
    this.demo,
    this.code,
    this.api = const [],
    this.callbacks = const [],
    this.shapes,
  });

  final String name;

  /// The Dart class, shown under the heading (the web shows the selector).
  final String? widget;
  final String summary;
  final Widget? demo;
  final String? code;
  final List<ApiRow> api;
  final List<ApiRow> callbacks;
  final String? shapes;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: t.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: t.space2,
        children: [
          // Second-level headings drawn at the h3 size, like the web docs.
          Semantics(header: true, headingLevel: 2, child: UiText(name, variant: UiTextVariant.h3, heading: false)),
          if (widget != null) Align(alignment: Alignment.centerLeft, child: _Tag(widget!)),
          UiText(summary, color: t.textMuted),
          if (demo != null) ...[SizedBox(height: t.space2), DocDemo(child: demo!)],
          if (code != null) DocCode(code: code!),
          if (api.isNotEmpty) ApiTable(title: 'Parameters', rows: api),
          if (callbacks.isNotEmpty) ApiTable(title: 'Callbacks & methods', rows: callbacks),
          if (shapes != null) ...[
            Padding(padding: EdgeInsets.only(top: t.space3), child: UiText('Types', variant: UiTextVariant.label, color: t.textMuted)),
            DocCode(code: shapes!),
          ],
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: t.surfaceRaised, border: Border.all(color: t.border), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: context.uiText.code.copyWith(fontSize: t.fontSizeSm, color: t.primary)),
    );
  }
}

/// The bordered box a live demo sits in.
class DocDemo extends StatelessWidget {
  const DocDemo({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Container(
      padding: EdgeInsets.all(t.space4),
      decoration: BoxDecoration(
        color: t.surfaceSubtle,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusSm)),
      ),
      child: child,
    );
  }
}

/// A code sample with a Copy button. Scrolls sideways instead of wrapping.
class DocCode extends StatefulWidget {
  const DocCode({super.key, required this.code, this.language = 'DART'});
  final String code;
  final String language;

  @override
  State<DocCode> createState() => _DocCodeState();
}

class _DocCodeState extends State<DocCode> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Container(
      decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radiusSm)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: EdgeInsets.only(left: t.space3),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.border))),
          child: Row(children: [
            Expanded(child: UiText(widget.language, variant: UiTextVariant.caption)),
            UiButton(
              label: _copied ? 'Copied' : 'Copy',
              variant: UiButtonVariant.ghost,
              size: UiSize.sm,
              icon: UiIcon(_copied ? HugeIcons.strokeRoundedTick02 : HugeIcons.strokeRoundedCopy01),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: widget.code));
                if (mounted) setState(() => _copied = true);
              },
            ),
          ]),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.all(t.space3),
          child: Text(widget.code, style: context.uiText.code.copyWith(fontSize: 12.5, height: 1.5)),
        ),
      ]),
    );
  }
}

/// A compact API table that stacks on phones: each row shows name and type, then the description.
class ApiTable extends StatelessWidget {
  const ApiTable({super.key, required this.title, required this.rows});
  final String title;
  final List<ApiRow> rows;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Padding(
      padding: EdgeInsets.only(top: t.space3),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        UiText(title, variant: UiTextVariant.label, color: t.textMuted),
        SizedBox(height: t.space1),
        Container(
          decoration: BoxDecoration(border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radiusSm)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < rows.length; i++)
              Container(
                padding: EdgeInsets.all(t.space3),
                decoration: BoxDecoration(border: i == 0 ? null : Border(top: BorderSide(color: t.border))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 2, children: [
                  Wrap(spacing: t.space2, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Text(rows[i].name, style: context.uiText.code.copyWith(fontSize: 13, color: t.text, fontWeight: FontWeight.w700)),
                    Text(rows[i].type, style: context.uiText.code.copyWith(fontSize: 12, color: t.primary)),
                    if (rows[i].def != null) Text('= ${rows[i].def}', style: context.uiText.code.copyWith(fontSize: 12, color: t.textMuted)),
                  ]),
                  UiText(rows[i].desc, variant: UiTextVariant.caption),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}
