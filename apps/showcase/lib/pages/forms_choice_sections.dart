import 'package:flutter/widgets.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../docs/doc.dart';

/// The choice controls half of the Form controls page: checkboxes, radios, switch, slider, rating,
/// chip input, colour picker, file upload, choice grid, anchor picker and token input.
class FormsChoiceSections extends StatefulWidget {
  const FormsChoiceSections({super.key});

  @override
  State<FormsChoiceSections> createState() => _FormsChoiceSectionsState();
}

class _FormsChoiceSectionsState extends State<FormsChoiceSections> {
  bool _terms = true, _news = false, _wifi = true, _disabled = false;
  String? _plan = 'pro';
  List<String> _channels = ['email'];
  double _volume = 40;
  int _stars = 3;
  List<String> _tags = ['design', 'mobile'];
  String _colour = '#6a97c0';
  List<UiPickedFile> _files = [];
  List<UiPickedFile> _rejected = [];
  String? _effect = 'fade';
  String _lastPicked = '';
  UiAnchor _anchor = UiAnchor.centre;
  final _tokenKey = GlobalKey<UiTokenInputState>();
  List<UiTokenRun> _message = const [UiTokenRun.text('Dear '), UiTokenRun.token('guest.name'), UiTokenRun.text(', see you on '), UiTokenRun.token('event.date'), UiTokenRun.text('.')];

  static const _tokenNames = {'guest.name': 'Guest name', 'event.date': 'Event date', 'event.venue': 'Venue'};

