import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../docs/doc.dart';

/// Demo pictures drawn on the device (a gradient sky with a sun), so the media demos need no
/// network and no bundled photos. The web showcase does the same with SVG gradients.
@immutable
class DemoArt extends ImageProvider<DemoArt> {
  const DemoArt(this.from, this.to, {this.width = 600, this.height = 340, this.sun = 0.3});

  final Color from, to;
  final int width, height;

  /// Where the sun sits across the picture (0–1); negative for none.
  final double sun;

  static const palette = [
    DemoArt(Color(0xFF3D5AFE), Color(0xFFE5484D)),
    DemoArt(Color(0xFF2FAA6E), Color(0xFFD9A521), sun: 0.7),
    DemoArt(Color(0xFF8A8F98), Color(0xFF3D5AFE), sun: 0.5),
    DemoArt(Color(0xFF7A4FA0), Color(0xFF66C2A5), sun: 0.2),
    DemoArt(Color(0xFFB34A3C), Color(0xFFF2E1C2), sun: 0.8),
    DemoArt(Color(0xFF1F6F8B), Color(0xFF99D8E2), sun: -1),
  ];

  @override
  Future<DemoArt> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(DemoArt key, ImageDecoderCallback decode) {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final w = width.toDouble(), h = height.toDouble();
    c.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(w, h), [from, to]));
    if (sun >= 0) {
      c.drawCircle(Offset(w * sun, h * 0.36), h * 0.14, Paint()..color = const Color(0xF2FFFFFF));
    }
    // Two soft hills along the bottom.
    final hill = Paint()..color = const Color(0x33000000);
    c.drawPath(Path()..moveTo(0, h)..quadraticBezierTo(w * 0.3, h * 0.55, w * 0.65, h * 0.85)..quadraticBezierTo(w * 0.85, h, w, h * 0.75)..lineTo(w, h)..close(), hill);
    final img = rec.endRecording().toImageSync(width, height);
    return OneFrameImageStreamCompleter(SynchronousFuture(ImageInfo(image: img)));
  }

  @override
  bool operator ==(Object other) => other is DemoArt && other.from == from && other.to == to && other.width == width && other.height == height && other.sun == sun;

  @override
  int get hashCode => Object.hash(from, to, width, height, sun);
}

class MediaPage extends StatefulWidget {
  const MediaPage({super.key});

  @override
  State<MediaPage> createState() => _MediaPageState();
}

