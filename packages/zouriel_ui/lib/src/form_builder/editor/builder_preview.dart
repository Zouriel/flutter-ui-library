import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../button/button.dart';
import '../../button/segmented.dart';
import '../../core/icon.dart';
import '../../core/types.dart';
import '../../forms/text/inputs.dart';
import '../../theme/theme.dart';
import '../engine/engine.dart' show UiFormMode;
import '../engine/js.dart';
import '../engine/schema.dart';
import '../engine/validators.dart';
import '../renderer/form_renderer.dart';
import 'builder_bits.dart';
import 'builder_store.dart';

const _pretty = JsonEncoder.withIndent('  ');

/// `ui-fb-preview`: fill the form in as people will, with the saved JSON underneath (beside it on
/// a wide screen). Switch to edit or view mode and paste saved answers to see how the form opens
/// them.
class UiFbPreview extends StatefulWidget {
  const UiFbPreview({super.key});

  @override
  State<UiFbPreview> createState() => _UiFbPreviewState();
}

class _UiFbPreviewState extends State<UiFbPreview> {
  UiFormMode _mode = UiFormMode.create;
  bool _showData = true;
  int _run = 0;
  UiJson _live = const {};
  UiFormSubmission? _last;
  String _dataText = '{}';

  ({UiJson? ok, String? error}) get _parsed {
    try {
      final v = jsonDecode(_dataText.trim().isEmpty ? '{}' : _dataText);
      return v is Map ? (ok: v.cast<String, Object?>(), error: null) : (ok: null, error: 'Saved answers must be a JSON object, like { "name": "Ada" }.');
    } on FormatException {
      return (ok: null, error: 'That isn’t valid JSON yet.');
    }
  }

  void _setMode(UiFormMode m) {
    // Moving to edit/view starts from what was just filled in, which is the natural thing to test.
    if (m != UiFormMode.create && _mode == UiFormMode.create) _dataText = _pretty.convert(_last?.data ?? _live);
    setState(() {
      _mode = m;
      _restart();
    });
  }

  void _restart() {
    _last = null;
    _run++;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final store = UiFbBuilderScope.of(context);
    final parsed = _parsed;
    final builtIn = {for (final v in uiFbBuiltinValidators) v.type};
    final renderer = UiFormRenderer(
      key: ValueKey(_run),
      definition: store.def,
      data: _mode == UiFormMode.create ? null : (parsed.ok ?? const {}),
      mode: _mode,
      validators: [for (final v in store.validatorDefs) if (!builtIn.contains(v.type)) v],
      optionSources: store.optionSourceDefs,
      onValueChanged: (d) => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !jsonEquals(d, _live)) setState(() => _live = d);
      }),
      onSubmitted: (s) => setState(() {
        _last = s;
        _showData = true;
      }),
    );

    final data = Container(
      padding: EdgeInsets.all(t.space3),
      decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.borderSubtle), borderRadius: BorderRadius.circular(t.radius)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
        if (_last != null)
          Text('Submitted. This is what would be saved:', style: context.uiText.body.copyWith(fontSize: 13, color: t.success))
        else
          const FbHint('Answers so far, as they would be saved:'),
        Text(_pretty.convert(_last?.toJson() ?? _live), style: context.uiText.code.copyWith(fontSize: 12, height: 1.5, color: t.textSecondary)),
      ]),
    );

    return ColoredBox(
      color: t.bg,
      child: LayoutBuilder(builder: (context, box) {
        final split = _showData && box.maxWidth >= 900;
        final form = Container(
          padding: EdgeInsets.all(t.space4),
          decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.borderSubtle), borderRadius: BorderRadius.circular(t.radius)),
          child: renderer,
        );
        return ListView(
          padding: EdgeInsets.fromLTRB(t.space3, t.space3, t.space3, t.space12),
          children: [
            Wrap(spacing: t.space3, runSpacing: t.space2, crossAxisAlignment: WrapCrossAlignment.center, children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: UiSegmented<UiFormMode>(
                  label: 'Try it as',
                  size: UiSize.sm,
                  value: _mode,
                  options: const [
                    UiSegmentedOption(value: UiFormMode.create, label: 'New answers'),
                    UiSegmentedOption(value: UiFormMode.edit, label: 'Edit saved'),
                    UiSegmentedOption(value: UiFormMode.view, label: 'View saved'),
                  ],
                  onChanged: _setMode,
                ),
              ),
              UiButton(
                label: 'Start again',
                size: UiSize.sm,
                variant: UiButtonVariant.ghost,
                icon: const UiIcon(HugeIcons.strokeRoundedRefresh),
                onPressed: () => setState(_restart),
              ),
              FbSwitch(value: _showData, label: 'Show saved data', onChanged: (v) => setState(() => _showData = v)),
            ]),
            if (_mode != UiFormMode.create) ...[
              SizedBox(height: t.space3),
              FbSetting(
                label: 'Saved answers (JSON)',
                hint: parsed.error ?? 'Answers saved earlier, to see how the form opens them.',
                badHint: parsed.error != null,
                child: UiTextarea(value: _dataText, rows: 3, autosize: true, maxRows: 10, semanticLabel: 'Saved answers (JSON)', onChanged: (v) => setState(() => _dataText = v)),
              ),
            ],
            SizedBox(height: t.space3),
            if (split)
              Row(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space3, children: [
                Expanded(flex: 2, child: form),
                Expanded(child: data),
              ])
            else ...[
              Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: form)),
              if (_showData) ...[SizedBox(height: t.space3), data],
            ],
          ],
        );
      }),
    );
  }
}
