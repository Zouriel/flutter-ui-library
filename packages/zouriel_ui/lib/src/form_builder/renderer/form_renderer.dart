import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../button/button.dart';
import '../../core/icon.dart';
import '../../core/interactive.dart';
import '../../core/types.dart';
import '../../forms/choice/file_upload.dart';
import '../../overlay/anchored.dart';
import '../../theme/theme.dart';
import '../engine/engine.dart';
import '../engine/format.dart';
import '../engine/global_settings.dart';
import '../engine/http_sources.dart';
import '../engine/js.dart';
import '../engine/option_sources.dart';
import '../engine/schema.dart';
import '../engine/validators.dart';
import 'renderer_field.dart';

const _span = {'full': 12, 'two-thirds': 8, 'half': 6, 'third': 4};

/// `ui-form-renderer`: fills in a form built with the form builder.
///
/// Give it a [definition] (a [UiFormDefinition] or its stored JSON, migrated on load) and, to edit
/// or view saved answers, the saved [data]. [onSubmitted] gets a [UiFormSubmission] whose `data` is
/// the JSON to store, in exactly the shape the web renderer saves (sourced choices as
/// `{value, label}`, repeats as lists, sections as nested objects).
///
/// Fill mode shows one page at a time with Back/Continue, a progress bar and, when someone tries to
/// move on, a summary of the page's problems linking to each field. Edit mode (the default with
/// [data]) labels the button "Save changes" and lists what changed next to it. View mode shows
/// every page on the route at once, answers as text, and never validates.
///
/// The renderer doesn't scroll: put it in a scroll view. Read the running engine (answers, dirty,
/// changes) through a `GlobalKey<UiFormRendererState>`, which also has [UiFormRendererState.submit]
/// and [UiFormRendererState.reset].
class UiFormRenderer extends StatefulWidget {
  const UiFormRenderer({
    super.key,
    required this.definition,
    this.data,
    this.mode,
    this.validators = const [],
    this.optionSources = const [],
    this.globalSettings,
    this.httpSources = const UiFbHttpSourcesOptions(),
    this.uploader,
    this.filePicker,
    this.showTitle = true,
    this.showActions = true,
    this.submitLabel,
    this.cancelLabel,
    this.busy = false,
    this.today,
    this.onSubmitted,
    this.onCancelled,
    this.onValueChanged,
    this.onDirtyChanged,
  }) : assert(definition is UiFormDefinition || definition is Map, 'definition is a UiFormDefinition or its JSON map');

  /// The form: a [UiFormDefinition] or its JSON (`Map`). Usually the published version.
  final Object definition;

  /// Saved answers to edit or view. Unknown keys and answers hidden at the time are kept.
  final UiJson? data;

  /// Defaults to [UiFormMode.edit] when [data] is given, otherwise [UiFormMode.create].
  final UiFormMode? mode;

  /// App checks (the web `provideUiFormValidators`). Built-in checks are always on.
  final List<UiFbValidatorDef> validators;

  /// Lists that sourced dropdowns search (the web `provideUiFormOptionSources`).
  final List<UiFbOptionSourceDef> optionSources;

  /// App-wide settings from the global settings editor: their lists become searchable.
  final UiFormGlobalSettings? globalSettings;

  /// How lists from [globalSettings] make requests (fetch with the app's login, allowed origins).
  final UiFbHttpSourcesOptions httpSources;

  /// Uploads files as they're picked; without it, picked files come back in the submission's `files`.
  final UiFbUploader? uploader;

  /// Opens the platform's file picker for file questions (see [UiFilePicker]).
  final UiFilePicker? filePicker;
  final bool showTitle;

  /// Show the buttons. Turn off to drive the form with your own (via [UiFormRendererState.submit]).
  final bool showActions;

  /// The last button's text. Otherwise the form's setting, then "Submit" ("Save changes" in edit mode).
  final String? submitLabel;

  /// Shows a Cancel button with this text.
  final String? cancelLabel;