class _MediaPageState extends State<MediaPage> {
  int _slide = 0;
  final List<UiImagePickerItem> _items = [];
  String? _busy;
  String? _chosen;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _items.addAll(_page(0));
  }

  List<UiImagePickerItem> _page(int from) => [
        for (var i = from; i < from + 8; i++)
          UiImagePickerItem(
            id: 'art$i',
            image: DemoArt.palette[i % DemoArt.palette.length],
            label: 'Artwork ${i + 1}',
            badge: i % 5 == 1 ? 'Moves' : null,
            disabled: i == 3,
            hint: i == 3 ? 'Needs a newer plan' : null,
          ),
      ];

  Future<void> _more() async {
    if (_loading || _items.length >= 24) return;
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _items.addAll(_page(_items.length));
      _loading = false;
    });
  }

  Future<void> _choose(UiImagePickerItem item) async {
    setState(() => _busy = item.id);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _busy = null;
      _chosen = item.label;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final slides = [
      UiCarouselSlide(image: DemoArt.palette[0], alt: 'Blue to red sky', caption: 'Slide one: a blue to red sky'),
      UiCarouselSlide(image: DemoArt.palette[1], alt: 'Green to amber sky', caption: 'Slide two'),
      UiCarouselSlide(image: DemoArt.palette[2], alt: 'Grey to blue sky', caption: 'Slide three'),
    ];
    return DocPage(
      eyebrow: 'Components',
      title: 'Media',
      lead: 'A carousel, a thumbnail gallery with a full-screen lightbox, an image picker and a phone frame.',
      children: [
        DocSection(
          name: 'Carousel',
          widget: 'UiCarousel',
          summary: 'Slides with a swipe that follows the finger, dots and optional autoplay. A swipe stops at the first and last slide with a little resistance; the arrows (only where there is a mouse) wrap around. Each dot is a labelled button, 48dp tall on touch and as wide as there is room for (at least 24). Autoplay pauses while hovered, while focus is inside and mid-swipe, and is off under reduced motion. A swipe that starts inside is the carousel\'s own and never reaches a page-level UiSwipe. For TalkBack it is one adjustable control ("Slide 2 of 3"). overlay is laid over the slides.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
            UiCarousel(slides: slides, autoplay: const Duration(seconds: 4), index: _slide, onIndexChanged: (i) => setState(() => _slide = i)),
            UiText('Showing slide ${_slide + 1} of ${slides.length}', variant: UiTextVariant.caption),
          ]),
          code: 'UiCarousel(\n  slides: slides,\n  autoplay: const Duration(seconds: 4),\n  index: slide,\n  onIndexChanged: (i) => setState(() => slide = i),\n)',
          api: const [
            ApiRow('slides', 'List<UiCarouselSlide>', 'The pictures.'),
            ApiRow('index / onIndexChanged', 'int? / ValueChanged<int>?', 'The slide showing; null keeps it inside.'),
            ApiRow('initialIndex', 'int', 'Uncontrolled start.', def: '0'),
            ApiRow('autoplay', 'Duration?', 'Time between turns; null disables.'),
            ApiRow('dots / arrows', 'bool', 'The built-in markers and (mouse-only) arrows.', def: 'true'),
            ApiRow('overlay', 'Widget?', 'Laid over the slides (a title, a counter).'),
            ApiRow('aspectRatio / maxHeight', 'double', 'Slide shape, capped in height.', def: '16/9, 360'),
            ApiRow('label', 'String', 'Accessible name.', def: "'Carousel'"),
          ],
          shapes: 'UiCarouselSlide({required ImageProvider image, String? alt, String? caption})',
        ),
        DocSection(
          name: 'Gallery',
          widget: 'UiGallery',
          summary: 'A responsive grid of square thumbnails (as many columns at least minThumb wide as fit). A thumbnail opens the full-screen lightbox on that picture: swipe or arrow keys to step, pinch or double tap to zoom, drag down, back or Escape to close. Focus stays inside the lightbox and returns to the thumbnail. Thumbnails use alt as their accessible name, so give every image one.',
          demo: UiGallery(
            minThumb: 90,
            label: 'Demo set',
            images: [for (var i = 0; i < 6; i++) UiGalleryImage(image: DemoArt.palette[i], alt: 'Picture ${i + 1}')],
          ),
          code: "UiGallery(\n  minThumb: 90,\n  images: [UiGalleryImage(image: NetworkImage(url), alt: 'Sunset')],\n)",
          api: const [
            ApiRow('images', 'List<UiGalleryImage>', 'The pictures.'),
            ApiRow('minThumb', 'double', 'Narrowest thumbnail.', def: '120'),
            ApiRow('label', 'String', 'The lightbox\'s title line.'),
          ],
          callbacks: const [ApiRow('UiGallery.open(context, images, index)', 'Future<int?>', 'Opens the lightbox yourself.')],
          shapes: 'UiGalleryImage({required ImageProvider image, ImageProvider? thumb, String? alt})',
        ),
        DocSection(
          name: 'Poster grid',
          widget: 'UiPosterGrid',
          summary: "One grid of same-shape picture tiles (ratio): 2 columns on a phone, 3 from 544 wide, 4 from 992 and 5 from 1280 of the grid's own width. A poster's details are drawn on its tile over the bottom of the picture on a compact UiScrim that fades from clear to dark, so the words stay readable on any picture; keep them short and non-interactive, since the whole tile is the target. Without details a tile is the picture alone, named by its label. No picture, or one that fails to load, shows a gradient of its colors (or the theme's primary and accent). A small dot (mark) can flag a tile; screen readers hear its label. It doesn't scroll, so put it in a scroll view.",
          demo: const _PosterDemo(),
          code: "UiPosterGrid(\n  focus: UiPosterFocus.top,\n  posters: [UiPoster(label: 'Aisha and Ali', image: NetworkImage(url), mark: UiPosterMark(tone: UiStatus.primary, label: 'New'),\n    details: Text('Aisha and Ali', maxLines: 1, overflow: TextOverflow.ellipsis))],\n  onSelect: (i) => openEvent(i),\n)",
          api: const [
            ApiRow('posters', 'List<UiPoster>', 'The tiles: picture, semantic label, fallback colours, optional dot.'),
            ApiRow('ratio', 'double', 'Width / height of every tile.', def: '0.75'),
            ApiRow('focus', 'UiPosterFocus', "Which part of a picture survives the crop; top keeps a poster's heading.", def: 'center'),
          ],
          callbacks: const [ApiRow('onSelect', 'ValueChanged<int>', 'The index of the tile that was tapped.')],
          shapes: 'UiPoster({required String label, ImageProvider? image, List<Color>? colors, UiPosterMark? mark, Widget? details})\nUiPosterMark({required UiStatus tone, required String label})',
        ),
        DocSection(
          name: 'Poster view',
          widget: 'UiPosterView',
          summary: 'One picture full-size, shown whole over a blurred copy of itself, with the child laid over its bottom on a UiScrim: the details and the buttons. Escape, back or the close button close it. Open it with UiPosterView.show.',
          demo: const _PosterViewDemo(),
          api: const [
            ApiRow('label', 'String', 'The semantic label of the view and the picture.'),
            ApiRow('image', 'ImageProvider?', 'The picture.'),
            ApiRow('colors', 'List<Color>?', 'Fallback gradient when there is no picture, as on UiPosterGrid.'),
            ApiRow('child', 'Widget', 'Details and buttons, laid over the bottom on a UiScrim.'),
          ],
          callbacks: const [
            ApiRow('onClose', 'VoidCallback', 'Escape or the close button.'),
            ApiRow('UiPosterView.show(context, label:, builder:, image:, colors:)', 'Future<T?>', 'Pushes the view as a route that fades in.'),
          ],
        ),
        DocSection(
          name: 'Scrim',
          widget: 'UiScrim',
          summary: 'A see-through layer that fades from clear at its top to the media scrim colour at its bottom, for putting words on a picture. The fade reaches 60% before the content starts and 88% at the bottom, so on-scrim text keeps at least 4.5:1 over any picture, white included.',
          demo: SizedBox(
            width: 320,
            child: AspectRatio(
              aspectRatio: 0.75,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(fit: StackFit.expand, children: [
                  const Image(image: DemoArt(Color(0xFFFFFFFF), Color(0xFFCFE8FF), width: 300, height: 400, sun: -1), fit: BoxFit.cover),
                  Positioned(left: 0, right: 0, bottom: 0, child: UiScrim(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text('Aisha and Ali', style: context.uiText.h4.copyWith(color: context.ui.mediaOnScrim)),
                    const Text('Over a white picture, still readable.'),
                  ]))),
                ]),
              ),
            ),
          ),
          code: 'Stack(children: [Image(...), Positioned(left: 0, right: 0, bottom: 0, child: UiScrim(child: details))])',
          api: const [ApiRow('child', 'Widget', 'The words; text and icons take the on-scrim colour.')],
        ),
        DocSection(
          name: 'Image picker',
          widget: 'UiImagePicker',
          summary: 'A grid of tiles to choose from (search results, stock art). Each tile is a button named by its label. While busyId is set that tile shows a spinner and the others are disabled. With hasMore, scrolling within 240px of the end calls onMore, and again after a page loads if the end is still in view. Thumbnails that fail to load show the label; tiles sit on a faint checkerboard so white art shows. With draggable, a long press lifts a tile for a DragTarget.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
            UiImagePicker(
              items: _items,
              busyId: _busy,
              loading: _loading,
              hasMore: _items.length < 24,
              captions: true,
              minThumb: 88,
              onPick: _choose,
              onMore: _more,
            ),
            UiText(_chosen == null ? 'Pick an artwork' : 'Chose ${_chosen!}', variant: UiTextVariant.caption),
          ]),
          code: 'UiImagePicker(\n  items: items,\n  busyId: busy,\n  hasMore: true,\n  onPick: choose,\n  onMore: loadMore,\n)',
          api: const [
            ApiRow('items', 'List<UiImagePickerItem>', 'The tiles.'),
            ApiRow('onPick / onMore', 'ValueChanged / VoidCallback?', 'A tile chosen; the next page wanted.'),
            ApiRow('busyId', 'String?', 'The tile being fetched.'),
            ApiRow('loading / hasMore', 'bool', 'A page is loading; there is another.', def: 'false'),
            ApiRow('minThumb', 'double', 'Narrowest tile.', def: '96'),
            ApiRow('captions', 'bool', 'Label under each tile.', def: 'false'),
            ApiRow('emptyText', 'String', 'With no items.'),
            ApiRow('draggable', 'bool', 'Long press to drag (data: the item).', def: 'false'),
          ],
          shapes: 'UiImagePickerItem({required String id, required ImageProvider image, required String label,\n  String? badge, bool disabled = false, String? hint})',
        ),
        DocSection(
          name: 'Device frame',
          widget: 'UiDeviceFrame',
          summary: 'A phone-shaped frame whose screen is exactly width × height logical px, scaled down to fit. The child lays out at true phone size (and sees a phone-sized MediaQuery) and is only scaled visually. onScale reports the scale, for overlays that must line up with the screen.',
          demo: SizedBox(
            height: 320,
            child: UiDeviceFrame(
              child: ColoredBox(
                color: t.bg,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(t.space6, 80, t.space6, t.space6),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space4, children: [
                    const UiText('Hello', variant: UiTextVariant.h1),
                    const UiText('This page lays out at 390 × 844 and is scaled to fit.'),
                    UiCarousel(slides: slides.sublist(0, 2)),
                  ]),
                ),
              ),
            ),
          ),
          code: 'UiDeviceFrame(width: 390, height: 844, child: preview)',
          api: const [
            ApiRow('width / height', 'double', 'The screen in logical px.', def: '390 × 844'),
            ApiRow('bezel', 'bool', 'The dark rim.', def: 'true'),
            ApiRow('island', 'bool', 'The camera cut-out.', def: 'true'),
            ApiRow('maxScale', 'double', 'Never scale up past this.', def: '1'),
            ApiRow('onScale', 'ValueChanged<double>?', 'The current scale.'),
          ],
        ),
      ],
    );
  }
}


