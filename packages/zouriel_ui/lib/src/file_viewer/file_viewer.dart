import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../button/button.dart';
import '../core/icon.dart';
import '../core/interactive.dart';
import '../core/types.dart';
import '../theme/theme.dart';
import 'image_viewer.dart';
import 'pdf_viewer.dart';
import 'players.dart';
import 'sources.dart';
import 'text_viewers.dart';

/// The kinds of file [UiFileViewer] can show.
enum UiFileType { image, video, audio, pdf, text, code, unknown }

const Map<String, UiFileType> _byExtension = {
  'png': UiFileType.image, 'jpg': UiFileType.image, 'jpeg': UiFileType.image, 'gif': UiFileType.image, 'webp': UiFileType.image,
  'bmp': UiFileType.image, 'avif': UiFileType.image, 'svg': UiFileType.unknown,
  'mp4': UiFileType.video, 'webm': UiFileType.video, 'mov': UiFileType.video, 'ogv': UiFileType.video, 'm4v': UiFileType.video,
  'mp3': UiFileType.audio, 'wav': UiFileType.audio, 'ogg': UiFileType.audio, 'm4a': UiFileType.audio, 'flac': UiFileType.audio, 'aac': UiFileType.audio,
  'pdf': UiFileType.pdf,
  'txt': UiFileType.text, 'md': UiFileType.text, 'log': UiFileType.text, 'csv': UiFileType.text, 'rtf': UiFileType.text,
  'ts': UiFileType.code, 'tsx': UiFileType.code, 'js': UiFileType.code, 'jsx': UiFileType.code, 'json': UiFileType.code, 'css': UiFileType.code,
  'scss': UiFileType.code, 'html': UiFileType.code, 'xml': UiFileType.code, 'yml': UiFileType.code, 'yaml': UiFileType.code, 'py': UiFileType.code,
  'java': UiFileType.code, 'go': UiFileType.code, 'rs': UiFileType.code, 'sh': UiFileType.code, 'dart': UiFileType.code, 'kt': UiFileType.code,
};

/// `ui-file-viewer`: works out what a file is and shows it with the matching viewer: image (zoom
/// and pan), video, audio, PDF, text or code; anything else gets a file icon, the name and an Open
/// button ([onOpenExternally]).
///
/// [kind] may be a type (`image`, `video`, `audio`, `pdf`, `text`, `code`), a MIME type
/// (`application/pdf`, `image/png`) or an extension (`ts`). Without it the extension of [name] (or
/// of [src]) decides. [src] is a URL, file path or asset key (see [UiFileSources]). SVG is shown as
/// unknown: Flutter has no built-in SVG renderer.
class UiFileViewer extends StatelessWidget {
  const UiFileViewer({super.key, required this.src, this.name, this.kind, this.onOpenExternally});

  final String src;
  final String? name;
  final String? kind;

  /// Called by the fallback's Open button (hand the file to another app, or download it).
  final VoidCallback? onOpenExternally;

  /// The extension the viewer uses (for the code viewer's language label).
  static String extensionFor({required String src, String? name, String? kind}) {
    if (kind != null && !kind.contains('/') && !UiFileType.values.any((t) => t.name == kind)) return kind.toLowerCase();
    return UiFileSources.extensionOf(name ?? src);
  }

  /// The detected type, the web `type()`.
  static UiFileType typeOf({required String src, String? name, String? kind}) {
    final k = kind?.toLowerCase();
    if (k != null) {
      for (final t in UiFileType.values) {
        if (t.name == k && t != UiFileType.unknown) return t;
      }
      if (k.startsWith('image/')) return k == 'image/svg+xml' ? UiFileType.unknown : UiFileType.image;
      if (k.startsWith('video/')) return UiFileType.video;
      if (k.startsWith('audio/')) return UiFileType.audio;
      if (k == 'application/pdf') return UiFileType.pdf;
      if (k.startsWith('text/')) return UiFileType.text;
    }
    return _byExtension[extensionFor(src: src, name: name, kind: kind)] ?? UiFileType.unknown;
  }