  /// Shows the submit button as busy (while the host saves).
  final bool busy;

  /// Fixes "today" (YYYY-MM-DD) for date rules and ages.
  final String Function()? today;

  final ValueChanged<UiFormSubmission>? onSubmitted;
  final VoidCallback? onCancelled;

  /// The answers as they'd be saved, after every change.
  final ValueChanged<UiJson>? onValueChanged;

  /// Whether the answers differ from what the form opened with.
  final ValueChanged<bool>? onDirtyChanged;

  @override
  State<UiFormRenderer> createState() => UiFormRendererState();
}

/// State of a [UiFormRenderer]: [engine], [submit] and [reset].
class UiFormRendererState extends State<UiFormRenderer> {
  late UiFormEngine _engine;
  final Map<String, GlobalKey<UiFbFieldViewState>> _fieldKeys = {};
  final Map<String, FocusNode> _addNodes = {};
  final FocusNode _summaryFocus = FocusNode(debugLabel: 'fr-summary', skipTraversal: true);
  final FocusNode _pageFocus = FocusNode(debugLabel: 'fr-page', canRequestFocus: false, skipTraversal: true);
  final GlobalKey _summaryKey = GlobalKey();
  final OverlayPortalController _changes = OverlayPortalController();
  String _announce = '';
  ({UiFbRemovedRow row, String label})? _removed;
  Timer? _removedTimer;
  UiJson? _lastData;
  bool? _lastDirty;

  /// The running form: `data`, `dirty`, `changes` and the rest.
  UiFormEngine get engine => _engine;

  @override
  void initState() {
    super.initState();
    _create();
  }

  @override
  void didUpdateWidget(UiFormRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget;
    final w = widget;
    if (!identical(old.definition, w.definition) ||
        !identical(old.data, w.data) ||
        old.mode != w.mode ||
        old.today != w.today ||
        old.globalSettings != w.globalSettings ||
        !listEquals(old.validators, w.validators) ||
        !listEquals(old.optionSources, w.optionSources)) {
      _engine.dispose();
      _create();
    }
  }

  @override
  void dispose() {
    _engine.dispose();
    _removedTimer?.cancel();
    _summaryFocus.dispose();
    _pageFocus.dispose();
    for (final n in _addNodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  void _create() {
    final w = widget;
    _engine = UiFormEngine.fromJson(
      w.definition is UiFormDefinition ? (w.definition as UiFormDefinition).toJson() : w.definition,
      data: w.data,
      mode: w.mode,
      validators: w.validators,
      optionSources: [...sourcesFromSettings(w.globalSettings, w.httpSources), ...w.optionSources],
      today: w.today,
    );
    _engine.addListener(_onEngine);
    _lastData = _engine.data;
    _lastDirty = _engine.dirty;
    _removed = null;
    _removedTimer?.cancel();
  }

  void _onEngine() {
    if (!mounted) return;
    setState(() {});
    final data = _engine.data;
    if (!jsonEquals(data, _lastData)) {
      _lastData = data;
      widget.onValueChanged?.call(data);
    }
    final dirty = _engine.dirty;
    if (dirty != _lastDirty) {
      _lastDirty = dirty;
      widget.onDirtyChanged?.call(dirty);
    }
  }

  /// Starts over from the data the form was given (or blank), back on the first page.
  void reset() {
    setState(() {
      _engine.dispose();
      _create();
      _announce = '';
    });
  }

  /// Checks every page on the route. Calls [UiFormRenderer.onSubmitted] and returns the submission
  /// when it's all valid; otherwise returns null, moves to the first page with problems and shows them.
  UiFormSubmission? submit() {
    final e = _engine;
    final before = e.pageIndex;
    final s = e.submit();
    if (s == null) {
      if (e.pageIndex != before) _pageChanged();
      _showSummary();
      return null;
    }
    widget.onSubmitted?.call(s);
    return s;
  }

  // ── Actions ────────────────────────────────────────────────────────────────────────────────

  bool get _multiPage => _engine.path.length > 1;

  /// Continue on inner pages, submit on the last.
  void _primary() {
    final e = _engine;
    if (!e.isLastPage) {
      if (e.next()) {
        _pageChanged();
      } else {
        _showSummary();
      }
      return;
    }
    submit();
  }

  void _back() {
    if (_engine.back()) _pageChanged();
  }

  String _entryLabel(UiFbGroup g, int n) => (g.repeat?.itemLabel ?? 'Entry {n}').replaceFirst('{n}', '${n + 1}');

  void _addRow(UiFbGroup g) {
    if (_engine.addRow(g.id) == null) return;
    setState(() => _announce = '${_entryLabel(g, _engine.rows(g.id).length - 1)} added');
  }

  void _removeRow(UiFbGroup g, String row, int n) {
    final snapshot = _engine.removeRow(g.id, row);
    if (snapshot == null) return;
    final label = _entryLabel(g, n);
    setState(() {
      _removed = (row: snapshot, label: label);
      _announce = '$label removed. Undo is next to the add button.';
    });
    _removedTimer?.cancel();
    _removedTimer = Timer(const Duration(seconds: 12), () {
      if (mounted) setState(() => _removed = null);
    });
    // The button that was pressed is gone; keep focus in the same place in the form.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final node = _addNodes[g.id];
      if (mounted && node != null && node.context != null && node.canRequestFocus) node.requestFocus();
    });
  }

