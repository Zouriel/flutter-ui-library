import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/icon.dart';
import '../../core/interactive.dart';
import '../../core/types.dart';
import '../../overlay/anchored.dart';
import '../../theme/theme.dart';
import 'form_field.dart';
import 'inputs.dart';
import 'phone.dart';
import 'text_core.dart';

export 'phone.dart';

/// `ui-phone-input`: a phone number as one E.164 string ("+447700900123"): a country button (flag
/// and dial code, opening a searchable list of every country) beside the national number field.
///
/// In: a [value] picks its country by dial code (the longest that exists; for a shared code like +1,
/// the country whose leading digits match, else [defaultCountry] if it shares the code, else the
/// code's main country) and the field shows the national digits as stored. With no value,
/// [defaultCountry] (ISO 3166 alpha-2) is chosen; without one, no country is (a globe and "+").
///
/// Out ([onChanged]): '+', the dial code, and the typed digits with spaces, dashes, dots and brackets
/// dropped and the country's trunk prefix removed (the UK's leading 0; never Italy's 0, which belongs
/// to the number). Typing or pasting "+44…" or "0044…" switches the country. Empty, or no country:
/// null. Whether the number is valid is the app's job; show it with [invalid] or a [UiFormField]
/// error. Twin of Angular's `ui-phone-input`.
class UiPhoneInput extends StatefulWidget {
  const UiPhoneInput({
    super.key,
    this.value,
    this.onChanged,
    this.defaultCountry,
    this.onCountryChanged,
    this.placeholder,
    this.semanticLabel,
    this.size = UiSize.md,
    this.invalid = false,
    this.radius,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
  });

  /// E.164 ("+447700900123") or null.
  final String? value;
  final ValueChanged<String?>? onChanged;

  /// ISO 3166 alpha-2 ('GB', 'US', 'MV') chosen while the value is empty. No default otherwise.
  final String? defaultCountry;

  /// The user picked a country (from the list, or by typing a '+' number): its ISO code.
  final ValueChanged<String>? onCountryChanged;
  final String? placeholder;

  /// The number field's name; default the [UiFormField]'s label, else [UiStrings.phoneNumber].
  final String? semanticLabel;
  final UiSize size;
  final bool invalid;
  final bool? radius;
  final bool enabled;

  /// The number field's focus node.
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<UiPhoneInput> createState() => _UiPhoneInputState();
}

