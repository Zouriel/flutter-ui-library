import 'dart:math' as math;
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';
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
      lead: 'A carousel, a thumbnail gallery with a full-screen lightbox, an image picker, a masonry grid that zooms between column counts and a phone frame.',
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
          summary: "One grid of same-shape picture tiles (ratio): 2 columns on a phone, 3 from 544 wide, 4 from 992 and 5 from 1280 of the grid's own width. A poster's details are drawn on its tile over the bottom of the picture on a compact UiScrim that fades from clear to dark, so the words stay readable on any picture; keep them short and non-interactive, since the whole tile is the target. Without details a tile is the picture alone, named by its label. No picture, or one that fails to load, shows a gradient of its colors (or the theme's primary and accent). A small dot (mark) can flag a tile; screen readers hear its label. A poster's corner draws something small, such as a venue's UiAvatarTag at size xs, over its picture's top-start corner (top-left in a left-to-right app): inset by space2, above the picture, never wider than it (nor over the dot), and it takes no taps, so the whole tile stays the target. The Avatar tag demo shows it. It doesn't scroll, so put it in a scroll view.",
          demo: const _PosterDemo(),
          code: "UiPosterGrid(\n  focus: UiPosterFocus.top,\n  posters: [UiPoster(label: 'Aisha and Ali', image: NetworkImage(url), mark: UiPosterMark(tone: UiStatus.primary, label: 'New'),\n    details: Text('Aisha and Ali', maxLines: 1, overflow: TextOverflow.ellipsis))],\n  onSelect: (i) => openEvent(i),\n)",
          api: const [
            ApiRow('posters', 'List<UiPoster>', 'The tiles: picture, semantic label, fallback colours, optional dot.'),
            ApiRow('ratio', 'double', 'Width / height of every tile.', def: '0.75'),
            ApiRow('focus', 'UiPosterFocus', "Which part of a picture survives the crop; top keeps a poster's heading.", def: 'center'),
            ApiRow('UiPoster.details', 'Widget?', 'Drawn over the bottom of the picture on a compact scrim.'),
            ApiRow('UiPoster.corner', 'Widget?', "Something small (a UiAvatarTag, size xs) over the picture's top-start corner, inside it with a space2 inset; no taps of its own. 0.74.0."),
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
          name: 'Selectable',
          widget: 'UiSelectable',
          summary: 'Wraps one grid tile for long-press multi-select, like a phone gallery. A tap calls onTap (the app opens the tile, or toggles it while selecting); a long press calls onLongPress with a light haptic, and only for a finger that stays put, so it works inside a scroll view and a scroll never selects. While selecting, a round mark sits in the top corner: an empty ring over a small scrim, or filled with the primary colour and a check, readable on white and black pictures. A selected tile shrinks a little (instantly under reduced motion) with a primary outline and tint. Screen readers hear the label and the selected state, checked or not while selecting, and get the long press as an action. In the demo: press and hold a photo, tap more, then Save to gallery for a fake job.',
          demo: const _SelectDemo(),
          code: "UiSelectable(\n  semanticLabel: 'Photo 3',\n  selected: picked.contains(3),\n  selecting: picked.isNotEmpty,\n  onTap: () => picked.isEmpty ? open(3) : toggle(3),\n  onLongPress: () => toggle(3),\n  child: Image(image: photo, fit: BoxFit.cover),\n)",
          api: const [
            ApiRow('child', 'Widget', 'The tile (a picture).'),
            ApiRow('selected', 'bool', 'Whether this tile is selected.'),
            ApiRow('selecting', 'bool', 'Selection mode: the marks show.'),
            ApiRow('semanticLabel', 'String?', "The tile's name for screen readers."),
            ApiRow('borderRadius', 'BorderRadius?', "The tile's corners; the theme's radius when null."),
          ],
          callbacks: const [
            ApiRow('onTap', 'VoidCallback?', 'A tap (open, or toggle while selecting).'),
            ApiRow('onLongPress', 'VoidCallback?', 'Press and hold (start selecting); comes with a selection-click haptic.'),
          ],
        ),
        DocSection(
          name: 'Likes',
          widget: 'UiLikeCount',
          summary: 'Hearts on photos. UiLikeCount is the small heart and number in a tile\'s corner: a dark see-through pill readable on any picture, nothing at all at 0, the heart filled when you liked it, big numbers shortened (1.2k), read as "Liked, 12 likes". It never takes a tap. Liking is a double tap: give UiSelectable an onDoubleTap and it reports the point, while a single tap waits 280ms for a second one before onTap (never while selecting); a press held right after a tap becomes a long press. UiHeartBurst sits over the media and play(offset) pops a big heart there (a fade only with animations off). UiLikeButton is the viewer\'s heart toggle with its count (tone surface on an ordinary background). Double tap a tile or the big photo, or use its heart.',
          code: 'final burst = GlobalKey<UiHeartBurstState>();\nUiSelectable(\n  selected: false, selecting: false,\n  onTap: () => open(i),\n  onDoubleTap: (at) { like(i); burst.currentState!.play(at); },\n  child: Stack(fit: StackFit.expand, children: [\n    Image(image: photo),\n    UiHeartBurst(key: burst),\n    PositionedDirectional(start: 4, bottom: 4, child: UiLikeCount(count: likes, liked: mine)),\n  ]),\n)\nUiLikeButton(liked: mine, count: likes, onChanged: (v) => setLiked(i, v)',
          api: const [
            ApiRow('UiLikeCount count / liked / size', 'int / bool / UiLikeCountSize', 'Hearts; filled when liked; sm for tiles, md for cards. Nothing shows at 0 unless liked.'),
            ApiRow('UiHeartBurst size', 'double', 'The heart, in logical pixels.', def: '88'),
            ApiRow('UiHeartBurstState.play([Offset?])', 'method', 'Pops a heart at a point inside the box (the centre without one).'),
            ApiRow('UiLikeButton liked / count / tone', 'bool / int / UiLikeButtonTone', 'State shown; the count hides at 0; media (white) or surface.'),
            ApiRow('UiSelectable onDoubleTap', 'ValueChanged<Offset>?', 'Two taps within 280ms and 24px; while set, a single tap waits.'),
            ApiRow('UiMediaLightbox onDoubleTap / leadingActions', 'bool Function(item, index, Offset)? / Widget Function(context, item, index)?', 'A double tap likes instead of zooming (return true to pop the heart); a like button at the start of the bottom bar (0.63.1).'),
          ],
          callbacks: const [ApiRow('UiLikeButton onChanged', 'ValueChanged<bool>?', 'The new state; the count is yours to update.')],
          demo: const _LikeDemo(),
        ),
        DocSection(
          name: 'Avatar tag',
          widget: 'UiAvatarTag',
          summary: 'A tiny round picture and a name in small text, for a venue or a person on the corner of an album tile or a feed post. The picture is decorative; without one, or when it fails to load, the circle shows the name\'s first letter on the primary colour. A long name ends in an ellipsis inside the width the tag is given; it never grows past it, so give the corner a width (Positioned with start and end, or a ConstrainedBox). The overlay variant (the default) is the dark see-through pill of UiLikeCount, readable on any picture, white included; with glass (the theme\'s glass config by default) it also blurs the photo behind it and lights its rim. The plain variant sits on an ordinary surface. Size xs (16dp picture) is for a small tile\'s corner, sm (20dp) for a post. Read as prefix + name ("At Coco Palm"); it takes no tap of its own.',
          code: "UiPosterGrid(\n  posters: [UiPoster(\n    label: album.name,\n    image: NetworkImage(album.cover),\n    details: Text(album.name, maxLines: 1, overflow: TextOverflow.ellipsis),\n    // Over the picture's top-left corner, inside it\n    corner: UiAvatarTag(name: venue.name, image: NetworkImage(venue.logo), prefix: 'At', size: UiAvatarTagSize.xs),\n  )],\n  onSelect: (i) => openAlbum(i),\n)\nUiAvatarTag(name: venue.name, image: logo, prefix: 'At', variant: UiAvatarTagVariant.plain)",
          api: const [
            ApiRow('name', 'String', 'The name shown, ellipsised when long; its first letter is the fallback picture.'),
            ApiRow('image', 'ImageProvider?', 'The picture (the web\'s src), decorative. Missing or failing: the first letter.'),
            ApiRow('prefix', 'String?', 'Words read before the name, e.g. "At" for "At Coco Palm". Not shown.'),
            ApiRow('variant', 'UiAvatarTagVariant', 'overlay: dark see-through pill for photos; plain: for a normal surface.', def: 'overlay'),
            ApiRow('size', 'UiAvatarTagSize', 'sm: 20dp picture (a post); xs: 16dp picture (a small tile corner).', def: 'sm'),
            ApiRow('glass', 'bool?', 'Blur what is behind the tag and light its rim; null follows the theme config.'),
          ],
          demo: const AvatarTagDemo(),
        ),
        DocSection(
          name: 'Selection bar',
          widget: 'UiSelectionBar',
          summary: 'The bar shown while selecting: Cancel (an X) at the start, "12 selected", a Select all toggle that reads Clear once count reaches total (each side hidden when its callback is null), then the actions. Actions are off while nothing is selected or when not enabled; danger draws the destructive style. When the labels don\'t all fit (a 360 phone with three actions) the toggle and the actions with an icon become icon buttons that keep their label for screen readers and as a tooltip, and the count falls back to the number alone, so nothing overflows at 320. Count changes are announced politely. The demo is in Selectable above.',
          code: "UiSelectionBar(\n  count: picked.length,\n  total: photos.length,\n  onSelectAll: selectAll,\n  onClear: clear,\n  onCancel: clear,\n  actions: const [\n    UiSelectionAction(id: 'share', label: 'Share', icon: UiIcon(HugeIcons.strokeRoundedShare08)),\n    UiSelectionAction(id: 'delete', label: 'Delete', icon: UiIcon(HugeIcons.strokeRoundedDelete02), danger: true),\n  ],\n  onAction: (id) => run(id),\n)",
          api: const [
            ApiRow('count', 'int', 'How many are selected.'),
            ApiRow('total', 'int?', 'Everything there is; at count == total the toggle reads Clear.'),
            ApiRow('actions', 'List<UiSelectionAction>', 'The buttons at the end.', def: 'const []'),
          ],
          callbacks: const [
            ApiRow('onCancel', 'VoidCallback', 'The X: leave selecting.'),
            ApiRow('onSelectAll / onClear', 'VoidCallback?', 'The toggle; null hides that side.'),
            ApiRow('onAction', 'ValueChanged<String>?', 'The id of the action pressed.'),
          ],
          shapes: 'UiSelectionAction({required String id, required String label, Widget? icon, bool danger = false, bool enabled = true})',
        ),
        DocSection(
          name: 'Filter',
          widget: 'UiFilter · UiFilterChips',
          summary: 'One compact Filter button for a toolbar, however many filters there are: a filter icon, the words and, while filters are on, a count bubble (read as "Filter, 2 on"). It opens a panel of sections. On a screen under narrowAt (600) the panel is a modal bottom sheet with its footer pinned; wider, a 340 popover under the button whose body scrolls between its title and footer. Each section is a titled group: its "all" row (allLabel, e.g. Everyone) first, then its options with counts; multiple sections have checkboxes (any chosen option passes), the others radios, and from searchAt options (8) a search field narrows the rows. Rows are 44 tall (48 to the touch). Every tap calls onChanged at once, so the page behind updates; the footer\'s Show N (resultCount) or Done closes it, Clear all turns everything off. Escape, a tap outside, a drag down and Back close it too. To add a filter, add a section: the toolbar keeps its one button. UiFilterChips shows the filters that are on as removable chips with Clear all, for under the toolbar; uiFilterPrune drops choices the sections no longer offer, so a stale choice never empties the page. UiFilterButton, UiFilterPanel and UiFilterFooter are the parts, for your own container.',
          demo: const _FilterDemo(),
          code: 'UiFilter(\n  sections: sections,\n  value: filter,\n  resultCount: shown.length,\n  onChanged: (v) => setState(() => filter = v),\n),\nUiFilterChips(sections: sections, value: filter, onChanged: (v) => setState(() => filter = v)),',
          api: const [
            ApiRow('sections', 'List<UiFilterSection>', 'The panel, top to bottom. Add one to add a filter.'),
            ApiRow('value', 'UiFilterValue (Map<String, List<String>>)', 'Chosen option ids by section id; missing or empty = everything.'),
            ApiRow('resultCount', 'int?', 'How many pass: the footer reads Show N; null: Done.'),
            ApiRow('label / title', 'String?', "The button's words / the panel's title.", def: "'Filter'"),
            ApiRow('size', 'UiSize', 'The button size (48 to the touch either way).', def: 'UiSize.sm'),
            ApiRow('narrowAt', 'double', 'Below this width the panel is a bottom sheet, else a popover.', def: '600'),
            ApiRow('enabled', 'bool', 'The button on or off.', def: 'true'),
          ],
          callbacks: const [
            ApiRow('onChanged', 'ValueChanged<UiFilterValue>', 'Every tap in the panel, Clear all, and a chip\'s remove.'),
            ApiRow('UiFilterChips(sections, value, onChanged, label)', 'Widget', 'The filters that are on as chips and Clear all; nothing while none is on.'),
            ApiRow('UiFilterButton(count, onPressed, label, size)', 'Widget', 'Only the button.'),
            ApiRow('UiFilterPanel(sections, value, onChanged)', 'Widget', 'Only the sections (put it in a scroll view).'),
            ApiRow('UiFilterFooter(count, resultCount, onClearAll, onDone)', 'Widget', 'Only the footer.'),
          ],
          shapes: 'UiFilterOption({required String id, required String label, int? count})\nUiFilterSection({required String id, required String title, required List<UiFilterOption> options,\n  bool multiple = false, String? allLabel, int? allCount, int searchAt = 8})\nuiFilterCount · uiActiveFilters · uiFilterPrune · uiFilterToggle · uiFilterSet · uiFilterRemove',
        ),
        DocSection(
          name: 'Task progress',
          widget: 'UiTaskProgress · showUiTaskProgress',
          summary: 'Progress for a job over many files: the title, "12 of 40", a detail line (the file in hand) and a bar that fills as files finish (it sweeps while the total is 0). Cancel calls controller.cancel() and then reads Stopping, busy, until the job calls controller.close(). showUiTaskProgress opens it in a small dialog the backdrop can\'t close; back and Escape cancel, and it closes itself on close() (even one that came before it finished opening) and completes once closed.',
          demo: const _TaskDemo(),
          code: "final job = UiTaskProgressController(total: photos.length);\nshowUiTaskProgress(context: context, controller: job, title: 'Saving photos');\nfor (final p in photos) {\n  if (job.cancelled) break;\n  job.update(detail: p.name);\n  await save(p);\n  job.update(done: job.done + 1);\n}\njob.close();",
          api: const [
            ApiRow('controller', 'UiTaskProgressController', 'done, total, detail; update(), cancel(), close(); cancelled, closed.'),
            ApiRow('title', 'String', 'What the job is; also names the bar and the dialog.'),
            ApiRow('cancelLabel', 'String?', 'The Cancel button; UiStrings.cancel when null.'),
          ],
          callbacks: const [
            ApiRow('showUiTaskProgress(context:, controller:, title:, cancelLabel:, useRootNavigator:)', 'Future<void>', 'Opens it in a dialog; completes when it has closed.'),
          ],
          shapes: 'UiTaskProgressController({int total = 0, int done = 0, String? detail})',
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
          name: 'Masonry grid',
          widget: 'UiMasonryGrid',
          summary: 'Columns of different heights, each item keeping its own shape, for a photo album. Items are dealt in order to the shortest column (the leftmost on a tie). The parent owns the column count: a two-finger pinch asks for one fewer (apart) or one more (together) through onColumnsChanged, within minColumns..maxColumns. On every change the tiles glide and resize from where they are to their new places, as a phone gallery zooms between grid sizes, and a change mid-glide carries on from where they are. After a pinch the scroll view moves so the picture under the fingers stays under them; a change from a button keeps the scroll where it is. Tiles far off screen jump straight to their place, and with animations off it changes at once. It is not a scroll view itself and builds every item, so put it in one. uiMasonryLayout(width, ratios, columns, gap) is the same layout as a plain function, identical to the web\'s.',
          demo: const _MasonryDemo(),
          code: 'SingleChildScrollView(\n  child: UiMasonryGrid(\n    itemCount: photos.length,\n    ratioOf: (i) => photos[i].height / photos[i].width,\n    itemKey: (i) => photos[i].id,\n    columns: columns,\n    onColumnsChanged: (c) => setState(() => columns = c),\n    itemBuilder: (context, i) => Image(image: photos[i].image, fit: BoxFit.cover),\n  ),\n)',
          api: const [
            ApiRow('itemCount', 'int', 'How many items.'),
            ApiRow('ratioOf', 'double Function(int)', 'Height / width of an item; not finite or not above 0 counts as 1.'),
            ApiRow('itemBuilder', 'Widget Function(BuildContext, int)', 'Fills a tile, laid out at exactly its size (use BoxFit.cover for pictures).'),
            ApiRow('columns', 'int', 'The column count now shown (at least 1).'),
            ApiRow('onColumnsChanged', 'ValueChanged<int>?', 'The pinch asks for a new count; set columns to it.'),
            ApiRow('itemKey', 'Object Function(int)?', 'Stable identity per item, so tiles keep their state.', def: 'index'),
            ApiRow('gap', 'double', 'Space between tiles.', def: '4'),
            ApiRow('minColumns / maxColumns', 'int', 'The pinch stays within these.', def: '1 / 5'),
            ApiRow('pinchable', 'bool', 'Answer a two-finger pinch.', def: 'true'),
            ApiRow('duration / curve', 'Duration / Curve', 'The glide between layouts.', def: '280ms, easeOutCubic'),
          ],
          shapes: 'List<Rect> uiMasonryLayout(double width, List<double> ratios, int columns, double gap)\ndouble uiMasonryHeight(List<Rect> rects)  // the tallest column',
        ),
        DocSection(
          name: 'Device frame',
          widget: 'UiDeviceFrame',
          summary: 'A phone-shaped frame whose screen is exactly width × height logical px, scaled down to fit. The child lays out at true phone size (and sees a phone-sized MediaQuery) and is only scaled visually. onScale reports the scale drawn, for overlays that must line up with the screen, and onFitScale the scale at zoom 1. zoom multiplies the fitted scale (1 fits; kept within 0.25–8, not capped by maxScale): zoomed past the space the frame scrolls both ways to every edge, smaller it stays centred. To zoom around a point, pass horizontalController / verticalController and after the new zoom lays out jump each to UiDeviceFrame.anchoredOffset(...).',
          demo: _DeviceFrameDemo(
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
          code: 'UiDeviceFrame(width: 390, height: 844, zoom: zoom, horizontalController: h, verticalController: v, child: preview)\n\n'
              '// keep the point under the cursor still:\n'
              'h.jumpTo(UiDeviceFrame.anchoredOffset(offset: h.offset, focal: x, viewport: w, extent: frame.outerSize.width, oldScale: s0, newScale: s1));',
          api: const [
            ApiRow('width / height', 'double', 'The screen in logical px.', def: '390 × 844'),
            ApiRow('bezel', 'bool', 'The dark rim.', def: 'true'),
            ApiRow('island', 'bool', 'The camera cut-out.', def: 'true'),
            ApiRow('maxScale', 'double', 'Never fit up past this (zoom is not capped by it).', def: '1'),
            ApiRow('zoom', 'double', 'Multiplies the fitted scale; 0.25–8. Above 1 the frame scrolls both ways.', def: '1'),
            ApiRow('onScale', 'ValueChanged<double>?', 'The scale drawn (fit × zoom).'),
            ApiRow('onFitScale', 'ValueChanged<double>?', 'The scale at zoom 1.'),
            ApiRow('horizontalController / verticalController', 'ScrollController?', 'Scroll positions while zoomed in.'),
            ApiRow('UiDeviceFrame.anchoredOffset(...)', 'static double', 'The offset that keeps a point still across a zoom change.'),
          ],
        ),
      ],
    );
  }
}


