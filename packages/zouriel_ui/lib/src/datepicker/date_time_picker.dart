import 'package:flutter/widgets.dart';

import '../core/types.dart';
import '../forms/text/time_picker.dart';
import '../theme/theme.dart';
import 'date_names.dart';
import 'date_picker.dart';

/// `ui-date-time-picker` (0.87.0): a [UiDatePicker] and a [UiTimePicker] side by side for one local
/// date-time, `YYYY-MM-DDTHH:MM` (`HH:MM:SS` when [step] is under 60), null while there is no date.
///
/// The date takes the room left beside a 136px time field; at 320px wide or less the two stack. Picking a
/// date before any time emits it with [defaultTime] (and the time field shows it); changing either part
/// emits the two together. A time picked before a date is kept until a date comes. [min] / [max] (date-time
/// or date strings) limit the calendar by their date part. The parts are named [dateLabel] and
/// [timeLabel] (else [UiStrings.dateLabel] / [UiStrings.timeLabel]).
class UiDateTimePicker extends StatefulWidget {
  const UiDateTimePicker({
    super.key,
    this.value,
    this.onChanged,
    this.min,
    this.max,
    this.step = 60,
    this.size = UiSize.md,
    this.radius,
    this.invalid = false,
    this.placeholder,
    this.defaultTime = '09:00',
    this.dateLabel,
    this.timeLabel,
    this.enabled = true,
  });

  final String? value;
  final ValueChanged<String?>? onChanged;
  final String? min;
  final String? max;

  /// Granularity of the time in seconds (as [UiTimePicker.step]).
  final int step;
  final UiSize size;
  final bool? radius;
  final bool invalid;

  /// The date field's placeholder.
  final String? placeholder;

  /// The time a date gets when it is picked before a time (`HH:MM`).
  final String defaultTime;
  final String? dateLabel;
  final String? timeLabel;
  final bool enabled;

  @override
  State<UiDateTimePicker> createState() => _UiDateTimePickerState();
}

class _UiDateTimePickerState extends State<UiDateTimePicker> {
  String? _date, _time;

  @override
  void initState() {
    super.initState();
    _read(widget.value);
  }

  @override
  void didUpdateWidget(UiDateTimePicker old) {
    super.didUpdateWidget(old);
    if (widget.value != old.value && widget.value != _combined) _read(widget.value);
  }

  /// Splits a value into its parts; a value without a date clears the date and keeps no time.
  void _read(String? value) {
    final m = RegExp(r'^(\d{4}-\d{2}-\d{2})(?:[T ](\d{1,2}:\d{2}(?::\d{2})?))?').firstMatch(value ?? '');
    _date = m == null || uiParseIsoDate(m[1]) == null ? null : m[1];
    _time = _date == null ? null : (m![2] == null ? null : _fit(m[2]!));
  }

  /// A time in the step's shape: seconds added or dropped.
  String _fit(String time) {
    final parts = time.split(':');
    final hm = '${parts[0].padLeft(2, '0')}:${parts[1]}';
    return widget.step < 60 ? '$hm:${parts.length > 2 ? parts[2] : '00'}' : hm;
  }

  String? get _combined => _date == null ? null : '${_date}T${_time ?? _fit(widget.defaultTime)}';

  void _emit() {
    final next = _combined;
    if (next != null && next != widget.value) widget.onChanged?.call(next);
  }

  void _pickDate(String date) {
    setState(() {
      _date = date;
      _time ??= _fit(widget.defaultTime);
    });
    _emit();
  }

  void _pickTime(String time) {
    setState(() => _time = time);
    _emit();
  }

  /// The date part of a limit ("2026-05-01T10:00" limits the calendar to 2026-05-01).
  static String? _datePart(String? limit) => limit == null || limit.length < 10 ? limit : limit.substring(0, 10);

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final strings = context.uiStrings;
    final date = UiDatePicker(
      value: _date,
      onChanged: _pickDate,
      placeholder: widget.placeholder,
      size: widget.size,
      radius: widget.radius,
      min: _datePart(widget.min),
      max: _datePart(widget.max),
      invalid: widget.invalid,
      enabled: widget.enabled,
      label: widget.dateLabel ?? strings.dateLabel,
    );
    final time = UiTimePicker(
      value: _time,
      onChanged: _pickTime,
      step: widget.step,
      size: widget.size,
      radius: widget.radius,
      invalid: widget.invalid,
      enabled: widget.enabled,
      label: widget.timeLabel ?? strings.timeLabel,
    );
    // The web's role="group": one container holding the two named parts.
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: LayoutBuilder(
        builder: (context, box) => box.maxWidth <= 320
            ? Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [date, time])
            : Row(spacing: t.space2, children: [Expanded(child: date), SizedBox(width: 136, child: time)]),
      ),
    );
  }
}