  /// The showcase has no file-picker plugin, so this stands in for one: it "picks" sample files,
  /// one of which doesn't match the accept list, to show the rejected path.
  Future<List<UiPickedFile>?> _fakePicker({required bool multiple, required List<String> accept}) async {
    return const [
      UiPickedFile(name: 'floor-plan.pdf', size: 482113, mimeType: 'application/pdf'),
      UiPickedFile(name: 'cover.png', size: 91234, mimeType: 'image/png'),
      UiPickedFile(name: 'notes.txt', size: 812, mimeType: 'text/plain'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final caption = context.uiText.caption.copyWith(color: t.textMuted);
    final enabled = !_disabled;
    final sections = <Widget>[
      DocSection(
        name: 'Checkbox & switch',
        widget: 'UiCheckbox · UiSwitch',
        summary: 'Boolean controls with their label beside them; the whole row is the touch target and Space toggles a focused control. A null value draws the checkbox\'s mixed state (a dash), announced as mixed. The switch is announced as a switch and its thumb springs across. Leave onChanged null to disable either.',
        demo: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          UiSwitch(value: _disabled, label: 'Disable the controls below', onChanged: (v) => setState(() => _disabled = v)),
          UiCheckbox(value: _terms, label: 'I agree to the terms', onChanged: enabled ? (v) => setState(() => _terms = v) : null),
          UiCheckbox(value: _news, label: 'Send me the newsletter', invalid: !_news, onChanged: enabled ? (v) => setState(() => _news = v) : null),
          UiSwitch(value: _wifi, label: 'Wi-Fi', onChanged: enabled ? (v) => setState(() => _wifi = v) : null),
        ]),
        code: '''UiCheckbox(value: agreed, label: 'I agree', onChanged: (v) => setState(() => agreed = v))
UiCheckbox(value: null, label: 'Some selected', onChanged: selectAll) // mixed
UiSwitch(value: wifi, label: 'Wi-Fi', onChanged: (v) => setState(() => wifi = v))''',
        api: const [
          ApiRow('value', 'bool? / bool', 'Checked state. Checkbox only: null is mixed.'),
          ApiRow('onChanged', 'ValueChanged<bool>?', 'New state. Null disables the control.'),
          ApiRow('label / child', 'String? / Widget?', 'The label beside the mark (also its accessible name).'),
          ApiRow('invalid', 'bool', 'Checkbox: danger border.', def: 'false'),
          ApiRow('semanticLabel', 'String?', 'Name when there is no visible label.'),
          ApiRow('focusNode / autofocus', 'FocusNode? / bool', 'Keyboard focus.'),
        ],
      ),
      DocSection(
        name: 'Radio group',
        widget: 'UiRadioGroup<T>',
        summary: 'One choice from a list. Like native radios the group is one tab stop (the chosen option, or the first enabled one), and the arrow keys move the choice, wrapping and skipping disabled options. Announced as a named radio group.',
        demo: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space2, children: [
          UiRadioGroup<String>(
            label: 'Plan',
            value: _plan,
            onChanged: enabled ? (v) => setState(() => _plan = v) : null,
            options: const [
              UiRadioOption(label: 'Free', value: 'free'),
              UiRadioOption(label: 'Pro', value: 'pro'),
              UiRadioOption(label: 'Team (coming soon)', value: 'team', disabled: true),
            ],
          ),
          Text('Plan: $_plan', style: caption),
        ]),
        code: '''UiRadioGroup<String>(
  label: 'Plan',
  value: plan,
  options: const [UiRadioOption(label: 'Free', value: 'free'), UiRadioOption(label: 'Pro', value: 'pro')],
  onChanged: (v) => setState(() => plan = v),
)''',
        api: const [
          ApiRow('options', 'List<UiRadioOption<T>>', 'The choices, in order.'),
          ApiRow('value', 'T?', 'The chosen value; null for none.'),
          ApiRow('onChanged', 'ValueChanged<T>?', 'New choice. Null disables the group.'),
          ApiRow('label', 'String?', 'Accessible name of the group.'),
          ApiRow('direction', 'Axis', 'vertical, or horizontal (wraps).', def: 'vertical'),
        ],
        shapes: 'class UiRadioOption<T> { String label; T value; bool disabled = false; }',
      ),
      DocSection(
        name: 'Checkbox group',
        widget: 'UiCheckboxGroup<T>',
        summary: 'A multi-select set of checkboxes; the value is the chosen values in the order they were chosen. selectAll adds a master checkbox that ticks or clears every enabled option and shows the mixed state while some are ticked. It never changes disabled options.',
        demo: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space2, children: [
          UiCheckboxGroup<String>(
            label: 'Notify me by',
            selectAll: true,
            value: _channels,
            onChanged: enabled ? (v) => setState(() => _channels = v) : null,
            options: const [
              UiCheckboxOption(label: 'Email', value: 'email'),
              UiCheckboxOption(label: 'SMS', value: 'sms'),
              UiCheckboxOption(label: 'Push', value: 'push'),
              UiCheckboxOption(label: 'Fax (retired)', value: 'fax', disabled: true),
            ],
          ),
          Text('Value: $_channels', style: caption),
        ]),
        code: '''UiCheckboxGroup<String>(
  selectAll: true,
  value: channels,
  options: const [UiCheckboxOption(label: 'Email', value: 'email'), UiCheckboxOption(label: 'SMS', value: 'sms')],
  onChanged: (v) => setState(() => channels = v),
)''',
        api: const [
          ApiRow('options', 'List<UiCheckboxOption<T>>', 'The options, in order.'),
          ApiRow('value', 'List<T>', 'Chosen values, in the order chosen.'),
          ApiRow('onChanged', 'ValueChanged<List<T>>?', 'New selection. Null disables the group.'),
          ApiRow('selectAll', 'bool', 'Adds the master checkbox.', def: 'false'),
          ApiRow('selectAllLabel', 'String', 'Its label.', def: "'Select all'"),
          ApiRow('label', 'String?', 'Accessible name of the group.'),
          ApiRow('direction', 'Axis', 'vertical, or horizontal (wraps).', def: 'vertical'),
        ],
        shapes: 'class UiCheckboxOption<T> { String label; T value; bool disabled = false; }',
      ),
      DocSection(
        name: 'Slider',
        widget: 'UiSlider',
        summary: 'A themed range slider. Drag or tap the track; with a keyboard the arrow keys move one step, Page Up/Down a tenth of the range, Home/End to the ends. Values snap to step. The filled part of the track follows the value and showValue prints it. Screen readers get the value and increase/decrease actions. On phones the track sits in a 48dp touch band.',
        demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          UiSlider(value: _volume, label: 'Volume', onChanged: enabled ? (v) => setState(() => _volume = v) : null),
          UiSlider(value: _volume / 100, max: 1, step: 0.05, label: 'Opacity', onChanged: enabled ? (v) => setState(() => _volume = v * 100) : null),
        ]),
        code: "UiSlider(value: volume, min: 0, max: 100, step: 1, label: 'Volume', onChanged: (v) => setState(() => volume = v))",
        api: const [
          ApiRow('value', 'double?', 'Current value; null shows min.'),
          ApiRow('onChanged', 'ValueChanged<double>?', 'Fires while dragging. Null disables it.'),
          ApiRow('onChangeEnd', 'ValueChanged<double>?', 'Once, when a drag or key press ends.'),
          ApiRow('min / max / step', 'double', 'Range and step.', def: '0 / 100 / 1'),
          ApiRow('label', 'String', 'Accessible name.', def: "'Slider'"),
          ApiRow('showValue', 'bool', 'Print the value beside the track.', def: 'true'),
          ApiRow('format', 'String Function(double)?', 'Formats the shown and announced value.'),
        ],
      ),
      DocSection(
        name: 'Rating',
        widget: 'UiRating',
        summary: 'Star rating from 0 (none) to max. A radio group with one tab stop: arrow keys and Home/End move the rating, a tap sets it, tapping the current star again clears it to 0. Each star is announced as "3 of 5". Stars get 48dp cells on phones.',
        demo: Row(spacing: t.space3, children: [
          UiRating(value: _stars, onChanged: enabled ? (v) => setState(() => _stars = v) : null),
          Text('$_stars / 5', style: caption),
        ]),
        code: 'UiRating(value: stars, max: 5, onChanged: (v) => setState(() => stars = v))',
        api: const [
          ApiRow('value', 'int', '0 to max; 0 means none.'),
          ApiRow('onChanged', 'ValueChanged<int>?', 'New rating. Null disables it.'),
          ApiRow('max', 'int', 'Number of stars.', def: '5'),
          ApiRow('label', 'String', 'Accessible name of the group.', def: "'Rating'"),
        ],
      ),
      DocSection(
        name: 'Chip input',
        widget: 'UiChipInput',
        summary: 'Free-text tags. Enter or a comma adds the typed text (trimmed) as a chip; Backspace in an empty field removes the last chip, on soft keyboards too; each chip has a remove button. Duplicates are kept. Tapping anywhere in the box focuses the field.',
        demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
          UiChipInput(value: _tags, label: 'Tags', onChanged: enabled ? (v) => setState(() => _tags = v) : null),
          Text('Value: $_tags', style: caption),
        ]),
        code: "UiChipInput(value: tags, label: 'Tags', onChanged: (v) => setState(() => tags = v))",
        api: const [
          ApiRow('value', 'List<String>', 'The chips.'),
          ApiRow('onChanged', 'ValueChanged<List<String>>?', 'New list. Null disables it.'),
          ApiRow('placeholder', 'String', 'Shown when there are no chips and no text.', def: "'Add tag…'"),
          ApiRow('label', 'String?', 'Accessible name of the text field.'),
          ApiRow('invalid', 'bool', 'Danger border.', def: 'false'),
          ApiRow('radius', 'bool?', 'Rounded corners; defaults to UiConfig.radius.'),
        ],
      ),
      DocSection(
        name: 'Colour picker',
        widget: 'UiColorPicker',
        summary: 'A colour well, a hex field and preset swatches; the value is a lower-case #rrggbb string. The hex field passes a colour on only once it is a whole #rgb or #rrggbb (the # optional); leaving the field puts the current colour back. Phones have no native colour dialog, so the well opens a saturation/brightness square over a hue strip.',
        demo: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space2, children: [
          UiColorPicker(value: _colour, onChanged: enabled ? (v) => setState(() => _colour = v) : null),
          Text('Value: $_colour', style: caption),
        ]),
        code: "UiColorPicker(value: colour, swatches: const ['#1b3d59', '#a83a3f'], onChanged: (hex) => setState(() => colour = hex))",
        api: const [
          ApiRow('value', 'String', 'Hex colour.'),
          ApiRow('onChanged', 'ValueChanged<String>?', 'Lower-case #rrggbb. Null disables it.'),
          ApiRow('swatches', 'List<String>', 'Preset colours.', def: 'six winter colours'),
          ApiRow('radius', 'bool?', 'Rounded corners; defaults to UiConfig.radius.'),
        ],
        callbacks: const [
          ApiRow('uiNormalizeHex(raw)', 'String?', 'Whole hex colour as #rrggbb, or null.'),
          ApiRow('uiHexToColor(hex) / uiColorToHex(color)', 'Color? / String', 'Conversions.'),
        ],
      ),
      DocSection(
        name: 'File upload',
        widget: 'UiFileUpload',
        summary: 'A dropzone that opens a file picker when tapped and lists the chosen files with their sizes. The library ships no picker, since that needs a plugin: pass a UiFilePicker that wraps file_picker or file_selector. Files that don\'t match accept (extensions, MIME types, image/*) go to onRejected, the rest to onFilesSelected (only the first unless multiple). For drag and drop, wire a drop plugin to setDragOver and addFiles on the state. This demo\'s picker returns three sample files.',
        demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
          UiFileUpload(
            picker: _fakePicker,
            enabled: enabled,
            multiple: true,
            accept: '.pdf,image/*',
            acceptLabel: 'PDF or image',
            onFilesSelected: (f) => setState(() => _files = f),
            onRejected: (f) => setState(() => _rejected = f),
          ),
          Text('Selected ${_files.length}; rejected: ${_rejected.map((f) => f.name).join(', ')}', style: caption),
        ]),
        code: '''UiFileUpload(
  multiple: true,
  accept: '.pdf,image/*',
  picker: ({required multiple, required accept}) async {
    final r = await FilePicker.platform.pickFiles(allowMultiple: multiple);
    return r?.files.map((f) => UiPickedFile(name: f.name, size: f.size, path: f.path)).toList();
  },
  onFilesSelected: upload,
  onRejected: (files) => toast('Not a PDF or image'),
)''',
        api: const [
          ApiRow('picker', 'UiFilePicker?', 'Opens the platform picker. Null disables the zone.'),
          ApiRow('onFilesSelected', 'ValueChanged<List<UiPickedFile>>?', 'Accepted files.'),
          ApiRow('onRejected', 'ValueChanged<List<UiPickedFile>>?', 'Files that don\'t match accept.'),
          ApiRow('multiple', 'bool', 'Keep every file, not just the first.', def: 'false'),
          ApiRow('accept', 'String?', 'Web-style list: .pdf,image/png,image/*.'),
          ApiRow('acceptLabel', 'String?', 'What to show instead of accept.'),
          ApiRow('dropEnabled', 'bool', 'Mention drag and drop in the hint.', def: 'false'),
          ApiRow('enabled', 'bool', 'Disable the zone.', def: 'true'),
        ],
        callbacks: const [
          ApiRow('state.addFiles(files)', 'void', 'Dropped files: filtered by accept, rejects reported.'),
          ApiRow('state.setDragOver(bool)', 'void', 'Highlight while files are dragged over.'),
          ApiRow('uiFileMatchesAccept(file, accept)', 'bool', 'The accept check on its own.'),
        ],
        shapes: '''class UiPickedFile { String name; int size; String? mimeType; String? path; Uint8List? bytes; }
typedef UiFilePicker = Future<List<UiPickedFile>?> Function({required bool multiple, required List<String> accept});''',
      ),
      DocSection(
        name: 'Choice grid',
        widget: 'UiChoiceGrid<T>',
        summary: 'One of many options shown as tiles, grouped under headings: presets, templates, effects. A radio group underneath: arrow keys (and Home/End) move through the enabled tiles in reading order and choose as they go, only the chosen tile is in the tab order, Enter/Space choose. tileBuilder draws a picture above each label. onPicked fires on every choice, even the selected tile again, for pickers where choosing is an action.',
        demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
          UiChoiceGrid<String>(
            label: 'Entrance effect',
            value: _effect,
            enabled: enabled,
            onChanged: (v) => setState(() => _effect = v),
            onPicked: (c) => setState(() => _lastPicked = c.label),
            tileBuilder: (context, item, selected) => _EffectArt(effect: item.value, selected: selected),
            options: const [
              UiChoice(value: 'fade', label: 'Fade', group: 'Entrances'),
              UiChoice(value: 'rise', label: 'Rise', group: 'Entrances'),
              UiChoice(value: 'zoom', label: 'Zoom', group: 'Entrances'),
              UiChoice(value: 'pulse', label: 'Pulse', group: 'Loops', description: 'A gentle beat'),
              UiChoice(value: 'spin', label: 'Spin', group: 'Loops', disabled: true),
            ],
          ),
          Text('Chosen: $_effect · last picked: $_lastPicked', style: caption),
        ]),
        code: '''UiChoiceGrid<String>(
  value: effect,
  options: const [UiChoice(value: 'fade', label: 'Fade', group: 'Entrances'), ...],
  tileBuilder: (context, item, selected) => Preview(item.value),
  onChanged: (v) => setState(() => effect = v),
)''',
        api: const [
          ApiRow('options', 'List<UiChoice<T>>', 'The tiles; group puts them under headings.'),
          ApiRow('value', 'T?', 'The chosen value.'),
          ApiRow('onChanged', 'ValueChanged<T>?', 'New choice.'),
          ApiRow('onPicked', 'ValueChanged<UiChoice<T>>?', 'Every choice, including the selected tile again.'),
          ApiRow('enabled', 'bool', 'Disable every tile.', def: 'true'),
          ApiRow('label', 'String', 'Accessible name of the group.', def: "'Choices'"),
          ApiRow('minTile', 'double', 'Narrowest a tile may get; columns fill the width.', def: '88'),
          ApiRow('tileBuilder', 'Widget Function(context, item, selected)?', 'Art above the label, in a 1.4:1 box.'),
        ],
        shapes: 'class UiChoice<T> { T value; String label; String? description; String? group; bool disabled = false; }',
      ),
      DocSection(
        name: 'Anchor picker',
        widget: 'UiAnchorPicker',
        summary: 'The nine-dot grid for picking a point of a box, such as a pivot or an alignment, as in Figma and Photoshop. The value is UiAnchor(x, y) in fractions of the box; a point between the dots shows none chosen. A radio group with one tab stop; arrow keys move the choice, and each dot is named (Top left, Centre...).',
        demo: Row(spacing: t.space4, children: [
          UiAnchorPicker(value: _anchor, label: 'Pivot', onChanged: enabled ? (v) => setState(() => _anchor = v) : null),
          Text('x ${_anchor.x}, y ${_anchor.y}', style: caption),
        ]),
        code: "UiAnchorPicker(value: pivot, label: 'Pivot', onChanged: (a) => setState(() => pivot = a))",
        api: const [
          ApiRow('value', 'UiAnchor?', 'The point; null means the centre.'),
          ApiRow('onChanged', 'ValueChanged<UiAnchor>?', 'New point. Null disables it.'),
          ApiRow('label', 'String', 'Accessible name of the group.', def: "'Point'"),
        ],
        shapes: 'class UiAnchor { double x; double y; } // 0, 0.5 or 1 for a dot',
      ),
      DocSection(
        name: 'Token input',
        widget: 'UiTokenInput',
        summary: 'Rich text where some pieces are atomic tokens (variables, mentions) shown as chips; the value is a list of UiTokenRun. A chip acts like one character: the caret steps over it and one Backspace removes it. Ctrl/Cmd+B and Ctrl/Cmd+I toggle bold and italic; pasted text is always plain. insertToken() on the state drops a chip at the caret (or at the end if the field never had the caret).',
        demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
          UiTokenInput(
            key: _tokenKey,
            value: _message,
            label: 'Message',
            tokenLabel: (tok) => _tokenNames[tok] ?? tok,
            onChanged: enabled ? (v) => setState(() => _message = v) : null,
          ),
          Wrap(spacing: t.space2, runSpacing: t.space2, children: [
            for (final e in _tokenNames.entries)
              UiButton(label: 'Insert ${e.value}', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: enabled ? () => _tokenKey.currentState?.insertToken(e.key) : null),
          ]),
          Text(_message.map((r) => r.toJson()).join(' '), style: caption),
        ]),
        code: '''final key = GlobalKey<UiTokenInputState>();

UiTokenInput(
  key: key,
  value: runs,
  tokenLabel: (t) => names[t] ?? t,
  onChanged: (v) => setState(() => runs = v),
)
key.currentState!.insertToken('guest.name');''',
        api: const [
          ApiRow('value', 'List<UiTokenRun>', 'Text and token runs.'),
          ApiRow('onChanged', 'ValueChanged<List<UiTokenRun>>?', 'Normalised runs. Null disables it.'),
          ApiRow('tokenLabel', 'String Function(String)?', 'Chip text for a token value.'),
          ApiRow('multiline', 'bool', 'Enter adds a line; off gives a one-line field.', def: 'true'),
          ApiRow('placeholder / label', 'String', 'Placeholder and accessible name.'),
          ApiRow('minHeight', 'double?', 'Minimum height of a multiline field.'),
          ApiRow('onTokenTap', 'ValueChanged<String>?', 'A chip was tapped.'),
          ApiRow('onFocusChange', 'ValueChanged<bool>?', 'Focus in or out.'),
        ],
        callbacks: const [
          ApiRow('state.insertToken(token)', 'void', 'Chip at the caret, replacing any selection.'),
          ApiRow('state.focus()', 'void', 'Focus with the caret at the end.'),
          ApiRow('uiNormalizeRuns(runs)', 'List<UiTokenRun>', 'Merge like runs, drop empty ones.'),
        ],
        shapes: 'class UiTokenRun { String? text; String? token; bool bold; bool italic; toJson(); }',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) Container(height: 1, color: t.border),
          sections[i],
        ],
      ],
    );
  }
}

/// Tile art for the choice grid demo: a small block positioned or scaled to suggest the effect.
class _EffectArt extends StatelessWidget {
  const _EffectArt({required this.effect, required this.selected});
  final String effect;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final colour = selected ? t.primary : t.textMuted;
    final block = Container(width: 22, height: 22, decoration: BoxDecoration(color: colour, borderRadius: BorderRadius.circular(t.radiusXs)));
    return switch (effect) {
      'fade' => Opacity(opacity: 0.45, child: block),
      'rise' => Transform.translate(offset: const Offset(0, 6), child: block),
      'zoom' => Transform.scale(scale: 0.6, child: block),
      'pulse' => Transform.scale(scale: 1.25, child: block),
      _ => Transform.rotate(angle: 0.6, child: block),
    };
  }
}