/// The device frame demo: zoom out / percentage / zoom in / Fit, above a frame that scrolls when zoomed.
class _DeviceFrameDemo extends StatefulWidget {
  const _DeviceFrameDemo({required this.child});
  final Widget child;

  @override
  State<_DeviceFrameDemo> createState() => _DeviceFrameDemoState();
}

class _DeviceFrameDemoState extends State<_DeviceFrameDemo> {
  static const _steps = [0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0, 6.0, 8.0];
  double _zoom = 1;

  void _step(int dir) {
    final next = dir > 0 ? _steps.where((s) => s > _zoom + 1e-6).firstOrNull : _steps.reversed.where((s) => s < _zoom - 1e-6).firstOrNull;
    if (next != null) setState(() => _zoom = next);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
      Row(spacing: t.space2, children: [
        UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedMinusSign), label: 'Zoom out', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: _zoom <= 0.25 ? null : () => _step(-1)),
        SizedBox(width: 48, child: UiText('${(_zoom * 100).round()}%', textAlign: TextAlign.center)),
        UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedPlusSign), label: 'Zoom in', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: _zoom >= 8 ? null : () => _step(1)),
        UiButton(label: 'Fit', size: UiSize.sm, variant: UiButtonVariant.ghost, onPressed: _zoom == 1 ? null : () => setState(() => _zoom = 1)),
      ]),
      SizedBox(height: 320, child: UiDeviceFrame(zoom: _zoom, child: widget.child)),
    ]);
  }
}

