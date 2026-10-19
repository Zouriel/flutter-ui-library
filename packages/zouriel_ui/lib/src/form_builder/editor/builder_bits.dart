import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../button/button.dart';
import '../../core/icon.dart';
import '../../core/interactive.dart';
import '../../core/types.dart';
import '../../forms/choice/switch.dart';
import '../../theme/theme.dart';
import '../engine/schema.dart';

// Small building blocks shared by the builder's panels (the web `FB_SHARED_STYLES`): labels,
// hints, chips, link buttons, sections and the icons for each kind of thing.

const Map<String, UiIconData> _fieldIcons = {
  'text': HugeIcons.strokeRoundedText,
  'textarea': HugeIcons.strokeRoundedTextAlignLeft,
  'email': HugeIcons.strokeRoundedMail01,
  'phone': HugeIcons.strokeRoundedCall02,
  'url': HugeIcons.strokeRoundedLink01,
  'number': HugeIcons.strokeRoundedHashtag,
  'currency': HugeIcons.strokeRoundedDollar01,
  'date': HugeIcons.strokeRoundedCalendar01,
  'time': HugeIcons.strokeRoundedClock02,
  'select': HugeIcons.strokeRoundedArrowDown01,
  'radio': HugeIcons.strokeRoundedCircleDot,
  'checkboxes': HugeIcons.strokeRoundedCheckList,
  'multiselect': HugeIcons.strokeRoundedTags,
  'checkbox': HugeIcons.strokeRoundedCheckmarkSquare02,
  'toggle': HugeIcons.strokeRoundedToggleOn,
  'rating': HugeIcons.strokeRoundedStar,
  'slider': HugeIcons.strokeRoundedSlidersHorizontal,
  'file': HugeIcons.strokeRoundedFileUpload,
  'hidden': HugeIcons.strokeRoundedViewOff,
  'calculated': HugeIcons.strokeRoundedCalculator,
};

/// The icon of a field type (short text for unknown types).
UiIconData fbFieldIcon(UiFbFieldType type) => _fieldIcons[type.name] ?? HugeIcons.strokeRoundedText;

/// The icon of a heading, text block or divider.
UiIconData fbStaticIcon(String type) => switch (type) {
  'heading' => HugeIcons.strokeRoundedHeading,
  'paragraph' => HugeIcons.strokeRoundedParagraph,
  _ => HugeIcons.strokeRoundedMinusSign,
};

const UiIconData fbGroupIcon = HugeIcons.strokeRoundedLayers01;
const UiIconData fbRepeatIcon = HugeIcons.strokeRoundedRepeat;

/// The icon of any element.
UiIconData fbElementIcon(UiFbElement el) => switch (el) {
  UiFbField(:final type) => fbFieldIcon(type),
  UiFbGroup(:final repeat) => repeat != null ? fbRepeatIcon : fbGroupIcon,
  UiFbStatic(:final type) => fbStaticIcon(type),
};

/// A setting's label (the web `.fb-label`).
class FbLabel extends StatelessWidget {
  const FbLabel(this.text, {super.key, this.required = false});
  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final style = context.uiText.label.copyWith(fontSize: 12, fontWeight: FontWeight.w500, color: t.textSecondary, height: 1.3);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text.rich(TextSpan(text: text, children: [if (required) TextSpan(text: ' *', style: TextStyle(color: t.danger))]), style: style),
    );
  }
}

/// A short explanation under a setting (the web `.fb-hint`).
class FbHint extends StatelessWidget {
  const FbHint(this.text, {super.key, this.bad = false});
  final String text;
  final bool bad;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Text(text, style: context.uiText.body.copyWith(fontSize: 12, height: 1.35, color: bad ? t.danger : t.textMuted));
  }
}

/// A warning note in a tinted box (the web `.fb-warn`).
class FbWarn extends StatelessWidget {
  const FbWarn({super.key, this.text, this.child});
  final String? text;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: t.space2, vertical: 6),
      decoration: BoxDecoration(
        color: Color.alphaBlend(t.warning.withValues(alpha: 0.14), t.surface),
        borderRadius: BorderRadius.circular(t.radiusXs),
        border: Border.all(color: t.warning.withValues(alpha: 0.35)),
      ),
      child: DefaultTextStyle.merge(
        style: context.uiText.body.copyWith(fontSize: 12, height: 1.4, color: t.text),
        child: child ?? Text(text ?? ''),
      ),
    );
  }
}

enum FbTone { neutral, logic, warn, bad, ok }

/// A small status chip on a card or rule (the web `.fb-chip`).
class FbChip extends StatelessWidget {
  const FbChip(this.text, {super.key, this.tone = FbTone.neutral, this.tooltip});
  final String text;
  final FbTone tone;

  /// Read by screen readers after the chip's text (the web `title`).
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final (Color fg, Color bg) = switch (tone) {
      FbTone.neutral => (t.textSecondary, t.surfaceHover),
      FbTone.logic => (Color.lerp(t.primary, t.text, 0.25)!, t.primary.withValues(alpha: 0.13)),
      FbTone.warn => (t.warning, t.warning.withValues(alpha: 0.14)),
      FbTone.bad => (t.danger, t.danger.withValues(alpha: 0.13)),
      FbTone.ok => (t.success, t.success.withValues(alpha: 0.13)),
    };
    return Semantics(
      label: tooltip == null ? text : '$text. $tooltip',
      child: ExcludeSemantics(
        child: Container(
          height: 18,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(t.radiusXs)),
          child: Center(widthFactor: 1, child: Text(text, maxLines: 1, style: context.uiText.label.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: fg, height: 1))),
        ),
      ),
    );
  }
}

