import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/icon.dart';
import '../../core/types.dart';
import '../../theme/theme.dart';
import 'form_field.dart';
import 'text_core.dart';

/// The web input `type`s: each picks the matching keyboard (and [password] hides the text).
enum UiInputType { text, email, url, tel, password, search }

TextInputType _keyboardFor(UiInputType type) => switch (type) {
      UiInputType.email => TextInputType.emailAddress,
      UiInputType.url => TextInputType.url,
      UiInputType.tel => TextInputType.phone,
      UiInputType.password => TextInputType.visiblePassword,
      UiInputType.search || UiInputType.text => TextInputType.text,
    };

/// `ui-input`: a single-line text field.
///
/// Controlled with [value] + [onChanged], or pass a [controller]. [autofillHints] is the web
/// `autocomplete` (e.g. `[AutofillHints.email]`). Inside a [UiFormField] it takes the field's label
/// as its accessible name and shows the field's error.
class UiInput extends StatefulWidget {
  const UiInput({
    super.key,
    this.value,
    this.onChanged,
    this.controller,
    this.focusNode,
    this.type = UiInputType.text,
    this.placeholder = '',
    this.keyboardType,
    this.autofillHints,
    this.size = UiSize.md,
    this.invalid = false,
    this.radius,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.onSubmitted,
    this.textInputAction,
    this.inputFormatters,
    this.semanticLabel,
  });

  final String? value;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final UiInputType type;
  final String placeholder;

  /// The web `inputmode`: overrides the keyboard the [type] picks.
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final UiSize size;
  final bool invalid;
  final bool? radius;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;

  /// Accessible name when no [UiFormField] label names it.
  final String? semanticLabel;

  @override
  State<UiInput> createState() => _UiInputState();
}

class _UiInputState extends State<UiInput> with UiTextControllerMixin {
  @override
  TextEditingController? get externalController => widget.controller;
  @override
  FocusNode? get externalFocusNode => widget.focusNode;
  @override
  String? get controlledValue => widget.value;

  @override
  void didUpdateWidget(UiInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncControlledValue();
  }

  @override
  void dispose() {
    disposeTextController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return ListenableBuilder(
      listenable: focusNode,
      builder: (context, _) => UiFieldFrame(
        height: widget.size.height(t),
        focused: focusNode.hasFocus,
        invalid: uiFieldInvalid(context, widget.invalid),
        enabled: widget.enabled,
        radius: widget.radius,
        padding: EdgeInsets.symmetric(horizontal: t.space3),
        child: UiTextEditor(
          controller: controller,
          focusNode: focusNode,
          style: uiFieldTextStyle(context, widget.size),
          placeholder: widget.placeholder,
          enabled: widget.enabled,
          readOnly: widget.readOnly,
          obscureText: widget.type == UiInputType.password,
          keyboardType: widget.keyboardType ?? _keyboardFor(widget.type),
          textInputAction: widget.textInputAction ?? (widget.type == UiInputType.search ? TextInputAction.search : null),
          autofillHints: widget.autofillHints,
          inputFormatters: widget.inputFormatters,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          autofocus: widget.autofocus,
          semanticLabel: widget.semanticLabel,
        ),
      ),
    );
  }
}

/// `ui-textarea`: a multi-line text field.
///
/// Shows [rows] lines. With [autosize] it grows with the text from [rows] up to [maxRows] lines,
/// then scrolls; without it, it stays [rows] tall and scrolls.
class UiTextarea extends StatefulWidget {
  const UiTextarea({
    super.key,
    this.value,
    this.onChanged,
    this.controller,
    this.focusNode,
    this.placeholder = '',
    this.rows = 4,
    this.autosize = false,
    this.maxRows = 8,
    this.autofillHints,
    this.invalid = false,
    this.radius,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.semanticLabel,
    this.maxLength,
  });

  final String? value;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String placeholder;
  final int rows;
  final bool autosize;
  final int maxRows;
  final Iterable<String>? autofillHints;
  final bool invalid;
  final bool? radius;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final String? semanticLabel;

  /// The most characters it takes (the web `maxlength`): typing and pasting stop there.
  final int? maxLength;

  @override
  State<UiTextarea> createState() => _UiTextareaState();
}

class _UiTextareaState extends State<UiTextarea> with UiTextControllerMixin {
  @override
  TextEditingController? get externalController => widget.controller;
  @override
  FocusNode? get externalFocusNode => widget.focusNode;
  @override
  String? get controlledValue => widget.value;

  @override
  void didUpdateWidget(UiTextarea old) {
    super.didUpdateWidget(old);
    syncControlledValue();
  }

  @override
  void dispose() {
    disposeTextController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final style = context.uiText.body.copyWith(fontSize: t.fontSizeMd, height: 1.5, color: t.text);
    return ListenableBuilder(
      listenable: focusNode,
      builder: (context, _) => UiFieldFrame(
        focused: focusNode.hasFocus,
        invalid: uiFieldInvalid(context, widget.invalid),
        enabled: widget.enabled,
        radius: widget.radius,
        padding: EdgeInsets.symmetric(horizontal: t.space3, vertical: t.space2),
        child: UiTextEditor(
          controller: controller,
          focusNode: focusNode,
          style: style,
          placeholder: widget.placeholder,
          enabled: widget.enabled,
          readOnly: widget.readOnly,
          minLines: widget.rows,
          maxLines: widget.autosize ? math.max(widget.rows, widget.maxRows) : widget.rows,
          autofillHints: widget.autofillHints,
          onChanged: widget.onChanged,
          autofocus: widget.autofocus,
          semanticLabel: widget.semanticLabel,
          inputFormatters: widget.maxLength == null ? null : [LengthLimitingTextInputFormatter(widget.maxLength)],
        ),
      ),
    );
  }
}

