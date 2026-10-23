import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/icon.dart';

import '../core/interactive.dart';
import '../core/types.dart';
import '../theme/theme.dart';

/// `ui-badge`: a small status or count label. [dot] draws an 8px dot with no text.
class UiBadge extends StatelessWidget {
  const UiBadge({super.key, this.label, this.tone = UiStatus.neutral, this.dot = false, this.semanticLabel})
      : assert(dot || label != null, 'A badge needs a label unless it is a dot.');

  final String? label;
  final UiStatus tone;
  final bool dot;

  /// Accessible text for a dot badge (e.g. "Online").
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final solid = tone != UiStatus.neutral;
    final fill = solid ? tone.color(t) : t.surfaceRaised;
    final fg = solid ? tone.contrast(t) : t.text;
    if (dot) {
      return Semantics(
        label: semanticLabel,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: solid ? fill : t.textMuted, shape: BoxShape.circle),
        ),
      );
    }
    return Container(
      height: 20 * t.densityScale,
      padding: EdgeInsets.symmetric(horizontal: t.space2),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(t.radiusPill),
        border: Border.all(color: solid ? const Color(0x00000000) : t.border),
      ),
      // Hug the text: Container(alignment:) would stretch to the full available width.
      child: Align(
        widthFactor: 1,
        child: Text(
        label!,
        maxLines: 1,
        style: context.uiText.body.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 16 / 11,
          color: fg,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      ),
    );
  }
}

/// `ui-chip`: a compact tag, optionally removable. The remove button is named "Remove [label]".
///
/// On phones the remove button gets a full 48dp touch area: the chip keeps its 26px look but
/// reserves the space around the button, since Flutter only registers taps inside a widget.
class UiChip extends StatelessWidget {
  const UiChip({super.key, required this.label, this.tone = UiStatus.neutral, this.onRemove, this.leading, this.radius});

  final String label;
  final UiStatus tone;

  /// Shows a remove button when set.
  final VoidCallback? onRemove;
  final Widget? leading;
  final bool? radius;

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final toned = tone != UiStatus.neutral;
    final c = tone.color(t);
    final rounded = radius ?? theme.config.radius;
    final style = context.uiText.body.copyWith(fontSize: t.fontSizeSm, color: t.text, height: 1.35);
    final removable = onRemove != null;
    // The 16px remove circle sits 4px from the chip's right edge.
    final chip = Container(
      height: t.sizeSm,
      padding: EdgeInsets.only(left: t.space3, right: removable ? t.space1 : t.space3),
      decoration: BoxDecoration(
        color: toned ? c.withValues(alpha: 0.22) : t.surfaceRaised,
        border: Border.all(color: toned ? c : t.border),
        borderRadius: BorderRadius.circular(rounded ? t.radiusPill : t.radius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: t.space1,
        children: [
          if (leading != null) IconTheme.merge(data: IconThemeData(size: 14, color: toned ? t.text : (t.icon ?? t.text)), child: leading!),
          Flexible(child: Text(label, style: style, maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (removable) const SizedBox(width: 16),
        ],
      ),
    );
    final touch = uiTouchPlatform(context);
    // Every chip takes the same row height on touch devices, so removable and plain chips line up.
    if (!removable) return touch ? SizedBox(height: uiMinTouchTarget, child: Center(widthFactor: 1, child: chip)) : chip;

    final hit = touch ? uiMinTouchTarget : 24.0;
    // Distance from the chip's right edge to the circle's centre: border + padding + half the circle.
    final centre = 1 + t.space1 + 8;
    final overhang = (hit / 2 - centre).clamp(0.0, double.infinity);
    return SizedBox(
      height: touch ? uiMinTouchTarget : t.sizeSm,
      child: Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [
          Padding(padding: EdgeInsetsDirectional.only(end: overhang), child: chip),
          PositionedDirectional(
            end: 0,
            top: 0,
            bottom: 0,
            width: hit,
            child: _ChipRemove(label: label, onTap: onRemove!),
          ),
        ],
      ),
    );
  }
}

class _ChipRemove extends StatelessWidget {
  const _ChipRemove({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return UiInteractive(
      onTap: onTap,
      semanticLabel: 'Remove $label',
      excludeChildSemantics: true,
      pressScale: false,
      padTouchTarget: false,
      builder: (context, s) => Center(
        child: AnimatedContainer(
          duration: t.motionFast,
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: s.hovered || s.pressed ? t.text.withValues(alpha: 0.18) : null,
            // A single 2px band, so the ring stays inside the 4px gap to the label.
            boxShadow: s.focused ? [UiRingShadow(color: t.borderFocus, spread: 2)] : const [],
          ),
          child: UiIcon(HugeIcons.strokeRoundedCancel01, size: 12, color: t.text, strokeWidth: 2),
        ),
      ),
    );
  }
}

/// `ui-avatar`: an image with an initials fallback (also used when the image fails to load).
class UiAvatar extends StatefulWidget {
  const UiAvatar({super.key, this.image, this.name, this.alt, this.size = UiSize.md, this.square = false, this.dimension});