  void _undoRemove() {
    final r = _removed;
    if (r == null) return;
    _removedTimer?.cancel();
    _engine.restoreRow(r.row);
    setState(() {
      _removed = null;
      _announce = '${r.label} restored';
    });
  }

  void _focusField(String addr) => _fieldKeys[addr]?.currentState?.focus();

  void _showSummary() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_engine.settings.errorSummary) {
        final first = _engine.pageErrors(_engine.pageIndex).firstOrNull;
        if (first != null) _focusField(first.addr);
        return;
      }
      final ctx = _summaryKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, alignment: 0.1, duration: context.uiAnimate ? context.ui.motionBase : Duration.zero);
        _summaryFocus.requestFocus();
      }
    });
  }

  void _pageChanged() {
    final e = _engine;
    final page = e.page;
    setState(() => _announce = 'Step ${e.step + 1} of ${e.path.length}${page.title != null && page.title!.isNotEmpty ? ': ${page.title}' : ''}');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Bring the top of the form back into view if the page was scrolled past it.
      Scrollable.ensureVisible(context, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart);
      // On touch screens focusing a text box would pop the keyboard up unasked; keyboards get focus moved in.
      if (uiTouchPlatform(context)) return;
      for (final n in _pageFocus.traversalDescendants) {
        if (n.canRequestFocus) {
          n.requestFocus();
          return;
        }
      }
    });
  }

  String _show(UiFbChange c, Object? v) {
    if (v == null || v == '') return 'Empty';
    final plain = c.path.replaceAll(RegExp(r'\[\d+\]'), '');
    UiFbField? field;
    for (final x in _engine.index.values) {
      if (x.kind == 'field' && _engine.dataPath(x.id, null) == plain) {
        field = x.asField;
        break;
      }
    }
    if (field != null) {
      final s = formatValue(field, v);
      return s.isEmpty ? 'Empty' : s;
    }
    return v is Map || v is List ? jsonStringify(v) : jsString(v);
  }

  // ── Building ───────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final ty = context.uiText;
    final e = _engine;
    final def = e.definition;
    final s = def.settings;
    final viewing = e.mode == UiFormMode.view;
    final children = <Widget>[];

    if (widget.showTitle && (def.title.isNotEmpty || (def.description ?? '').isNotEmpty)) {
      children.add(Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space1, children: [
        if (def.title.isNotEmpty)
          Semantics(
            header: true,
            child: Text(def.title, style: ty.h3.copyWith(fontSize: 20, fontWeight: FontWeight.w600, color: t.text, height: 1.25)),
          ),
        if ((def.description ?? '').isNotEmpty) _desc(context, def.description!),
      ]));
    }

    if (viewing) {
      // Reading saved answers: every page on the route, one after another, no steps.
      final pages = e.path;
      for (var k = 0; k < pages.length; k++) {
        final p = def.pages[pages[k]];
        children.add(Container(
          padding: EdgeInsets.only(top: k > 0 ? t.space6 : 0),
          margin: EdgeInsets.only(top: k > 0 ? t.space2 : 0),
          decoration: BoxDecoration(border: k > 0 ? Border(top: BorderSide(color: t.border)) : null),
          child: Semantics(
            container: true,
            label: p.title,
            explicitChildNodes: true,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
              if (_multiPage && ((p.title ?? '').isNotEmpty || (p.description ?? '').isNotEmpty)) _pageHead(context, p, showTitle: true),
              _grid(context, p.elements, null, 1),
            ]),
          ),
        ));
      }
    } else {
      if (_multiPage && s?.showProgress != false) children.add(_progress(context));
      final summary = e.settings.errorSummary && e.attempted.contains(e.page.id) ? e.pageErrors(e.pageIndex) : const <UiFbErrorItem>[];
      if (summary.isNotEmpty) children.add(_summary(context, summary));
      final page = e.page;
      if (_multiPage && ((page.title ?? '').isNotEmpty || (page.description ?? '').isNotEmpty)) {
        children.add(_pageHead(context, page, showTitle: s?.showProgress == false));
      }
      children.add(Focus(focusNode: _pageFocus, child: KeyedSubtree(key: ValueKey('page-${page.id}'), child: _grid(context, page.elements, null, 1))));
    }

    if (widget.showActions && !viewing) children.add(_footer(context));
    children.add(Semantics(liveRegion: true, label: _announce, child: const SizedBox.shrink()));

    return DefaultTextStyle.merge(
      style: TextStyle(color: t.text),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: widget.showTitle && def.title.isNotEmpty ? def.title : null,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, spacing: t.space4, children: children),
      ),
    );
  }

  Widget _desc(BuildContext context, String text) {
    final t = context.ui;
    return Text(text, style: context.uiText.body.copyWith(fontSize: t.fontSizeSm, height: 1.45, color: t.textSecondary));
  }

  Widget _pageHead(BuildContext context, UiFbPage p, {required bool showTitle}) {
    final t = context.ui;
    if (!showTitle && (p.description ?? '').isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 2, children: [
      if (showTitle && (p.title ?? '').isNotEmpty)
        Semantics(
          header: true,
          child: Text(p.title!, style: context.uiText.body.copyWith(fontSize: t.fontSizeLg, fontWeight: FontWeight.w600, color: t.text, height: 1.3)),
        ),
      if ((p.description ?? '').isNotEmpty) _desc(context, p.description!),
    ]);
  }

  Widget _progress(BuildContext context) {
    final t = context.ui;
    final e = _engine;
    final page = e.page;
    final dur = context.uiAnimate ? t.motionBase : Duration.zero;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
      ExcludeSemantics(
        child: Row(spacing: 4, children: [
          for (var n = 0; n < e.path.length; n++)
            Expanded(
              child: AnimatedContainer(
                duration: dur,
                curve: t.easeStandard,
                height: 4,
                decoration: BoxDecoration(
                  color: n == e.step ? t.primary : (n < e.step ? uiMix(t.primary, 0.55, t.track) : t.track),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ]),
      ),
      Text(
        'Step ${e.step + 1} of ${e.path.length}${(page.title ?? '').isNotEmpty ? ': ${page.title}' : ''}',
        style: context.uiText.body.copyWith(fontSize: t.fontSizeSm, fontWeight: FontWeight.w500, color: t.textSecondary),
      ),
    ]);
  }

  Widget _summary(BuildContext context, List<UiFbErrorItem> items) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final ty = context.uiText;
    final title = items.length == 1 ? 'There is a problem' : 'There are ${items.length} problems';
    return Focus(
      key: _summaryKey,
      focusNode: _summaryFocus,
      child: ListenableBuilder(
        listenable: _summaryFocus,
        builder: (context, _) => Semantics(
          container: true,
          liveRegion: true,
          explicitChildNodes: true,
          label: title,
          child: Container(
            padding: EdgeInsets.all(t.space3),
            decoration: BoxDecoration(
              // A lighter tint than the web's 8% so the 13px danger links keep 4.5:1 in every theme.
              color: uiMix(t.danger, 0.04, t.surface),
              borderRadius: BorderRadius.circular(theme.radius()),
              border: Border(
                left: BorderSide(color: uiMix(t.danger, 0.55, t.surface), width: 4),
                top: BorderSide(color: uiMix(t.danger, 0.55, t.surface)),
                right: BorderSide(color: uiMix(t.danger, 0.55, t.surface)),
                bottom: BorderSide(color: uiMix(t.danger, 0.55, t.surface)),
              ),
              boxShadow: _summaryFocus.hasFocus && FocusManager.instance.highlightMode == FocusHighlightMode.traditional ? t.focusRing : const [],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space1, children: [
              ExcludeSemantics(
                child: Text(title, style: ty.body.copyWith(fontSize: t.fontSizeMd, fontWeight: FontWeight.w600, color: t.text)),
              ),
              for (final item in items)
                UiInteractive(
                  onTap: () => _focusField(item.addr),
                  button: false,
                  semanticLabel: item.message,
                  excludeChildSemantics: true,
                  pressScale: false,
                  padTouchTarget: false,
                  builder: (context, st) => Semantics(
                    link: true,
                    child: Container(
                      constraints: BoxConstraints(minHeight: uiTouchPlatform(context) ? uiMinTouchTarget : 0),
                      alignment: AlignmentDirectional.centerStart,
                      decoration: BoxDecoration(boxShadow: st.focused ? t.focusRing : const [], borderRadius: BorderRadius.circular(2)),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space2, children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 7),
                          child: Container(width: 4, height: 4, decoration: BoxDecoration(color: t.danger, shape: BoxShape.circle)),
                        ),
                        Expanded(
                          child: Text(
                            item.message,
                            style: ty.body.copyWith(
                              fontSize: t.fontSizeSm,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                              color: t.danger,
                              // Underlined on hover/focus only: at rest the 1px line drags the measured
                              // contrast of 13px text under 4.5:1 in the dark themes.
                              decoration: st.hovered || st.focused ? TextDecoration.underline : TextDecoration.none,
                              decorationColor: t.danger,
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }

  /// Grid width of an element, out of 12 (the web `span`).
  int _spanOf(UiFbElement el, int cols) {
    final isBlock = el is UiFbStatic && el.type != 'paragraph';
    final layout = switch (el) {
      UiFbField(:final layout) => layout,
      UiFbGroup(:final layout) => layout,
      UiFbStatic(:final layout) => layout,
    };
    final w = isBlock ? null : layout?.width;
    if (w != null) return _span[w] ?? 12;
    if (isBlock) return 12;
    return cols > 1 ? (12 / cols).round() : 12;
  }

  /// A 12-column grid like the web's: cells flow left to right and wrap; at 560px or narrower
  /// every cell is full width.
  Widget _grid(BuildContext context, List<UiFbElement> els, String? row, int cols) {
    final t = context.ui;
    final e = _engine;
    final cells = <(int, Widget)>[];
    for (final el in els) {
      if (el.archived == true || !e.instanceState(el.id, row).visible) continue;
      if (el is UiFbField && el.type == UiFbFieldType.hidden) continue;
      cells.add((_spanOf(el, cols), KeyedSubtree(key: ValueKey('${el.id}|$row'), child: _Enter(child: _element(context, el, row)))));
    }
    if (cells.isEmpty) return const SizedBox.shrink();
    final gap = t.space3;
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final narrow = w <= 560;
      return Wrap(
        spacing: gap,
        runSpacing: t.space4,
        children: [
          for (final (span, child) in cells)
            SizedBox(width: narrow || span >= 12 ? w : math.max(0, span * (w + gap) / 12 - gap - 0.01), child: child),
        ],
      );
    });
  }

  Widget _element(BuildContext context, UiFbElement el, String? row) {
    final t = context.ui;
    final ty = context.uiText;
    switch (el) {
      case UiFbField():
        final addr = addrOf(el.id, row);
        return UiFbFieldView(
          key: _fieldKeys.putIfAbsent(addr, () => GlobalKey<UiFbFieldViewState>(debugLabel: addr)),
          engine: _engine,
          field: el,
          row: row,
          uploader: widget.uploader,
          filePicker: widget.filePicker,
          today: widget.today,
        );
      case UiFbStatic():
        switch (el.type) {
          case 'heading':
            return Padding(
              padding: EdgeInsets.only(top: t.space2),
              child: Semantics(
                header: true,
                child: Text(el.text ?? '', style: ty.h4.copyWith(fontSize: t.fontSizeLg, fontWeight: FontWeight.w600, color: t.text, height: 1.3)),
              ),
            );
          case 'paragraph':
            return Text(el.text ?? '', style: ty.body.copyWith(fontSize: t.fontSizeSm, height: 1.5, color: t.textSecondary));
          default:
            return Padding(padding: EdgeInsets.symmetric(vertical: t.space1), child: Container(height: 1, color: t.borderSubtle));
        }
      case UiFbGroup():
        return _group(context, el, row);
    }
  }

  Widget _group(BuildContext context, UiFbGroup g, String? row) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final ty = context.uiText;
    final e = _engine;
    final viewing = e.mode == UiFormMode.view;
    final disabled = e.instanceState(g.id, row).disabled && !viewing;
    final cols = (g.columns ?? 1).toInt();
    final content = <Widget>[
      if ((g.title ?? '').isNotEmpty)
        Semantics(header: true, child: Text(g.title!, style: ty.body.copyWith(fontSize: t.fontSizeMd, fontWeight: FontWeight.w600, color: t.text))),
      if ((g.description ?? '').isNotEmpty) _desc(context, g.description!),
    ];
    if (g.repeat == null) {
      content.add(_grid(context, g.elements, row, cols));
    } else {
      final rows = e.rows(g.id);
      for (var n = 0; n < rows.length; n++) {
        content.add(KeyedSubtree(key: ValueKey('entry-${rows[n]}'), child: _Enter(child: _entry(context, g, rows, n, cols))));
      }
      if (rows.isEmpty) {
        content.add(Text(viewing ? 'None added.' : 'Nothing added yet.', style: ty.body.copyWith(fontSize: t.fontSizeSm, color: t.textMuted)));
      }
      if (!viewing) {
        final removed = _removed;
        if (removed != null && removed.row.groupId == g.id) {
          content.add(Row(spacing: t.space1, children: [
            Flexible(child: Text('${removed.label} removed.', style: ty.body.copyWith(fontSize: t.fontSizeSm, color: t.textSecondary))),
            UiButton(label: 'Undo', variant: UiButtonVariant.link, size: UiSize.sm, onPressed: _undoRemove),
          ]));
        }
        final max = g.repeat!.max;
        content.add(Row(spacing: t.space3, children: [
          UiButton(
            focusNode: _addNodes.putIfAbsent(g.id, () => FocusNode(debugLabel: 'add-${g.id}')),
            variant: UiButtonVariant.outline,
            size: UiSize.sm,
            icon: const UiIcon(HugeIcons.strokeRoundedAdd01, size: 15),
            label: g.repeat!.addLabel ?? 'Add another',
            onPressed: e.canAddRow(g.id) && !e.instanceState(g.id, row).disabled ? () => _addRow(g) : null,
          ),
          if (max != null) Text('${rows.length} of ${max.toInt()}', style: ty.body.copyWith(fontSize: t.fontSizeSm, color: t.textMuted)),
        ]));
      }
    }
    return Opacity(
      opacity: disabled ? 0.6 : 1,
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: g.title,
        child: Container(
          padding: EdgeInsets.all(t.space3),
          decoration: BoxDecoration(border: Border.all(color: t.borderSubtle), borderRadius: BorderRadius.circular(theme.radius())),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: content),
        ),
      ),
    );
  }

  Widget _entry(BuildContext context, UiFbGroup g, List<String> rows, int n, int cols) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final e = _engine;
    final r = rows[n];
    final label = _entryLabel(g, n);
    final editing = e.mode != UiFormMode.view;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: label,
      child: Container(
        padding: EdgeInsets.all(t.space3),
        decoration: BoxDecoration(color: t.surfaceSubtle, borderRadius: BorderRadius.circular(theme.radius())),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 24),
            child: Row(spacing: t.space2, children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(label, style: context.uiText.body.copyWith(fontSize: t.fontSizeSm, fontWeight: FontWeight.w600, color: t.textSecondary)),
                ),
              ),
              if (editing) ...[
                if (rows.length > 1) ...[
                  _EntryTool(icon: HugeIcons.strokeRoundedArrowUp01, label: 'Move $label up', onTap: n == 0 ? null : () => e.moveRow(g.id, r, -1)),
                  _EntryTool(icon: HugeIcons.strokeRoundedArrowDown01, label: 'Move $label down', onTap: n == rows.length - 1 ? null : () => e.moveRow(g.id, r, 1)),
                ],
                if (e.canRemoveRow(g.id)) _EntryTool(icon: HugeIcons.strokeRoundedDelete02, label: 'Remove $label', danger: true, onTap: () => _removeRow(g, r, n)),
              ],
            ]),
          ),
          _grid(context, g.elements, r, cols),
        ]),
      ),
    );
  }

  Widget _footer(BuildContext context) {
    final t = context.ui;
    final ty = context.uiText;
    final e = _engine;
    final s = e.definition.settings;
    final primaryLabel = !e.isLastPage
        ? (s?.nextLabel?.isNotEmpty == true ? s!.nextLabel! : 'Continue')
        : (widget.submitLabel ?? (s?.submitLabel?.isNotEmpty == true ? s!.submitLabel! : (e.mode == UiFormMode.edit ? 'Save changes' : 'Submit')));
    final start = <Widget>[
      if (_multiPage && e.step > 0)
        UiButton(
          variant: UiButtonVariant.outline,
          icon: const UiIcon(HugeIcons.strokeRoundedArrowLeft01, size: 14),
          label: s?.backLabel?.isNotEmpty == true ? s!.backLabel! : 'Back',
          onPressed: _back,
        ),
      if (widget.cancelLabel != null) UiButton(variant: UiButtonVariant.ghost, label: widget.cancelLabel, onPressed: widget.onCancelled ?? () {}),
    ];
    final end = <Widget>[
      if (e.mode == UiFormMode.edit)
        if (e.dirty) _changesButton(context) else Text('No changes', style: ty.body.copyWith(fontSize: t.fontSizeSm, color: t.textMuted)),
      UiButton(
        label: primaryLabel,
        loading: widget.busy,
        trailingIcon: e.isLastPage ? null : const UiIcon(HugeIcons.strokeRoundedArrowRight01, size: 14),
        onPressed: _primary,
      ),
    ];
    return Container(
      padding: EdgeInsets.only(top: t.space3),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: t.borderSubtle))),
      child: Row(children: [
        Wrap(spacing: t.space2, runSpacing: t.space2, crossAxisAlignment: WrapCrossAlignment.center, children: start),
        SizedBox(width: t.space3),
        Expanded(
          child: Wrap(alignment: WrapAlignment.end, spacing: t.space2, runSpacing: t.space2, crossAxisAlignment: WrapCrossAlignment.center, children: end),
        ),
      ]),
    );
  }

  Widget _changesButton(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final ty = context.uiText;
    final changes = _engine.changes;
    final label = changes.length == 1 ? '1 change' : '${changes.length} changes';
    final small = ty.body.copyWith(fontSize: t.fontSizeSm, height: 1.35);
    return UiAnchoredOverlay(
      controller: _changes,
      placement: UiPlacement.topEnd,
      gap: 6,
      onDismiss: _changes.hide,
      panelBuilder: (context, anchor) => ConstrainedBox(
        constraints: BoxConstraints(maxWidth: math.min(360, MediaQuery.sizeOf(context).width * 0.8), maxHeight: 260),
        child: Container(
          decoration: BoxDecoration(
            color: t.surfaceRaised,
            border: Border.all(color: t.border),
            borderRadius: BorderRadius.circular(theme.radius()),
            boxShadow: t.shadow2,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(t.space2),
            child: Semantics(
              container: true,
              explicitChildNodes: true,
              label: 'Changes',
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, spacing: 6, children: [
                for (final c in changes)
                  MergeSemantics(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 1, children: [
                      Text(c.label, style: small.copyWith(fontWeight: FontWeight.w600, color: t.text)),
                      Semantics(
                        label: 'was ${_show(c, c.from)}',
                        excludeSemantics: true,
                        child: Text(_show(c, c.from), style: small.copyWith(color: t.textMuted, decoration: TextDecoration.lineThrough, decorationColor: t.textMuted)),
                      ),
                      Semantics(
                        label: 'now ${_show(c, c.to)}',
                        excludeSemantics: true,
                        child: Text(_show(c, c.to), style: small.copyWith(color: t.text)),
                      ),
                    ]),
                  ),
              ]),
            ),
          ),
        ),
      ),
      child: UiButton(
        variant: UiButtonVariant.ghost,
        size: UiSize.sm,
        label: label,
        semanticLabel: '$label: show the list',
        onPressed: () => _changes.isShowing ? _changes.hide() : _changes.show(),
      ),
    );
  }
}

