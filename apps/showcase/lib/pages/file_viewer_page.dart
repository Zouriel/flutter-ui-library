import 'package:flutter/widgets.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../docs/doc.dart';
import 'media_page.dart' show DemoArt;

const _sampleCode = '''import 'package:zouriel_ui/zouriel_ui.dart';

/// Opens whatever the user picked, with the right viewer.
Widget preview(UiFileNode file) => UiFileViewer(
      src: file.url!,
      name: file.name,
      onOpenExternally: () => share(file), // anything it can't show
    );
''';

const _demoFiles = UiFileNode.dir('demo', children: [
  UiFileNode.dir('docs', children: [
    UiFileNode.file('handbook.pdf', url: 'assets/demo/handbook.pdf'),
    UiFileNode.file('readme.txt', url: 'assets/demo/readme.txt'),
  ]),
  UiFileNode.dir('media', children: [
    UiFileNode.file('tour.mp4', url: 'assets/demo/clip.mp4'),
    UiFileNode.file('tone.m4a', url: 'assets/demo/tone.m4a'),
    UiFileNode.file('poster.jpg', url: 'assets/demo/poster.jpg'),
  ]),
  UiFileNode.file('main.dart', url: 'assets/demo/main.dart.txt', kind: 'dart'),
  UiFileNode.file('backup.zip', url: 'assets/demo/backup.zip'),
  UiFileNode.dir('empty'),
]);

class FileViewerPage extends StatefulWidget {
  const FileViewerPage({super.key});

  @override
  State<FileViewerPage> createState() => _FileViewerPageState();
}

class _FileViewerPageState extends State<FileViewerPage> {
  int _photo = 0;
  String _fillKind = 'image';
  UiFileNode _file = const UiFileNode.file('handbook.pdf', url: 'assets/demo/handbook.pdf');
  final List<String> _log = [];