/// The masonry grid demo: 60 coloured tiles in a scroll box, pinch or pick a column count.
class _MasonryDemo extends StatefulWidget {
  const _MasonryDemo();

  @override
  State<_MasonryDemo> createState() => _MasonryDemoState();
}

class _MasonryDemoState extends State<_MasonryDemo> {
  static const _shapes = [1.0, 1.5, 0.66, 1.25, 0.8, 1.33, 0.75];
  int _columns = 3;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
      UiSegmented<int>(
        label: 'Columns',
        options: [for (var c = 1; c <= 5; c++) UiSegmentedOption(value: c, label: '$c')],
        value: _columns,
        onChanged: (c) => setState(() => _columns = c),
      ),
      UiText('$_columns ${_columns == 1 ? 'column' : 'columns'}. Pinch with two fingers, or pick a count.', variant: UiTextVariant.caption),
      Container(
        height: 420,
        decoration: BoxDecoration(border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radius)),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(t.space1),
          child: UiMasonryGrid(
            itemCount: 60,
            ratioOf: (i) => _shapes[(i * 5 + i ~/ 7) % _shapes.length],
            columns: _columns,
            onColumnsChanged: (c) => setState(() => _columns = c),
            itemBuilder: (context, i) => DecoratedBox(
              decoration: BoxDecoration(
                color: HSVColor.fromAHSV(1, (i * 37) % 360, 0.45, 0.8).toColor(),
                borderRadius: BorderRadius.circular(t.radiusSm),
              ),
              child: Center(child: Text('${i + 1}', style: context.uiText.caption.copyWith(color: const Color(0xFF111111)))),
            ),
          ),
        ),
      ),
    ]);
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


