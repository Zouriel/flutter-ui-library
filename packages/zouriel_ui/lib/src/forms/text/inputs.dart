import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/icon.dart';
import '../../core/types.dart';
import '../../theme/theme.dart';
import 'form_field.dart';
import 'text_core.dart';
import 'text_dir.dart';

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
///
/// [leading] and [trailing] are content slots inside the border (the web `[input-leading]` /
/// `[input-trailing]`): an icon or a small [UiIconButton], at the inline start and end (they swap in
/// RTL), with the text between them. A tap on a slot's empty space focuses the field. [dir] sets the
/// writing direction ([UiTextDir.auto] follows the text typed), [textStyle] is merged over the field
/// font (e.g. `TextStyle(fontFamily: 'Faruma')` to type Thaana in the app's own font).
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
    this.leading,
    this.trailing,
    this.dir,
    this.textStyle,
  });

  final String? value;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final UiInputType type;

  /// Inside the border at the inline start (the web `[input-leading]`).
  final Widget? leading;

  /// Inside the border at the inline end (the web `[input-trailing]`).
  final Widget? trailing;

  /// The writing direction (the web `dir`); null keeps the surrounding [Directionality].
  final UiTextDir? dir;

  /// Merged over the field's text style (and its placeholder): a font family, `fontFamilyFallback`.
  final TextStyle? textStyle;
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
    final lead = widget.leading, trail = widget.trailing;
    return UiFieldDirection(
      dir: widget.dir,
      controller: controller,
      child: ListenableBuilder(
      listenable: focusNode,
      builder: (context, _) => UiFieldFrame(
        height: widget.size.height(t),
        focused: focusNode.hasFocus,
        invalid: uiFieldInvalid(context, widget.invalid),
        enabled: widget.enabled,
        radius: widget.radius,
        padding: EdgeInsetsDirectional.only(start: lead != null ? t.space1 : t.space3, end: trail != null ? t.space1 : t.space3),
        child: _withSlots(t, UiTextEditor(
          controller: controller,
          focusNode: focusNode,
          style: uiMergeFieldStyle(uiFieldTextStyle(context, widget.size), widget.textStyle),
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
        )),
      ),
      ),
    );
  }

  Widget _withSlots(UiTokens t, Widget editor) {
    final lead = widget.leading, trail = widget.trailing;
    if (lead == null && trail == null) return editor;
    return Row(children: [
      if (lead != null) ...[UiFieldSlot(focusNode: focusNode, enabled: widget.enabled, child: lead), SizedBox(width: t.space2)],
      Expanded(child: editor),
      if (trail != null) ...[SizedBox(width: t.space2), UiFieldSlot(focusNode: focusNode, enabled: widget.enabled, child: trail)],
    ]);
  }
}

/// `ui-textarea`: a multi-line text field.
///
/// Shows [rows] lines. With [autosize] it grows with the text from [rows] up to [maxRows] lines,
/// then scrolls; without it, it stays [rows] tall and scrolls.
///
/// [leading] and [trailing] are content slots inside the border (the web `[textarea-leading]` /
/// `[textarea-trailing]`), at the inline start and end (they swap in RTL), aligned to the last line
/// so they stay at the bottom while it grows. A tap on a slot's empty space focuses the field; a
/// [UiIconButton] in a slot keeps its 48dp touch target without making the box taller. [dir] and
/// [textStyle] as on [UiInput].
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
    this.size = UiSize.md,
    this.leading,
    this.trailing,
    this.dir,
    this.textStyle,
  });

  /// Inside the border at the inline start, on the last line (the web `[textarea-leading]`).
  final Widget? leading;

  /// Inside the border at the inline end, on the last line (the web `[textarea-trailing]`).
  final Widget? trailing;

  /// The writing direction (the web `dir`); null keeps the surrounding [Directionality].
  final UiTextDir? dir;

  /// Merged over the field's text style (and its placeholder): a font family, `fontFamilyFallback`.
  final TextStyle? textStyle;

  final String? value;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String placeholder;

  /// Text size, matching UiInput's sizes; [UiSize.sm] for dense panels.
  final UiSize size;
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
    final style = uiMergeFieldStyle(context.uiText.body.copyWith(fontSize: uiFieldFontSize(t, widget.size), height: 1.5, color: t.text), widget.textStyle);
    final padY = widget.size == UiSize.sm ? t.space1 : t.space2;
    final editor = UiTextEditor(
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
        );
    final lead = widget.leading, trail = widget.trailing;
    return UiFieldDirection(
      dir: widget.dir,
      controller: controller,
      child: ListenableBuilder(
        listenable: focusNode,
        builder: (context, _) {
          final invalid = uiFieldInvalid(context, widget.invalid);
          if (lead == null && trail == null) {
            return UiFieldFrame(
              focused: focusNode.hasFocus,
              invalid: invalid,
              enabled: widget.enabled,
              radius: widget.radius,
              padding: EdgeInsets.symmetric(horizontal: t.space3, vertical: padY),
              child: editor,
            );
          }
          // With slots: the box is drawn behind a row of [slot, text, slot]. The slots are as tall as
          // the last line (its padding included) and sit at the bottom, so they stay on the line
          // being typed as the box grows. On touch screens a transparent margin above and below
          // keeps a slot button's 48dp hit area inside the widget without making the box taller.
          final lineBox = (style.fontSize ?? t.fontSizeMd) * MediaQuery.textScalerOf(context).scale(1) * 1.5 + 2 * padY;
          final m = uiSlotTouchMargin(context, lineBox);
          const border = 1.0;
          return Opacity(
            opacity: widget.enabled ? 1 : 0.5,
            child: Stack(children: [
              Positioned.fill(
                top: m,
                bottom: m,
                child: UiFieldFrame(focused: focusNode.hasFocus, invalid: invalid, radius: widget.radius, child: const SizedBox.expand()),
              ),
              Padding(
                padding: EdgeInsetsDirectional.only(start: border + (lead != null ? t.space1 : t.space3), end: border + (trail != null ? t.space1 : t.space3)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  if (lead != null) ...[
                    UiFieldSlot(focusNode: focusNode, enabled: widget.enabled, height: lineBox + 2 * m, child: lead),
                    SizedBox(width: t.space2),
                  ],
                  Expanded(child: Padding(padding: EdgeInsets.symmetric(vertical: m + border + padY), child: editor)),
                  if (trail != null) ...[
                    SizedBox(width: t.space2),
                    UiFieldSlot(focusNode: focusNode, enabled: widget.enabled, height: lineBox + 2 * m, child: trail),
                  ],
                ]),
              ),
            ]),
          );
        },
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