  List<UiMediaItem> get _lightboxItems => [
        UiMediaItem.image(DemoArt.palette[0], alt: 'Blue to red sky', caption: 'Sunrise · Aisha'),
        UiMediaItem.image(DemoArt.palette[1], alt: 'Green to amber sky'),
        const UiMediaItem.video('assets/demo/clip.mp4', thumb: AssetImage('assets/demo/poster.jpg'), caption: 'A short clip'),
        UiMediaItem.image(DemoArt.palette[3], alt: 'Purple to teal sky', caption: 'Dusk'),
      ];

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final photos = [for (var i = 0; i < 4; i++) DemoArt.palette[i]];
    return DocPage(
      eyebrow: 'Flagship',
      title: 'File viewer',
      lead: 'A viewer for any file: images, video, audio, text, code and PDF, a full-screen lightbox for photos and clips, and a folder browser.',
      children: [
        DocSection(
          name: 'File viewer',
          widget: 'UiFileViewer',
          summary: 'Works out the type and shows an image, video, audio, PDF, text or code viewer, or a file icon with the name and an Open button when it doesn\'t know the type. kind may be a type (image, video, audio, pdf, text, code), a MIME type or an extension; without it the extension of name (or src) decides. src is a URL, a file path or an asset key. Pick a file in the explorer below to see it here.',
          demo: SizedBox(
            height: 360,
            child: KeyedSubtree(
              key: ValueKey(_file.url),
              child: UiFileViewer(src: _file.url ?? '', name: _file.name, kind: _file.kind, onOpenExternally: () => setState(() => _log.add('open ${_file.name}'))),
            ),
          ),
          code: "UiFileViewer(src: 'https://example.com/report.pdf', name: 'report.pdf')",
          api: const [
            ApiRow('src', 'String', 'URL, file path or asset key.'),
            ApiRow('name', 'String?', 'Shown in the fallback; its extension decides the type.'),
            ApiRow('kind', 'String?', 'A type, MIME type or extension override.'),
            ApiRow('onOpenExternally', 'VoidCallback?', 'The fallback\'s Open button.'),
          ],
          callbacks: const [ApiRow('UiFileViewer.typeOf(src:, name:, kind:)', 'UiFileType', 'The detection on its own.')],
        ),
        DocSection(
          name: 'File explorer',
          widget: 'UiFileExplorer',
          summary: 'A folder browser: a breadcrumb path over the current folder, folders first then files, each sorted by name, with an icon per type. Tapping a folder enters it; tapping a file reports it through onOpen, ready for UiFileViewer. A breadcrumb goes back up, and so does the system back gesture. On a phone it is the list on its own; on a tablet put it beside a viewer in a UiSplitter.',
          demo: UiFileExplorer(root: _demoFiles, onOpen: (f) => setState(() => _file = f)),
          code: "UiFileExplorer(\n  root: const UiFileNode.dir('project', children: [\n    UiFileNode.file('notes.pdf', url: 'assets/notes.pdf'),\n  ]),\n  onOpen: (file) => setState(() => open = file),\n)",
          api: const [
            ApiRow('root', 'UiFileNode', 'The top folder.'),
            ApiRow('onOpen', 'ValueChanged<UiFileNode>?', 'A file was tapped.'),
            ApiRow('maxHeight', 'double', 'The list scrolls past this.', def: '280'),
          ],
          shapes: 'UiFileNode.file(String name, {String? url, String? kind})\nUiFileNode.dir(String name, {List<UiFileNode> children})',
        ),
        DocSection(
          name: 'Image viewer',
          widget: 'UiImageViewer',
          summary: 'Zoom with the buttons, a pinch, a double tap or Ctrl+wheel; pan by dragging when zoomed in, with the wheel or the arrow keys; Fit resets. With hasPrevious/hasNext it shows step buttons and reads a swipe (only at fit: a zoomed picture pans), reporting the intent through onPrevious/onNext; the host keeps the list and swaps image. It bounds itself to 70% of the screen so the bar stays in view.',
          demo: UiImageViewer(
            image: photos[_photo],
            alt: 'Demo picture ${_photo + 1}',
            maxHeight: 320,
            hasPrevious: _photo > 0,
            hasNext: _photo < photos.length - 1,
            onPrevious: () => setState(() => _photo--),
            onNext: () => setState(() => _photo++),
          ),
          code: 'UiImageViewer(\n  image: photos[i],\n  alt: captions[i],\n  hasPrevious: i > 0,\n  hasNext: i < photos.length - 1,\n  onPrevious: () => setState(() => i--),\n  onNext: () => setState(() => i++),\n)',
          api: const [
            ApiRow('image', 'ImageProvider', 'The picture.'),
            ApiRow('alt', 'String', 'Accessible description.'),
            ApiRow('hasPrevious / hasNext', 'bool', 'Whether neighbours exist.', def: 'false'),
            ApiRow('onPrevious / onNext', 'VoidCallback?', 'A swipe, key or step button asking for the neighbour.'),
            ApiRow('maxHeight', 'double?', 'Default 70% of the screen.'),
            ApiRow('fill', 'bool', 'The whole page: no cap, the controls floating over the bottom. See Full-page document viewer.', def: 'false'),
          ],
        ),
        DocSection(
          name: 'Full-page document viewer',
          widget: 'UiImageViewer(fill: true) · UiPdfViewer(fill: true)',
          summary: 'For a page whose whole point is one document, such as a payment slip opened from a list: put the viewer in an Expanded (or a full route) and set fill. It takes all of that space with no frame, the photo or page is fitted into it (contain, centred; 100% is fitted), pinch, double tap, Ctrl+wheel and the buttons still zoom and a zoomed photo still pans, and the controls float over the bottom on the glass surface, above the home indicator, instead of a bar of their own. The PDF viewer adds a Fit button.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space3, children: [
            UiSegmented<String>(
              label: 'Document',
              value: _fillKind,
              options: const [UiSegmentedOption(value: 'image', label: 'Photo'), UiSegmentedOption(value: 'pdf', label: 'PDF')],
              onChanged: (v) => setState(() => _fillKind = v),
            ),
            // A phone-sized page: the title, then the viewer filling everything below it.
            Container(
              key: const ValueKey('fill-demo'),
              constraints: const BoxConstraints(maxWidth: 390),
              height: 640,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: t.bg, border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radiusLg)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Padding(padding: EdgeInsets.symmetric(horizontal: t.space4, vertical: t.space3), child: const UiText('Payment slip', variant: UiTextVariant.h5)),
                Expanded(
                  child: _fillKind == 'pdf'
                      ? const UiPdfViewer(src: 'assets/demo/handbook.pdf', fill: true)
                      : const UiImageViewer(image: AssetImage('assets/demo/slip.jpg'), alt: 'Photo of a payment receipt', fill: true),
                ),
              ]),
            ),
          ]),
          code: "Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [\n  UiText('Payment slip', variant: UiTextVariant.h5),\n  Expanded(\n    child: slip.isPdf\n        ? UiPdfViewer(data: slip.bytes, fill: true)\n        : UiImageViewer(image: MemoryImage(slip.bytes), alt: 'Payment slip', fill: true),\n  ),\n])",
          api: const [
            ApiRow('fill', 'bool', 'UiImageViewer and UiPdfViewer: take all the space the parent gives, fitted, with floating controls. In an unbounded parent it falls back to maxHeight.', def: 'false'),
          ],
        ),
        DocSection(
          name: 'Media lightbox',
          widget: 'UiMediaLightbox',
          summary: 'Photographs and clips at full screen, edge to edge, with the chrome floating on top. It opens as a modal route: focus stays inside, back or Escape closes. Photos zoom (pinch, double tap) and pan; clips get themed controls and start themselves. Swipe between items, drag down to dismiss, tap the dark to close, tap a photo to hide the chrome; it fades away on its own while a clip plays. Keys: Left/Right step (Shift seeks), Space or k plays, j/l seek 10s, m mutes, 0 resets the zoom. Actions can apply to some items only.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space2, children: [
            UiButton(
              label: 'Open the lightbox',
              onPressed: () => UiMediaLightbox.show(
                context,
                items: _lightboxItems,
                label: 'Demo set',
                actions: [
                  const UiMediaAction(id: 'save', label: 'Save'),
                  UiMediaAction(id: 'remove', label: 'Remove', danger: true, when: (item, i) => !item.isVideo),
                ],
                onAction: (id, item, i) => setState(() => _log.add('$id item ${i + 1}')),
              ),
            ),
            if (_log.isNotEmpty) UiText('Last action: ${_log.last}', variant: UiTextVariant.caption),
          ]),
          code: "UiMediaLightbox.show(\n  context,\n  items: [\n    UiMediaItem.image(NetworkImage(url), alt: 'Cake'),\n    UiMediaItem.video('https://example.com/toast.mp4', thumb: poster),\n  ],\n  actions: [UiMediaAction(id: 'remove', label: 'Remove', danger: true, when: (item, i) => mine(item))],\n  onAction: (id, item, i) => ...,\n)",
          api: const [
            ApiRow('items', 'List<UiMediaItem>', 'What there is.'),
            ApiRow('initialIndex', 'int', 'Where to start.', def: '0'),
            ApiRow('label', 'String', 'The set\'s title (when an item has no caption).'),
            ApiRow('actions / onAction', 'List<UiMediaAction> / callback', 'Top-bar buttons and their presses.'),
            ApiRow('onIndexChanged', 'ValueChanged<int>?', 'Every step.'),
          ],
          callbacks: const [ApiRow('UiMediaLightbox.show(...)', 'Future<int?>', 'Completes with the index it closed on.')],
          shapes: 'UiMediaItem.image(ImageProvider image, {ImageProvider? thumb, String? alt, String? caption})\nUiMediaItem.video(String src, {ImageProvider? thumb, String? caption})\nUiMediaAction({required String id, required String label, bool danger = false,\n  bool Function(UiMediaItem item, int index)? when})',
        ),
        DocSection(
          name: 'Video player',
          widget: 'UiVideoPlayer',
          summary: 'The platform player (ExoPlayer on Android, through video_player) with themed controls: play/pause, the time, a seek bar, mute, speed (1×, 1.5×, 2×, 0.5×) and full screen. Tapping the picture plays or pauses. The phone\'s volume keys set the volume.',
          demo: const UiVideoPlayer(src: 'assets/demo/clip.mp4', poster: AssetImage('assets/demo/poster.jpg'), maxHeight: 220),
          code: "UiVideoPlayer(src: 'https://example.com/tour.mp4', poster: NetworkImage(posterUrl))",
          api: const [
            ApiRow('src', 'String', 'URL, file path or asset key.'),
            ApiRow('poster', 'ImageProvider?', 'Shown until it starts.'),
            ApiRow('controller', 'VideoPlayerController?', 'Manage playback yourself.'),
            ApiRow('maxHeight', 'double?', 'Default 60% of the screen.'),
          ],
        ),
        DocSection(
          name: 'Audio player',
          widget: 'UiAudioPlayer',
          summary: 'Themed audio controls: play/pause, a title, the elapsed time, a seek bar and the duration. The seek bar is a slider for TalkBack ("0:02 of 0:08"). It plays through video_player too, so the library needs one media plugin rather than two.',
          demo: const UiAudioPlayer(src: 'assets/demo/tone.m4a', title: 'A quiet tone'),
          code: "UiAudioPlayer(src: 'https://example.com/interview.mp3', title: 'Interview')",
          api: const [
            ApiRow('src', 'String', 'URL, file path or asset key.'),
            ApiRow('title', 'String?', 'Shown beside the button.'),
            ApiRow('controller', 'VideoPlayerController?', 'Manage playback yourself.'),
          ],
        ),
        DocSection(
          name: 'Text & code viewers',
          widget: 'UiTextViewer · UiCodeViewer',
          summary: 'UiTextViewer shows plain text with wrapped lines. UiCodeViewer shows monospace source with line numbers that stay put while long lines scroll sideways, a language label and a Copy button. Both take the text as content, or load src (showing Loading… and then the text or the error).',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: const [
            UiCodeViewer(content: _sampleCode, language: 'dart'),
            UiTextViewer(src: 'assets/demo/readme.txt'),
          ]),
          code: "UiCodeViewer(content: source, language: 'dart')\nUiTextViewer(src: 'assets/notes.txt')",
          api: const [
            ApiRow('content', 'String?', 'The text itself.'),
            ApiRow('src', 'String?', 'Loaded when content is null.'),
            ApiRow('load', 'Future<String> Function(String)?', 'Fetch src your own way.'),
            ApiRow('language', 'String', 'UiCodeViewer: the label.', def: "'text'"),
            ApiRow('copyable', 'bool', 'UiCodeViewer: the Copy button.', def: 'true'),
            ApiRow('maxHeight', 'double?', 'Scrolls past this height.'),
          ],
        ),
        DocSection(
          name: 'PDF viewer',
          widget: 'UiPdfViewer',
          summary: 'A PDF one page at a time, rendered by PDFium (pdfrx), with previous/next page buttons and zoom from 40% to 400% by buttons, pinch or double tap; 100% fits the page to the width. Give it src, the bytes as data, or any pdfrx documentRef. If the file can\'t be loaded the error shows in place of the page.',
          demo: const SizedBox(height: 380, child: UiPdfViewer(src: 'assets/demo/handbook.pdf')),
          code: "UiPdfViewer(src: 'https://example.com/handbook.pdf')\nUiPdfViewer(data: bytes)",
          api: const [
            ApiRow('src / data / documentRef', 'String? / Uint8List? / PdfDocumentRef?', 'Where the PDF comes from.'),
            ApiRow('initialPage', 'int', 'First page shown.', def: '1'),
            ApiRow('onPageChanged', 'ValueChanged<int>?', 'Each page turn.'),
            ApiRow('maxHeight', 'double?', 'Height in an unbounded parent (70% of the screen).'),
            ApiRow('fill', 'bool', 'The whole page: each page fitted (100% = fitted), controls floating at the bottom, a Fit button.', def: 'false'),
          ],
        ),
      ],
    );
  }
}