  /// The Hugeicons icon for a file of [type].
  static UiIconData iconFor(UiFileType type) => switch (type) {
        UiFileType.image => HugeIcons.strokeRoundedImage02,
        UiFileType.video => HugeIcons.strokeRoundedVideo02,
        UiFileType.audio => HugeIcons.strokeRoundedMusicNote02,
        UiFileType.pdf => HugeIcons.strokeRoundedPdf01,
        UiFileType.code => HugeIcons.strokeRoundedSourceCode,
        _ => HugeIcons.strokeRoundedFile01,
      };

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final type = typeOf(src: src, name: name, kind: kind);
    switch (type) {
      case UiFileType.image:
        return UiImageViewer(image: _imageProvider(src), alt: name ?? '');
      case UiFileType.video:
        return UiVideoPlayer(src: src);
      case UiFileType.audio:
        return UiAudioPlayer(src: src, title: name);
      case UiFileType.pdf:
        return UiPdfViewer(src: src);
      case UiFileType.text:
        return UiTextViewer(src: src);
      case UiFileType.code:
        return UiCodeViewer(src: src, language: extensionFor(src: src, name: name, kind: kind));
      case UiFileType.unknown:
        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 200),
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(t.space6),
              child: Column(mainAxisSize: MainAxisSize.min, spacing: t.space2, children: [
                UiIcon(HugeIcons.strokeRoundedFile01, size: 40, strokeWidth: 1.6, color: t.textMuted),
                Text(name ?? UiFileSources.nameOf(src), textAlign: TextAlign.center, style: context.uiText.body),
                Text('Preview not available for this file type.', textAlign: TextAlign.center, style: context.uiText.caption),
                if (onOpenExternally != null)
                  UiButton(label: 'Open', icon: const UiIcon(HugeIcons.strokeRoundedDownload01), variant: UiButtonVariant.link, size: UiSize.sm, onPressed: onOpenExternally),
              ]),
            ),
          ),
        );
    }
  }

  static ImageProvider _imageProvider(String src) {
    if (UiFileSources.isNetwork(src)) return NetworkImage(src);
    return AssetImage(src);
  }
}

/// A file or folder for [UiFileExplorer].
@immutable
class UiFileNode {
  const UiFileNode.file(this.name, {this.url, this.kind}) : children = const [], isDir = false;
  const UiFileNode.dir(this.name, {this.children = const []})
      : isDir = true,
        url = null,
        kind = null;

  final String name;
  final bool isDir;

  /// Where the file is, ready for [UiFileViewer.src].
  final String? url;

  /// A type, MIME type or extension hint.
  final String? kind;
  final List<UiFileNode> children;

  UiFileType get type => isDir ? UiFileType.unknown : UiFileViewer.typeOf(src: url ?? name, name: name, kind: kind);
}

/// `ui-file-explorer`: a folder browser. A breadcrumb path over a list of the current folder,
/// folders first and then files, each sorted by name, with an icon per type. Tapping a folder goes
/// into it; tapping a file reports it through [onOpen] (ready for [UiFileViewer]). A breadcrumb goes
/// back up, and so does the system back gesture while inside a folder.
///
/// On phones this is the list on its own; on a tablet put it beside a [UiFileViewer] in a
/// [UiSplitter].
class UiFileExplorer extends StatefulWidget {
  const UiFileExplorer({super.key, required this.root, this.onOpen, this.maxHeight = 280});

  final UiFileNode root;
  final ValueChanged<UiFileNode>? onOpen;

  /// The list scrolls past this height.
  final double maxHeight;

  @override
  State<UiFileExplorer> createState() => _UiFileExplorerState();
}

class _UiFileExplorerState extends State<UiFileExplorer> {
  final List<UiFileNode> _path = [];

  @override
  void didUpdateWidget(UiFileExplorer old) {
    super.didUpdateWidget(old);
    if (old.root != widget.root) _path.clear();
  }

  List<UiFileNode> get _entries {
    final dir = _path.isEmpty ? widget.root : _path.last;
    return [...dir.children]..sort((a, b) => a.isDir == b.isDir ? a.name.toLowerCase().compareTo(b.name.toLowerCase()) : (a.isDir ? -1 : 1));
  }

  void _goTo(int index) => setState(() => index < 0 ? _path.clear() : _path.removeRange(index + 1, _path.length));

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final entries = _entries;
    final crumbs = [widget.root, ..._path];

