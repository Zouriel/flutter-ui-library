import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../button/button.dart';
import '../../button/segmented.dart';
import '../../core/icon.dart';
import '../../core/interactive.dart';
import '../../core/types.dart';
import '../../forms/text/inputs.dart';
import '../../theme/theme.dart';
import '../engine/localize.dart';
import '../engine/schema.dart';
import 'builder_bits.dart';
import 'builder_store.dart';

/// Languages offered when adding one (any other code can be typed).
const List<String> uiFbSuggestedLocales = ['dv', 'en', 'ar', 'hi', 'si', 'ta', 'bn', 'ur', 'fr', 'es', 'de', 'zh'];

final RegExp _codePattern = RegExp(r'^[A-Za-z]{2,3}([-_][A-Za-z0-9]{2,8})*$');

/// `ui-fb-languages`: the languages of the form. Add one, remove one, pick the default (the
/// language everything is first written in) and set each language's writing direction.
class UiFbLanguages extends StatefulWidget {
  const UiFbLanguages({super.key});

  @override
  State<UiFbLanguages> createState() => _UiFbLanguagesState();
}

class _UiFbLanguagesState extends State<UiFbLanguages> {
  String _code = '';
  String _error = '';
  String? _confirming;
  int _inputRun = 0;

  void _add(UiFormBuilderController store, String code) {
    final ok = store.addLocale(code, dir: fbDefaultDir(code));
    setState(() => _error = ok ? '' : 'That language is already in the form.');
  }

  void _addCustom(UiFormBuilderController store) {
    final c = _code.trim();
    if (c.isEmpty) return;
    if (!_codePattern.hasMatch(c)) {
      setState(() => _error = 'Use a language code like “dv”, “fr” or “pt-BR”.');
      return;
    }
    _add(store, c.replaceFirst('_', '-'));
    if (_error.isEmpty) {
      setState(() {
        _code = '';
        _inputRun++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final store = UiFbBuilderScope.of(context);
    final locales = store.locales;
    final suggestions = [for (final c in uiFbSuggestedLocales) if (!locales.any((l) => l.code == c)) c];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
      const FbHint('Write everything in the default language first, then switch to another language in the toolbar to translate side by side. A question with no translation shows in the default language.'),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
        for (final l in locales) ...[
          Container(
            padding: EdgeInsets.all(t.space2),
            decoration: BoxDecoration(border: Border.all(color: t.borderSubtle), borderRadius: BorderRadius.circular(t.radius)),
            child: Wrap(spacing: t.space2, runSpacing: t.space2, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Directionality(
                textDirection: l.dir == UiFbDir.rtl ? TextDirection.rtl : TextDirection.ltr,
                child: Text(l.label, style: context.uiText.label.copyWith(fontSize: 14 * t.fontScale, fontWeight: FontWeight.w600, color: t.text)),
              ),
              Text(l.code.toUpperCase(), style: context.uiText.body.copyWith(fontSize: 12, color: t.textMuted)),
              if (l.code == store.defaultLocale) const FbChip('Default'),
              UiSegmented<String>(
                label: 'Direction of ${l.label}',
                size: UiSize.sm,
                value: l.dir.name,
                options: const [UiSegmentedOption(value: 'ltr', label: 'Left to right'), UiSegmentedOption(value: 'rtl', label: 'Right to left')],
                onChanged: (v) => store.setLocaleDir(l.code, UiFbDir(v)),
              ),
              if (l.code != store.defaultLocale) ...[
                UiButton(label: 'Make default', size: UiSize.sm, variant: UiButtonVariant.ghost, onPressed: () => store.setDefaultLocale(l.code)),
                FbIconButton(icon: HugeIcons.strokeRoundedDelete02, label: 'Remove ${l.label}', danger: true, onPressed: () => setState(() => _confirming = l.code)),
              ],
            ]),
          ),
          if (_confirming == l.code)
            Semantics(
              liveRegion: true,
              child: Padding(
                padding: EdgeInsets.all(t.space2),
                child: Wrap(spacing: t.space2, runSpacing: t.space2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text(
                    'Remove ${l.label}? Its translations are deleted from every question. You can undo this.',
                    style: context.uiText.body.copyWith(fontSize: 13 * t.fontScale, color: t.danger),
                  ),
                  UiButton(label: 'Keep', size: UiSize.sm, variant: UiButtonVariant.ghost, onPressed: () => setState(() => _confirming = null)),
                  UiButton(
                    label: 'Remove',
                    size: UiSize.sm,
                    variant: UiButtonVariant.destructive,
                    onPressed: () {
                      setState(() => _confirming = null);
                      store.removeLocale(l.code);
                    },
                  ),
                ]),
              ),
            ),
        ],
      ]),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
        const FbLabel('Add a language'),
        Wrap(spacing: t.space1, runSpacing: t.space1, children: [
          for (final c in suggestions) _SuggestionChip(label: '${fbLocaleName(c)} ($c)', onTap: () => _add(store, c)),
        ]),
        Row(spacing: t.space2, children: [
          Expanded(
            child: UiInput(
              key: ValueKey(_inputRun),
              size: UiSize.sm,
              value: _code,
              placeholder: 'Other code, e.g. pt-BR',
              semanticLabel: 'Language code',
              onChanged: (v) => _code = v,
              onSubmitted: (_) => _addCustom(store),
            ),
          ),
          UiButton(label: 'Add', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: () => _addCustom(store)),
        ]),
        if (_error.isNotEmpty) Semantics(liveRegion: true, child: FbHint(_error, bad: true)),
      ]),
    ]);
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return UiInteractive(
      onTap: onTap,
      semanticLabel: 'Add $label',
      excludeChildSemantics: true,
      pressScale: false,
      builder: (context, s) => Container(
        height: 28,
        padding: EdgeInsets.symmetric(horizontal: t.space3),
        decoration: BoxDecoration(
          color: s.hovered ? t.surfaceHover : null,
          border: Border.all(color: t.border),
          borderRadius: BorderRadius.circular(14),
          boxShadow: s.focused ? t.focusRing : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, spacing: 4, children: [
          UiIcon(HugeIcons.strokeRoundedAdd01, size: 12, color: t.text, strokeWidth: 2),
          Text(label, style: context.uiText.body.copyWith(fontSize: 13 * t.fontScale, color: t.text)),
        ]),
      ),
    );
  }
}
