import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../combobox/combobox.dart';
import '../../combobox/multi_select.dart';
import '../../core/icon.dart';
import '../../core/interactive.dart';
import '../../core/types.dart';
import '../../datepicker/date_picker.dart';
import '../../forms/choice/checkbox.dart';
import '../../forms/choice/file_upload.dart';
import '../../forms/choice/radio_group.dart';
import '../../forms/choice/rating.dart';
import '../../forms/choice/slider.dart';
import '../../forms/choice/switch.dart';
import '../../forms/text/form_field.dart';
import '../../forms/text/inputs.dart';
import '../../forms/text/number_input.dart';
import '../../forms/text/select.dart';
import '../../forms/text/time_picker.dart';
import '../../theme/theme.dart';
import '../engine/conditions.dart';
import '../engine/engine.dart';
import '../engine/field_types.dart';
import '../engine/format.dart';
import '../engine/js.dart';
import '../engine/schema.dart';
import '../engine/validators.dart';
import '../sources/source_picker.dart';

/// Uploads a picked file and returns what to store (usually with a `url` or `id`).
typedef UiFbUploader = Future<UiFbFileValue> Function(UiPickedFile file, UiFbField field);

/// Controls that are several inputs (radios, ticks, stars): labelled as a group.
const _groupTypes = {UiFbFieldType.radio, UiFbFieldType.checkboxes, UiFbFieldType.checkbox, UiFbFieldType.toggle, UiFbFieldType.rating};

final _autofill = <String, String>{
  'name': AutofillHints.name,
  'given-name': AutofillHints.givenName,
  'family-name': AutofillHints.familyName,
  'email': AutofillHints.email,
  'tel': AutofillHints.telephoneNumber,
  'url': AutofillHints.url,
  'street-address': AutofillHints.fullStreetAddress,
  'postal-code': AutofillHints.postalCode,
  'country-name': AutofillHints.countryName,
  'organization': AutofillHints.organizationName,
  'username': AutofillHints.username,
  'bday': AutofillHints.birthday,
};

/// `ui-fb-field`: one field of a `UiFormRenderer`: label, help, control and messages, laid out as
/// the form (or the field) asks. Reads and writes its answer through [engine].
///
/// Label placements: `top`, `left` (two columns while there's room), `hidden` (still the control's
/// accessible name) and `inside` (a floating label on text boxes; other controls fall back to
/// `top`). Errors show below the control, or inside text boxes as a short pill when the form says
/// `errorPlacement: inside` (the full text is still announced).
class UiFbFieldView extends StatefulWidget {
  const UiFbFieldView({super.key, required this.engine, required this.field, this.row, this.uploader, this.filePicker, this.today});

  final UiFormEngine engine;
  final UiFbField field;

  /// The repeat entry this copy belongs to, or null outside repeats.
  final String? row;
  final UiFbUploader? uploader;

  /// Opens the platform's file picker for file fields; without it they can't take new files.
  final UiFilePicker? filePicker;

  /// "Today" as YYYY-MM-DD, for date limits like `today+30`.
  final String Function()? today;

  @override
  State<UiFbFieldView> createState() => UiFbFieldViewState();
}

/// State of a [UiFbFieldView]; [focus] moves into its control (used by the error summary).
class UiFbFieldViewState extends State<UiFbFieldView> {
  final FocusNode _wrap = FocusNode(debugLabel: 'fb-field', canRequestFocus: false, skipTraversal: true);
  final UiFieldLink _link = UiFieldLink();
  bool _focused = false;
  bool _uploading = false;
  String _uploadError = '';
  int _pickSeq = 0;
  String? _lastParams;

  UiFormEngine get _e => widget.engine;
  UiFbField get _f => widget.field;

  /// The field's address in the engine: `id`, or `row/id` inside a repeat entry.
  String get addr => addrOf(_f.id, widget.row);