    final bar = Container(
      padding: EdgeInsets.symmetric(horizontal: t.space2, vertical: t.space1),
      decoration: BoxDecoration(color: t.surfaceRaised, border: Border(bottom: BorderSide(color: t.border))),
      child: Semantics(
        container: true,
        label: 'Path',
        explicitChildNodes: true,
        child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: t.space1, children: [
          for (var i = 0; i < crumbs.length; i++) ...[
            if (i > 0) ExcludeSemantics(child: Text('/', style: context.uiText.caption)),
            _Crumb(
              label: i == 0 && crumbs[i].name.isEmpty ? 'root' : crumbs[i].name,
              current: i == crumbs.length - 1,
              onTap: () => _goTo(i - 1),
            ),
          ],
        ]),
      ),
    );

    final list = entries.isEmpty
        ? Padding(padding: EdgeInsets.all(t.space4), child: Text('Empty folder', textAlign: TextAlign.center, style: context.uiText.caption))
        : ListView(
            shrinkWrap: true,
            padding: EdgeInsets.all(t.space1),
            children: [
              for (final n in entries)
                _Row(
                  node: n,
                  onTap: () => n.isDir ? setState(() => _path.add(n)) : widget.onOpen?.call(n),
                ),
            ],
          );

    return PopScope(
      canPop: _path.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _path.isNotEmpty) setState(_path.removeLast);
      },
      child: Container(
        decoration: BoxDecoration(border: Border.all(color: t.border), borderRadius: BorderRadius.circular(context.uiTheme.radius())),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(context.uiTheme.radius()),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            bar,
            ConstrainedBox(constraints: BoxConstraints(maxHeight: widget.maxHeight), child: list),
          ]),
        ),
      ),
    );
  }
}

class _Crumb extends StatelessWidget {
  const _Crumb({required this.label, required this.current, required this.onTap});
  final String label;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return UiInteractive(
      onTap: onTap,
      semanticLabel: label,
      semanticHint: current ? 'Current folder' : null,
      excludeChildSemantics: true,
      builder: (context, s) => AnimatedContainer(
        duration: context.uiAnimate ? t.motionBase : Duration.zero,
        height: t.sizeSm,
        constraints: const BoxConstraints(maxWidth: 200),
        padding: EdgeInsets.symmetric(horizontal: t.space1),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: s.hovered || s.pressed ? t.elevatedHover : null,
          borderRadius: BorderRadius.circular(t.radiusXs),
          boxShadow: uiFocusRing(t, show: s.focused),
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.uiText.caption.copyWith(color: current || s.hovered ? t.text : t.textMuted)),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.node, required this.onTap});
  final UiFileNode node;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final touch = uiTouchPlatform(context);
    return UiInteractive(
      onTap: onTap,
      padTouchTarget: false,
      pressScale: false,
      semanticLabel: node.isDir ? '${node.name}, folder' : node.name,
      excludeChildSemantics: true,
      builder: (context, s) => AnimatedContainer(
        duration: context.uiAnimate ? t.motionBase : Duration.zero,
        constraints: BoxConstraints(minHeight: touch ? uiMinTouchTarget : t.sizeMd),
        padding: EdgeInsets.symmetric(horizontal: t.space2, vertical: t.space1),
        decoration: BoxDecoration(
          color: s.hovered || s.pressed ? t.surfaceHover : null,
          borderRadius: BorderRadius.circular(t.radiusXs),
        ),
        // Inset ring: the list scrolls, and an outset ring would be clipped at its edges.
        foregroundDecoration: s.focused ? BoxDecoration(borderRadius: BorderRadius.circular(t.radiusXs), border: Border.all(color: t.borderFocus, width: 2)) : null,
        child: Row(spacing: t.space2, children: [
          UiIcon(node.isDir ? HugeIcons.strokeRoundedFolder01 : UiFileViewer.iconFor(node.type), size: 16, strokeWidth: 1.6, color: t.textMuted),
          Expanded(child: Text(node.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.uiText.body.copyWith(fontSize: t.fontSizeSm))),
          if (node.isDir) UiIcon(HugeIcons.strokeRoundedArrowRight01, size: 14, color: t.textMuted),
        ]),
      ),
    );
  }
}
