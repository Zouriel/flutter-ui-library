import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../button/button.dart';
import '../../core/icon.dart';
import '../../core/interactive.dart';
import '../../core/types.dart';
import '../../theme/theme.dart';

/// A file handed to [UiFileUpload] by a picker or a drop. Only [name] and [size] are needed by the
/// widget; the rest is carried through for the app.
@immutable
class UiPickedFile {
  const UiPickedFile({required this.name, required this.size, this.mimeType, this.path, this.bytes});
  final String name;

  /// Bytes.
  final int size;

  /// e.g. `image/png`; used by MIME rules in `accept`.
  final String? mimeType;
  final String? path;
  final Uint8List? bytes;
}

/// Opens the platform's file picker. The library ships no picker (that needs a plugin); the app
/// supplies one, typically wrapping `file_picker` or `file_selector`:
///
/// ```dart
/// Future<List<UiPickedFile>?> pick({required bool multiple, required List<String> accept}) async {
///   final r = await FilePicker.platform.pickFiles(allowMultiple: multiple,
///       type: FileType.custom, allowedExtensions: [for (final a in accept) if (a.startsWith('.')) a.substring(1)]);
///   return r?.files.map((f) => UiPickedFile(name: f.name, size: f.size, path: f.path)).toList();
/// }
/// ```
///
/// [accept] is the `accept` list split into rules (`.pdf`, `image/png`, `image/*`). Return null or
/// an empty list when the user cancels.
typedef UiFilePicker = Future<List<UiPickedFile>?> Function({required bool multiple, required List<String> accept});

/// The rules of an `accept` string (comma-separated, trimmed, lower-case).
List<String> uiAcceptRules(String? accept) =>
    (accept ?? '').split(',').map((r) => r.trim().toLowerCase()).where((r) => r.isNotEmpty).toList();

/// Whether a file matches an `accept` list the way a browser's file dialog reads it: extensions
/// (`.pdf`), exact MIME types (`image/png`) or wildcards (`image/*`). No list accepts everything.
bool uiFileMatchesAccept(UiPickedFile file, String? accept) {
  final rules = uiAcceptRules(accept);
  if (rules.isEmpty) return true;
  final name = file.name.toLowerCase();
  final type = (file.mimeType ?? '').toLowerCase();
  return rules.any((r) => r.startsWith('.') ? name.endsWith(r) : r.endsWith('/*') ? type.startsWith(r.substring(0, r.length - 1)) : type == r);
}

/// `ui-file-upload`: a dropzone that opens a file picker when tapped, then lists the chosen files with
/// their sizes. Files that don't match [accept] go to [onRejected]; the rest to [onFilesSelected]
/// (only the first unless [multiple]).
///
/// The picker comes from the app ([picker], see [UiFilePicker]). Drag and drop needs a platform drop
/// plugin too: wire its events to [UiFileUploadState.setDragOver] and [UiFileUploadState.addFiles]
/// (through a `GlobalKey<UiFileUploadState>`) and set [dropEnabled] so the hint mentions dropping.
class UiFileUpload extends StatefulWidget {
  const UiFileUpload({
    super.key,
    required this.picker,
    this.onFilesSelected,
    this.onRejected,
    this.multiple = false,
    this.accept,
    this.acceptLabel,
    this.dropEnabled = false,
    this.enabled = true,
    this.radius,
    this.label,
    this.hint,
    this.preview,
    this.previewSemanticLabel,
    this.previewFit = BoxFit.cover,
    this.previewAspectRatio = 16 / 9,
    this.replaceLabel,
    this.onRemove,
    this.removeLabel,
    this.showFiles = true,
  });

  /// List the picked files (name and size) under the box (the web `showFiles`). Turn it off when the app shows
  /// its own list, such as one with each file's upload progress.
  final bool showFiles;

  /// A picture already uploaded (the web `preview`). The same box then shows it, and tapping it picks a
  /// replacement ([replaceLabel], "Tap to change" by default). Null shows the empty dropzone.
  final ImageProvider? preview;

  /// What the picture shows (the web `previewAlt`); also starts the box's semantic label.
  final String? previewSemanticLabel;

  /// [BoxFit.cover] fills the box (photos); [BoxFit.contain] shows all of it with room around (logos,
  /// transparent pictures). The web `previewFit` 'cover' / 'contain'.
  final BoxFit previewFit;

  /// The box's shape while it shows a picture (the web `previewAspect`, '16 / 9' there).
  final double previewAspectRatio;