/// Runs a fake many-file job in [showUiTaskProgress]: one "file" every 120ms, stopping on Cancel.
Future<void> _fakeJob(BuildContext context, {required String title, required int count}) async {
  final job = UiTaskProgressController(total: count);
  final shown = showUiTaskProgress(context: context, controller: job, title: title);
  for (var i = 0; i < count && !job.cancelled; i++) {
    job.update(detail: 'IMG_${(1000 + i)}.jpg');
    await Future<void>.delayed(const Duration(milliseconds: 120));
    job.update(done: i + 1);
  }
  // Pretend stopping takes a moment, as finishing the file in hand would.
  if (job.cancelled) await Future<void>.delayed(const Duration(milliseconds: 600));
  job.close();
  await shown;
  job.dispose();
}

class _TaskDemo extends StatelessWidget {
  const _TaskDemo();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: UiButton(label: 'Save 40 photos', onPressed: () => _fakeJob(context, title: 'Saving photos', count: 40)),
    );
  }
}

/// A small album: press and hold to start selecting, tap to toggle, then act on the selection.
class _SelectDemo extends StatefulWidget {
  const _SelectDemo();

  @override
  State<_SelectDemo> createState() => _SelectDemoState();
}

class _SelectDemoState extends State<_SelectDemo> {
  static const _count = 12;
  final _picked = <int>{};
  String _note = 'Press and hold a photo to start selecting.';

