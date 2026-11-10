import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/icon.dart';

import '../core/interactive.dart';
import '../core/types.dart';
import '../theme/theme.dart';

/// Thaana letters and marks.
final RegExp _thaanaText = RegExp('[\u0780-\u07BF]');

/// `ui-badge`: a small status or count label. [dot] draws an 8px dot with no text.
class UiBadge extends StatelessWidget {
  const UiBadge({super.key, this.label, this.tone = UiStatus.neutral, this.tier, this.dot = false, this.semanticLabel})
      : assert(dot || label != null, 'A badge needs a label unless it is a dot.');

  final String? label;
  final UiStatus tone;

  /// A premium tier's metal: gold, platinum or premium, the same in every theme. Wins over [tone].
  final UiBadgeTier? tier;
  final bool dot;

  /// Accessible text for a dot badge (e.g. "Online").
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final solid = tone != UiStatus.neutral;
    final fill = solid ? tone.color(t) : t.surfaceRaised;
    final metal = tier;
    final fg = metal != null ? metal.contrast(t) : (solid ? tone.contrast(t) : t.text);
    if (dot) {
      return Semantics(
        label: semanticLabel,
        child: Container(
          width: 8,
          height: 8,
          decoration: metal != null
              ? BoxDecoration(gradient: metal.gradient(t).toGradient(), border: Border.all(color: metal.border(t)), shape: BoxShape.circle)
              : BoxDecoration(color: solid ? fill : t.textMuted, shape: BoxShape.circle),
        ),
      );
    }
    // Thaana (0.46.1): its marks below the line hang lower than Latin descenders, and the fixed 16px
    // line clipped them. In right-to-left text, or for a Thaana label, the pill takes the body line
    // height (1.45, spread by the fonts' own ascent and descent, the Thaana fallback's included) and 1px
    // more below, growing only as far as the text needs; Latin keeps 20px (compact 20, from 18). The web
    // does the same under :lang(dv) / :dir(rtl), with line-height: normal.
    final thaana = Directionality.of(context) == TextDirection.rtl || _thaanaText.hasMatch(label!);
    return Container(
      height: thaana ? null : 20 * t.densityScale,
      constraints: thaana ? BoxConstraints(minHeight: 20 * t.densityScale) : null,
      padding: thaana ? EdgeInsets.fromLTRB(t.space2, 0, t.space2, 1) : EdgeInsets.symmetric(horizontal: t.space2),
      decoration: BoxDecoration(
        color: metal != null ? null : fill,
        gradient: metal?.gradient(t).toGradient(),
        borderRadius: BorderRadius.circular(t.radiusPill),
        border: Border.all(color: metal != null ? metal.border(t) : (solid ? const Color(0x00000000) : t.border)),
      ),
      // Hug the text: Container(alignment:) would stretch to the full available width.
      child: Align(
        widthFactor: 1,
        heightFactor: thaana ? 1 : null,
        child: Text(
        label!,
        maxLines: 1,
        style: context.uiText.body.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: thaana ? 1.45 : 16 / 11,
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
    // The 16px remove circle sits 4px from the chip's end edge (the left in RTL).
    final chip = Container(
      height: t.sizeSm,
      padding: EdgeInsetsDirectional.only(start: t.space3, end: removable ? t.space1 : t.space3),
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
      semanticLabel: uiFormatString(context.uiStrings.remove, {'label': label}),
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

/// A rectangle inside an image, as fractions (0-1) of its width and height.
class UiAvatarCrop {
  const UiAvatarCrop({required this.x, required this.y, required this.w, required this.h});

  /// From a `Rect.fromLTWH(x, y, w, h)` in fractions.
  UiAvatarCrop.fromRect(Rect r) : this(x: r.left, y: r.top, w: r.width, h: r.height);

  final double x, y, w, h;

  @override
  bool operator ==(Object other) => other is UiAvatarCrop && other.x == x && other.y == y && other.w == w && other.h == h;
  @override
  int get hashCode => Object.hash(x, y, w, h);
}

/// Where the whole image sits inside the avatar, in percent of the avatar's size.
class UiAvatarCropLayout {
  const UiAvatarCropLayout({required this.width, required this.height, required this.left, required this.top});
  final double width, height, left, top;
}

/// Works out how to place an image so [crop] (grown by [padding] of its size on every side, kept
/// inside the image) fills a round avatar, centred. [aspect] is the image's width over its height.
/// A box that is not square in pixels is covered by its larger side. Null for no crop.
UiAvatarCropLayout? uiAvatarCropLayout(UiAvatarCrop? crop, {double padding = 0.25, double aspect = 1}) {
  if (crop == null || !(crop.w > 0) || !(crop.h > 0)) return null;
  final a = aspect > 0 && aspect.isFinite ? aspect : 1.0;
  final pad = padding > 0 ? padding : 0.0;
  double clamp(double v, double lo, double hi) => math.min(hi, math.max(lo, v));
  final x0 = clamp(crop.x - crop.w * pad, 0, 1), x1 = clamp(crop.x + crop.w * (1 + pad), 0, 1);
  final y0 = clamp(crop.y - crop.h * pad, 0, 1), y1 = clamp(crop.y + crop.h * (1 + pad), 0, 1);
  final w = x1 - x0, h = y1 - y0;
  if (!(w > 0) || !(h > 0)) return null;
  final width = 100 / math.max(w, h / a);
  final height = 100 / math.max(w * a, h);
  // Keep the image covering the circle when it can; otherwise centre it.
  double place(double centre, double size) => size >= 100 ? clamp(50 - centre * size, 100 - size, 0) : (100 - size) / 2;
  return UiAvatarCropLayout(width: width, height: height, left: place((x0 + x1) / 2, width), top: place((y0 + y1) / 2, height));
}

/// `ui-avatar`: an image with an initials fallback (also used when the image fails to load).
/// [crop] shows just a box of the image (a face from a photo) filling the avatar, so no cropped file
/// is needed.
class UiAvatar extends StatefulWidget {
  const UiAvatar({super.key, this.image, this.name, this.alt, this.size = UiSize.md, this.square = false, this.dimension, this.crop, this.cropPadding = 0.25});

  /// A box of the image, as fractions, to fill the avatar (e.g. a face); null shows the whole image.
  /// A box that is not square in pixels is covered by its larger side. The image is read first to
  /// keep it undistorted, and nothing is drawn until it has loaded.
  final UiAvatarCrop? crop;

  /// How much of the box's size to add on every side so the whole face and hair show, kept inside
  /// the image; 0 fits the box exactly.
  final double cropPadding;

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
  double? _aspect;
  ImageStream? _stream;
  late final ImageStreamListener _listener = ImageStreamListener(_onImage, onError: (_, __) {
    if (mounted && !_failed) setState(() => _failed = true);
  });

  void _onImage(ImageInfo info, bool _) {
    final a = info.image.width / info.image.height;
    if (mounted && a != _aspect) setState(() => _aspect = a);
  }

  /// Reads the image's size, but only while a crop needs it.
  void _watch() {
    final stream = widget.crop == null || widget.image == null ? null : widget.image!.resolve(createLocalImageConfiguration(context));
    if (stream?.key == _stream?.key && stream != null) return;
    _stream?.removeListener(_listener);
    _stream = stream?..addListener(_listener);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _watch();
  }

  @override
  void didUpdateWidget(UiAvatar old) {
    super.didUpdateWidget(old);
    if (old.image != widget.image) {
      _failed = false;
      _aspect = null;
    }
    _watch();
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  String get _initials {
    final parts = (widget.name ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first.characters.first;
    final last = parts.length > 1 ? parts.last.characters.first : '';
    return (first + last).toUpperCase();
  }

  Widget _fail(Widget initials) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_failed) setState(() => _failed = true);
    });
    return initials;
  }

  /// The image placed so the crop box fills the avatar; nothing until its size is known.
  Widget _cropped(Widget initials) {
    final layout = _aspect == null ? null : uiAvatarCropLayout(widget.crop, padding: widget.cropPadding, aspect: _aspect!);
    if (layout == null) return const SizedBox.expand();
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth, h = box.maxHeight;
      return Stack(clipBehavior: Clip.hardEdge, children: [
        Positioned(
          left: layout.left / 100 * w,
          top: layout.top / 100 * h,
          width: layout.width / 100 * w,
          height: layout.height / 100 * h,
          child: Image(image: widget.image!, fit: BoxFit.fill, errorBuilder: (context, error, stack) => _fail(initials)),
        ),
      ]);
    });
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
              : widget.crop != null && uiAvatarCropLayout(widget.crop) != null
                  ? _cropped(initials)
                  : Image(image: widget.image!, fit: BoxFit.cover, errorBuilder: (context, error, stack) => _fail(initials)),
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
          PositionedDirectional(
            start: i * (dim - overlap),
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