/// `ui-password-input`: a password field with a show/hide button ("Show password" / "Hide
/// password"). [autofillHints] defaults to the current password; use
/// `[AutofillHints.newPassword]` on sign-up forms.
class UiPasswordInput extends StatefulWidget {
  const UiPasswordInput({
    super.key,
    this.value,
    this.onChanged,
    this.controller,
    this.focusNode,
    this.placeholder = '',
    this.size = UiSize.md,
    this.autofillHints = const [AutofillHints.password],
    this.invalid = false,
    this.radius,
    this.enabled = true,
    this.autofocus = false,
    this.onSubmitted,
    this.semanticLabel,
  });

  final String? value;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String placeholder;
  final UiSize size;
  final Iterable<String>? autofillHints;
  final bool invalid;
  final bool? radius;
  final bool enabled;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  final String? semanticLabel;

  @override
  State<UiPasswordInput> createState() => _UiPasswordInputState();
}

class _UiPasswordInputState extends State<UiPasswordInput> with UiTextControllerMixin {
  bool _reveal = false;

  @override
  TextEditingController? get externalController => widget.controller;
  @override
  FocusNode? get externalFocusNode => widget.focusNode;
  @override
  String? get controlledValue => widget.value;

  @override
  void didUpdateWidget(UiPasswordInput old) {
    super.didUpdateWidget(old);
    syncControlledValue();
  }

  @override
  void dispose() {
    disposeTextController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final h = widget.size.height(t);
    return ListenableBuilder(
      listenable: focusNode,
      builder: (context, _) => UiFieldFrame(
        height: h,
        focused: focusNode.hasFocus,
        invalid: uiFieldInvalid(context, widget.invalid),
        enabled: widget.enabled,
        radius: widget.radius,
        padding: const EdgeInsetsDirectional.only(end: 2),
        child: Row(children: [
          Expanded(
            child: Padding(
              padding: EdgeInsetsDirectional.only(start: t.space3),
              child: UiTextEditor(
                controller: controller,
                focusNode: focusNode,
                style: uiFieldTextStyle(context, widget.size),
                placeholder: widget.placeholder,
                enabled: widget.enabled,
                obscureText: !_reveal,
                keyboardType: TextInputType.visiblePassword,
                autofillHints: widget.autofillHints,
                onChanged: widget.onChanged,
                onSubmitted: widget.onSubmitted,
                autofocus: widget.autofocus,
                semanticLabel: widget.semanticLabel,
              ),
            ),
          ),
          UiFieldButton(
            label: _reveal ? 'Hide password' : 'Show password',
            visual: math.min(t.sizeSm, h - 4),
            focusable: true,
            enabled: widget.enabled,
            onTap: () => setState(() => _reveal = !_reveal),
            icon: UiIcon(_reveal ? HugeIcons.strokeRoundedViewOff : HugeIcons.strokeRoundedView),
          ),
        ]),
      ),
    );
  }
}

/// `ui-search-input`: a pill-shaped search field with a search icon and a clear button that
/// appears once there is text. Clearing empties it and puts focus back in the field.
class UiSearchInput extends StatefulWidget {
  const UiSearchInput({
    super.key,
    this.value,
    this.onChanged,
    this.controller,
    this.focusNode,
    this.placeholder = 'Search…',
    this.label,
    this.size = UiSize.md,
    this.radius,
    this.enabled = true,
    this.autofocus = false,
    this.onSubmitted,
  });

  final String? value;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String placeholder;

  /// Accessible name when no [UiFormField] label names it (a toolbar search).
  final String? label;
  final UiSize size;
  final bool? radius;
  final bool enabled;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  @override
  State<UiSearchInput> createState() => _UiSearchInputState();
}

class _UiSearchInputState extends State<UiSearchInput> with UiTextControllerMixin {
  @override
  TextEditingController? get externalController => widget.controller;
  @override
  FocusNode? get externalFocusNode => widget.focusNode;
  @override
  String? get controlledValue => widget.value;

  @override
  void didUpdateWidget(UiSearchInput old) {
    super.didUpdateWidget(old);
    syncControlledValue();
  }

  @override
  void dispose() {
    disposeTextController();
    super.dispose();
  }

  void _clear() {
    controller.clear();
    widget.onChanged?.call('');
    focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final h = widget.size.height(t);
    return ListenableBuilder(
      listenable: Listenable.merge([focusNode, controller]),
      builder: (context, _) => UiFieldFrame(
        height: h,
        focused: focusNode.hasFocus,
        enabled: widget.enabled,
        radius: widget.radius,
        borderRadius: t.radiusPill,
        padding: EdgeInsetsDirectional.only(start: widget.size == UiSize.sm ? t.space2 : t.space3, end: t.space1),
        child: Row(spacing: t.space2, children: [
          UiIcon(HugeIcons.strokeRoundedSearch01, size: 16, color: t.textMuted),
          Expanded(
            child: UiTextEditor(
              controller: controller,
              focusNode: focusNode,
              style: uiFieldTextStyle(context, widget.size),
              placeholder: widget.placeholder,
              enabled: widget.enabled,
              textInputAction: TextInputAction.search,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              autofocus: widget.autofocus,
              semanticLabel: widget.label,
            ),
          ),
          if (controller.text.isNotEmpty)
            UiFieldButton(
              label: 'Clear search',
              visual: 20,
              round: true,
              focusable: true,
              enabled: widget.enabled,
              onTap: _clear,
              icon: const UiIcon(HugeIcons.strokeRoundedCancel01, strokeWidth: 2),
            ),
        ]),
      ),
    );
  }
}