  void _toggle(int i) => setState(() => _picked.contains(i) ? _picked.remove(i) : _picked.add(i));

  Future<void> _act(String id) async {
    final n = _picked.length;
    if (id == 'save') {
      await _fakeJob(context, title: 'Saving $n photos', count: n);
    }
    if (!mounted) return;
    setState(() {
      _note = switch (id) { 'share' => 'Shared $n photos.', 'save' => 'Saved $n photos.', _ => 'Deleted $n photos (not really).' };
      _picked.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final selecting = _picked.isNotEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
      SizedBox(
        height: 56,
        child: selecting
            ? DecoratedBox(
                decoration: BoxDecoration(color: t.surfaceRaised, borderRadius: BorderRadius.circular(t.radius), border: Border.all(color: t.border)),
                child: UiSelectionBar(
                  count: _picked.length,
                  total: _count,
                  onSelectAll: () => setState(() => _picked.addAll(List.generate(_count, (i) => i))),
                  onClear: () => setState(_picked.clear),
                  onCancel: () => setState(_picked.clear),
                  actions: const [
                    UiSelectionAction(id: 'share', label: 'Share', icon: UiIcon(HugeIcons.strokeRoundedShare08)),
                    UiSelectionAction(id: 'save', label: 'Save to gallery', icon: UiIcon(HugeIcons.strokeRoundedDownload04)),
                    UiSelectionAction(id: 'delete', label: 'Delete', icon: UiIcon(HugeIcons.strokeRoundedDelete02), danger: true),
                  ],
                  onAction: _act,
                ),
              )
            : Align(alignment: AlignmentDirectional.centerStart, child: UiText(_note, variant: UiTextVariant.caption)),
      ),
      LayoutBuilder(builder: (context, box) {
        final columns = box.maxWidth >= 544 ? 4 : 3;
        final size = (box.maxWidth - t.space1 * (columns - 1)) / columns;
        return Wrap(spacing: t.space1, runSpacing: t.space1, children: [
          for (var i = 0; i < _count; i++)
            SizedBox(
              width: size,
              height: size,
              child: UiSelectable(
                semanticLabel: 'Photo ${i + 1}',
                selected: _picked.contains(i),
                selecting: selecting,
                onTap: () => selecting ? _toggle(i) : setState(() => _note = 'Opened photo ${i + 1}.'),
                onLongPress: () => _toggle(i),
                child: Image(image: DemoArt.palette[i % DemoArt.palette.length], fit: BoxFit.cover, excludeFromSemantics: true),
              ),
            ),
        ]);
      }),
    ]);
  }
}


