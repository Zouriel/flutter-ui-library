import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../docs/doc.dart';

/// The text-entry and picker sections of the Form controls page: form field and validation,
/// text inputs, number, password, search, time, select, combobox, multi-select, OTP, editable
/// text, and the date controls.
class FormsTextSections extends StatefulWidget {
  const FormsTextSections({super.key});

  @override
  State<FormsTextSections> createState() => _FormsTextSectionsState();
}

const _fonts = [
  UiSelectOption(label: 'Roboto', value: 'Roboto'),
  UiSelectOption(label: 'Space Grotesk', value: 'Space Grotesk'),
  UiSelectOption(label: 'Bricolage Grotesque', value: 'Bricolage Grotesque'),
  UiSelectOption(label: 'JetBrains Mono', value: 'JetBrains Mono'),
];

const _comboFonts = [
  UiComboboxOption(label: 'Roboto', value: 'Roboto'),
  UiComboboxOption(label: 'Space Grotesk', value: 'Space Grotesk'),
  UiComboboxOption(label: 'Bricolage Grotesque', value: 'Bricolage Grotesque'),
  UiComboboxOption(label: 'JetBrains Mono', value: 'JetBrains Mono'),
];

const _countries = [
  UiComboboxOption(label: 'Maldives', value: 'mv'),
  UiComboboxOption(label: 'Malaysia', value: 'my'),
  UiComboboxOption(label: 'Mali', value: 'ml'),
  UiComboboxOption(label: 'Malta', value: 'mt'),
  UiComboboxOption(label: 'New Zealand', value: 'nz'),
  UiComboboxOption(label: 'Norway', value: 'no'),
  UiComboboxOption(label: 'Portugal', value: 'pt'),
  UiComboboxOption(label: 'Sri Lanka', value: 'lk'),
];

const _teams = [
  UiComboboxOption(label: 'Design', value: 'design'),
  UiComboboxOption(label: 'Engineering', value: 'eng'),
  UiComboboxOption(label: 'Marketing', value: 'mkt'),
  UiComboboxOption(label: 'Sales', value: 'sales'),
  UiComboboxOption(label: 'Support', value: 'support'),
];

class _FormsTextSectionsState extends State<FormsTextSections> {
  final _form = GlobalKey<FormState>();
  String _submitted = '';

  String _name = 'Ada Lovelace';
  String _bio = '';
  String _message = '';
  int _sent = 0;
  num? _qty = 2;
  num? _width = 240;
  String _password = '';
  String _search = '';
  String? _time = '09:30';
  String? _fruit;
  String _font = 'Space Grotesk';
  String? _country = 'mv';
  String? _comboFont = 'Bricolage Grotesque';
  List<String> _picked = const ['design', 'eng'];
  String _otp = '';
  String _title = 'Quarterly roadmap';
  String? _date;
  String? _day = '2026-10-21';
  UiDateRange _range = const UiDateRange(start: '2026-10-08', end: '2026-10-15');

  Widget _divider(BuildContext context) => Container(height: 1, color: context.ui.border);

  Widget _caption(String text) => UiText(text, variant: UiTextVariant.caption);