/// An icon button in a repeat entry's header (move up, move down, remove).
class _EntryTool extends StatelessWidget {
  const _EntryTool({required this.icon, required this.label, required this.onTap, this.danger = false});
  final UiIconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return UiInteractive(
      onTap: onTap,
      enabled: onTap != null,
      semanticLabel: label,
      excludeChildSemantics: true,
      builder: (context, s) => Opacity(
        opacity: s.disabled ? 0.35 : 1,
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: s.hovered && !s.disabled ? t.surfaceHover : null,
            borderRadius: BorderRadius.circular(t.radiusXs),
            boxShadow: s.focused ? t.focusRing : const [],
          ),
          child: UiIcon(icon, size: 15, color: s.hovered && !s.disabled ? (danger ? t.danger : t.text) : t.textMuted),
        ),
      ),
    );
  }
}

/// Fades and drops in a cell or entry as it appears (the web `ui-fr-enter`); instant with reduced motion.
class _Enter extends StatefulWidget {
  const _Enter({required this.child});
  final Widget child;

  @override
  State<_Enter> createState() => _EnterState();
}

class _EnterState extends State<_Enter> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, value: 1);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (context.uiAnimate) {
      _c.duration = context.ui.motionBase;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _c, curve: context.ui.easeDecelerate);
    return AnimatedBuilder(
      animation: curve,
      child: widget.child,
      // Same widget shape at rest and while moving, so the child's state is never rebuilt.
      builder: (context, child) => Opacity(
        opacity: curve.value,
        child: Transform.translate(offset: Offset(0, -4 * (1 - curve.value)), child: child),
      ),
    );
  }
}