  @override
  void initState() {
    super.initState();
    _listen(null);
  }

  @override
  void didUpdateWidget(UiFbFieldView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget;
    if (old.engine != widget.engine) {
      _lastParams = null;
      _listen(old.engine);
    }
  }

  @override
  void dispose() {
    _e.removeListener(_onEngine);
    _wrap.dispose();
    _link.dispose();
    super.dispose();
  }

  void _listen(UiFormEngine? old) {
    old?.removeListener(_onEngine);
    if (_f.source == null) return;
    _lastParams = _paramsKey();
    _e.addListener(_onEngine);
  }

  String _paramsKey() => jsonEncode(_e.sourceParams(_f.id, widget.row), toEncodable: (o) => o.toString());

  /// A dependent list (Cities of the chosen Country) drops its answer when what it depends on changes.
  void _onEngine() {
    final key = _paramsKey();
    final last = _lastParams;
    _lastParams = key;
    if (last == null || key == last || _e.mode == UiFormMode.view) return;
    if (!isEmptyValue(_e.instanceState(_f.id, widget.row).value)) {
      _e.setValue(_f.id, widget.row, _f.type == UiFbFieldType.multiselect ? const <Object?>[] : null);
    }
  }

  /// Moves focus into the control and scrolls it into view.
  void focus() {
    Scrollable.ensureVisible(context, alignment: 0.3, duration: context.uiAnimate ? context.ui.motionBase : Duration.zero);
    for (final n in _wrap.traversalDescendants) {
      if (n.canRequestFocus) {
        n.requestFocus();
        return;
      }
    }
  }

  void _set(Object? v) {
    // Whole doubles (a slider at 5.0) are saved as JSON writes them on the web: 5.
    if (v is double && v.isFinite && v == v.truncateToDouble()) v = v.toInt();
    _e.setValue(_f.id, widget.row, v);
  }

  void _onFocusChange(bool has) {
    // Moving between the radios of one group isn't leaving the field: only the wrapper's change counts.
    if (!has) _e.markTouched(_f.id, widget.row);
    setState(() => _focused = has);
  }

  // ── Derived ────────────────────────────────────────────────────────────────────────────────

  bool get _viewing => _e.mode == UiFormMode.view;
  UiFbFieldTypeInfo get _info => fieldTypeInfo(_f.type);

  String get _labelPos {
    final p = _f.layout?.labelPlacement ?? _e.definition.settings?.labelPlacement ?? 'top';
    // Floating labels only work inside a single text box.
    if (p == 'inside' && (!_info.textLike || _viewing)) return 'top';
    return p;
  }

  bool get _errInside {
    final p = _f.layout?.errorPlacement ?? _e.definition.settings?.errorPlacement ?? 'below';
    return p == 'inside' && _info.textLike;
  }

  String get _placeholder => _labelPos == 'inside' ? '' : (_f.placeholder ?? '');

  List<({String label, String value})> _options(Object? v) {
    final live = [for (final o in _f.options ?? const <UiFbOption>[]) if (o.archived != true) (label: o.label, value: o.value)];
    final chosen = [for (final x in (v is List ? v : (isEmptyValue(v) ? const [] : [v]))) jsString(x)];
    for (final c in chosen) {
      if (live.any((o) => o.value == c)) continue;
      UiFbOption? old;
      for (final o in _f.options ?? const <UiFbOption>[]) {
        if (o.value == c) old = o;
      }
      // Old answers show (and stay chosen) instead of silently vanishing.
      live.add((label: '${old?.label ?? c} (no longer offered)', value: c));
    }
    return live;
  }

  String? _dateBound(String type) {
    for (final v in _f.validators ?? const <UiFbValidatorRule>[]) {
      if (v.type == type) return resolveDateParam(v.params?['date'], widget.today?.call() ?? todayIso());
    }
    return null;
  }

