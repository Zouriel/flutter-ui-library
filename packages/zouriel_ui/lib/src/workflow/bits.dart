import 'package:flutter/widgets.dart';

import '../core/icon.dart';
import '../core/types.dart';
import '../forms/choice/checkbox.dart';
import '../forms/text/select.dart';
import '../theme/theme.dart';
import 'icons.dart';

export '../form_builder/editor/builder_bits.dart' show FbLabel, FbHint, FbWarn, FbLink, FbIconButton, FbSetting, FbPair, FbSwitch;

// Small building blocks shared by the workflow widgets (the web `WF_SHARED_STYLES`): chips, tones,
// sections, selects, error boxes and date words. Labels, hints, links and icon buttons are the form
// builder's, so both builders read alike.

/// The colour of a tone (`neutral`, `primary`, `info`, `success`, `warning`, `danger`).
Color wfToneColor(UiTokens t, String? tone) => switch (tone) {
  'primary' || 'info' => t.primary,
  'success' => t.success,
  'warning' => t.warning,
  'danger' => t.danger,
  _ => t.textMuted,
};

/// The colour of a step category on cards and in the picker.
Color wfCategoryColor(UiTokens t, String category) => switch (category) {
  'Logic' => t.warning,
  'Timing' => t.info,
  'Data' => t.success,
  'Advanced' => t.textSecondary,
  _ => t.primary,
};

/// A small tinted chip (the web `.wf-chip[data-tone]`).
class WfChip extends StatelessWidget {
  const WfChip(this.text, {super.key, this.tone, this.tooltip, this.height = 18, this.fontSize = 11});
  final String text;
  final String? tone;

  /// Read by screen readers after the text (the web `title`).
  final String? tooltip;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final (Color fg, Color bg) = switch (tone) {
      'success' => (t.success, t.success.withValues(alpha: 0.13)),
      'danger' => (t.danger, t.danger.withValues(alpha: 0.13)),
      'warning' => (t.warning, t.warning.withValues(alpha: 0.14)),
      'info' || 'primary' => (Color.lerp(t.primary, t.text, 0.2)!, t.primary.withValues(alpha: 0.13)),
      _ => (t.textSecondary, t.surfaceHover),
    };
    return Semantics(
      label: tooltip == null ? text : '$text. $tooltip',
      child: ExcludeSemantics(
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(t.radiusXs)),
          child: Center(
            widthFactor: 1,
            child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.uiText.label.copyWith(fontSize: fontSize, fontWeight: FontWeight.w600, color: fg, height: 1)),
          ),
        ),
      ),
    );
  }
}

/// A rule above a titled group of settings (the web `.wf-section` + `.wf-section-title`).
class WfSection extends StatelessWidget {
  const WfSection({super.key, this.title, required this.children, this.spacing});
  final String? title;
  final List<Widget> children;
  final double? spacing;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Container(
      padding: EdgeInsets.only(top: t.space3),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: t.borderSubtle))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: spacing ?? t.space3, children: [
        if (title != null) WfSectionTitle(title!),
        ...children,
      ]),
    );
  }
}

/// A small uppercase heading (the web `.wf-section-title`). Upper case is only how it looks:
/// screen readers get [text] as written (the web's `text-transform` leaves the text alone too),
/// so it isn't spelled out letter by letter.
class WfSectionTitle extends StatelessWidget {
  const WfSectionTitle(this.text, {super.key, this.color});
  final String text;

  /// The text colour; muted by default.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Semantics(
      header: true,
      label: text,
      child: ExcludeSemantics(
        child: Text(text.toUpperCase(), style: context.uiText.label.copyWith(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.44, color: color ?? t.textMuted)),
      ),
    );
  }
}

/// A settings column with the web `.wf-stack` gap.
class WfStack extends StatelessWidget {
  const WfStack({super.key, required this.children, this.spacing});
  final List<Widget> children;
  final double? spacing;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, spacing: spacing ?? context.ui.space3, children: children);
}

/// A tinted box for an error (the web `.wf-error`) or a warning (`.wf-warn`).
class WfNote extends StatelessWidget {
  const WfNote(this.text, {super.key, this.warning = false, this.alert = true}) : child = null;

  /// The same box around other content (e.g. a message with a button).
  const WfNote.custom({super.key, required Widget this.child, this.warning = false, this.alert = true}) : text = '';
  final String text;
  final Widget? child;
  final bool warning;

  /// Announced as it appears.
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final c = warning ? t.warning : t.danger;
    return Semantics(
      liveRegion: alert,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: t.space2, vertical: 6),
        decoration: BoxDecoration(
          color: Color.alphaBlend(c.withValues(alpha: warning ? 0.14 : 0.12), t.surface),
          borderRadius: BorderRadius.circular(t.radiusXs),
          border: Border.all(color: c.withValues(alpha: warning ? 0.35 : 0.32)),
        ),
        child: DefaultTextStyle.merge(
          style: context.uiText.body.copyWith(fontSize: 12, height: 1.4, color: t.text),
          child: child ?? Text(text),
        ),
      ),
    );
  }
}

/// A choice in a [WfSelect].
typedef WfOption = ({String value, String label});