  static const _sizeRow = ApiRow('size', 'UiSize', 'sm (26), md (30), lg (38) visual height; 48dp touch area on phones.', def: 'md');
  static const _invalidRow = ApiRow('invalid', 'bool', 'Error styling (red border). Also set by an enclosing UiFormField error.', def: 'false');
  static const _radiusRow = ApiRow('radius', 'bool?', 'Rounded corners; defaults to UiConfig.radius.');
  static const _enabledRow = ApiRow('enabled', 'bool', 'False greys it out and ignores input.', def: 'true');

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final sections = <Widget>[
      DocSection(
        name: 'Form field & validation',
        widget: 'UiFormField',
        summary:
            'Label, hint and error around one control. The label becomes the control\'s accessible name (it is announced once, as the control\'s name) and tapping it focuses the control. When error is set it replaces the hint, turns the control\'s border red and is announced as a live region. required draws the * marker and marks the control required for assistive tech. UiFormField.validated wraps Flutter\'s FormField: bind the control to field.value / field.didChange, and Form.validate() runs required and your validator and shows the message here.',
        demo: Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
            UiFormField<String>.validated(
              label: 'Email',
              hint: 'We never share it.',
              required: true,
              validator: (v) => v!.contains('@') ? null : 'Enter an email address',
              builder: (field) => UiInput(
                type: UiInputType.email,
                placeholder: 'you@example.com',
                autofillHints: const [AutofillHints.email],
                value: field.value,
                onChanged: field.didChange,
              ),
            ),
            UiFormField<String>.validated(
              label: 'Verification code',
              hint: 'Six digits from the SMS.',
              validator: UiOtpInput.validator(length: 6),
              builder: (field) => Align(alignment: Alignment.centerLeft, child: UiOtpInput(value: field.value, onChanged: field.didChange)),
            ),
            Row(spacing: t.space2, children: [
              UiButton(
                label: 'Submit',
                onPressed: () => setState(() => _submitted = _form.currentState!.validate() ? 'Valid: submitted' : 'Fix the errors above'),
              ),
              UiButton(
                label: 'Reset',
                variant: UiButtonVariant.ghost,
                onPressed: () {
                  _form.currentState!.reset();
                  setState(() => _submitted = '');
                },
              ),
            ]),
            if (_submitted.isNotEmpty) _caption(_submitted),
          ]),
        ),
        code: '''final form = GlobalKey<FormState>();

Form(
  key: form,
  child: UiFormField<String>.validated(
    label: 'Email',
    hint: 'We never share it.',
    required: true,
    validator: (v) => v!.contains('@') ? null : 'Enter an email address',
    builder: (field) => UiInput(value: field.value, onChanged: field.didChange),
  ),
)

// Plain wrapper with your own error:
UiFormField(label: 'Name', error: nameError, child: UiInput(value: name, onChanged: setName))''',
        api: const [
          ApiRow('label', 'String?', 'Field label; names the control.'),
          ApiRow('hint', 'String?', 'Helper text, hidden while there is an error.'),
          ApiRow('error', 'String?', 'Error message (live region). With .validated the validator\'s message wins.'),
          ApiRow('required', 'bool', 'Shows *, marks the control required; with .validated an empty value fails.', def: 'false'),
          ApiRow('child', 'Widget', 'The control (plain constructor).'),
          ApiRow('builder', 'FormFieldBuilder<T>', 'Builds the control from the FormFieldState (.validated).'),
          ApiRow('validator', 'FormFieldValidator<T>?', 'Runs after the required check (.validated).'),
          ApiRow('initialValue / onSaved / autovalidateMode', 'FormField', 'Passed to the FormField (.validated).'),
          ApiRow('requiredMessage', 'String?', 'Message for an empty required field.', def: "'<label> is required'"),
          ApiRow('isEmpty', 'bool Function(T?)?', 'Custom emptiness for required (default: null, blank text, empty list).'),
        ],
      ),
      DocSection(
        name: 'Input',
        widget: 'UiInput',
        summary:
            'Single-line text field built on EditableText. Value type: String. Controlled with value + onChanged, or give it a controller. type picks the keyboard (email, url, tel) and password hides the text; autofillHints is the web autocomplete. Long-press selects text and shows a themed Cut / Copy / Paste menu.',
        demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
          UiFormField(label: 'Name', child: UiInput(value: _name, autofillHints: const [AutofillHints.name], onChanged: (v) => setState(() => _name = v))),
          Row(spacing: t.space2, children: const [
            Expanded(child: UiInput(size: UiSize.sm, placeholder: 'Small', semanticLabel: 'Small')),
            Expanded(child: UiInput(size: UiSize.lg, placeholder: 'Large', semanticLabel: 'Large')),
          ]),
          const UiInput(value: 'Read only', readOnly: true, semanticLabel: 'Read only'),
          const UiInput(value: 'Disabled', enabled: false, semanticLabel: 'Disabled'),
          _caption('Value: $_name'),
        ]),
        code: "UiFormField(\n  label: 'Name',\n  child: UiInput(value: name, onChanged: (v) => setState(() => name = v)),\n)",
        api: const [
          ApiRow('value / onChanged', 'String? / ValueChanged<String>', 'Controlled text.'),
          ApiRow('controller / focusNode', 'TextEditingController? / FocusNode?', 'Your own controller or focus node.'),
          ApiRow('type', 'UiInputType', 'text, email, url, tel, password, search.', def: 'text'),
          ApiRow('placeholder', 'String', 'Shown while empty; read as the hint.', def: "''"),
          ApiRow('keyboardType', 'TextInputType?', 'The web inputmode: overrides the type\'s keyboard.'),
          ApiRow('autofillHints', 'Iterable<String>?', 'The web autocomplete, e.g. [AutofillHints.email].'),
          ApiRow('onSubmitted', 'ValueChanged<String>?', 'Enter / the keyboard action key.'),
          ApiRow('semanticLabel', 'String?', 'Accessible name when no UiFormField label names it.'),
          _sizeRow, _invalidRow, _radiusRow, _enabledRow,
        ],
        shapes: 'enum UiInputType { text, email, url, tel, password, search }',
      ),
      DocSection(
        name: 'Textarea',
        widget: 'UiTextarea',
        summary: 'Multi-line text field. Value type: String. Shows rows lines; with autosize it grows with the text from rows up to maxRows lines, then scrolls.',
        demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
          UiFormField(
            label: 'Bio',
            hint: 'Grows from 2 to 6 lines.',
            child: UiTextarea(value: _bio, rows: 2, autosize: true, maxRows: 6, placeholder: 'Tell us about yourself', onChanged: (v) => setState(() => _bio = v)),
          ),
          _caption('${_bio.length} characters'),
        ]),
        code: 'UiTextarea(value: bio, rows: 2, autosize: true, maxRows: 6, onChanged: setBio)',
        api: const [
          ApiRow('value / onChanged', 'String? / ValueChanged<String>', 'Controlled text.'),
          ApiRow('rows', 'int', 'Visible lines (the starting height with autosize). On phones even one row lays out at least 48dp tall, the box centred, at any text size or textStyle.', def: '4'),
          ApiRow('autosize', 'bool', 'Grow with the text.', def: 'false'),
          ApiRow('maxRows', 'int', 'With autosize: most lines before it scrolls.', def: '8'),
          ApiRow('maxLength', 'int?', 'The most characters it takes (the web maxlength): typing and pasting stop there.', def: 'null'),
          ApiRow('placeholder', 'String', 'Shown while empty.', def: "''"),
          ApiRow('dir', 'UiTextDir?', 'Writing direction: ltr, rtl, or auto (follows the first strong character typed). See Field slots.', def: 'null'),
          ApiRow('textStyle', 'TextStyle?', 'Merged over the field font, e.g. an app font for Thaana with fontFamilyFallback.', def: 'null'),
          _invalidRow, _radiusRow, _enabledRow,
        ],
      ),
      DocSection(
        name: 'Field slots',
        widget: 'UiTextarea / UiInput leading, trailing',
        summary:
            'Content inside the border of a textarea or input: an icon, or a small UiIconButton to attach or send. leading sits at the inline start and trailing at the inline end, so they swap sides in RTL; on the textarea both are aligned to the last line and stay at the bottom while autosize grows. The text keeps clear of them, the focus ring and the invalid border go round the whole field, a tap on a slot\'s empty space focuses the field (buttons in it take their own taps), and an icon button keeps its 48dp touch target on phones without making the box taller. dir auto follows what is typed, so a Thaana message turns the field right to left; textStyle lets an app type in its own font.',
        demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
          UiTextarea(
            value: _message,
            rows: 1,
            autosize: true,
            maxRows: 5,
            dir: UiTextDir.auto,
            placeholder: 'Message… (try ދިވެހި)',
            semanticLabel: 'Message',
            onChanged: (v) => setState(() => _message = v),
            leading: UiIconButton(label: 'Attach a file', size: UiSize.sm, onPressed: () {}, icon: const UiIcon(HugeIcons.strokeRoundedAttachment01)),
            trailing: UiIconButton(
              label: 'Send',
              size: UiSize.sm,
              variant: UiButtonVariant.primary,
              onPressed: _message.trim().isEmpty ? null : () => setState(() {
                _sent++;
                _message = '';
              }),
              icon: const UiIcon(HugeIcons.strokeRoundedSent),
            ),
          ),
          Directionality(
            textDirection: TextDirection.rtl,
            child: UiTextarea(
              rows: 1,
              autosize: true,
              placeholder: 'ސިޓީ ލިޔުއްވާ…',
              semanticLabel: 'Message, right to left',
              leading: UiIconButton(label: 'Attach a file', size: UiSize.sm, onPressed: () {}, icon: const UiIcon(HugeIcons.strokeRoundedAttachment01)),
              trailing: UiIconButton(label: 'Send', size: UiSize.sm, variant: UiButtonVariant.primary, onPressed: () {}, icon: const UiIcon(HugeIcons.strokeRoundedSent)),
            ),
          ),
          const UiInput(type: UiInputType.email, placeholder: 'you@example.com', semanticLabel: 'Email', leading: UiIcon(HugeIcons.strokeRoundedMail01)),
          _caption('$_sent sent'),
        ]),
        code: '''UiTextarea(
  value: message,
  rows: 1,
  autosize: true,
  dir: UiTextDir.auto,                       // Thaana typed: right to left
  textStyle: TextStyle(fontFamily: 'Faruma'), // the app's own font
  onChanged: setMessage,
  leading: UiIconButton(label: 'Attach a file', size: UiSize.sm, onPressed: attach,
      icon: UiIcon(HugeIcons.strokeRoundedAttachment01)),
  trailing: UiIconButton(label: 'Send', size: UiSize.sm, variant: UiButtonVariant.primary, onPressed: send,
      icon: UiIcon(HugeIcons.strokeRoundedSent)),
)

UiInput(leading: UiIcon(HugeIcons.strokeRoundedMail01), semanticLabel: 'Email')''',
        api: const [
          ApiRow('leading', 'Widget?', 'Inside the border at the inline start (left in LTR, right in RTL); on the textarea, on the last line.'),
          ApiRow('trailing', 'Widget?', 'Inside the border at the inline end; on the textarea, on the last line.'),
          ApiRow('dir', 'UiTextDir?', 'ltr, rtl, or auto (follows the first strong character typed); the slots follow it. null keeps the surrounding Directionality.', def: 'null'),
          ApiRow('textStyle', 'TextStyle?', 'Merged over the field font (fontFamily, fontFamilyFallback); the app font is used as given.', def: 'null'),
        ],
      ),
      DocSection(
        name: 'Number input',
        widget: 'UiNumberInput',
        summary:
            'Numeric field with decrement and increment buttons side by side at its end (48dp wide each on phones). Value type: num?. A value is passed on while typing once it is in range; Enter or leaving the field clamps to min/max and rounds to precision. Focus selects the number so typing replaces it. ArrowUp/ArrowDown step it. Give it a label to get a handle you drag sideways to scrub the value (step per 2px; Shift for 10x, Alt for 0.1x with a keyboard).',
        demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
          UiFormField(label: 'Quantity', hint: '1 to 10', child: UiNumberInput(value: _qty, min: 1, max: 10, onChanged: (v) => setState(() => _qty = v))),
          UiNumberInput(value: _width, label: 'W', semanticLabel: 'Width', suffix: 'px', min: 0, max: 1200, step: 4, onChanged: (v) => setState(() => _width = v)),
          _caption('Quantity: ${_qty ?? 'empty'} · Width: ${_width ?? 'empty'}'),
        ]),
        code: "UiNumberInput(value: width, label: 'W', semanticLabel: 'Width', suffix: 'px', min: 0, max: 1200, step: 4, onChanged: setWidth)",
        api: const [
          ApiRow('value / onChanged', 'num? / ValueChanged<num?>', 'Controlled number; null when emptied.'),
          ApiRow('min / max', 'num?', 'Clamped on Enter, blur, steppers and scrub.'),
          ApiRow('step', 'num', 'Stepper, arrow key and scrub increment.', def: '1'),
          ApiRow('precision', 'int?', 'Decimal places kept.'),
          ApiRow('label', 'String', 'Short label before the number; drag it to scrub.', def: "''"),
          ApiRow('labelIcon', 'Widget?', 'An icon in place of the text label (keep label or semanticLabel).'),
          ApiRow('semanticLabel', 'String?', 'Accessible name when the label is too terse.'),
          ApiRow('suffix', 'String', 'Unit after the number, e.g. "px".', def: "''"),
          ApiRow('steppers', 'bool', 'Show the buttons.', def: 'true'),
          _sizeRow, _invalidRow, _radiusRow, _enabledRow,
        ],
      ),
      DocSection(
        name: 'Password input',
        widget: 'UiPasswordInput',
        summary: 'Password field with a show/hide button (named Show password / Hide password). Value type: String. autofillHints defaults to the saved password; pass [AutofillHints.newPassword] on sign-up forms.',
        demo: UiFormField(label: 'Password', child: UiPasswordInput(value: _password, onChanged: (v) => setState(() => _password = v))),
        code: 'UiPasswordInput(value: password, autofillHints: const [AutofillHints.newPassword], onChanged: setPassword)',
        api: const [
          ApiRow('value / onChanged', 'String? / ValueChanged<String>', 'Controlled text.'),
          ApiRow('autofillHints', 'Iterable<String>?', 'Saved password by default.', def: '[AutofillHints.password]'),
          ApiRow('placeholder', 'String', 'Shown while empty.', def: "''"),
          _sizeRow, _invalidRow, _radiusRow, _enabledRow,
        ],
      ),
      DocSection(
        name: 'Search input',
        widget: 'UiSearchInput',
        summary: 'Pill-shaped search field with a search icon and a clear button that appears once there is text; clearing empties it and puts focus back in the field. Value type: String. Name it with UiFormField, or with label when there is no visible label.',
        demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
          UiSearchInput(label: 'Search components', value: _search, onChanged: (v) => setState(() => _search = v)),
          _caption(_search.isEmpty ? 'Type to search' : 'Searching for "$_search"'),
        ]),
        code: "UiSearchInput(label: 'Search components', value: query, onChanged: setQuery)",
        api: const [
          ApiRow('value / onChanged', 'String? / ValueChanged<String>', 'Controlled text; clearing sends an empty string.'),
          ApiRow('placeholder', 'String', 'Shown while empty.', def: "'Search…'"),
          ApiRow('label', 'String?', 'Accessible name without a UiFormField.'),
          ApiRow('onSubmitted', 'ValueChanged<String>?', 'The keyboard search key.'),
          _sizeRow, _radiusRow, _enabledRow,
        ],
      ),
      DocSection(
        name: 'Time picker',
        widget: 'UiTimePicker',
        summary:
            "24-hour time. Value type: String, 'HH:MM' (or 'HH:MM:SS' when step is under a minute). The web uses the native time input; here the field opens columns of hours, minutes (in steps) and seconds, which suits phones. Tap a cell to set that part. With a keyboard: Enter, Space or ArrowDown opens it, ArrowUp/Down change the active column, ArrowLeft/Right switch columns, Enter or Escape closes.",
        demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
          UiFormField(label: 'Start time', hint: '15-minute steps', child: UiTimePicker(value: _time, step: 900, onChanged: (v) => setState(() => _time = v))),
          _caption('Value: ${_time ?? 'none'}'),
        ]),
        code: 'UiTimePicker(value: time, step: 900, onChanged: setTime)',
        api: const [
          ApiRow('value / onChanged', 'String? / ValueChanged<String>', "'HH:MM' or 'HH:MM:SS'."),
          ApiRow('step', 'int', 'Seconds: 60 = minutes, 900 = quarter hours, under 60 adds seconds.', def: '60'),
          ApiRow('placeholder', 'String?', 'Shown while empty.', def: "'--:--'"),
          ApiRow('label', 'String?', 'Accessible name without a UiFormField.'),
          _sizeRow, _invalidRow, _radiusRow, _enabledRow,
        ],
      ),
      DocSection(
        name: 'Select',
        widget: 'UiSelect',
        summary:
            'Single choice from a list. Value type: String. The closed field shows the chosen label or the placeholder; tapping it, or Enter, Space or ArrowDown, opens the list with the chosen option active. ArrowUp/Down, Home/End and typing a letter move; Enter or Space chooses; Escape or a tap outside closes and focus returns to the field. Disabled options are skipped. For a font picker set fontPreview: each option, and the closed field, is drawn in the font it names (its fontFamily, or its value as a family name, from fontPackage when the fonts ship in a package). Unlike the web\'s native select this works on every platform.',
        demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
          UiFormField(
            label: 'Fruit',
            child: UiSelect(
              value: _fruit,
              placeholder: 'Pick a fruit',
              options: const [
                UiSelectOption(label: 'Apple', value: 'apple'),
                UiSelectOption(label: 'Banana', value: 'banana'),
                UiSelectOption(label: 'Blueberry (out of season)', value: 'blueberry', disabled: true),
                UiSelectOption(label: 'Cherry', value: 'cherry'),
              ],
              onChanged: (v) => setState(() => _fruit = v),
            ),
          ),
          UiFormField(
            label: 'Font',
            hint: 'Fonts bundled with zouriel_ui, each shown in its own face.',
            child: UiSelect(value: _font, options: _fonts, fontPreview: true, fontPackage: 'zouriel_ui', onChanged: (v) => setState(() => _font = v)),
          ),
          Text('The quick brown fox jumps over the lazy dog.', style: uiApplyFont(context.uiText.body, uiFontPreviewStyle(context, _font, package: 'zouriel_ui'))),
        ]),
        code: '''UiSelect(
  value: font,
  fontPreview: true,
  fontPackage: 'zouriel_ui',
  options: const [
    UiSelectOption(label: 'Space Grotesk', value: 'Space Grotesk'),
    UiSelectOption(label: 'Bricolage Grotesque', value: 'Bricolage Grotesque'),
    UiSelectOption(label: 'Code', value: 'code', fontFamily: 'JetBrains Mono'),
  ],
  onChanged: setFont,
)''',
        api: const [
          ApiRow('options', 'List<UiSelectOption>', 'The choices.'),
          ApiRow('value / onChanged', 'String? / ValueChanged<String>', 'The chosen value.'),
          ApiRow('placeholder', 'String?', 'Shown while nothing is chosen.'),
          ApiRow('label', 'String?', 'Accessible name without a UiFormField.'),
          ApiRow('fontPreview', 'bool', 'Draw each option and the closed field in the font it names.', def: 'false'),
          ApiRow('fontPackage', 'String?', 'Package of value-named fonts, e.g. \'zouriel_ui\'.'),
          _sizeRow, _invalidRow, _radiusRow, _enabledRow,
        ],
        shapes:
            'class UiSelectOption {\n  String label; String value; bool disabled = false;\n  String? fontFamily;   // show this option in this font\n  String? fontPackage;  // the package that bundles it\n}',
      ),
      DocSection(
        name: 'Combobox',
        widget: 'UiCombobox',
        summary:
            'Filterable autocomplete. Value type: String?. Focus or tap opens the list, which shows every option with the chosen one active; typing filters by label. ArrowUp/Down move, Enter chooses, Escape or a tap outside closes. Leaving the field puts the chosen label back, so typed text never becomes the value. With clearable (the default) a Clear button shows while a value is chosen; it, or emptying the text and leaving the field, sets the value to null. fontPreview draws each option and the chosen value in the font it names.',
        demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
          UiFormField(label: 'Country', child: UiCombobox(options: _countries, value: _country, onChanged: (v) => setState(() => _country = v))),
          UiFormField(
            label: 'Heading font',
            child: UiCombobox(options: _comboFonts, value: _comboFont, fontPreview: true, fontPackage: 'zouriel_ui', placeholder: 'Search fonts…', onChanged: (v) => setState(() => _comboFont = v)),
          ),
          _caption('Country: ${_country ?? 'none'} · Font: ${_comboFont ?? 'none'}'),
        ]),
        code: 'UiCombobox(options: countries, value: country, onChanged: (v) => setState(() => country = v))',
        api: const [
          ApiRow('options', 'List<UiComboboxOption>', 'The choices.'),
          ApiRow('value / onChanged', 'String? / ValueChanged<String?>', 'The chosen value; null when cleared.'),
          ApiRow('placeholder', 'String', 'Shown while empty.', def: "'Search…'"),
          ApiRow('clearable', 'bool', 'Clear button, and an emptied field clears on blur.', def: 'true'),
          ApiRow('fontPreview / fontPackage', 'bool / String?', 'Font picker mode, as on UiSelect.', def: 'false'),
          ApiRow('label', 'String?', 'Accessible name without a UiFormField.'),
          _sizeRow, _invalidRow, _radiusRow, _enabledRow,
        ],
        callbacks: const [
          ApiRow('onQuery', 'ValueChanged<String>?', 'The text as it is typed (the web field\'s native input event), to look options up as the person types.'),
          ApiRow('clear()', 'UiComboboxState', 'Clears the value, keeps focus, leaves the list closed.'),
        ],
        shapes: 'class UiComboboxOption { String label; String value; String? fontFamily; String? fontPackage; }',
      ),
      DocSection(
        name: 'Multi-select',
        widget: 'UiMultiSelect',
        summary:
            'Choose several options; the chosen ones show as chips, each with a Remove button. Value type: List<String>, in the order chosen. Type to filter; ArrowUp/Down move, Enter toggles the active option, Backspace in an empty field removes the last chip, Escape or a tap outside closes. With clearable (the default) a Clear all button empties the selection. Chips wrap onto more rows.',
        demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
          UiFormField(label: 'Teams', child: UiMultiSelect(options: _teams, value: _picked, onChanged: (v) => setState(() => _picked = v))),
          _caption('Value: [${_picked.join(', ')}]'),
        ]),
        code: 'UiMultiSelect(options: teams, value: picked, onChanged: (v) => setState(() => picked = v))',
        api: const [
          ApiRow('options', 'List<UiComboboxOption>', 'The choices.'),
          ApiRow('value / onChanged', 'List<String> / ValueChanged<List<String>>', 'Chosen values in the order chosen.'),
          ApiRow('placeholder', 'String', 'Shown while nothing is chosen.', def: "'Select…'"),
          ApiRow('clearable', 'bool', 'Clear all button.', def: 'true'),
          ApiRow('label', 'String?', 'Accessible name without a UiFormField.'),
          _sizeRow, _invalidRow, _radiusRow, _enabledRow,
        ],
        callbacks: const [ApiRow('clear()', 'UiMultiSelectState', 'Empties the selection, keeps focus, leaves the list closed.')],
      ),
      DocSection(
        name: 'OTP input',
        widget: 'UiOtpInput',
        summary:
            "Fixed-length one-time code, one cell per character. Value type: String, one character per cell in position: an empty cell before a filled one is a space and empty cells at the end are dropped, so 1, 2, empty, 4 reads '12 4' and writing '12 4' back fills the same cells. Typing moves to the next cell; Backspace in an empty cell and ArrowLeft/Right move between cells. Pasting or autofilling a whole code (SMS autofill on the first cell) fills every cell from the first. Validate with UiOtpInput.validator: a non-empty code with fewer than length filled cells is incomplete; an empty one is valid unless the field is required.",
        demo: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space2, children: [
          UiOtpInput(length: 6, value: _otp, onChanged: (v) => setState(() => _otp = v), invalid: UiOtpInput.isIncomplete(_otp, 6)),
          _caption(_otp.isEmpty ? 'Empty' : "Value: '$_otp'${UiOtpInput.isIncomplete(_otp, 6) ? ' (incomplete)' : ''}"),
        ]),
        code: "UiFormField<String>.validated(\n  label: 'Code',\n  required: true,\n  validator: UiOtpInput.validator(length: 6),\n  builder: (f) => UiOtpInput(value: f.value, onChanged: f.didChange),\n)",
        api: const [
          ApiRow('value / onChanged', 'String? / ValueChanged<String>', 'The code, holes as spaces.'),
          ApiRow('length', 'int', 'Number of cells.', def: '6'),
          ApiRow('numeric', 'bool', 'Digits only and the number keyboard.', def: 'true'),
          ApiRow('semanticLabel', 'String', 'Name of the group (a UiFormField label wins).', def: "'One-time code'"),
          _invalidRow, _enabledRow,
        ],
        callbacks: const [
          ApiRow('UiOtpInput.validator({length, message})', 'FormFieldValidator<String>', 'Fails while the code is incomplete.'),
          ApiRow('UiOtpInput.isIncomplete(value, length)', 'bool', 'Started but not finished.'),
          ApiRow('UiOtpInput.filledCount(value, length)', 'int', 'Filled cells.'),
        ],
      ),
      DocSection(
        name: 'Editable text',
        widget: 'UiEditableText',
        summary: 'Tap-to-edit inline text. Value type: String. Shows as a button (the pencil is always visible on touch screens); tapping it, or Enter/Space, opens a field with the text selected. Enter or leaving the field commits, Escape cancels.',
        demo: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space2, children: [
          UiEditableText(value: _title, semanticLabel: 'Board name', style: context.uiText.h4, onChanged: (v) => setState(() => _title = v)),
          _caption('Value: $_title'),
        ]),
        code: "UiEditableText(value: title, semanticLabel: 'Board name', onChanged: setTitle)",
        api: const [
          ApiRow('value / onChanged', 'String / ValueChanged<String>', 'Committed text (called only when it changed).'),
          ApiRow('placeholder', 'String', 'Shown while empty.', def: "'Empty'"),
          ApiRow('semanticLabel', 'String?', 'Accessible name, announced with the text.'),
          ApiRow('style', 'TextStyle?', 'Text style (e.g. a heading).'),
          _enabledRow,
        ],
      ),
      DocSection(
        name: 'Date picker',
        widget: 'UiDatePicker',
        summary:
            "Calendar popover. Value type: ISO String 'YYYY-MM-DD' (or null; an empty or malformed string counts as no date), shown as local text. Tap the field, or press Enter, Space or ArrowDown on it, to open; focus goes to the chosen day (or today). Arrow keys move by day and week, PageUp/PageDown by month, Home/End to the ends of the month, Enter picks. Tab stays inside the popover; Escape or a tap outside closes it and returns to the field. The month and year in the header open month and year grids: arrow keys move (Up/Down by a row of three), Home/End to the first and last cell, PageUp/PageDown change the year or the page of 12 years, Enter or Space picks. min/max limit which days can be picked. Weeks start on Sunday.",
        demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
          UiFormField(label: 'Due date', hint: 'From today on', child: UiDatePicker(value: _date, min: uiIsoDate(uiToday()), onChanged: (v) => setState(() => _date = v))),
          _caption('Value: ${_date ?? 'null'}'),
        ]),
        code: "UiDatePicker(value: due, min: '2026-01-01', onChanged: setDue)",
        api: const [
          ApiRow('value / onChanged', 'String? / ValueChanged<String>', "ISO 'YYYY-MM-DD'."),
          ApiRow('min / max', 'String?', 'Earliest / latest day that can be picked (ISO).'),
          ApiRow('placeholder', 'String', 'Shown while empty.', def: "'Select a date'"),
          ApiRow('label', 'String?', 'Accessible name without a UiFormField.'),
          _sizeRow, _invalidRow, _radiusRow, _enabledRow,
        ],
      ),
      DocSection(
        name: 'Calendar',
        widget: 'UiCalendar',
        summary:
            "Inline month calendar. Value type: ISO String 'YYYY-MM-DD' (or null); it opens on the month of its value. Each day is a button named with its full date; the chosen day is selected and today is marked (and announced as Today). The same keyboard grid and month/year grids as the date picker. Days fit 48dp touch targets on phones.",
        demo: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space2, children: [
          UiCalendar(value: _day, onChanged: (v) => setState(() => _day = v)),
          _caption('Value: ${_day ?? 'null'}'),
        ]),
        code: 'UiCalendar(value: day, onChanged: setDay)',
        api: const [
          ApiRow('value / onChanged', 'String? / ValueChanged<String>', "ISO 'YYYY-MM-DD'."),
          ApiRow('min / max', 'String?', 'Pickable range (ISO).'),
          _radiusRow, _enabledRow,
        ],
      ),
      DocSection(
        name: 'Date range picker',
        widget: 'UiDateRangePicker',
        summary: 'Inline range selection. Tap a start day, then an end day (an earlier end swaps them); a third tap starts a new range. With a mouse, hovering previews the band while choosing the end. Value type: UiDateRange (ISO days); it opens on the month the range starts in. The footer reads the range and is announced when it changes.',
        demo: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space2, children: [
          UiDateRangePicker(value: _range, onChanged: (v) => setState(() => _range = v)),
          _caption('Value: ${_range.start ?? 'null'} to ${_range.end ?? 'null'}'),
        ]),
        code: 'UiDateRangePicker(value: range, onChanged: (r) => setState(() => range = r))',
        api: const [
          ApiRow('value / onChanged', 'UiDateRange / ValueChanged<UiDateRange>', 'Start and end ISO days.'),
          ApiRow('min / max', 'String?', 'Pickable range (ISO).'),
          _radiusRow, _enabledRow,
        ],
        shapes: 'class UiDateRange { String? start; String? end; }',
      ),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < sections.length; i++) ...[if (i > 0) _divider(context), sections[i]],
    ]);
  }
}