/// The poster grid demo: tap a tile for the view with its details.
class _PosterDemo extends StatefulWidget {
  const _PosterDemo();

  @override
  State<_PosterDemo> createState() => _PosterDemoState();
}

class _PosterDemoState extends State<_PosterDemo> {
  static const _when = ['Sat 12 Dec · Malé', 'Sun 20 Dec · Hulhumalé', 'Not finished', 'Fri 1 Jan · Addu', '12 guests', 'Tue 5 Jan'];
  static final _posters = [
    UiPoster(label: 'Aisha and Ali', image: DemoArt.palette[0], mark: const UiPosterMark(tone: UiStatus.primary, label: 'New')),
    UiPoster(label: 'Eid get-together', image: DemoArt.palette[1]),
    const UiPoster(label: 'Hawwa turns 30', colors: [Color(0xFF5B2A86), Color(0xFFE5484D)], mark: UiPosterMark(tone: UiStatus.warning, label: 'Not finished')),
    UiPoster(label: 'Graduation', image: DemoArt.palette[2]),
    const UiPoster(label: 'Office dinner'),
    UiPoster(label: 'Housewarming', image: DemoArt.palette[4]),
  ];
  int _picked = 0;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      UiPosterGrid(
        focus: UiPosterFocus.top,
        posters: [
          for (var i = 0; i < _posters.length; i++)
            UiPoster(
              label: _posters[i].label,
              image: _posters[i].image,
              colors: _posters[i].colors,
              mark: _posters[i].mark,
              details: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(_posters[i].label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.uiText.label.copyWith(color: t.mediaOnScrim)),
                Text(_when[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: context.uiText.caption.copyWith(color: t.mediaOnScrim)),
              ]),
            ),
        ],
        onSelect: (i) => setState(() => _picked = i),
      ),
      SizedBox(height: t.space2),
      Text('Last picked: ${_posters[_picked].label}', style: context.uiText.caption),
    ]);
  }
}

/// The poster view demo: one button that opens it.
class _PosterViewDemo extends StatelessWidget {
  const _PosterViewDemo();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: UiButton(
        label: 'Open the poster view',
        onPressed: () => UiPosterView.show<void>(
          context,
          label: 'Aisha and Ali',
          image: DemoArt.palette[0],
          builder: (context) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('Aisha and Ali', style: context.uiText.h3.copyWith(color: context.ui.mediaOnScrim)),
            const Text('Saturday 12 December, 7 pm · Malé'),
            SizedBox(height: context.ui.space2),
            UiButton(label: 'Open invitation', onPressed: () => Navigator.of(context).pop()),
          ]),
        ),
      ),
    );
  }
}