  /// The label on the picture; defaults to [UiStrings.uploadReplace].
  final String? replaceLabel;

  /// When set, a Remove button under the picture calls it (the web `removable` + `(remove)`).
  final VoidCallback? onRemove;

  /// Its label; defaults to [UiStrings.uploadRemove].
  final String? removeLabel;

  /// The action, in bold (the web `label`); defaults to [UiStrings.uploadLabel] ("Tap to upload").
  final String? label;

  /// What follows it when [dropEnabled] (the web `hint`); defaults to [UiStrings.uploadHint]
  /// ("or drag & drop"); '' hides it.
  final String? hint;

  /// Null (or [enabled] false) disables the dropzone.
  final UiFilePicker? picker;
  final ValueChanged<List<UiPickedFile>>? onFilesSelected;

  /// Files that don't match [accept].
  final ValueChanged<List<UiPickedFile>>? onRejected;
  final bool multiple;

  /// Accepted types, web style: `.pdf,image/*`.
  final String? accept;

  /// What to show for the accepted types when [accept] reads badly (e.g. "PNG, JPEG or WebP").
  final String? acceptLabel;

  /// Mention drag and drop in the hint (only when the app has wired a drop plugin).
  final bool dropEnabled;
  final bool enabled;
  final bool? radius;

  @override
  State<UiFileUpload> createState() => UiFileUploadState();
}

class UiFileUploadState extends State<UiFileUpload> {
  List<UiPickedFile> _files = const [];
  bool _over = false;
  bool _picking = false;

  bool get _enabled => widget.enabled && widget.picker != null;

  /// Files the user is dragging over the zone: highlight it.
  void setDragOver(bool over) {
    if (_enabled && over != _over) setState(() => _over = over);
  }

  /// Takes dropped (or otherwise obtained) files: checks them against `accept`, reports rejects,
  /// keeps the rest.
  void addFiles(List<UiPickedFile> files) {
    setState(() => _over = false);
    if (!_enabled) return;
    final ok = files.where((f) => uiFileMatchesAccept(f, widget.accept)).toList();
    if (ok.length < files.length) widget.onRejected?.call(files.where((f) => !ok.contains(f)).toList());
    if (ok.isNotEmpty) _commit(ok);
  }

  void _commit(List<UiPickedFile> list) {
    final files = widget.multiple ? list : list.take(1).toList();
    setState(() => _files = files);
    widget.onFilesSelected?.call(files);
  }

