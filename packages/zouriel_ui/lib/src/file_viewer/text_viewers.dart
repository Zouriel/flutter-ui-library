import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../behaviors/misc.dart';
import '../button/button.dart';
import '../core/icon.dart';
import '../core/types.dart';
import '../theme/theme.dart';
import 'sources.dart';

/// Loads text for a viewer: [content] when given, otherwise [src] through [load].
mixin _TextSource<W extends StatefulWidget> on State<W> {
  String? get _content;
  String? get _srcValue;
  Future<String> Function(String src)? get _loader;

  String? fetched;
  String? error;
  bool loading = false;
  int _generation = 0;

  String get text => _content ?? fetched ?? '';

  void loadSource() {
    final src = _srcValue;
    if (_content != null || src == null || src.isEmpty) return;
    final gen = ++_generation;
    setState(() {
      loading = true;
      error = null;
    });
    (_loader ?? UiFileSources.loadText)(src).then((v) {
      if (mounted && gen == _generation) setState(() => fetched = v);
    }, onError: (Object e) {
      if (mounted && gen == _generation) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    }).whenComplete(() {
      if (mounted && gen == _generation) setState(() => loading = false);
    });
  }

  Widget? statusMessage(BuildContext context) {
    final t = context.ui;
    if (_content != null) return null;
    if (loading) {
      return Semantics(liveRegion: true, child: Padding(padding: EdgeInsets.all(t.space4), child: Text(context.uiStrings.loading, style: context.uiText.body.copyWith(color: t.textMuted))));
    }
    if (error != null) {
      return Semantics(liveRegion: true, child: Padding(padding: EdgeInsets.all(t.space4), child: Text(error!, style: context.uiText.body.copyWith(color: t.danger))));
    }
    return null;
  }
}

/// `ui-text-viewer`: plain text with wrapped lines in a monospace face, from [content] or loaded
/// from [src] (a URL, file path or asset key; see [UiFileSources]) showing "Loading…" and then the
/// text or the error. Pass [load] to fetch [src] your own way.
class UiTextViewer extends StatefulWidget {
  const UiTextViewer({super.key, this.content, this.src, this.load, this.maxHeight});

  final String? content;
  final String? src;
  final Future<String> Function(String src)? load;

  /// Scrolls past this height; by default it fills a bounded parent or grows with the text.
  final double? maxHeight;

  @override
  State<UiTextViewer> createState() => _UiTextViewerState();
}

class _UiTextViewerState extends State<UiTextViewer> with _TextSource<UiTextViewer> {
  @override
  String? get _content => widget.content;
  @override
  String? get _srcValue => widget.src;
  @override
  Future<String> Function(String src)? get _loader => widget.load;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) loadSource();
    });
  }

  @override
  void didUpdateWidget(UiTextViewer old) {
    super.didUpdateWidget(old);
    if (old.src != widget.src || old.content != widget.content) loadSource();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final style = context.uiText.code.copyWith(fontSize: t.fontSizeSm, height: 1.5, color: t.text);
    final body = statusMessage(context) ??
        SingleChildScrollView(padding: EdgeInsets.all(t.space3), child: SizedBox(width: double.infinity, child: Text(text, style: style)));
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.maxHeight ?? double.infinity),
      child: DecoratedBox(
        decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(context.uiTheme.radius())),
        child: body,
      ),
    );
  }
}

/// `ui-code-viewer`: monospace source with line numbers that stay put while long lines scroll
/// sideways, a [language] label and a Copy button. Text comes from [content] or is loaded from
/// [src], like [UiTextViewer].
class UiCodeViewer extends StatefulWidget {
  const UiCodeViewer({super.key, this.content, this.src, this.language = 'text', this.load, this.maxHeight, this.copyable = true});

  final String? content;
  final String? src;
  final String language;
  final Future<String> Function(String src)? load;
  final double? maxHeight;

  /// Shows the Copy button.
  final bool copyable;

  @override
  State<UiCodeViewer> createState() => _UiCodeViewerState();
}

class _UiCodeViewerState extends State<UiCodeViewer> with _TextSource<UiCodeViewer> {
  @override
  String? get _content => widget.content;
  @override
  String? get _srcValue => widget.src;
  @override
  Future<String> Function(String src)? get _loader => widget.load;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) loadSource();
    });
  }

  @override
  void didUpdateWidget(UiCodeViewer old) {
    super.didUpdateWidget(old);
    if (old.src != widget.src || old.content != widget.content) loadSource();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final style = context.uiText.code.copyWith(fontSize: t.fontSizeSm, height: 1.5, color: t.text);
    final lines = text.split('\n');
    // A trailing newline is not a line of its own.
    final count = lines.length > 1 && lines.last.isEmpty ? lines.length - 1 : lines.length;
    final code = lines.length > 1 && lines.last.isEmpty ? text.substring(0, text.length - 1) : text;

    final bar = Container(
      constraints: BoxConstraints(minHeight: t.sizeSm),
      padding: EdgeInsets.only(left: t.space3, right: t.space1),
      decoration: BoxDecoration(color: t.surfaceRaised, border: Border(bottom: BorderSide(color: t.border))),
      child: Row(children: [
        Expanded(
          child: Text(widget.language.toUpperCase(), style: context.uiText.caption.copyWith(fontSize: 11, letterSpacing: 11 * 0.04, height: 1.35)),
        ),
        if (widget.copyable && statusMessage(context) == null)
          UiCopyToClipboard(
            text: text,
            builder: (context, copied, copy) => UiButton(
              label: copied ? 'Copied' : 'Copy',
              icon: UiIcon(copied ? HugeIcons.strokeRoundedTick02 : HugeIcons.strokeRoundedCopy01),
              variant: UiButtonVariant.ghost,
              size: UiSize.sm,
              onPressed: copy,
            ),
          ),
      ]),
    );

    // Code and its line numbers read left to right in an RTL app too (0.46.0).
    final body = statusMessage(context) ??
        Directionality(textDirection: TextDirection.ltr, child: SingleChildScrollView(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ExcludeSemantics(
              child: Container(
                padding: EdgeInsets.symmetric(vertical: t.space3, horizontal: t.space2),
                decoration: BoxDecoration(color: t.surface, border: Border(right: BorderSide(color: t.border))),
                child: Text(
                  [for (var i = 1; i <= count; i++) '$i'].join('\n'),
                  textAlign: TextAlign.right,
                  style: style.copyWith(color: t.textMuted),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.all(t.space3),
                child: Text(code, style: style, softWrap: false),
              ),
            ),
          ]),
        ));

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.maxHeight ?? double.infinity),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(context.uiTheme.radius()),
        child: ColoredBox(
          color: t.surface,
          // Fills a bounded parent and scrolls; in an unbounded one (a list) it grows with the code.
          child: LayoutBuilder(builder: (context, box) {
            final labelled = Semantics(label: '${widget.language} code', child: body);
            return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              bar,
              if (box.maxHeight.isFinite) Flexible(child: labelled) else labelled,
            ]);
          }),
        ),
      ),
    );
  }
}