  static String _size(num bytes) {
    if (bytes < 1024) return '${bytes.round()} byte';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} kB';
    final mb = (bytes / 1024 / 1024 * 10).round() / 10;
    return '${mb == mb.truncateToDouble() ? mb.toInt() : mb} MB';
  }

  // ── Files ──────────────────────────────────────────────────────────────────────────────────

  List<UiJson> get _files {
    final v = _e.instanceState(_f.id, widget.row).value;
    return v is List ? [for (final x in v) if (x is Map) x.cast<String, Object?>()] : const [];
  }

  Future<void> _pick(List<UiPickedFile> picked) async {
    final multiple = _f.props?.multiple == true;
    final keep = multiple ? _files : const <UiJson>[];
    final up = widget.uploader;
    final row = widget.row;
    // A fresh dropzone each time: the picked files are listed here, with remove buttons.
    setState(() {
      _pickSeq++;
      _uploadError = '';
    });
    _e.markTouched(_f.id, row);
    if (up == null) {
      final meta = [for (final p in picked) UiFbFileValue(name: p.name, size: p.size, type: p.mimeType ?? '').toJson()];
      final prev = _e.files[addr] ?? const <UiFbPickedFile>[];
      final now = [for (final p in picked) UiFbPickedFile(name: p.name, size: p.size, type: p.mimeType ?? '', handle: p)];
      _e.files[addr] = multiple ? [...prev, ...now] : now;
      _e.setValue(_f.id, row, [...keep, ...meta]);
      return;
    }
    setState(() => _uploading = true);
    try {
      final done = await Future.wait([for (final p in picked) up(p, _f)]);
      _e.setValue(_f.id, row, [...keep, for (final d in done) d.toJson()]);
    } catch (_) {
      if (mounted) setState(() => _uploadError = 'The file could not be uploaded. Try again.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _unpick(int i) {
    final next = [..._files]..removeAt(i);
    final kept = _e.files[addr];
    if (kept != null && i < kept.length) _e.files[addr] = [...kept]..removeAt(i);
    _e.setValue(_f.id, widget.row, next);
  }

  void _rejected(List<UiPickedFile> files) {
    setState(() => _uploadError = files.length == 1
        ? '“${files.first.name}” isn’t a file type this question takes.'
        : '${files.length} files aren’t a type this question takes.');
  }

  // ── Building ───────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final ty = context.uiText;
    final st = _e.instanceState(_f.id, widget.row);
    final shown = st.errors.isNotEmpty && _e.errorsShown(_f.id, widget.row);
    final error = shown ? st.errors.first : '';
    final warnings = _e.errorsShown(_f.id, widget.row) ? st.warnings : const <String>[];
    final display = formatValue(_f, st.value);
    final pos = _labelPos;
    final small = ty.body.copyWith(fontSize: t.fontSizeSm, height: 1.35);

    Widget? head;
    if (pos == 'top' || pos == 'left') head = _label(context, st, grouped: _groupTypes.contains(_f.type));

    final body = <Widget>[];
    if (_viewing) {
      body.add(Text(
        display.isEmpty ? 'Not answered' : display,
        style: ty.body.copyWith(
          fontSize: t.fontSizeMd,
          height: 1.4,
          color: display.isEmpty ? t.textMuted : t.text,
          fontStyle: display.isEmpty ? FontStyle.italic : null,
        ),
      ));
    } else {
      body.add(Focus(
        focusNode: _wrap,
        onFocusChange: _onFocusChange,
        child: UiFieldScope(
          label: _f.label,
          invalid: shown,
          required: st.required,
          link: _link,
          child: _decorated(context, st, shown, error, display),
        ),
      ));
      if (_f.help != null && _f.help!.isNotEmpty) body.add(Text(_f.help!, style: small.copyWith(color: t.textSecondary)));
      if (shown) {
        final announced = Semantics(liveRegion: true, container: true, label: 'Error: $error', child: const SizedBox.shrink());
        body.add(_errInside
            ? announced
            : Semantics(
                liveRegion: true,
                container: true,
                label: 'Error: $error',
                excludeSemantics: true,
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, spacing: 5, children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: UiIcon(HugeIcons.strokeRoundedAlert01, size: 14, strokeWidth: 2, color: t.danger),
                  ),
                  Expanded(child: Text(error, style: small.copyWith(color: t.danger))),
                ]),
              ));
      }
      for (final w in warnings) {
        body.add(Text(w, style: small.copyWith(color: t.warning)));
      }
      if (st.pending && _e.touched.contains(addr)) {
        body.add(Semantics(liveRegion: true, child: Text('Checking…', style: small.copyWith(color: t.textMuted))));
      }
    }
    final bodyCol = Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, spacing: t.space1, children: body);

    Widget out;
    if (pos == 'left') {
      out = LayoutBuilder(builder: (context, c) {
        if (c.maxWidth <= 520) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, spacing: t.space1, children: [head!, bodyCol]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space4, children: [
          SizedBox(
            width: math.max(120, c.maxWidth * 0.32),
            child: Padding(padding: EdgeInsets.only(top: _viewing ? 0 : (t.sizeMd - 19) / 2 + (uiTouchPlatform(context) ? 4 : 0)), child: head),
          ),
          Expanded(child: bodyCol),
        ]);
      });
    } else {
      out = Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, spacing: t.space1, children: [?head, bodyCol]);
    }
    // In view mode the label and the answer read as one: "Full name, Aminath Shareef".
    if (_viewing) out = MergeSemantics(child: out);
    return out;
  }

  Widget _label(BuildContext context, UiFbInstanceState st, {required bool grouped}) {
    final t = context.ui;
    final ty = context.uiText;
    final marker = _e.settings.requiredMarker;
    final text = Text.rich(
      TextSpan(children: [
        TextSpan(text: _f.label),
        if (marker == 'asterisk' && st.required) TextSpan(text: ' *', style: TextStyle(color: t.danger), semanticsLabel: ''),
        if (marker == 'optional' && !st.required && !_viewing && _f.type != UiFbFieldType.calculated)
          TextSpan(text: ' (optional)', style: TextStyle(color: t.textMuted, fontWeight: FontWeight.w400)),
      ]),
      style: ty.label.copyWith(color: t.text, height: 1.35, fontSize: t.fontSizeSm),
    );
    // The control carries the label as its accessible name; in view mode the label is read with the answer.
    if (_viewing) return text;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: focus, excludeFromSemantics: true, child: ExcludeSemantics(child: text));
  }

  /// The control, plus the floating label and the error pill when those are placed inside.
  Widget _decorated(BuildContext context, UiFbInstanceState st, bool shown, String error, String display) {
    final control = _control(context, st, shown, display);
    final inside = _labelPos == 'inside';
    final pill = _errInside && shown;
    if (!inside && !pill) return control;
    final t = context.ui;
    final multiline = _f.type == UiFbFieldType.textarea;
    final hasValue = !isEmptyValue(st.value);
    final floated = _focused || hasValue;
    final dur = context.uiAnimate ? t.motionFast : Duration.zero;
    final steppers = _f.type == UiFbFieldType.number;
    return LayoutBuilder(
      builder: (context, c) => Stack(clipBehavior: Clip.none, children: [
        control,
        if (inside)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedPadding(
                duration: dur,
                curve: t.easeDecelerate,
                padding: EdgeInsetsDirectional.only(start: t.space3 - (floated ? 4 : 0), end: t.space6, top: multiline && !floated ? t.space2 + 1 : 0),
                child: AnimatedAlign(
                  duration: dur,
                  curve: t.easeDecelerate,
                  alignment: floated || multiline ? AlignmentDirectional.topStart : AlignmentDirectional.centerStart,
                  child: AnimatedSlide(
                    duration: dur,
                    curve: t.easeDecelerate,
                    offset: floated ? const Offset(0, -0.5) : Offset.zero,
                    child: AnimatedContainer(
                      duration: dur,
                      padding: EdgeInsets.symmetric(horizontal: floated ? 4 : 0),
                      decoration: BoxDecoration(color: floated ? t.surface : const Color(0x00000000), borderRadius: BorderRadius.circular(t.radiusXs)),
                      child: AnimatedDefaultTextStyle(
                        duration: dur,
                        style: context.uiText.body.copyWith(
                          fontSize: floated ? t.fontSizeSm - 1 : t.fontSizeMd,
                          height: 1.3,
                          color: shown ? t.danger : (_focused ? t.primary : t.textMuted),
                          fontWeight: floated ? FontWeight.w500 : FontWeight.w400,
                        ),
                        child: ExcludeSemantics(
                          child: Text.rich(
                            TextSpan(children: [
                              TextSpan(text: _f.label),
                              if (_e.settings.requiredMarker == 'asterisk' && st.required) TextSpan(text: ' *', style: TextStyle(color: t.danger)),
                            ]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (pill)
          PositionedDirectional(
            end: steppers ? 58 + (uiTouchPlatform(context) ? 40 : 0) : t.space2,
            top: multiline ? null : 0,
            bottom: multiline ? t.space2 : 0,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: math.min(c.maxWidth * 0.44, 210)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: uiMix(t.danger, 0.12, t.surface), borderRadius: BorderRadius.circular(t.radiusXs)),
                      child: Row(mainAxisSize: MainAxisSize.min, spacing: 4, children: [
                        UiIcon(HugeIcons.strokeRoundedAlert01, size: 14, strokeWidth: 2, color: t.danger),
                        Flexible(
                          child: Text(error, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.uiText.body.copyWith(fontSize: 12, height: 1.3, color: t.danger)),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _control(BuildContext context, UiFbInstanceState st, bool invalid, String display) {
    final t = context.ui;
    final ty = context.uiText;
    final f = _f;
    final p = f.props;
    final enabled = !st.disabled;
    final v = st.value;
    final text = v == null ? '' : jsString(v);
    final list = v is List ? [for (final x in v) jsString(x)] : const <String>[];

    if (f.source != null && (f.type == UiFbFieldType.select || f.type == UiFbFieldType.multiselect)) {
      final src = _e.optionSource(f.source!.type);
      if (src == null) {
        return Semantics(
          liveRegion: true,
          child: Text(
            'This list isn’t available right now.${display.isNotEmpty ? ' Saved answer: $display.' : ''}',
            style: ty.body.copyWith(fontSize: t.fontSizeSm, color: t.danger),
          ),
        );
      }
      return UiFbSourcePicker(
        source: src,
        params: _e.sourceParams(f.id, widget.row),
        multiple: f.type == UiFbFieldType.multiselect,
        value: v,
        placeholder: _placeholder.isNotEmpty ? _placeholder : 'Search ${src.label.toLowerCase()}…',
        enabled: enabled,
        invalid: invalid,
        onChanged: _set,
      );
    }

    Widget number() => UiNumberInput(
          value: v is num ? v : null,
          onChanged: enabled ? _set : null,
          min: p?.min,
          max: p?.max,
          step: p?.step ?? 1,
          precision: p?.decimals?.toInt(),
          suffix: f.type == UiFbFieldType.currency ? (p?.currency ?? '') : (p?.suffix ?? ''),
          steppers: f.type != UiFbFieldType.currency,
          placeholder: _placeholder,
          semanticLabel: f.label,
          invalid: invalid,
          enabled: enabled,
        );

    final hints = p?.autocomplete == null ? null : [?_autofill[p!.autocomplete]];

    switch (f.type) {
      case UiFbFieldType.textarea:
        return UiTextarea(
          value: text,
          onChanged: _set,
          rows: (p?.rows ?? 3).toInt(),
          autosize: true,
          maxRows: (p?.maxRows ?? 8).toInt(),
          placeholder: _placeholder,
          autofillHints: hints,
          invalid: invalid,
          enabled: enabled,
        );
      case UiFbFieldType.number:
      case UiFbFieldType.currency:
        return number();
      case UiFbFieldType.date:
        return UiDatePicker(
          value: v is String && v.isNotEmpty ? v : null,
          onChanged: _set,
          placeholder: _placeholder.isNotEmpty ? _placeholder : 'Select a date',
          min: _dateBound('minDate'),
          max: _dateBound('maxDate'),
          invalid: invalid,
          enabled: enabled,
        );
      case UiFbFieldType.time:
        return UiTimePicker(value: v is String && v.isNotEmpty ? v : null, onChanged: _set, invalid: invalid, enabled: enabled);
      case UiFbFieldType.select:
        return UiSelect(
          options: [for (final o in _options(v)) UiSelectOption(label: o.label, value: o.value)],
          value: text.isEmpty ? null : text,
          onChanged: _set,
          placeholder: _placeholder.isNotEmpty ? _placeholder : 'Choose…',
          label: f.label,
          invalid: invalid,
          enabled: enabled,
        );
      case UiFbFieldType.radio:
        return UiRadioGroup<String>(
          options: [for (final o in _options(v)) UiRadioOption(label: o.label, value: o.value)],
          value: text.isEmpty ? null : text,
          onChanged: enabled ? _set : null,
          label: f.label,
          direction: p?.orientation == 'horizontal' ? Axis.horizontal : Axis.vertical,
        );
      case UiFbFieldType.checkboxes:
        return UiCheckboxGroup<String>(
          options: [for (final o in _options(v)) UiCheckboxOption(label: o.label, value: o.value)],
          value: list,
          onChanged: enabled ? _set : null,
          label: f.label,
          direction: p?.orientation == 'horizontal' ? Axis.horizontal : Axis.vertical,
          selectAll: p?.selectAll == true,
        );
      case UiFbFieldType.multiselect:
        return UiMultiSelect(
          options: [for (final o in _options(v)) UiComboboxOption(label: o.label, value: o.value)],
          value: list,
          onChanged: _set,
          placeholder: _placeholder.isNotEmpty ? _placeholder : 'Choose…',
          label: f.label,
          invalid: invalid,
          enabled: enabled,
        );
      case UiFbFieldType.checkbox:
        return UiCheckbox(value: v == true, onChanged: enabled ? _set : null, label: p?.caption ?? f.label, invalid: invalid);
      case UiFbFieldType.toggle:
        return UiSwitch(value: v == true, onChanged: enabled ? _set : null, label: p?.caption ?? 'Yes', semanticLabel: '${f.label}: ${p?.caption ?? 'Yes'}');
      case UiFbFieldType.rating:
        return UiRating(value: v is num ? v.toInt() : 0, onChanged: enabled ? _set : null, max: (p?.maxRating ?? 5).toInt(), label: f.label);
      case UiFbFieldType.slider:
        final min = (p?.min ?? 0).toDouble();
        return UiSlider(
          value: v is num ? v.toDouble() : min,
          onChanged: enabled ? _set : null,
          min: min,
          max: (p?.max ?? 10).toDouble(),
          step: (p?.step ?? 1).toDouble(),
          label: f.label,
        );
      case UiFbFieldType.file:
        return _fileControl(context, st);
      case UiFbFieldType.calculated:
        return Semantics(
          label: f.label,
          value: display.isEmpty ? 'Worked out as you answer' : display,
          readOnly: true,
          container: true,
          excludeSemantics: true,
          child: CustomPaint(
            foregroundPainter: _DashedBorder(color: t.border, radius: context.uiTheme.radius()),
            child: Container(
              constraints: BoxConstraints(minHeight: t.sizeMd),
              padding: EdgeInsets.symmetric(horizontal: t.space3),
              decoration: BoxDecoration(color: t.surfaceSubtle, borderRadius: BorderRadius.circular(context.uiTheme.radius())),
              child: Row(spacing: t.space2, children: [
                UiIcon(HugeIcons.strokeRoundedCalculator, size: 15, color: t.textMuted),
                Expanded(
                  child: Text(
                    display.isEmpty ? 'Worked out as you answer' : display,
                    style: ty.body.copyWith(
                      fontSize: display.isEmpty ? t.fontSizeSm : t.fontSizeMd,
                      color: display.isEmpty ? t.textMuted : t.text,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ]),
            ),
          ),
        );
      default:
        return UiInput(
          value: text,
          onChanged: _set,
          type: switch (f.type) {
            UiFbFieldType.email => UiInputType.email,
            UiFbFieldType.phone => UiInputType.tel,
            UiFbFieldType.url => UiInputType.url,
            _ => UiInputType.text,
          },
          placeholder: _placeholder,
          autofillHints: hints,
          invalid: invalid,
          enabled: enabled,
        );
    }
  }

  Widget _fileControl(BuildContext context, UiFbInstanceState st) {
    final t = context.ui;
    final ty = context.uiText;
    final files = _files;
    final small = ty.body.copyWith(fontSize: t.fontSizeSm, height: 1.35);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, spacing: t.space2, children: [
      UiFileUpload(
        key: ValueKey(_pickSeq),
        picker: widget.filePicker,
        multiple: _f.props?.multiple == true,
        accept: _f.props?.accept,
        enabled: !st.disabled,
        onFilesSelected: _pick,
        onRejected: _rejected,
      ),
      if (files.isNotEmpty)
        Semantics(
          container: true,
          explicitChildNodes: true,
          label: 'Chosen files',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 2, children: [
            for (var i = 0; i < files.length; i++)
              Container(
                padding: EdgeInsetsDirectional.only(start: t.space2),
                decoration: BoxDecoration(color: t.surfaceSubtle, borderRadius: BorderRadius.circular(context.uiTheme.radius())),
                child: Row(spacing: t.space2, children: [
                  Expanded(
                    child: Text(jsString(files[i]['name']), maxLines: 1, overflow: TextOverflow.ellipsis, style: small.copyWith(color: t.text)),
                  ),
                  Text(_size(files[i]['size'] is num ? files[i]['size'] as num : 0),
                      style: small.copyWith(color: t.textMuted, fontFeatures: const [FontFeature.tabularFigures()])),
                  UiInteractive(
                    onTap: () => _unpick(i),
                    enabled: !st.disabled,
                    semanticLabel: 'Remove ${jsString(files[i]['name'])}',
                    excludeChildSemantics: true,
                    pressScale: false,
                    builder: (context, s) => Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: s.hovered ? t.surfaceHover : null,
                        borderRadius: BorderRadius.circular(t.radiusXs),
                        boxShadow: s.focused ? t.focusRing : const [],
                      ),
                      child: UiIcon(HugeIcons.strokeRoundedCancel01, size: 14, color: s.hovered ? t.text : t.textMuted),
                    ),
                  ),
                ]),
              ),
          ]),
        ),
      if (_uploading) Semantics(liveRegion: true, child: Text('Uploading…', style: small.copyWith(color: t.textMuted))),
      if (_uploadError.isNotEmpty) Semantics(liveRegion: true, child: Text(_uploadError, style: small.copyWith(color: t.danger))),
    ]);
  }
}

/// The dashed outline of a calculated field (the web `border: 1px dashed`).
class _DashedBorder extends CustomPainter {
  _DashedBorder({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius((Offset.zero & size).deflate(0.5), Radius.circular(radius));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 7) {
        canvas.drawPath(metric.extractPath(d, math.min(d + 4, metric.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color || old.radius != radius;
}