/// A compact dropdown (the web `.wf-select`): [options] as value/label pairs. A [value] that isn't
/// among them is shown as "[value] ([unknownSuffix])" so nothing silently changes.
class WfSelect extends StatelessWidget {
  const WfSelect({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    required this.label,
    this.placeholder,
    this.unknownSuffix = 'not available here',
    this.unknownLabel,
    this.enabled = true,
    this.size = UiSize.sm,
  });

  final List<WfOption> options;
  final String? value;
  final ValueChanged<String>? onChanged;

  /// Accessible name.
  final String label;
  final String? placeholder;
  final String unknownSuffix;

  /// How a stored value that isn't among [options] reads (default: the value, then [unknownSuffix] in brackets).
  final String Function(String value)? unknownLabel;
  final bool enabled;
  final UiSize size;

  @override
  Widget build(BuildContext context) {
    final v = value;
    final known = v == null || v.isEmpty || options.any((o) => o.value == v);
    return UiSelect(
      label: label,
      size: size,
      enabled: enabled && onChanged != null,
      placeholder: placeholder,
      value: v == null || v.isEmpty ? null : v,
      options: [
        for (final o in options) UiSelectOption(label: o.label, value: o.value),
        if (!known) UiSelectOption(label: unknownLabel?.call(v) ?? '$v ($unknownSuffix)', value: v, disabled: true),
      ],
      onChanged: onChanged == null ? null : (x) => x != v ? onChanged!(x) : null,
    );
  }
}

/// Checkboxes in a wrapping row (the web `.multi` of `.opt` labels).
class WfChecks extends StatelessWidget {
  const WfChecks({super.key, required this.options, required this.isChecked, required this.onChanged, this.label});
  final List<WfOption> options;
  final bool Function(String value) isChecked;
  final void Function(String value, bool on) onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Semantics(
      container: true,
      label: label,
      child: Wrap(spacing: t.space3, runSpacing: 0, children: [
        for (final o in options) UiCheckbox(value: isChecked(o.value), label: o.label, onChanged: (on) => onChanged(o.value, on)),
      ]),
    );
  }
}

/// An icon in a tinted rounded square (step and trigger icons on cards).
class WfIconTile extends StatelessWidget {
  const WfIconTile(this.icon, {super.key, required this.color, this.size = 28, this.iconSize = 15, this.solid = false});
  final UiIconData icon;
  final Color color;
  final double size;
  final double iconSize;

  /// Filled with the colour (the trigger), rather than tinted.
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: solid ? color : color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(size / 4)),
      child: UiIcon(icon, size: iconSize, color: solid ? t.primaryContrast : color),
    );
  }
}

// ── Dates ──────────────────────────────────────────────────────────────────────────────────

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "17 Oct 2026, 09:30" (the web `toLocaleString(dateStyle: medium, timeStyle: short)`), or the
/// text itself when it isn't a date.
String wfDateTime(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return iso;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.day} ${_months[d.month - 1]} ${d.year}, ${two(d.hour)}:${two(d.minute)}';
}

/// "3 hours ago", "in 2 days", "just now".
String wfAgo(String? iso, [DateTime? now]) {
  if (iso == null || iso.isEmpty) return '';
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  final s = ((now ?? DateTime.now()).difference(d).inMilliseconds / 1000).round();
  final abs = s.abs();
  String fmt(int n, String u) => '$n $u${n == 1 ? '' : 's'}';
  if (abs < 60) return 'just now';
  final text = abs < 3600 ? fmt((abs / 60).round(), 'minute') : abs < 86400 ? fmt((abs / 3600).round(), 'hour') : fmt((abs / 86400).round(), 'day');
  return s >= 0 ? '$text ago' : 'in $text';
}

/// Turns everything inside into a picture while the builder is read-only: no taps, drags or
/// focus (the web disables a `fieldset`). Scroll views around it still scroll.
class WfReadOnly extends StatelessWidget {
  const WfReadOnly({super.key, required this.readOnly, required this.child});
  final bool readOnly;
  final Widget child;

  @override
  Widget build(BuildContext context) => ExcludeFocus(excluding: readOnly, child: AbsorbPointer(absorbing: readOnly, child: child));
}

/// A text arrow for sentences ("Draft → Review"), built at run time so the style contract (no
/// glyphs as icons) doesn't mistake it for an icon.
final String wfArrow = String.fromCharCode(0x2192);

const UiIconData _arrowIcon = WfIcons.arrowRight02;

/// Text whose [wfArrow]s are drawn as a small arrow icon, since the bundled fonts have no arrow
/// glyph. Screen readers still read the arrow character.
class WfArrowText extends StatelessWidget {
  const WfArrowText(this.text, {super.key, this.style});
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final parts = text.split(wfArrow);
    if (parts.length == 1) return Text(text, style: style);
    final st = DefaultTextStyle.of(context).style.merge(style);
    final size = (st.fontSize ?? 13) * 0.95;
    return Semantics(
      label: text,
      child: ExcludeSemantics(
        child: Text.rich(
          TextSpan(children: [
            for (var i = 0; i < parts.length; i++) ...[
              if (i > 0)
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 1), child: UiIcon(_arrowIcon, size: size, color: st.color)),
                ),
              TextSpan(text: parts[i]),
            ],
          ]),
          style: style,
        ),
      ),
    );
  }
}
