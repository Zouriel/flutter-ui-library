import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:pdfrx/pdfrx.dart';

import '../button/button.dart';
import '../core/icon.dart';
import '../core/interactive.dart';
import '../core/types.dart';
import '../feedback/spinner.dart';
import '../theme/theme.dart';
import 'sources.dart';

/// `ui-pdf-viewer`: a PDF, one page at a time, with previous/next page buttons and zoom from 40% to
/// 400% (buttons, pinch, double tap); 100% fits the page to the width. [src] is a URL, file path
/// or asset key (see [UiFileSources]), or pass the bytes as [data].
///
/// Rendered by PDFium through `pdfrx`, drawn sharp at the current zoom. If the file can't be
/// loaded the error shows in place of the page.
class UiPdfViewer extends StatefulWidget {
  const UiPdfViewer({super.key, this.src, this.data, this.documentRef, this.initialPage = 1, this.onPageChanged, this.maxHeight})
    : assert(src != null || data != null || documentRef != null, 'Give the viewer a src, data or documentRef.');

  final String? src;
  final Uint8List? data;

  /// Any other pdfrx source (a custom loader, a password-protected file); overrides [src] and [data].
  final PdfDocumentRef? documentRef;
  final int initialPage;
  final ValueChanged<int>? onPageChanged;

  /// The viewer's height when its parent leaves it unbounded (default 70% of the screen).
  final double? maxHeight;

  static const double minScale = 0.4, maxScale = 4;

  /// The pdfrx document reference for a source, as the viewer opens it.
  static PdfDocumentRef refFor({String? src, Uint8List? data}) {
    if (data != null) return PdfDocumentRefData(data, sourceName: src ?? 'pdf-${identityHashCode(data)}');
    final s = src!;
    if (UiFileSources.isNetwork(s)) return PdfDocumentRefUri(Uri.parse(s));
    if (UiFileSources.isFile(s)) return PdfDocumentRefFile(s.startsWith('file://') ? Uri.parse(s).toFilePath() : s);
    return PdfDocumentRefAsset(s);
  }

  @override
  State<UiPdfViewer> createState() => _UiPdfViewerState();
}

class _UiPdfViewerState extends State<UiPdfViewer> {
  late int _page = widget.initialPage;
  final TransformationController _view = TransformationController();
  late PdfDocumentRef _ref = widget.documentRef ?? UiPdfViewer.refFor(src: widget.src, data: widget.data);
  Size _stage = Size.zero;

  double get _scale => _view.value.getMaxScaleOnAxis();

