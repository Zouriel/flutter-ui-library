import 'package:flutter/widgets.dart';

import '../core/interactive.dart';
import '../file_viewer/media_lightbox.dart';
import '../layout/layout.dart';
import '../theme/theme.dart';

/// One picture in a [UiGallery].
@immutable
class UiGalleryImage {
  const UiGalleryImage({required this.image, this.thumb, this.alt});

  /// The full-size picture.
  final ImageProvider image;

  /// A smaller still for the grid (defaults to [image]).
  final ImageProvider? thumb;

  /// The thumbnail's accessible name and the picture's alt text. Give every image one.
  final String? alt;
}

/// `ui-gallery`: a responsive grid of square thumbnails (as many columns at least [minThumb] wide
/// as fit) that opens a full-screen [UiMediaLightbox] on the tapped picture: swipe or arrow keys to
/// step, pinch or double tap to zoom, drag down, back or Escape to close. The lightbox is a modal
/// route (focus stays inside it) and closing returns focus to the thumbnail that opened it.
class UiGallery extends StatelessWidget {
  const UiGallery({super.key, required this.images, this.minThumb = 120, this.label = ''});

  final List<UiGalleryImage> images;
  final double minThumb;

  /// What the set is called (the lightbox's title line).
  final String label;

  /// Opens the lightbox at [index], as tapping a thumbnail does.
  static Future<int?> open(BuildContext context, List<UiGalleryImage> images, int index, {String label = ''}) => UiMediaLightbox.show(
        context,
        initialIndex: index,
        label: label,
        items: [for (final i in images) UiMediaItem.image(i.image, thumb: i.thumb, alt: i.alt)],
      );

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final r = BorderRadius.circular(context.uiTheme.radius());
    return UiGrid(
      minColumnWidth: minThumb,
      gap: 2,
      collapseEmptyColumns: false,
      children: [
        for (var i = 0; i < images.length; i++)
          UiInteractive(
            onTap: () => open(context, images, i, label: label),
            padTouchTarget: false,
            semanticLabel: images[i].alt ?? 'Open image',
            excludeChildSemantics: true,
            builder: (context, s) => AspectRatio(
              aspectRatio: 1,
              child: AnimatedContainer(
                duration: context.uiAnimate ? t.motionBase : Duration.zero,
                decoration: BoxDecoration(
                  borderRadius: r,
                  border: Border.all(color: s.hovered ? t.primary : t.border),
                  boxShadow: uiFocusRing(t, show: s.focused),
                ),
                child: ClipRRect(
                  borderRadius: r,
                  child: Image(
                    image: images[i].thumb ?? images[i].image,
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                    errorBuilder: (context, _, _) => ColoredBox(color: t.surfaceSubtle),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