/// A toolbar Filter over 30 coloured tiles by ten people, some of them videos.
class _FilterDemo extends StatefulWidget {
  const _FilterDemo();
  @override
  State<_FilterDemo> createState() => _FilterDemoState();
}

class _FilterDemoState extends State<_FilterDemo> {
  static const names = ['Aisha', 'Ali', 'Mariyam', 'Hassan', 'Shaina', 'Ibrahim', 'Fathimath', 'Ahmed', 'Zara', 'Moosa'];
  static final items = [for (var n = 0; n < 30; n++) (n: n, who: names[(n * 7) % (n < 12 ? 3 : 10)], video: n % 5 == 0)];
  UiFilterValue filter = const {};

  List<UiFilterSection> get sections {
    final counts = <String, int>{};
    for (final it in items) {
      counts[it.who] = (counts[it.who] ?? 0) + 1;
    }
    final people = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final videos = items.where((it) => it.video).length;
    return [
      UiFilterSection(id: 'who', title: 'Uploaded by', multiple: true, allLabel: 'Everyone', allCount: items.length, options: [for (final e in people) UiFilterOption(id: e.key, label: e.key, count: e.value)]),
      UiFilterSection(id: 'kind', title: 'Type', allLabel: 'Photos and videos', options: [UiFilterOption(id: 'photo', label: 'Photos', count: items.length - videos), UiFilterOption(id: 'video', label: 'Videos', count: videos)]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final s = sections;
    final v = uiFilterPrune(s, filter);
    final shown = [
      for (final it in items)
        if ((v['who'] == null || v['who']!.contains(it.who)) && (v['kind'] == null || v['kind']!.contains(it.video ? 'video' : 'photo'))) it,
    ];
    const colours = [Color(0xFF3D5AFE), Color(0xFFE5484D), Color(0xFF2FAA6E), Color(0xFFD9A521), Color(0xFF8A8F98), Color(0xFF5B2A86)];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        UiFilter(sections: s, value: filter, resultCount: shown.length, onChanged: (v) => setState(() => filter = v)),
        SizedBox(width: t.space2),
        Text('${shown.length} of ${items.length}', style: context.uiText.caption),
      ]),
      SizedBox(height: t.space2),
      UiFilterChips(sections: s, value: filter, onChanged: (v) => setState(() => filter = v)),
      SizedBox(height: t.space2),
      Wrap(spacing: 4, runSpacing: 4, children: [
        for (final it in shown)
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: colours[it.n % colours.length], borderRadius: BorderRadius.circular(t.radiusSm)),
            child: Text(it.video ? '${it.who}\n(video)' : it.who, textAlign: TextAlign.center, style: context.uiText.caption.copyWith(color: const Color(0xFFFFFFFF), fontWeight: FontWeight.w600)),
          ),
      ]),
    ]);
  }
}