  Future<void> _pick() async {
    if (!_enabled || _picking) return;
    _picking = true;
    try {
      final picked = await widget.picker!(multiple: widget.multiple, accept: uiAcceptRules(widget.accept));
      // Pickers usually filter already; check anyway so a loose picker can't slip a wrong type in.
      if (mounted && picked != null && picked.isNotEmpty) addFiles(picked);
    } finally {
      _picking = false;
    }
  }

  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final r = (widget.radius ?? theme.config.radius) ? t.radius : 0.0;
    final acceptText = widget.acceptLabel ?? widget.accept;
    final body = context.uiText.body;
    if (widget.preview != null) return _withPreview(context, widget.preview!, r);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UiInteractive(
          onTap: _enabled ? _pick : null,
          enabled: _enabled,
          semanticHint: acceptText,
          pressScale: false,
          // Far larger than a touch target already; padding would stop it stretching.
          padTouchTarget: false,
          builder: (context, s) {
            final hot = _over || (s.hovered && !s.disabled);
            return AnimatedOpacity(
              opacity: s.disabled ? 0.5 : 1,
              duration: t.motionBase,
              child: CustomPaint(
                foregroundPainter: _DashedBorder(color: hot ? t.primary : t.controlBorder, radius: r),
                child: AnimatedContainer(
                  duration: context.uiAnimate ? t.motionBase : Duration.zero,
                  padding: EdgeInsets.symmetric(vertical: t.space6, horizontal: t.space4),
                  decoration: BoxDecoration(
                    color: hot ? uiMix(t.primary, 0.08, t.surface) : t.surface,
                    borderRadius: BorderRadius.circular(r),
                    boxShadow: s.focused ? t.focusRing : const [],
                  ),
                  child: Column(
                    spacing: t.space1,
                    children: [
                      UiIcon(HugeIcons.strokeRoundedCloudUpload, size: 22, color: t.textMuted),
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(text: widget.label ?? context.uiStrings.uploadLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                          if (widget.dropEnabled && (widget.hint ?? context.uiStrings.uploadHint).isNotEmpty)
                            TextSpan(text: ' ${widget.hint ?? context.uiStrings.uploadHint}'),
                        ]),
                        textAlign: TextAlign.center,
                        style: body.copyWith(fontSize: t.fontSizeMd, height: 1.35, color: t.text),
                      ),
                      if (acceptText != null)
                        Text(acceptText, textAlign: TextAlign.center, style: body.copyWith(fontSize: t.fontSizeSm, color: t.textMuted)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        if (widget.showFiles && _files.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: t.space2),
            child: Semantics(
              container: true,
              label: context.uiStrings.chosenFiles,
              explicitChildNodes: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 2,
                children: [
                  for (final f in _files)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: t.space2, vertical: t.space1),
                      decoration: BoxDecoration(color: t.surfaceRaised, borderRadius: BorderRadius.circular(t.radiusXs)),
                      child: MergeSemantics(
                        child: Row(
                          spacing: t.space3,
                          children: [
                            Expanded(child: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: body.copyWith(fontSize: t.fontSizeSm, color: t.text))),
                            Text(formatSize(f.size),
                                style: body.copyWith(fontSize: t.fontSizeSm, color: t.textMuted, fontFeatures: const [FontFeature.tabularFigures()])),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

extension on UiFileUploadState {
  /// The box with the uploaded picture in it: tapping (or dropping on) it picks a replacement; Remove under it.
  Widget _withPreview(BuildContext context, ImageProvider image, double r) {
    final t = context.uiTheme.tokens;
    final strings = context.uiStrings;
    final replace = widget.replaceLabel ?? strings.uploadReplace;
    final name = widget.previewSemanticLabel;
    final contain = widget.previewFit == BoxFit.contain;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UiInteractive(
          onTap: _enabled ? _pick : null,
          enabled: _enabled,
          semanticLabel: name == null || name.isEmpty ? replace : '$name. $replace',
          pressScale: false,
          padTouchTarget: false,
          builder: (context, s) {
            final hot = _over || (s.hovered && !s.disabled);
            return AnimatedOpacity(
              opacity: s.disabled ? 0.5 : 1,
              duration: t.motionBase,
              child: AspectRatio(
                aspectRatio: widget.previewAspectRatio,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 120),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: t.surface,
                    border: Border.all(color: hot ? t.primary : t.border),
                    borderRadius: BorderRadius.circular(r),
                    boxShadow: s.focused ? t.focusRing : const [],
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Padding(
                        // A contained picture (a logo) keeps clear of the label at the bottom.
                        padding: contain ? EdgeInsets.fromLTRB(t.space3, t.space3, t.space3, t.space3 + 32) : EdgeInsets.zero,
                        child: Image(image: image, fit: widget.previewFit, excludeFromSemantics: true,
                            errorBuilder: (context, _, _) => const SizedBox.shrink()),
                      ),
                      Positioned(
                        left: t.space2,
                        right: t.space2,
                        bottom: t.space2,
                        child: Center(
                          child: AnimatedContainer(
                            duration: context.uiAnimate ? t.motionBase : Duration.zero,
                            padding: EdgeInsets.symmetric(horizontal: t.space3, vertical: t.space1),
                            decoration: BoxDecoration(
                              color: hot ? t.primary : t.surface.withValues(alpha: 0.88),
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: t.shadow1,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              spacing: t.space1,
                              children: [
                                UiIcon(HugeIcons.strokeRoundedCloudUpload, size: 16, color: hot ? t.primaryContrast : t.text),
                                Flexible(
                                  child: Text(replace,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.uiText.body.copyWith(fontSize: t.fontSizeSm, height: 1.35, color: hot ? t.primaryContrast : t.text)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        if (widget.onRemove != null)
          Padding(
            padding: EdgeInsets.only(top: t.space2),
            child: UiButton(
              label: widget.removeLabel ?? strings.uploadRemove,
              icon: const UiIcon(HugeIcons.strokeRoundedDelete02),
              variant: UiButtonVariant.ghost,
              size: UiSize.sm,
              onPressed: _enabled ? widget.onRemove : null,
            ),
          ),
      ],
    );
  }
}

class _DashedBorder extends CustomPainter {
  _DashedBorder({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.5);
    final path = Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 9) {
        canvas.drawPath(m.extractPath(d, (d + 5).clamp(0, m.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color || old.radius != radius;
}