class _UiPhoneInputState extends State<UiPhoneInput> {
  final TextEditingController _text = TextEditingController();
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode(debugLabel: 'phone country search');
  final FocusNode _triggerFocus = FocusNode(debugLabel: 'phone country');
  final ScrollController _list = ScrollController();
  final OverlayPortalController _overlay = OverlayPortalController();
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode(debugLabel: 'phone number'));

  UiPhoneCountry? _country;

  /// Whether the country came from a value or the user (then defaultCountry no longer moves it).
  bool _fixed = false;

  /// The last value sent out, so it isn't written back over what the user is typing.
  String? _sent;
  bool _open = false;
  int _active = 0;
  List<UiPhoneCountry> _filtered = uiPhoneCountries;

  @override
  void initState() {
    super.initState();
    _write(widget.value);
  }

  @override
  void didUpdateWidget(UiPhoneInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _sent && widget.value != oldWidget.value) {
      _write(widget.value);
    } else if (widget.defaultCountry != oldWidget.defaultCountry && !_fixed && _text.text.isEmpty) {
      _country = uiPhoneCountry(widget.defaultCountry);
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _search.dispose();
    _searchFocus.dispose();
    _triggerFocus.dispose();
    _list.dispose();
    _ownFocus?.dispose();
    super.dispose();
  }

  /// Shows a value from outside: its country and its national digits as stored.
  void _write(String? v) {
    _sent = v;
    final parsed = v == null || v.isEmpty ? null : uiPhoneSplit(uiPhoneInternationalDigits(v.startsWith('+') ? v : '+$v'), defaultCountry: widget.defaultCountry);
    if (parsed != null) {
      _country = parsed.country;
      _fixed = true;
      _setText(parsed.national);
    } else {
      _fixed = false;
      _country = uiPhoneCountry(widget.defaultCountry);
      _setText('');
    }
  }

  void _setText(String t) {
    if (_text.text != t) _text.value = TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }

  String? get _value {
    final c = _country;
    return c == null ? null : uiPhoneE164(c, _text.text);
  }

  void _emit() {
    final v = _value;
    _sent = v;
    widget.onChanged?.call(v);
  }

  void _setCountry(UiPhoneCountry c) {
    final changed = c != _country;
    _country = c;
    _fixed = true;
    if (changed) widget.onCountryChanged?.call(c.iso2);
  }

  void _onText(String text) {
    if (uiPhoneIsInternational(text)) {
      final parsed = uiPhoneSplit(uiPhoneInternationalDigits(text), defaultCountry: widget.defaultCountry);
      if (parsed != null) {
        _setCountry(parsed.country);
        _setText(parsed.national);
      }
    }
    if (_text.text.isNotEmpty) _fixed = true;
    setState(() {});
    _emit();
  }

  void _toggle() => _open ? _close(refocus: true) : _show();

  void _show() {
    if (!widget.enabled || _open) return;
    _search.clear();
    _filtered = uiPhoneCountries;
    final i = _country == null ? 0 : uiPhoneCountries.indexOf(_country!);
    _active = i < 0 ? 0 : i;
    setState(() => _open = true);
    _overlay.show();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_open) return;
      _searchFocus.requestFocus();
      _reveal(center: true);
    });
  }

  void _close({required bool refocus}) {
    if (!_open) return;
    setState(() => _open = false);
    _overlay.hide();
    if (refocus) _triggerFocus.requestFocus();
  }

  /// Picks a country: closes the list, emits the new value, and moves to the number field.
  void _choose(UiPhoneCountry c) {
    _setCountry(c);
    setState(() => _open = false);
    _overlay.hide();
    _focus.requestFocus();
    _emit();
  }

  void _onSearch(String q) {
    setState(() {
      _filtered = uiPhoneSearch(q);
      _active = 0;
    });
    _reveal();
  }

  double get _rowHeight => uiTouchPlatform(context) ? uiMinTouchTarget : 32;

  /// Keeps the active row in view.
  void _reveal({bool center = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_list.hasClients) return;
      final pos = _list.position;
      final top = _active * _rowHeight, bottom = top + _rowHeight;
      double to = pos.pixels;
      if (center) {
        to = top - (pos.viewportDimension - _rowHeight) / 2;
      } else if (top < pos.pixels) {
        to = top;
      } else if (bottom > pos.pixels + pos.viewportDimension) {
        to = bottom - pos.viewportDimension;
      }
      pos.jumpTo(to.clamp(pos.minScrollExtent, pos.maxScrollExtent));
    });
  }

  KeyEventResult _onSearchKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final n = _filtered.length;
    int? next;
    if (k == LogicalKeyboardKey.arrowDown) {
      next = n == 0 ? 0 : (_active + 1).clamp(0, n - 1);
    } else if (k == LogicalKeyboardKey.arrowUp) {
      next = (_active - 1).clamp(0, n == 0 ? 0 : n - 1);
    } else if (k == LogicalKeyboardKey.home) {
      next = 0;
    } else if (k == LogicalKeyboardKey.end) {
      next = n == 0 ? 0 : n - 1;
    } else if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
      if (_active < n) _choose(_filtered[_active]);
      return KeyEventResult.handled;
    } else if (k == LogicalKeyboardKey.escape) {
      _close(refocus: true);
      return KeyEventResult.handled;
    } else if (k == LogicalKeyboardKey.tab) {
      _close(refocus: false);
      return KeyEventResult.ignored;
    } else {
      return KeyEventResult.ignored;
    }
    setState(() => _active = next!);
    _reveal();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final s = context.uiStrings;
    final scope = UiFieldScope.maybeOf(context);
    final c = _country;
    final rounded = widget.radius ?? theme.config.radius;
    final r = rounded ? t.radius : 0.0;
    final scale = MediaQuery.textScalerOf(context).scale(t.fontSizeMd) / t.fontSizeMd;
    final boxHeight = widget.size.height(t) * (scale > 1 ? scale : 1);
    final style = uiFieldTextStyle(context, widget.size).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    final countryName = c == null ? s.phoneCountry : '${s.phoneCountry}: ${c.name} +${c.dial}';

    final trigger = Semantics(
      expanded: _open,
      child: UiInteractive(
        key: const ValueKey('ui-phone-trigger'),
        onTap: _toggle,
        enabled: widget.enabled,
        focusNode: _triggerFocus,
        semanticLabel: countryName,
        excludeChildSemantics: true,
        pressScale: false,
        padTouchTarget: false,
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.arrowDown): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.arrowUp): ActivateIntent(),
        },
        builder: (context, st) {
          final corner = Radius.circular(r > 1 ? r - 1 : 0);
          return Center(
            child: Container(
              height: boxHeight - 2,
              margin: const EdgeInsetsDirectional.only(start: 1),
              padding: EdgeInsetsDirectional.only(start: t.space3 - 1, end: t.space2),
              decoration: BoxDecoration(
                color: st.hovered || st.pressed ? t.surfaceHover : null,
                border: BorderDirectional(end: BorderSide(color: t.border)),
                borderRadius: BorderRadiusDirectional.horizontal(start: corner).resolve(Directionality.of(context)),
              ),
              foregroundDecoration: st.focused
                  ? BoxDecoration(
                      border: Border.all(color: t.primary, width: 2),
                      borderRadius: BorderRadiusDirectional.horizontal(start: corner).resolve(Directionality.of(context)),
                    )
                  : null,
              child: Row(mainAxisSize: MainAxisSize.min, spacing: t.space1, children: [
                if (c != null)
                  Text(c.flag, key: const ValueKey('ui-phone-flag'), style: style.copyWith(fontSize: style.fontSize! * 1.15, height: 1))
                else
                  UiIcon(HugeIcons.strokeRoundedGlobal, key: const ValueKey('ui-phone-globe'), size: 16, strokeWidth: 1.6, color: t.textMuted),
                Text(c == null ? '+' : '+${c.dial}', key: const ValueKey('ui-phone-dial'), style: style.copyWith(height: 1)),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: context.uiAnimate ? t.motionFast : Duration.zero,
                  child: UiIcon(HugeIcons.strokeRoundedArrowDown01, size: 12, strokeWidth: 2, color: t.textMuted),
                ),
              ]),
            ),
          );
        },
      ),
    );

    final field = ListenableBuilder(
      listenable: _focus,
      builder: (context, _) => UiFieldFrame(
        height: widget.size.height(t),
        focused: _focus.hasFocus,
        active: _open,
        invalid: uiFieldInvalid(context, widget.invalid),
        enabled: widget.enabled,
        radius: widget.radius,
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          trigger,
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: t.space3),
              child: UiTextEditor(
                key: const ValueKey('ui-phone-number'),
                controller: _text,
                focusNode: _focus,
                style: style,
                placeholder: widget.placeholder,
                enabled: widget.enabled,
                autofocus: widget.autofocus,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumberNational],
                onChanged: _onText,
                semanticLabel: widget.semanticLabel ?? (scope?.label != null ? null : s.phoneNumber),
              ),
            ),
          ),
        ]),
      ),
    );

    return UiAnchoredOverlay(
      controller: _overlay,
      matchAnchorWidth: true,
      minWidth: 280,
      onDismiss: () => _close(refocus: false),
      panelBuilder: (context, anchor) => _panel(context),
      child: field,
    );
  }

  Widget _panel(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final s = context.uiStrings;
    final rowStyle = context.uiText.body.copyWith(fontSize: t.fontSizeMd, height: 1.35, color: t.text);
    final codeStyle = rowStyle.copyWith(fontSize: t.fontSizeSm, color: t.textMuted, fontFeatures: const [FontFeature.tabularFigures()]);
    final listHeight = (_filtered.length * _rowHeight).clamp(0.0, 260.0);

    Widget option(int i) {
      final c = _filtered[i];
      final selected = c == _country;
      final active = i == _active;
      final fill = selected ? (active ? uiMix(t.selected, 0.5, t.elevatedHover) : t.selected) : active ? t.elevatedHover : null;
      return MouseRegion(
        onEnter: (_) => setState(() => _active = i),
        child: UiInteractive(
          key: ValueKey('ui-phone-option-${c.iso2}'),
          onTap: () => _choose(c),
          button: false,
          selected: selected,
          semanticLabel: '${c.name} +${c.dial}',
          excludeChildSemantics: true,
          pressScale: false,
          padTouchTarget: false,
          builder: (context, st) => Container(
            height: _rowHeight,
            padding: EdgeInsets.symmetric(horizontal: t.space2),
            decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(theme.radius(t.radiusXs))),
            child: Row(spacing: t.space2, children: [
              Text(c.flag, style: rowStyle.copyWith(height: 1)),
              Expanded(
                child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false, style: rowStyle.copyWith(fontWeight: selected ? FontWeight.w600 : null)),
              ),
              Text('+${c.dial}', style: codeStyle),
            ]),
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Container(
        padding: EdgeInsets.all(t.space1),
        decoration: BoxDecoration(
          color: t.surfaceRaised,
          border: Border.all(color: t.border),
          borderRadius: BorderRadius.circular(theme.radius()),
          boxShadow: t.shadow2,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space1, children: [
          Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: _onSearchKey,
            child: UiInput(
              key: const ValueKey('ui-phone-search'),
              controller: _search,
              focusNode: _searchFocus,
              type: UiInputType.search,
              placeholder: s.phoneSearch,
              semanticLabel: s.phoneSearch,
              onChanged: _onSearch,
              onSubmitted: (_) {
                if (_active < _filtered.length) _choose(_filtered[_active]);
              },
            ),
          ),
          if (_filtered.isEmpty)
            Padding(
              padding: EdgeInsets.all(t.space2),
              child: Text(s.noResults, style: codeStyle),
            )
          else
            SizedBox(
              height: listHeight,
              child: Semantics(
                label: s.phoneCountry,
                container: true,
                explicitChildNodes: true,
                child: ExcludeFocus(
                  child: ListView.builder(
                    controller: _list,
                    padding: EdgeInsets.zero,
                    itemExtent: _rowHeight,
                    itemCount: _filtered.length,
                    itemBuilder: (context, i) => option(i),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