/// A text button that reads as a link: "Add a rule", "Restore" (the web `.fb-link`).
class FbLink extends StatelessWidget {
  const FbLink({super.key, required this.label, required this.onTap, this.icon, this.color, this.fontSize = 13});
  final String label;
  final VoidCallback? onTap;
  final UiIconData? icon;
  final Color? color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return UiInteractive(
      onTap: onTap,
      semanticLabel: label,
      excludeChildSemantics: true,
      pressScale: false,
      builder: (context, s) {
        final c = s.disabled ? t.textDisabled : (color ?? t.primary);
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(t.radiusXs), boxShadow: s.focused ? t.focusRing : null),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 4,
            children: [
              if (icon != null) UiIcon(icon!, size: fontSize, color: c, strokeWidth: 2),
              Text(
                label,
                style: context.uiText.label.copyWith(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  color: c,
                  decoration: s.hovered ? TextDecoration.underline : null,
                  decorationColor: c,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A small icon button (the web `.fb-icon-btn`).
class FbIconButton extends StatelessWidget {
  const FbIconButton({super.key, required this.icon, required this.label, required this.onPressed, this.danger = false});
  final UiIconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return UiIconButton(
      icon: UiIcon(icon, size: 16),
      label: label,
      size: UiSize.sm,
      iconColor: onPressed == null ? t.textDisabled : (danger ? t.danger : t.textMuted),
      onPressed: onPressed,
    );
  }
}

/// A setting: its label, the control and an optional hint underneath.
class FbSetting extends StatelessWidget {
  const FbSetting({super.key, required this.label, required this.child, this.hint, this.badHint = false, this.required = false});
  final String label;
  final Widget child;
  final String? hint;
  final bool badHint;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FbLabel(label, required: required),
        child,
        if (hint != null && hint!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: FbHint(hint!, bad: badHint)),
      ],
    );
  }
}

/// A control (or a row of them) with hints 4px underneath, kept together so the hints read as
/// belonging to it rather than taking the panel's wider gap.
class FbHinted extends StatelessWidget {
  const FbHinted({super.key, required this.child, required this.hints});
  final Widget child;
  final List<String> hints;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [child, for (final h in hints) Padding(padding: EdgeInsets.only(top: context.ui.space1), child: FbHint(h))],
      );
}

/// A titled group of settings with a rule above it (the web `.group-sec`).
class FbSection extends StatelessWidget {
  const FbSection({super.key, required this.title, required this.children, this.first = false});
  final String title;
  final List<Widget> children;

  /// No rule above it (the first section of a panel).
  final bool first;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Container(
      padding: EdgeInsets.only(top: first ? 0 : t.space3),
      decoration: first ? null : BoxDecoration(border: Border(top: BorderSide(color: t.borderSubtle))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: t.space2,
        children: [
          FbHeading(title),
          ...children,
        ],
      ),
    );
  }
}

/// A section heading in a settings panel (the web `.group-sec h3`); the Checks tab uses it too.
class FbHeading extends StatelessWidget {
  const FbHeading(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) =>
      Semantics(header: true, child: Text(text, style: context.uiText.label.copyWith(fontSize: 13, color: context.ui.text)));
}

/// Two settings side by side when there's room, stacked when there isn't (the web `.fb-grid2`).
class FbPair extends StatelessWidget {
  const FbPair({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 300 ? 2 : 1;
      final w = cols == 2 ? (c.maxWidth - t.space2) / 2 : c.maxWidth;
      // Bottom-aligned, so boxes line up when one label wraps onto two lines.
      return Wrap(spacing: t.space2, runSpacing: t.space2, crossAxisAlignment: WrapCrossAlignment.end, children: [for (final ch in children) SizedBox(width: w, child: ch)]);
    });
  }
}

/// A sentence that reads a rule back (the web `.sentence`).
class FbSentence extends StatelessWidget {
  const FbSentence(this.text, {super.key, this.tinted = true});
  final String text;
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: t.space2, vertical: 6),
      decoration: BoxDecoration(color: tinted ? t.primary.withValues(alpha: 0.08) : t.surfaceHover, borderRadius: BorderRadius.circular(t.radiusXs)),
      child: Text(text, style: context.uiText.body.copyWith(fontSize: 12, height: 1.4, color: t.textSecondary)),
    );
  }
}

/// A bordered box around one rule, jump or check (the web `.setv` / `.rule`).
class FbBox extends StatelessWidget {
  const FbBox({super.key, required this.children, this.dashed = false});
  final List<Widget> children;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Container(
      padding: EdgeInsets.all(t.space2),
      decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.borderSubtle), borderRadius: BorderRadius.circular(t.radius)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: children),
    );
  }
}

/// A row title with a trailing remove button ("When" … ×).
class FbRowHead extends StatelessWidget {
  const FbRowHead({super.key, required this.title, this.removeLabel, this.onRemove, this.trailing});
  final Widget title;
  final String? removeLabel;
  final VoidCallback? onRemove;
  final List<Widget>? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: title),
      ...?trailing,
      if (onRemove != null) FbIconButton(icon: HugeIcons.strokeRoundedCancel01, label: removeLabel ?? 'Remove', danger: true, onPressed: onRemove),
    ]);
  }
}

/// A switch that sits at the start of its row (a [UiSwitch] alone centres itself in the width it gets).
class FbSwitch extends StatelessWidget {
  const FbSwitch({super.key, required this.value, required this.label, required this.onChanged, this.size = UiSize.md});
  final bool value;
  final String label;
  final ValueChanged<bool>? onChanged;

  /// [UiSize.sm] in dense panels (the inspector and settings), so its label matches the fields.
  final UiSize size;

  @override
  Widget build(BuildContext context) =>
      Align(alignment: AlignmentDirectional.centerStart, widthFactor: 1, child: UiSwitch(size: size, value: value, label: label, onChanged: onChanged));
}
