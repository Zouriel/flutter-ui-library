import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../theme/theme.dart';

/// Connects a [UiFormField]'s label to the control inside it: the control attaches its focus node
/// so a tap on the label focuses it, and once a control has attached, the visible label stops
/// being announced separately (the control carries it as its own name).
class UiFieldLink extends ChangeNotifier {
  FocusNode? _node;

  /// Whether a control inside has taken the label as its name.
  bool get claimed => _node != null;

  FocusNode? get node => _node;

  void attach(FocusNode node) {
    if (_node == node) return;
    _node = node;
    _notifyLater();
  }

  void detach(FocusNode node) {
    if (_node != node) return;
    _node = null;
    _notifyLater();
  }

  /// Focuses the control, as clicking a `<label>` does on the web.
  void focus() {
    final n = _node;
    if (n != null && n.canRequestFocus) n.requestFocus();
  }

  bool _disposed = false;

  void _notifyLater() {
    // Controls attach while building; tell the label after the frame.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) notifyListeners();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// What a [UiFormField] tells the control inside it: the label (the control's accessible name),
/// whether it's in error, and whether it's required.
class UiFieldScope extends InheritedWidget {
  const UiFieldScope({super.key, this.label, this.invalid = false, this.required = false, this.link, required super.child});

  final String? label;
  final bool invalid;
  final bool required;
  final UiFieldLink? link;

  static UiFieldScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<UiFieldScope>();

  @override
  bool updateShouldNotify(UiFieldScope old) => old.label != label || old.invalid != invalid || old.required != required || old.link != link;
}

/// Whether a control should draw its error look: its own `invalid` or an enclosing field's error.
bool uiFieldInvalid(BuildContext context, bool invalid) => invalid || (UiFieldScope.maybeOf(context)?.invalid ?? false);

/// `ui-form-field`: a label, hint and error around one control.
///
/// The label names the control for screen readers (the control announces it as its own name) and
/// tapping the label focuses the control. When [error] is set it replaces the hint, turns the
/// control's border red and is announced. [required] draws the `*` marker and marks the control as
/// required for assistive tech.
///
/// For validation inside a Flutter [Form], use [UiFormField.validated]: it wraps a [FormField], so
/// `Form.of(context).validate()` runs [validator] and the message shows here as the error.
///
/// ```dart
/// UiFormField<String>.validated(
///   label: 'Email',
///   required: true,
///   validator: (v) => v!.contains('@') ? null : 'Enter an email address',
///   builder: (field) => UiInput(value: field.value, onChanged: field.didChange),
/// )
/// ```
class UiFormField<T> extends StatefulWidget {
  /// A plain label/hint/error wrapper; [error] comes from you.
  const UiFormField({super.key, this.label, this.hint, this.error, this.required = false, required Widget this.child})
      : builder = null,
        validator = null,
        initialValue = null,
        onSaved = null,
        autovalidateMode = null,
        enabled = true,
        requiredMessage = null,
        isEmpty = null;

  /// A [FormField] with this field's label, hint and error. [builder] gets the [FormFieldState]:
  /// bind the control's value to `field.value` and its onChanged to `field.didChange`.
  ///
  /// With [required], an empty value (null, '', an empty list, or whatever [isEmpty] says) fails
  /// with [requiredMessage] before [validator] runs.
  const UiFormField.validated({
    super.key,
    this.label,
    this.hint,
    this.error,
    this.required = false,
    required FormFieldBuilder<T> this.builder,
    this.validator,
    this.initialValue,
    this.onSaved,
    this.autovalidateMode,
    this.enabled = true,
    this.requiredMessage,
    this.isEmpty,
  }) : child = null;

  final String? label;

  /// Helper text, hidden while there is an error.
  final String? hint;

  /// An error message from outside (with [UiFormField.validated] the validator's message wins).
  final String? error;
  final bool required;
  final Widget? child;
  final FormFieldBuilder<T>? builder;
  final FormFieldValidator<T>? validator;
  final T? initialValue;
  final FormFieldSetter<T>? onSaved;
  final AutovalidateMode? autovalidateMode;
  final bool enabled;

  /// The message for an empty required field. Defaults to "[label] is required".
  final String? requiredMessage;

  /// Decides emptiness for [required] when the default (null, '', empty list) doesn't fit.
  final bool Function(T? value)? isEmpty;

  @override
  State<UiFormField<T>> createState() => _UiFormFieldState<T>();
}

class _UiFormFieldState<T> extends State<UiFormField<T>> {
  final UiFieldLink _link = UiFieldLink();

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  bool _empty(T? v) {
    if (widget.isEmpty != null) return widget.isEmpty!(v);
    if (v == null) return true;
    if (v is String) return v.trim().isEmpty;
    if (v is Iterable) return v.isEmpty;
    if (v is Map) return v.isEmpty;
    return false;
  }

  String? _validate(T? v) {
    if (widget.required && _empty(v)) return widget.requiredMessage ?? uiFormatString(context.uiStrings.fieldRequired, {'label': widget.label ?? context.uiStrings.thisField});
    return widget.validator?.call(v);
  }

  Widget _decorate(String? error, Widget child) {
    final t = context.ui;
    final ty = context.uiText;
    final label = widget.label;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: t.space1,
      children: [
        if (label != null && label.isNotEmpty)
          ListenableBuilder(
            listenable: _link,
            builder: (context, _) {
              final text = Text.rich(
                TextSpan(children: [
                  TextSpan(text: label),
                  if (widget.required) TextSpan(text: ' *', style: TextStyle(color: t.danger), semanticsLabel: ''),
                ]),
                style: ty.label.copyWith(color: t.text, height: 1.35),
              );
              // The control announces the label as its name; a label with no control to name stays readable.
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _link.focus,
                excludeFromSemantics: true,
                child: _link.claimed ? ExcludeSemantics(child: text) : text,
              );
            },
          ),
        UiFieldScope(label: label, invalid: error != null, required: widget.required, link: _link, child: child),
        if (error != null)
          Semantics(
            liveRegion: true,
            container: true,
            child: Text(error, style: ty.caption.copyWith(color: t.danger, height: 1.35)),
          )
        else if (widget.hint != null && widget.hint!.isNotEmpty)
          Text(widget.hint!, style: ty.caption.copyWith(height: 1.35)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.builder == null) return _decorate(widget.error, widget.child!);
    return FormField<T>(
      initialValue: widget.initialValue,
      validator: _validate,
      onSaved: widget.onSaved,
      autovalidateMode: widget.autovalidateMode,
      enabled: widget.enabled,
      builder: (field) => _decorate(field.errorText ?? widget.error, widget.builder!(field)),
    );
  }
}
