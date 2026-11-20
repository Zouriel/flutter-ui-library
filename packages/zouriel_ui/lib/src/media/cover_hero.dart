import 'package:flutter/widgets.dart';

import '../core/on_media.dart';
import '../overlay/menu.dart';
import '../theme/theme.dart';
import 'reposition.dart';

/// `ui-cover-hero`: a full-width cover picture with on-media chrome and a bottom fade into the page.
///
/// [topStart] and [topEnd] hold top controls, [child] holds the title and metadata, and [actions]
/// holds primary controls. A non-empty [coverMenu] makes the bare cover an accessible menu trigger
/// on tap, right-click, touch long-press and the keyboard.
class UiCoverHero extends StatefulWidget {
  const UiCoverHero({
    super.key,
    this.image,
    this.minHeight = 272,
    this.fadeBottom = true,
    this.scrimTop = true,
    this.scrimStart = true,
    this.coverMenu = const [],
    this.coverActionLabel = 'Change cover image',
    this.onCoverMenuSelected,
    this.topStart,
    this.topEnd,
    this.child,
    this.actions,
    this.position = const UiRepositionPosition(),
    this.repositionable = false,
    this.onPositionSave,
    this.onRepositionCancel,
  });

  final ImageProvider? image;

  /// Minimum cover height. The default becomes 320 at widths of 900 and above.
  final double minHeight;
  final bool fadeBottom;
  final bool scrimTop;
  final bool scrimStart;
  final List<UiMenuItem> coverMenu;
  final String coverActionLabel;
  final ValueChanged<UiMenuItem>? onCoverMenuSelected;
  final Widget? topStart;
  final Widget? topEnd;
  final Widget? child;
  final Widget? actions;
  final UiRepositionPosition position;
  final bool repositionable;
  final ValueChanged<UiRepositionPosition>? onPositionSave;
  final VoidCallback? onRepositionCancel;

  @override
  State<UiCoverHero> createState() => _UiCoverHeroState();
}

class _UiCoverHeroState extends State<UiCoverHero> {
  bool _broken = false;

  @override
  void didUpdateWidget(UiCoverHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) _broken = false;
  }

  void _imageFailed() {
    if (_broken) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_broken) setState(() => _broken = true);
    });
  }

  Widget _cover(BuildContext context, bool hasImage) {
    final t = context.ui;
    Widget cover = ColoredBox(
      color: t.bg,
      child: hasImage
          ? UiReposition(
              image: widget.image!,
              position: widget.position,
              active: widget.repositionable,
              onSave: widget.onPositionSave,
              onCancel: widget.onRepositionCancel,
              onImageError: _imageFailed,
            )
          : const SizedBox.expand(),
    );
    if (widget.coverMenu.isEmpty) return ExcludeSemantics(child: cover);
    cover = Semantics(
      label: widget.coverActionLabel,
      button: true,
      child: MouseRegion(cursor: SystemMouseCursors.click, child: cover),
    );
    return UiContextMenu(
      items: widget.coverMenu,
      onSelect: widget.onCoverMenuSelected ?? (_) {},
      openOnTap: true,
      semanticHint: widget.coverActionLabel,
      child: cover,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final hasImage = widget.image != null && !_broken;
    return LayoutBuilder(builder: (context, box) {
      final wideDefault = box.maxWidth >= 900 && widget.minHeight == 272;
      final height = wideDefault ? 320.0 : widget.minHeight;
      final bodyWidth = box.maxWidth >= 600 ? 0.69 : 0.85;
      return UiOnMediaScope(
        enabled: hasImage,
        child: ClipRect(
          child: Stack(children: [
            Positioned.fill(child: _cover(context, hasImage)),
            // While repositioning, the hero chrome fades out and takes no touches, so the whole photo shows
            // and a drag works anywhere on the cover.
            _RepositionChrome(
              hidden: widget.repositionable && hasImage,
              child: Stack(children: [
            if (hasImage && widget.scrimStart)
              Positioned.fill(
                child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                  begin: AlignmentDirectional.centerStart,
                  end: AlignmentDirectional.centerEnd,
                  colors: [
                    t.mediaScrim.withValues(alpha: 0.35),
                    t.mediaScrim.withValues(alpha: 0.12),
                    t.mediaScrim.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.4, 0.7],
                )))),
              ),
            if (hasImage && widget.scrimTop)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: t.space20,
                child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    t.mediaScrim.withValues(alpha: 0.34),
                    t.mediaScrim.withValues(alpha: 0.14),
                    t.mediaScrim.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.52, 1],
                )))),
              ),
            if (hasImage && widget.fadeBottom)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: t.space20,
                child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    t.bg,
                    t.bg.withValues(alpha: 0.82),
                    t.bg.withValues(alpha: 0.38),
                    t.bg.withValues(alpha: 0.10),
                    t.bg.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.24, 0.52, 0.76, 1],
                )))),
              ),
            ConstrainedBox(
              constraints: BoxConstraints(minWidth: double.infinity, minHeight: height),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.topStart != null || widget.topEnd != null)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: t.space4, vertical: t.space3),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (widget.topStart != null) widget.topStart!,
                        const Spacer(),
                        if (widget.topEnd != null) widget.topEnd!,
                      ]),
                    )
                  else
                    const SizedBox.shrink(),
                  if (widget.child != null || widget.actions != null)
                    Padding(
                      padding: EdgeInsets.fromLTRB(t.space4, t.space4, t.space4, t.space6),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, spacing: t.space2, children: [
                        if (widget.child != null)
                          FractionallySizedBox(widthFactor: bodyWidth, alignment: AlignmentDirectional.centerStart, child: widget.child),
                        if (widget.actions != null) widget.actions!,
                      ]),
                    )
                  else
                    const SizedBox.shrink(),
                ],
              ),
            ),
              ]),
            ),
          ]),
        ),
      );
    });
  }
}

class _RepositionChrome extends StatelessWidget {
  const _RepositionChrome({required this.hidden, required this.child});
  final bool hidden;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) == true;
    return IgnorePointer(
      ignoring: hidden,
      child: ExcludeSemantics(
        excluding: hidden,
        child: AnimatedOpacity(
          opacity: hidden ? 0 : 1,
          duration: still ? Duration.zero : const Duration(milliseconds: 200),
          child: child,
        ),
      ),
    );
  }
}