  /// A size in dp, for a profile photo bigger than xl (96, 128); overrides [size], and the initials
  /// scale with it.
  final double? dimension;

  /// Usually a `NetworkImage` or `AssetImage`.
  final ImageProvider? image;

  /// Used for the initials and, if [alt] is missing, the accessible name.
  final String? name;
  final String? alt;
  final UiSize size;
  final bool square;

  @override
  State<UiAvatar> createState() => _UiAvatarState();
}

class _UiAvatarState extends State<UiAvatar> {
  bool _failed = false;

  @override
  void didUpdateWidget(UiAvatar old) {
    super.didUpdateWidget(old);
    if (old.image != widget.image) _failed = false;
  }

  String get _initials {
    final parts = (widget.name ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first.characters.first;
    final last = parts.length > 1 ? parts.last.characters.first : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final dim = widget.dimension ?? widget.size.height(t);
    final fontSize = widget.dimension != null
        ? (widget.dimension! * 0.38).roundToDouble()
        : switch (widget.size) { UiSize.sm => 11.0, UiSize.md => t.fontSizeSm, UiSize.lg => t.fontSizeMd, UiSize.xl => 21.0 * t.fontScale };
    final shape = widget.square ? BorderRadius.circular(t.radius) : BorderRadius.circular(dim);
    final initials = Center(
      child: Text(_initials, style: context.uiText.body.copyWith(fontSize: fontSize, fontWeight: FontWeight.w600, color: t.text, height: 1)),
    );
    return Semantics(
      image: true,
      label: widget.alt ?? widget.name ?? 'avatar',
      child: ExcludeSemantics(
        child: Container(
          width: dim,
          height: dim,
          decoration: BoxDecoration(color: t.surfaceRaised, borderRadius: shape, border: Border.all(color: t.border)),
          clipBehavior: Clip.antiAlias,
          child: widget.image == null || _failed
              ? initials
              : Image(
                  image: widget.image!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && !_failed) setState(() => _failed = true);
                    });
                    return initials;
                  },
                ),
        ),
      ),
    );
  }
}

/// `ui-avatar-group`: overlapping avatars, with "+N" when there are more than [max].
class UiAvatarGroup extends StatelessWidget {
  const UiAvatarGroup({super.key, required this.children, this.max, this.size = UiSize.md, this.overlap = 4});

  final List<UiAvatar> children;
  final int? max;
  final UiSize size;

  /// How far each avatar overlaps the one before; 4 (plus the 2px ring) keeps its initials readable.
  final double overlap;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final shown = max != null && children.length > max! ? children.take(max!).toList() : children;
    final extra = children.length - shown.length;
    final dim = size.height(t);
    final items = <Widget>[
      ...shown,
      if (extra > 0)
        Semantics(
          label: '$extra more',
          child: ExcludeSemantics(
            child: Container(
              width: dim,
              height: dim,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: t.surfaceRaised, shape: BoxShape.circle, border: Border.all(color: t.border)),
              child: Text('+$extra', style: context.uiText.label.copyWith(fontSize: 11, color: t.textMuted)),
            ),
          ),
        ),
    ];
    return SizedBox(
      height: dim,
      width: dim + (items.length - 1) * (dim - overlap),
      child: Stack(children: [
        for (var i = 0; i < items.length; i++)
          Positioned(
            left: i * (dim - overlap),
            // A ring in the background colour separates the overlapping circles.
            child: DecoratedBox(
              decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: t.bg, spreadRadius: 2)]),
              child: items[i],
            ),
          ),
      ]),
    );
  }
}
