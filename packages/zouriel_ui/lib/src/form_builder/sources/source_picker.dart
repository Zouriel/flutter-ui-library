import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/icon.dart';
import '../../core/interactive.dart';
import '../../core/types.dart';
import '../../feedback/spinner.dart';
import '../../forms/choice/marks.dart';
import '../../forms/text/form_field.dart';
import '../../forms/text/text_core.dart';
import '../../overlay/anchored.dart';
import '../../theme/theme.dart';
import '../engine/js.dart';
import '../engine/option_sources.dart';

enum _Status { idle, loading, more, error, needs, short }

/// `ui-fb-source-picker`: a searchable dropdown over an option source. Type to search (after a
/// pause), scroll to the end to load the next page, pick one, or several as chips with [multiple].
///
/// Answers are `{value, label}` maps (a list of them with [multiple], or null), the shape the web
/// saves. Bare values in [value] are read as `{value: v, label: "v"}`. A search still running when
/// the next one starts is aborted through its `signal`. The renderer uses it for sourced fields.
class UiFbSourcePicker extends StatefulWidget {
  const UiFbSourcePicker({
    super.key,
    required this.source,
    this.params = const {},
    this.multiple = false,
    this.value,
    this.onChanged,
    this.placeholder = 'Search…',
    this.enabled = true,
    this.invalid = false,
    this.label,
    this.focusNode,
  });

  final UiFbOptionSourceDef source;

  /// The source's settings, already resolved (answers from other questions filled in).
  final Map<String, Object?> params;
  final bool multiple;

  /// A `{value, label}` map, a list of them when [multiple], or null.
  final Object? value;

  /// Called with a `{value, label}` map (or null) or, with [multiple], the new list.
  final ValueChanged<Object?>? onChanged;
  final String placeholder;
  final bool enabled;
  final bool invalid;

  /// Accessible name when no [UiFormField] label names it.
  final String? label;
  final FocusNode? focusNode;

  @override
  State<UiFbSourcePicker> createState() => UiFbSourcePickerState();
}

