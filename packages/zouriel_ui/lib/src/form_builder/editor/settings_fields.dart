import 'package:flutter/widgets.dart';

import '../../core/types.dart';
import '../../forms/text/inputs.dart';
import '../../forms/text/select.dart';
import '../../theme/theme.dart';
import '../engine/schema.dart';
import 'builder_bits.dart';

/// A change to merge into the form settings; quick typing in one box shares a [mergeKey].
typedef UiFbSettingsPatch = void Function(void Function(UiFbSettings s) edit, {String? mergeKey});

/// `ui-fb-settings-fields`: the form-wide options (where labels and errors go, when problems
/// show, buttons and steps). Used for one form in the builder, and for the defaults of new forms
/// in [UiFormGlobalSettingsEditor].
class UiFbSettingsFields extends StatelessWidget {
  const UiFbSettingsFields({super.key, required this.settings, required this.onPatch});

  final UiFbSettings settings;
  final UiFbSettingsPatch onPatch;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final s = settings;
    Widget select(String label, String value, List<(String, String)> options, void Function(UiFbSettings s, String v) set) => FbSetting(
      label: label,
      child: UiSelect(
        label: label,
        size: UiSize.sm,
        value: value,
        options: [for (final o in options) UiSelectOption(value: o.$1, label: o.$2)],
        onChanged: (v) => onPatch((st) => set(st, v)),
      ),
    );

    Widget input(String label, String? value, String placeholder, String mergeKey, void Function(UiFbSettings s, String? v) set) => FbSetting(
      label: label,
      child: UiInput(
        size: UiSize.sm,
        value: value ?? '',
        placeholder: placeholder,
        semanticLabel: label,
        onChanged: (v) => onPatch((st) => set(st, v.isEmpty ? null : v), mergeKey: mergeKey),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: t.space3,
      children: [
        FbSection(title: 'Questions', children: [
          FbPair(children: [
            select('Question text', s.labelPlacement ?? 'top', const [('top', 'Above the box'), ('inside', 'Inside the box'), ('left', 'To the left')], (st, v) => st.labelPlacement = v),
            select('Error messages', s.errorPlacement ?? 'below', const [('below', 'Below the box'), ('inside', 'Inside the box')], (st, v) => st.errorPlacement = v),
          ]),
          const FbHint('Each question can override these. “Inside the box” applies to text boxes only.'),
          select(
            'Mark questions',
            s.requiredMarker ?? 'asterisk',
            const [('asterisk', 'Required ones with *'), ('optional', 'Optional ones with “(optional)”'), ('none', 'Don’t mark')],
            (st, v) => st.requiredMarker = v,
          ),
        ]),
        FbSection(title: 'Checking answers', children: [
          select(
            'Show problems',
            s.validateOn ?? 'blur',
            const [('blur', 'When someone leaves a question'), ('submit', 'Only when they continue or submit')],
            (st, v) => st.validateOn = v,
          ),
          FbSwitch(value: s.errorSummary != false, label: 'List all problems at the top', onChanged: (v) => onPatch((st) => st.errorSummary = v ? null : false)),
          FbSetting(
            label: 'Answers to hidden questions',
            hint: 'Saved answers that were already hidden when someone opened the form are always kept.',
            child: UiSelect(
              label: 'Answers to hidden questions',
              size: UiSize.sm,
              value: s.clearHidden ?? 'onSubmit',
              options: const [UiSelectOption(value: 'onSubmit', label: 'Leave them out when saving'), UiSelectOption(value: 'never', label: 'Keep them')],
              onChanged: (v) => onPatch((st) => st.clearHidden = v),
            ),
          ),
        ]),
        FbSection(title: 'Buttons and steps', children: [
          FbSwitch(value: s.showProgress != false, label: 'Show progress on multi-page forms', onChanged: (v) => onPatch((st) => st.showProgress = v ? null : false)),
          FbPair(children: [
            input('Submit button', s.submitLabel, 'Submit', 'sl', (st, v) => st.submitLabel = v),
            input('Next button', s.nextLabel, 'Continue', 'nl', (st, v) => st.nextLabel = v),
            input('Back button', s.backLabel, 'Back', 'bl', (st, v) => st.backLabel = v),
          ]),
        ]),
      ],
    );
  }
}