/// Six tiles with counts and double tap, and a big photo with the viewer's heart.
class _LikeDemo extends StatefulWidget {
  const _LikeDemo();
  @override
  State<_LikeDemo> createState() => _LikeDemoState();
}

class _LikeDemoState extends State<_LikeDemo> {
  final _counts = [0, 3, 1250, 0, 12, 1];
  final _mine = List<bool>.filled(6, false);
  final _bursts = List.generate(6, (_) => GlobalKey<UiHeartBurstState>());
  final _big = GlobalKey<UiHeartBurstState>();
  int _open = 0;

  void _set(int i, bool liked) {
    if (_mine[i] == liked) return;
    setState(() {
      _mine[i] = liked;
      _counts[i] += liked ? 1 : -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space4, children: [
      LayoutBuilder(builder: (context, box) {
        final size = (math.min(box.maxWidth, 420) - t.space1 * 2) / 3;
        return Wrap(spacing: t.space1, runSpacing: t.space1, children: [
          for (var i = 0; i < 6; i++)
            SizedBox(
              width: size,
              height: size,
              child: UiSelectable(
                semanticLabel: 'Liked demo ${i + 1}',
                selected: false,
                selecting: false,
                onTap: () => setState(() => _open = i),
                onDoubleTap: (at) {
                  _set(i, !_mine[i]);
                  _bursts[i].currentState!.play(at);
                },
                child: Stack(fit: StackFit.expand, children: [
                  Image(image: DemoArt.palette[i % DemoArt.palette.length], fit: BoxFit.cover, excludeFromSemantics: true),
                  UiHeartBurst(key: _bursts[i], size: 56),
                  PositionedDirectional(start: t.space1, bottom: t.space1, child: UiLikeCount(count: _counts[i], liked: _mine[i])),
                ]),
              ),
            ),
        ]);
      }),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(t.radius),
              child: Stack(fit: StackFit.expand, children: [
                UiSelectable(
                  semanticLabel: 'Liked demo ${_open + 1}, large',
                  selected: false,
                  selecting: false,
                  onDoubleTap: (at) {
                    _set(_open, !_mine[_open]);
                    _big.currentState!.play(at);
                  },
                  child: Stack(fit: StackFit.expand, children: [
                    Image(image: DemoArt.palette[_open % DemoArt.palette.length], fit: BoxFit.cover, excludeFromSemantics: true),
                    UiHeartBurst(key: _big),
                  ]),
                ),
                PositionedDirectional(
                  end: t.space2,
                  bottom: t.space2,
                  child: UiLikeButton(liked: _mine[_open], count: _counts[_open], onChanged: (v) => _set(_open, v)),
                ),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }
}

/// The album tiles, feed post and plain tags of the Avatar tag section, at phone width.
class AvatarTagDemo extends StatelessWidget {
  const AvatarTagDemo({super.key});

  static const albums = [
    ('Coco Palm', DemoArt(Color(0xFF3D5AFE), Color(0xFFE5484D))),
    ('The Sunset Ballroom at Kurumba Maldives Resort', DemoArt(Color(0xFFF7F3EA), Color(0xFFFFFFFF), sun: -1)),
    ('Bandos Hall', DemoArt(Color(0xFF2FAA6E), Color(0xFFD9A521), sun: 0.7)),
    ('Dharubaaruge', null),
  ];
  /// The events the albums belong to, as the poster grid's tiles name them (the web demo's posters).
  static const events = ['Aisha and Ali', 'Hawwa turns 30', 'Eid get-together', 'Office dinner'];
  static const logo = DemoArt(Color(0xFF1F6F8B), Color(0xFF66C2A5), width: 64, height: 64, sun: -1);
  static const logo2 = DemoArt(Color(0xFFB34A3C), Color(0xFFF2E1C2), width: 64, height: 64, sun: -1);

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final logos = <ImageProvider?>[logo, logo2, null, const _BrokenArt()];
    Widget corner(Widget tag, {bool end = false}) => PositionedDirectional(
          top: end ? t.space2 : t.space1,
          start: t.space1,
          end: end ? t.space2 : t.space1,
          child: Align(alignment: end ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart, child: tag),
        );
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space4, children: [
          UiPosterGrid(
            ratio: 1,
            focus: UiPosterFocus.top,
            posters: [
              for (var i = 0; i < albums.length; i++)
                UiPoster(
                  label: events[i],
                  image: albums[i].$2,
                  colors: albums[i].$2 == null ? const [Color(0xFF5B2A86), Color(0xFFE5484D)] : null,
                  mark: i == 0 ? const UiPosterMark(tone: UiStatus.primary, label: 'New') : null,
                  details: Text(events[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: context.uiText.label.copyWith(color: t.mediaOnScrim)),
                  corner: UiAvatarTag(key: ValueKey('avatar-tag-corner-$i'), name: albums[i].$1, image: logos[i], prefix: 'At', size: UiAvatarTagSize.xs),
                ),
            ],
            onSelect: (_) {},
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: t.surface,
              border: Border.all(color: t.border),
              borderRadius: BorderRadius.circular(t.radius),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(t.radius),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: t.space3, vertical: t.space2),
                  child: Row(spacing: t.space2, children: [
                    Expanded(
                      child: Text("Aisha and Ali's wedding",
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: context.uiText.body.copyWith(fontWeight: FontWeight.w600, fontSize: t.fontSizeSm)),
                    ),
                    Flexible(
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: UiAvatarTag(name: 'Coco Palm Dhuni Kolhu', image: logo, prefix: 'At', variant: UiAvatarTagVariant.plain),
                      ),
                    ),
                  ]),
                ),
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Stack(fit: StackFit.expand, children: [
                    Image(image: DemoArt.palette[4], fit: BoxFit.cover, excludeFromSemantics: true),
                    corner(const UiAvatarTag(name: 'Coco Palm Dhuni Kolhu', image: logo, prefix: 'At'), end: true),
                  ]),
                ),
              ]),
            ),
          ),
          Wrap(spacing: t.space2, runSpacing: t.space2, crossAxisAlignment: WrapCrossAlignment.center, children: const [
            UiAvatarTag(name: 'Bandos Hall', variant: UiAvatarTagVariant.plain),
            UiAvatarTag(name: 'Bandos Hall', variant: UiAvatarTagVariant.plain, size: UiAvatarTagSize.xs),
            UiAvatarTag(name: 'Glass, plain', image: logo, variant: UiAvatarTagVariant.plain, glass: true),
          ]),
        ]),
      ),
    );
  }
}

/// A picture that fails to load, to show the first-letter fallback.
class _BrokenArt extends ImageProvider<_BrokenArt> {
  const _BrokenArt();
  @override
  Future<_BrokenArt> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(_BrokenArt key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(Future<ImageInfo>.error(StateError('broken demo picture')));
}