  @override
  void initState() {
    super.initState();
    _view.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(UiPdfViewer old) {
    super.didUpdateWidget(old);
    if (old.src != widget.src || old.data != widget.data || old.documentRef != widget.documentRef) {
      _ref = widget.documentRef ?? UiPdfViewer.refFor(src: widget.src, data: widget.data);
      _page = widget.initialPage;
      _view.value = Matrix4.identity();
    }
  }

  @override
  void dispose() {
    _view.dispose();
    super.dispose();
  }

  void _go(int page, int pages) {
    final p = page.clamp(1, math.max(1, pages)).toInt();
    if (p == _page) return;
    setState(() => _page = p);
    _view.value = Matrix4.identity();
    widget.onPageChanged?.call(p);
  }

  void _passWheelToPage(PointerSignalEvent e) {
    if (e is! PointerScrollEvent) return;
    final k = HardwareKeyboard.instance;
    if (k.isControlPressed || k.isMetaPressed) return;
    // InteractiveViewer zooms on every wheel event without asking the resolver, so this runs
    // before it (see _SignalFirst), keeps the view as it was, and puts it back once the event has
    // been handled; the wheel then scrolls the page around the viewer instead.
    final keep = _view.value.clone();
    final page = Scrollable.maybeOf(context)?.position;
    GestureBinding.instance.pointerSignalResolver.register(e, (ev) {
      _view.value = keep;
      page?.pointerScroll((ev as PointerScrollEvent).scrollDelta.dy);
    });
  }

  void _zoomBy(double d, Size stage) {
    final next = (_scale + d).clamp(UiPdfViewer.minScale, UiPdfViewer.maxScale);
    // Zoom about the middle of what is in view.
    final c = _view.toScene(stage.center(Offset.zero));
    _view.value = Matrix4.identity()
      ..translateByDouble(stage.width / 2, stage.height / 2, 0, 1)
      ..scaleByDouble(next, next, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return LayoutBuilder(
      builder: (context, box) {
        final h = box.maxHeight.isFinite ? box.maxHeight : (widget.maxHeight ?? MediaQuery.sizeOf(context).height * 0.7);
        return SizedBox(
          height: math.max(240, h),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(context.uiTheme.radius()),
            child: ColoredBox(
              color: t.surface,
              child: PdfDocumentViewBuilder(
                documentRef: _ref,
                loadingBuilder: (context) => _shell(context, null, _message(context, 'Loading PDF…')),
                errorBuilder: (context, error, _) => _shell(context, null, _message(context, error.toString(), error: true)),
                builder: (context, doc) => _shell(context, doc, doc == null ? _message(context, 'Loading PDF…') : null),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _message(BuildContext context, String text, {bool error = false}) {
    final t = context.ui;
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: EdgeInsets.all(t.space4),
        child: error
            ? Text(text, style: context.uiText.body.copyWith(color: t.danger))
            : Row(
                mainAxisSize: MainAxisSize.min,
                spacing: t.space2,
                children: [
                  const UiSpinner(decorative: true),
                  Text(text, style: context.uiText.body.copyWith(color: t.textMuted)),
                ],
              ),
      ),
    );
  }

  Widget _shell(BuildContext context, PdfDocument? doc, Widget? message) {
    final t = context.ui;
    final pages = doc?.pages.length ?? 0;
    final page = pages == 0 ? null : doc!.pages[(_page.clamp(1, pages)) - 1];
    final mono = context.uiText.code.copyWith(fontSize: t.fontSizeSm, fontWeight: FontWeight.w500, color: t.textMuted, fontFeatures: const [FontFeature.tabularFigures()]);
    final touch = uiTouchPlatform(context);

    {
      Widget btn(UiIconData icon, String label, VoidCallback? onTap) =>
          UiIconButton(icon: UiIcon(icon), label: label, size: UiSize.sm, onPressed: onTap);
      final bar = Container(
        padding: EdgeInsets.symmetric(horizontal: t.space2, vertical: t.space1),
        decoration: BoxDecoration(
          color: t.surfaceRaised,
          border: Border(bottom: BorderSide(color: t.border)),
        ),
        child: Row(
          spacing: touch ? 0 : t.space1,
          children: [
            btn(HugeIcons.strokeRoundedArrowLeft01, 'Previous page', page != null && _page > 1 ? () => _go(_page - 1, pages) : null),
            Semantics(
              liveRegion: true,
              label: pages == 0 ? null : 'Page $_page of $pages',
              child: ExcludeSemantics(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 42),
                  child: Text('$_page / ${pages == 0 ? '—' : pages}', textAlign: TextAlign.center, style: mono),
                ),
              ),
            ),
            btn(HugeIcons.strokeRoundedArrowRight01, 'Next page', page != null && _page < pages ? () => _go(_page + 1, pages) : null),
            const Spacer(),
            btn(
              HugeIcons.strokeRoundedMinusSign,
              'Zoom out',
              page != null && _scale > UiPdfViewer.minScale + 0.001 ? () => _zoomBy(-0.2, _stage) : null,
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 42),
              child: Text('${(_scale * 100).round()}%', textAlign: TextAlign.center, style: mono),
            ),
            btn(
              HugeIcons.strokeRoundedPlusSign,
              'Zoom in',
              page != null && _scale < UiPdfViewer.maxScale - 0.001 ? () => _zoomBy(0.2, _stage) : null,
            ),
          ],
        ),
      );

      Widget body(Size stage) {
        if (message != null || page == null) return Center(child: message ?? const SizedBox());
        {
          // 100% fits the page to the width; a tall page pans up and down.
          final pad = t.space3;
          final w = math.max(1.0, stage.width - pad * 2);
          final hgt = w * page.height / page.width;
          return ColoredBox(
            color: t.bg,
            child: GestureDetector(
              onDoubleTap: () => _scale > 1.01 ? _view.value = Matrix4.identity() : _zoomBy(1, stage),
              child: _SignalFirst(
                onSignal: _passWheelToPage,
                child: InteractiveViewer(
                  transformationController: _view,
                  minScale: UiPdfViewer.minScale,
                  maxScale: UiPdfViewer.maxScale,
                  boundaryMargin: EdgeInsets.all(stage.shortestSide),
                  constrained: false,
                  // A plain wheel scrolls the page around the viewer, as on the web (_SignalFirst
                  // above); Ctrl/Cmd + wheel still zooms.
                  child: SizedBox(
                    width: stage.width,
                    height: math.max(stage.height, hgt + pad * 2),
                    child: Padding(
                      padding: EdgeInsets.all(pad),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Semantics(
                          label: 'Page $_page',
                          image: true,
                          child: Container(
                            width: w,
                            height: hgt,
                            decoration: BoxDecoration(color: t.pdfPageBg, boxShadow: t.shadow2),
                            child: PdfPageView(document: doc, pageNumber: _page, backgroundColor: t.pdfPageBg),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          bar,
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                _stage = box.biggest;
                return body(_stage);
              },
            ),
          ),
        ],
      );
    }
  }
}

/// Hands pointer signals (the wheel) to [onSignal] before anything below it sees them: it puts
/// itself first in the hit test, where a plain [Listener] comes after its children.
class _SignalFirst extends SingleChildRenderObjectWidget {
  const _SignalFirst({required this.onSignal, super.child});

  final PointerSignalEventListener onSignal;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSignalFirst(onSignal);

  @override
  void updateRenderObject(BuildContext context, _RenderSignalFirst renderObject) => renderObject.onSignal = onSignal;
}

class _RenderSignalFirst extends RenderProxyBox {
  _RenderSignalFirst(this.onSignal);

  PointerSignalEventListener onSignal;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    result.add(BoxHitTestEntry(this, position));
    hitTestChildren(result, position: position);
    return true;
  }

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (event is PointerSignalEvent) onSignal(event);
  }
}