/// State of a [UiFbSourcePicker].
class UiFbSourcePickerState extends State<UiFbSourcePicker> {
  final OverlayPortalController _overlay = OverlayPortalController();
  final TextEditingController _text = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final Map<int, GlobalKey> _rowKeys = {};
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode(debugLabel: 'source-picker'));

  bool _open = false;
  bool _hadFocus = false;
  String _query = '';

  /// Typing in a single picker replaces the shown label until it closes.
  bool _typing = false;
  List<UiFbSourceItem> _items = const [];
  int _active = -1;
  _Status _status = _Status.idle;
  int _page = 0;
  bool _hasMore = false;
  String? _loadedKey;
  UiFbAbortController? _abort;
  Timer? _timer;

  /// Whether the list is open (for tests and hosts).
  bool get isOpen => _open;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
    _syncText();
  }

  @override
  void didUpdateWidget(UiFbSourcePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget;
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _ownFocus)?.removeListener(_onFocus);
      _focus.addListener(_onFocus);
    }
    // New params (a parent answer changed) make the loaded pages stale.
    if (!jsonEquals(old.params, widget.params) || old.source.type != widget.source.type) {
      _loadedKey = null;
      if (_open) _search(true);
    }
    if (!widget.enabled && _open) _close();
    if (!_typing) _syncText();
  }

  @override
  void dispose() {
    _abort?.abort();
    _timer?.cancel();
    _focus.removeListener(_onFocus);
    _text.dispose();
    _scroll.dispose();
    _ownFocus?.dispose();
    super.dispose();
  }

  // ── Value ──────────────────────────────────────────────────────────────────────────────────

  UiJson? get _single {
    if (widget.multiple) return null;
    final v = widget.value;
    return toChoice(v is List ? (v.isEmpty ? null : v.first) : v);
  }

  List<UiJson> get _chosen {
    final v = widget.value;
    final list = v is List ? v : (v == null || v == '' ? const [] : [v]);
    return [for (final x in list) ?toChoice(x)];
  }

  Set<String> get _chosenKeys => {for (final c in (widget.multiple ? _chosen : [?_single])) jsString(c['value'])};

  bool _isChosen(UiFbSourceItem it) => _chosenKeys.contains(jsString(it.value));

  void _syncText() {
    final text = widget.multiple || _typing ? _query : (_single?['label'] as String? ?? '');
    if (_text.text != text) _text.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }

  int get _pageSize => widget.source.pageSize ?? 20;

  String get _key => jsonEncode([widget.source.type, widget.params, _query.trim()], toEncodable: (o) => o.toString());

  ({String key, String label})? get _missingParam {
    for (final p in widget.source.params ?? const <UiFbSourceParamSpec>[]) {
      if (p.required && _isBlank(widget.params[p.key])) return (key: p.key, label: p.label);
    }
    return null;
  }

  String get _message {
    final missing = _missingParam;
    switch (_status) {
      case _Status.needs when missing != null:
        return 'Choose ${missing.label.toLowerCase()} first.';
      case _Status.short:
        return 'Type at least ${widget.source.minQueryLength} characters to search.';
      case _Status.error:
        return 'Couldn’t load the list.';
      case _Status.loading:
        return 'Searching…';
      case _Status.more:
        return 'Loading more…';
      default:
        if (_items.isEmpty && _loadedKey != null) {
          final q = _query.trim();
          return q.isNotEmpty ? 'No matches for “$q”.' : 'Nothing to choose from.';
        }
        return '';
    }
  }

  // ── Opening and closing ────────────────────────────────────────────────────────────────────

  void _onFocus() {
    final f = _focus.hasFocus;
    if (f && !_hadFocus) {
      _openPanel();
    } else if (!f && _hadFocus) {
      _close();
    }
    _hadFocus = f;
    if (mounted) setState(() {});
  }

  void _openPanel() {
    if (!widget.enabled || _open) return;
    _open = true;
    _overlay.show();
    if (_loadedKey != _key) _search(true);
    setState(() {});
  }

  void _close() {
    if (!_open) return;
    _open = false;
    _overlay.hide();
    _typing = false;
    _active = -1;
    _timer?.cancel();
    if (_query.isNotEmpty) {
      _query = '';
      _loadedKey = null;
    }
    _syncText();
    if (mounted) setState(() {});
  }

  // ── Input ──────────────────────────────────────────────────────────────────────────────────

  void _onText(String text) {
    _query = text;
    _typing = true;
    if (!_open) _openPanel();
    _active = -1;
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: widget.source.debounceMs ?? 250), () => _search(true));
    setState(() {});
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final n = _items.length;
    if (k == LogicalKeyboardKey.arrowDown || k == LogicalKeyboardKey.arrowUp) {
      if (!_open) {
        _openPanel();
        return KeyEventResult.handled;
      }
      if (n == 0) return KeyEventResult.handled;
      final d = k == LogicalKeyboardKey.arrowDown ? 1 : -1;
      _setActive(_active < 0 ? (d > 0 ? 0 : n - 1) : (_active + d + n) % n);
      return KeyEventResult.handled;
    }
    if ((k == LogicalKeyboardKey.home || k == LogicalKeyboardKey.end) && _open && n > 0 && _query.isEmpty) {
      _setActive(k == LogicalKeyboardKey.home ? 0 : n - 1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
      // Never let Enter submit the surrounding form while the list is open.
      if (!_open) return KeyEventResult.ignored;
      if (_active >= 0 && _active < n) _choose(_items[_active]);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.escape && _open) {
      _close();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.tab) {
      _close();
      return KeyEventResult.ignored;
    }
    if (k == LogicalKeyboardKey.backspace && widget.multiple && _query.isEmpty && _chosen.isNotEmpty) {
      widget.onChanged?.call(_chosen.sublist(0, _chosen.length - 1));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _setActive(int i) {
    setState(() => _active = i);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _rowKeys[i]?.currentContext;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(ctx, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd, duration: Duration.zero);
        Scrollable.ensureVisible(ctx, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart, duration: Duration.zero);
      }
    });
    // Reaching the end with the keyboard loads the next page too.
    if (i >= _items.length - 2) _loadMore();
  }

  void _choose(UiFbSourceItem it) {
    final choice = <String, Object?>{'value': it.value, 'label': it.label};
    if (widget.multiple) {
      final list = _chosen;
      final key = jsString(it.value);
      final has = list.any((c) => jsString(c['value']) == key);
      widget.onChanged?.call(has ? list.where((c) => jsString(c['value']) != key).toList() : [...list, choice]);
      return;
    }
    widget.onChanged?.call(choice);
    _close();
    _text.value = TextEditingValue(text: it.label, selection: TextSelection.collapsed(offset: it.label.length));
  }

  void _remove(UiJson c) {
    final key = jsString(c['value']);
    widget.onChanged?.call(_chosen.where((x) => jsString(x['value']) != key).toList());
  }

  void _clear() {
    widget.onChanged?.call(null);
    _query = '';
    _text.clear();
    _focus.requestFocus();
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.extentAfter < 48) _loadMore();
    return false;
  }

  void _retry() => _search(_page <= 1);

  void _loadMore() {
    if (_hasMore && _status != _Status.loading && _status != _Status.more) _search(false);
  }

  /// Loads page 1 ([reset]) or the next page, cancelling whatever is still in flight.
  Future<void> _search(bool reset) async {
    _timer?.cancel();
    _timer = null;
    final def = widget.source;
    final key = _key;
    final q = _query.trim();
    if (_missingParam != null) return _reset(_Status.needs, key);
    if (q.length < (def.minQueryLength ?? 0)) return _reset(_Status.short, key);
    _abort?.abort();
    final abort = UiFbAbortController();
    _abort = abort;
    final page = reset ? 1 : _page + 1;
    setState(() {
      _status = reset ? _Status.loading : _Status.more;
      if (reset) _active = -1;
    });
    try {
      final res = await def.search(UiFbSourceQuery(query: q, page: page, pageSize: _pageSize, params: widget.params, signal: abort.signal));
      if (abort.signal.aborted || !mounted) return;
      final items = reset ? res.items : [..._items, ...res.items];
      setState(() {
        _items = items;
        _page = page;
        _hasMore = sourceHasMore(res, items.length, _pageSize);
        _loadedKey = key;
        _status = _Status.idle;
        if (reset && items.isNotEmpty && _typing) _active = 0;
      });
      if (reset && _scroll.hasClients) _scroll.jumpTo(0);
    } catch (_) {
      if (abort.signal.aborted || !mounted) return;
      setState(() => _status = _Status.error);
    }
  }

  void _reset(_Status status, String key) {
    _abort?.abort();
    setState(() {
      _items = const [];
      _page = 0;
      _hasMore = false;
      _loadedKey = key;
      _status = status;
    });
  }

  // ── Building ───────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final touch = uiTouchPlatform(context);
    final rowH = touch ? uiMinTouchTarget : 24.0;
    final minH = math.max(t.sizeMd, touch ? uiMinTouchTarget : 0.0);
    final name = widget.label ?? UiFieldScope.maybeOf(context)?.label;
    final chosen = _chosen;
    final single = _single;
    final showClear = !widget.multiple && single != null && widget.enabled;

    final field = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled
          ? () {
              _focus.requestFocus();
              _openPanel();
            }
          : null,
      child: MouseRegion(
        cursor: widget.enabled ? SystemMouseCursors.text : SystemMouseCursors.forbidden,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minH),
          child: UiFieldFrame(
            focused: _focus.hasFocus,
            invalid: uiFieldInvalid(context, widget.invalid),
            enabled: widget.enabled,
            padding: EdgeInsetsDirectional.only(start: widget.multiple ? t.space1 : t.space3, end: t.space3, top: touch ? 0 : 2, bottom: touch ? 0 : 2),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minH - (touch ? 2 : 6)),
              child: Row(children: [
                Expanded(
                  child: Wrap(
                    spacing: t.space1,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (widget.multiple)
                        for (final c in chosen) _SourceChip(label: c['label'] as String, height: rowH, enabled: widget.enabled, onRemove: () => _remove(c)),
                      ConstrainedBox(
                        constraints: BoxConstraints(minWidth: 80, minHeight: rowH),
                        child: IntrinsicWidth(
                          child: Padding(
                            padding: EdgeInsetsDirectional.only(start: widget.multiple ? t.space2 : 0),
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              widthFactor: 1,
                              child: UiTextEditor(
                                controller: _text,
                                focusNode: _focus,
                                style: uiFieldTextStyle(context, UiSize.md),
                                placeholder: (!widget.multiple || chosen.isEmpty) ? widget.placeholder : null,
                                enabled: widget.enabled,
                                onChanged: _onText,
                                onKeyEvent: _onKey,
                                semanticLabel: name,
                                onTap: _openPanel,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (showClear)
                  UiFieldButton(label: 'Clear', visual: 24, onTap: _clear, icon: const UiIcon(HugeIcons.strokeRoundedCancel01, strokeWidth: 2)),
                SizedBox(width: showClear ? t.space1 : t.space2),
                SizedBox.square(
                  dimension: 14,
                  child: _status == _Status.loading && _open
                      ? UiSpinner(size: 12, decorative: true, color: t.primary)
                      : AnimatedRotation(
                          turns: _open ? 0.5 : 0,
                          duration: context.uiAnimate ? t.motionFast : Duration.zero,
                          child: UiIcon(HugeIcons.strokeRoundedArrowDown01, size: 14, strokeWidth: 2, color: t.textMuted),
                        ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );

    return Semantics(
      expanded: _open,
      child: UiAnchoredOverlay(
        controller: _overlay,
        matchAnchorWidth: true,
        onDismiss: _close,
        // Taps in the list count as inside the text field, so they don't blur it before they land.
        panelBuilder: (context, anchor) => TextFieldTapRegion(child: _panel(context, name)),
        child: field,
      ),
    );
  }

  Widget _panel(BuildContext context, String? name) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final ty = context.uiText;
    final touch = uiTouchPlatform(context);
    final message = _message;
    final rowStyle = ty.body.copyWith(fontSize: t.fontSizeMd, height: 1.35, color: t.text);
    final descStyle = ty.body.copyWith(fontSize: t.fontSizeSm, height: 1.35, color: t.textMuted);

    Widget row(int i) {
      final it = _items[i];
      final chosen = _isChosen(it);
      final active = i == _active;
      final fill = chosen ? (active ? uiMix(t.selected, 0.5, t.elevatedHover) : t.selected) : (active ? t.elevatedHover : null);
      return KeyedSubtree(
        key: _rowKeys.putIfAbsent(i, GlobalKey.new),
        child: MouseRegion(
          onEnter: (_) => setState(() => _active = i),
          child: UiInteractive(
            onTap: () => _choose(it),
            button: false,
            selected: widget.multiple ? null : chosen,
            checked: widget.multiple ? chosen : null,
            semanticLabel: it.description == null ? it.label : '${it.label}, ${it.description}',
            excludeChildSemantics: true,
            pressScale: false,
            padTouchTarget: false,
            builder: (context, s) => Container(
              constraints: BoxConstraints(minHeight: touch ? uiMinTouchTarget : 0),
              padding: EdgeInsets.symmetric(horizontal: t.space3, vertical: t.space2),
              decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(theme.radius(t.radiusXs))),
              child: Row(spacing: t.space2, children: [
                if (widget.multiple) UiCheckMark(value: chosen, states: s),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(it.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: rowStyle),
                    if (it.description != null) Text(it.description!, maxLines: 1, overflow: TextOverflow.ellipsis, style: descStyle),
                  ]),
                ),
                if (!widget.multiple && chosen) UiIcon(HugeIcons.strokeRoundedTick02, size: 14, strokeWidth: 2.4, color: t.primary),
              ]),
            ),
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: name ?? widget.source.label,
      child: Container(
        padding: EdgeInsets.all(t.space1),
        decoration: BoxDecoration(
          color: t.surfaceRaised,
          border: Border.all(color: t.border),
          borderRadius: BorderRadius.circular(theme.radius()),
          boxShadow: t.shadow2,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_items.isNotEmpty)
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 264),
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _onScroll,
                    // Rows aren't tab stops: the input owns the keyboard.
                    child: ExcludeFocus(
                      child: ListView.builder(
                        controller: _scroll,
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _items.length,
                        itemBuilder: (context, i) => row(i),
                      ),
                    ),
                  ),
                ),
              ),
            if (message.isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: t.space3, vertical: t.space2),
                child: Row(spacing: t.space2, children: [
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(message, style: descStyle.copyWith(color: _status == _Status.error ? t.danger : t.textMuted)),
                    ),
                  ),
                  if (_status == _Status.error)
                    ExcludeFocus(child: _RetryButton(onTap: _retry)),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

bool _isBlank(Object? v) =>
    v == null || v == '' || (v is List && v.isEmpty) || (isChoice(v) && ((v as Map)['value'] == null || v['value'] == ''));

/// "Try again" in the status row after a failed load.
class _RetryButton extends StatelessWidget {
  const _RetryButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    return UiInteractive(
      onTap: onTap,
      semanticLabel: 'Try again',
      excludeChildSemantics: true,
      pressScale: false,
      builder: (context, s) => Container(
        height: t.sizeSm,
        padding: EdgeInsets.symmetric(horizontal: t.space2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: s.hovered ? t.elevatedHover : t.surface,
          border: Border.all(color: t.border),
          borderRadius: BorderRadius.circular(theme.radius(t.radiusXs)),
          boxShadow: s.focused ? t.focusRing : const [],
        ),
        child: Text('Try again', style: context.uiText.body.copyWith(fontSize: t.fontSizeSm, color: t.text)),
      ),
    );
  }
}

/// A chosen item in a multiple picker: a tinted pill with a remove button (the web `.chip`).
class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.label, required this.height, required this.enabled, required this.onRemove});
  final String label;
  final double height;
  final bool enabled;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final touch = uiTouchPlatform(context);
    final hit = touch ? uiMinTouchTarget : 24.0;
    final style = context.uiText.body.copyWith(fontSize: t.fontSizeSm, color: t.text, height: 1.2);
    final overhang = touch ? (hit / 2 - 13).clamp(0.0, double.infinity) : 0.0;
    return SizedBox(
      height: height,
      child: Stack(alignment: AlignmentDirectional.centerStart, children: [
        Padding(
          padding: EdgeInsetsDirectional.only(end: overhang),
          child: Container(
            height: 22,
            padding: EdgeInsetsDirectional.only(start: t.space2, end: t.space1),
            decoration: BoxDecoration(
              color: t.selected,
              border: Border.all(color: t.primary.withValues(alpha: 0.45)),
              borderRadius: BorderRadius.circular(theme.radius(t.radiusXs)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, spacing: t.space1, children: [
              Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
              const SizedBox(width: 16),
            ]),
          ),
        ),
        PositionedDirectional(
          end: 0,
          top: 0,
          bottom: 0,
          width: hit,
          child: ExcludeFocus(
            child: UiInteractive(
              onTap: onRemove,
              enabled: enabled,
              semanticLabel: 'Remove $label',
              excludeChildSemantics: true,
              pressScale: false,
              padTouchTarget: false,
              builder: (context, s) => Center(
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: s.hovered || s.pressed ? t.text.withValues(alpha: 0.14) : null),
                  child: UiIcon(HugeIcons.strokeRoundedCancel01, size: 12, strokeWidth: 2, color: t.text.withValues(alpha: s.hovered ? 1 : 0.7)),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
