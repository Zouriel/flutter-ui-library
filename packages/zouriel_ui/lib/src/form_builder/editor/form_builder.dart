import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../button/button.dart';
import '../../button/segmented.dart';
import '../../core/icon.dart';
import '../../core/interactive.dart';
import '../../core/types.dart';
import '../../dialog/bottom_sheet.dart';
import '../../dialog/modal.dart';
import '../../dialog/toast.dart';
import '../../theme/theme.dart';
import '../engine/definition.dart';
import '../engine/global_settings.dart';
import '../engine/http_sources.dart';
import '../engine/option_sources.dart';
import '../engine/schema.dart';
import '../engine/validators.dart';
import 'builder_bits.dart';
import 'builder_canvas.dart';
import 'builder_dnd.dart';
import 'builder_inspector.dart';
import 'builder_logic.dart';
import 'builder_palette.dart';
import 'builder_preview.dart';
import 'builder_store.dart';

/// Which part of the builder is showing.
enum UiFormBuilderView { build, logic, preview }

/// How the builder lays itself out, by its own width.
enum UiFormBuilderLayout {
  /// Under 720: the canvas, an Add button that opens the palette in a sheet, and settings in a
  /// sheet that a long press (or a toolbar's settings button) opens.
  narrow,

  /// 720 to 1100: the canvas with settings beside it; the palette opens from Add.
  medium,

  /// 1100 and wider: palette, canvas and settings side by side.
  wide,
}

const Map<String, String> _refWords = {
  'visibility': 'decides when it shows',
  'required': 'decides when it’s required',
  'disabled': 'decides when it’s read-only',
  'setValue': 'fills itself in from it',
  'validator': 'checks against it',
  'calc': 'calculates from it',
  'jump': 'jumps based on it',
  'source': 'narrows its list by it',
};

/// `ui-form-builder`: build forms by adding fields to a page, then add rules: show or require a
/// question only when other answers say so, group questions into sections (that repeat, or depend
/// on other sections), split the form into steps, and add checks with your own messages.
///
/// The [definition] is plain JSON (the same as the web builder's), ready to store and to hand to
/// [UiFormRenderer]; every edit comes back through [onChanged]. Pass the [published] version and
/// its [submissionCount] so the builder protects answers that already exist (archiving instead of
/// deleting, locking saved values, remembering renamed keys).
///
/// It lays itself out by its own width (see [UiFormBuilderLayout]) and fills the space it is
/// given: put it in a bounded box (a page body, an `Expanded`). Keyboard: Ctrl/Cmd+Z and
/// Ctrl/Cmd+Shift+Z undo and redo; Escape clears the selection.
class UiFormBuilder extends StatefulWidget {
  const UiFormBuilder({
    super.key,
    this.definition,
    this.onChanged,
    this.controller,
    this.published,
    this.submissionCount = 0,
    this.validators = const [],
    this.optionSources = const [],
    this.globalSettings,
    this.httpSources = const UiFbHttpSourcesOptions(),
    this.actions,
  });

  /// The form being built: a [UiFormDefinition] or its stored JSON (migrated on load). Handing back
  /// the definition from [onChanged] keeps everything; a different form (another id, or other
  /// content) replaces it and clears undo history; the same form with only `revision` changed (a
  /// published copy stored back) keeps history.
  final Object? definition;
  final ValueChanged<UiFormDefinition>? onChanged;

  /// Drive the builder from outside (select, undo, read problems and changes). One is made when
  /// not given.
  final UiFormBuilderController? controller;

  /// The version people are answering now (for warnings and the change list).
  final UiFormDefinition? published;

  /// How many answers the published version has. Above zero, saved data is protected.
  final int submissionCount;

  /// App checks for the "Add a check" list, on top of the built-in ones.
  final List<UiFbValidatorDef> validators;

  /// Searchable lists for dropdowns and multi-selects (Options, Data source).
  final List<UiFbOptionSourceDef> optionSources;

  /// App-wide settings from [UiFormGlobalSettingsEditor]: their lists become data sources here.
  final UiFormGlobalSettings? globalSettings;

  /// How lists from [globalSettings] make requests.
  final UiFbHttpSourcesOptions httpSources;

  /// Your own buttons (Save, Publish) at the end of the top bar.
  final Widget? actions;

  @override
  State<UiFormBuilder> createState() => UiFormBuilderState();
}

/// State of a [UiFormBuilder]: [controller], [view] and [layout].
class UiFormBuilderState extends State<UiFormBuilder> {
  UiFormBuilderController? _own;
  late FbDnd _dnd;
  UiFormBuilderView _view = UiFormBuilderView.build;
  UiFormBuilderLayout _layout = UiFormBuilderLayout.wide;
  int _sheetSnap = 0;
  bool _addOpen = false;
  UiFbDropTarget? _addTarget;
  String? _toast;
  Timer? _toastTimer;
  final FocusNode _root = FocusNode(debugLabel: 'form builder');

  UiFormBuilderController get controller => widget.controller ?? (_own ??= UiFormBuilderController());
  UiFormBuilderView get view => _view;
  UiFormBuilderLayout get layout => _layout;

  @override
  void initState() {
    super.initState();
    _configure(notify: false);
    _dnd = FbDnd(controller);
    controller.addListener(_changed);
    _dnd.addListener(_dndChanged);
  }

  @override
  void didUpdateWidget(UiFormBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _own)?.removeListener(_changed);
      controller.addListener(_changed);
      _dnd.removeListener(_dndChanged);
      _dnd.dispose();
      _dnd = FbDnd(controller)..addListener(_dndChanged);
    }
    _configure(notify: false);
  }

  @override
  void dispose() {
    controller.removeListener(_changed);
    _dnd.removeListener(_dndChanged);
    _dnd.dispose();
    _own?.dispose();
    _toastTimer?.cancel();
    _root.dispose();
    super.dispose();
  }

  void _configure({required bool notify}) {
    final c = controller;
    if (widget.definition != null) {
      c.load(widget.definition!, notify: notify);
      _sent = c.def;
    }
    c.configure(
      published: widget.published,
      clearPublished: widget.published == null,
      submissionCount: widget.submissionCount,
      validatorDefs: [...uiFbBuiltinValidators, ...widget.validators],
      optionSourceDefs: [...sourcesFromSettings(widget.globalSettings, widget.httpSources), ...widget.optionSources],
      notify: notify,
    );
  }

  UiFormDefinition? _sent;

  void _changed() {
    final d = controller.def;
    if (!identical(d, _sent) && !identical(d, widget.definition)) {
      _sent = d;
      widget.onChanged?.call(d);
    }
    if (mounted) setState(() {});
  }

  String _announce = '';
  void _dndChanged() {
    if (_dnd.announcement != _announce) _announce = _dnd.announcement;
    if (mounted) setState(() {});
  }

  /// Selects an element or page (null for the form) and shows its settings.
  void select(String? id) {
    setState(() => _view = UiFormBuilderView.build);
    controller.select(id);
  }

  void _setView(UiFormBuilderView v) => setState(() {
    _view = v;
    _sheetSnap = 0;
  });

  void _openSettings(String? id) {
    controller.select(id);
    setState(() {
      _view = UiFormBuilderView.build;
      if (_layout == UiFormBuilderLayout.narrow) _sheetSnap = 1;
    });
  }

  void _openAdd(UiFbDropTarget? target) {
    if (_layout == UiFormBuilderLayout.narrow) {
      setState(() {
        _addTarget = target;
        _sheetSnap = 0;
        _addOpen = true;
      });
      return;
    }
    showUiModal<void>(
      context: context,
      title: 'Add a field',
      size: UiModalSize.lg,
      builder: (ctx) => SizedBox(
        height: 460,
        child: UiFbBuilderScope(
          controller: controller,
          child: UiFbPalette(compact: true, target: target, onAdded: () => Navigator.of(ctx).pop()),
        ),
      ),
    );
  }

  // ── Deleting ──────────────────────────────────────────────────────────────────────────────

  void _requestDelete(String id) {
    final store = controller;
    final entry = store.index[id];
    if (entry == null) return;
    final ids = subtreeIds(store.def, id);
    final answers = ids.any((x) => store.hasAnswers(x) && store.index[x]?.kind == 'field');
    final refs = store.externalRefs(id);
    final page = entry.kind == 'page';
    final count = page ? ids.where((x) => store.index[x]?.kind == 'field').length : 0;
    final name = store.name(id);
    if (!answers && refs.isEmpty && !(page && count > 0)) {
      _doDelete(id, name, page);
      return;
    }
    final t = context.ui;
    showUiModal<String>(
      context: context,
      size: UiModalSize.sm,
      title: answers && !page ? '“$name” has answers' : 'Delete “$name”?',
      builder: (ctx) {
        final style = context.uiText.body.copyWith(fontSize: 14, height: 1.5, color: t.text);
        return DefaultTextStyle.merge(
          style: style,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, spacing: t.space2, children: [
            if (answers)
              Text.rich(TextSpan(children: [
                TextSpan(text: 'People have already answered ${page ? 'questions on this page' : 'this'}. '),
                const TextSpan(text: 'Archiving', style: TextStyle(fontWeight: FontWeight.w700)),
                const TextSpan(text: ' hides it from new answers and keeps the saved ones readable. Deleting leaves old answers without a question to show them under.'),
              ]))
            else if (page && count > 0)
              Text('This page has $count question${count > 1 ? 's' : ''} on it. They’ll be deleted too.'),
            if (refs.isNotEmpty) ...[
              const Text('These rules use it and will be removed:'),
              for (final r in refs) Text('•  “${store.name(r.ownerId)}” ${_refWords[r.kind] ?? r.kind}'),
            ],
            const FbHint('You can undo this.'),
          ]),
        );
      },
      footerBuilder: (ctx) => Row(children: [
        UiButton(label: 'Cancel', variant: UiButtonVariant.ghost, onPressed: () => Navigator.of(ctx).pop()),
        const Spacer(),
        if (answers && !page) ...[
          UiButton(label: 'Delete anyway', variant: UiButtonVariant.outline, onPressed: () => Navigator.of(ctx).pop('delete')),
          SizedBox(width: t.space2),
          UiButton(label: 'Archive', onPressed: () => Navigator.of(ctx).pop('archive')),
        ] else
          UiButton(label: 'Delete', variant: UiButtonVariant.destructive, onPressed: () => Navigator.of(ctx).pop('delete')),
      ]),
    ).then((choice) {
      if (!mounted) return;
      if (choice == 'delete') _doDelete(id, name, page);
      if (choice == 'archive') {
        controller.setArchived(id, true);
        _showToast('Archived “$name”');
      }
    });
  }

  void _doDelete(String id, String name, bool page) {
    if (page) {
      controller.removePage(id);
    } else {
      controller.remove(id);
    }
    setState(() => _sheetSnap = 0);
    _showToast('Deleted “$name”');
  }

  void _showToast(String message) {
    _toastTimer?.cancel();
    setState(() => _toast = message);
    _toastTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  // ── Keyboard ──────────────────────────────────────────────────────────────────────────────

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final typing = FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<EditableText>() != null;
    final keys = HardwareKeyboard.instance;
    final mod = keys.isControlPressed || keys.isMetaPressed;
    final k = e.logicalKey;
    if (mod && !typing && k == LogicalKeyboardKey.keyZ) {
      keys.isShiftPressed ? controller.redo() : controller.undo();
      return KeyEventResult.handled;
    }
    if (mod && !typing && k == LogicalKeyboardKey.keyY) {
      controller.redo();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.escape && !typing && controller.selectedId != null && _dnd.payload == null && _view == UiFormBuilderView.build) {
      controller.select(null);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ── Layout ────────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return UiFbBuilderScope(
      controller: controller,
      child: Focus(
        focusNode: _root,
        onKeyEvent: _onKey,
        // Keys reach the builder once someone has touched it, so undo/redo work straight away.
        child: Listener(
          onPointerDown: (_) {
            if (!_root.hasFocus) _root.requestFocus();
          },
          child: LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth;
          _layout = w >= 1100 ? UiFormBuilderLayout.wide : (w >= 720 ? UiFormBuilderLayout.medium : UiFormBuilderLayout.narrow);
          final narrow = _layout == UiFormBuilderLayout.narrow;
          return ColoredBox(
            key: _dnd.rootKey,
            color: t.bg,
            child: Stack(children: [
              Positioned.fill(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _TopBar(state: this),
                  Expanded(child: _main(context)),
                ]),
              ),
              if (narrow && _view == UiFormBuilderView.build && _sheetSnap == 0 && !_addOpen)
                Positioned(
                  right: t.space4,
                  bottom: t.space4 + MediaQuery.paddingOf(context).bottom,
                  child: _Fab(onTap: () => _openAdd(null)),
                ),
              if (narrow && _view == UiFormBuilderView.build)
                UiBottomSheet(
                  snaps: const [0, 0.6, 0.94],
                  snap: _sheetSnap,
                  onSnapChanged: (s) => setState(() => _sheetSnap = s),
                  title: controller.selected != null ? controller.name(controller.selectedId!) : 'Form settings',
                  builder: (context, scroll) => UiFbInspector(showHead: false, scrollController: scroll, onDeleteRequest: _requestDelete),
                ),
              if (narrow)
                UiBottomSheet(
                  snaps: const [0, 0.75],
                  snap: _addOpen ? 1 : 0,
                  backdrop: true,
                  title: 'Add a field',
                  onSnapChanged: (s) {
                    if (s == 0) setState(() => _addOpen = false);
                  },
                  builder: (context, scroll) => Padding(
                    padding: EdgeInsets.fromLTRB(t.space3, t.space3, t.space3, 0),
                    child: UiFbPalette(compact: true, target: _addTarget, scrollController: scroll, onAdded: () => setState(() => _addOpen = false)),
                  ),
                ),
              if (_toast != null)
                Positioned(
                  left: t.space4,
                  right: t.space4,
                  bottom: (narrow ? 76 : t.space4) + MediaQuery.paddingOf(context).bottom,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: UiToastView(
                        toast: UiToast(id: 0, message: _toast!, action: UiToastAction(label: 'Undo', run: () {})),
                        onAction: () {
                          controller.undo();
                          setState(() => _toast = null);
                        },
                        onDismiss: () => setState(() => _toast = null),
                      ),
                    ),
                  ),
                ),
              ..._dragLayer(context),
              Semantics(liveRegion: true, label: _toast != null ? '$_toast. Undo is at the bottom of the screen.' : _announce, child: const SizedBox.shrink()),
            ]),
          );
        }),
        ),
      ),
    );
  }

  Widget _main(BuildContext context) {
    final t = context.ui;
    switch (_view) {
      case UiFormBuilderView.logic:
        return UiFbLogicOverview(onOpen: _openSettings);
      case UiFormBuilderView.preview:
        return const UiFbPreview();
      case UiFormBuilderView.build:
        final canvas = UiFbCanvas(
          dnd: _dnd,
          paletteBeside: _layout == UiFormBuilderLayout.wide,
          bottomPadding: _layout == UiFormBuilderLayout.narrow ? 64 : 0,
          onAddAt: _openAdd,
          onDeleteRequest: _requestDelete,
          onOpen: _openSettings,
          onOpenForm: () => _openSettings(null),
        );
        if (_layout == UiFormBuilderLayout.narrow) return canvas;
        BoxDecoration side(bool left) => BoxDecoration(
          color: t.surface,
          border: Border(left: left ? BorderSide.none : BorderSide(color: t.borderSubtle), right: left ? BorderSide(color: t.borderSubtle) : BorderSide.none),
        );
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (_layout == UiFormBuilderLayout.wide)
            Container(
              width: 240,
              padding: EdgeInsets.fromLTRB(t.space2, t.space3, t.space2, 0),
              decoration: side(true),
              child: Semantics(container: true, label: 'Fields to add', child: UiFbPalette(dnd: _dnd)),
            ),
          Expanded(child: canvas),
          Container(
            width: _layout == UiFormBuilderLayout.wide ? 340 : 316,
            decoration: side(false),
            child: Semantics(container: true, label: 'Settings', child: UiFbInspector(onDeleteRequest: _requestDelete)),
          ),
        ]);
    }
  }

  List<Widget> _dragLayer(BuildContext context) {
    final p = _dnd.payload;
    if (p == null) return const [];
    final t = context.ui;
    final at = _dnd.position;
    final drop = _dnd.drop;
    return [
      if (drop?.line case final l?)
        Positioned.fromRect(
          rect: l,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                color: drop!.valid ? t.primary : t.danger,
                borderRadius: BorderRadius.circular(2),
                boxShadow: drop.valid ? [BoxShadow(color: t.primary.withValues(alpha: 0.22), spreadRadius: 3)] : null,
              ),
            ),
          ),
        ),
      Positioned(
        left: at.dx + 12,
        top: at.dy + 8,
        child: IgnorePointer(
          child: Container(
            height: 30,
            padding: EdgeInsets.symmetric(horizontal: t.space3),
            decoration: BoxDecoration(
              color: t.surfaceRaised,
              border: Border.all(color: t.primary),
              borderRadius: BorderRadius.circular(t.radius),
              boxShadow: t.shadow3,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, spacing: 6, children: [
              UiIcon(p.icon, size: 14, color: t.text),
              Text(p.label, style: context.uiText.label.copyWith(fontSize: 13, fontWeight: FontWeight.w500, color: t.text)),
            ]),
          ),
        ),
      ),
    ];
  }
}

class _Fab extends StatelessWidget {
  const _Fab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return UiInteractive(
      onTap: onTap,
      semanticLabel: 'Add field',
      excludeChildSemantics: true,
      builder: (context, s) => Container(
        height: 48,
        padding: EdgeInsets.symmetric(horizontal: t.space4),
        decoration: BoxDecoration(
          color: s.hovered || s.pressed ? t.primaryHover : t.primary,
          borderRadius: BorderRadius.circular(24),
          boxShadow: s.focused ? [...t.shadow2, ...t.focusRing] : t.shadow2,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, spacing: 6, children: [
          UiIcon(HugeIcons.strokeRoundedAdd01, size: 18, color: t.primaryContrast, strokeWidth: 2),
          Text('Add field', style: context.uiText.label.copyWith(fontSize: 14, color: t.primaryContrast)),
        ]),
      ),
    );
  }
}

/// Title, Build / Logic / Preview, undo and redo, the problem and change pills, and the host's
/// own buttons.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.state});
  final UiFormBuilderState state;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final store = state.controller;
    final narrow = state._layout == UiFormBuilderLayout.narrow;
    final errors = store.errorCount;
    final changes = store.diff?.summary ?? const <String>[];
    final title = store.def.title.isNotEmpty ? store.def.title : 'Untitled form';

    final titleButton = UiInteractive(
      onTap: () => state._openSettings(null),
      semanticLabel: '$title, form settings',
      excludeChildSemantics: true,
      pressScale: false,
      builder: (context, s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: s.hovered || s.pressed ? t.surfaceHover : null,
          borderRadius: BorderRadius.circular(t.radiusXs),
          boxShadow: s.focused ? t.focusRing : null,
        ),
        child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.uiText.label.copyWith(fontSize: 14, color: t.text)),
      ),
    );

    final views = UiSegmented<UiFormBuilderView>(
      label: 'View',
      size: UiSize.sm,
      value: state._view,
      options: const [
        UiSegmentedOption(value: UiFormBuilderView.build, label: 'Build'),
        UiSegmentedOption(value: UiFormBuilderView.logic, label: 'Logic'),
        UiSegmentedOption(value: UiFormBuilderView.preview, label: 'Preview'),
      ],
      onChanged: state._setView,
    );

    final tools = Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 2, runSpacing: 2, children: [
      FbIconButton(icon: HugeIcons.strokeRoundedUndo02, label: 'Undo', onPressed: store.canUndo ? store.undo : null),
      FbIconButton(icon: HugeIcons.strokeRoundedRedo02, label: 'Redo', onPressed: store.canRedo ? store.redo : null),
      if (errors > 0)
        _Pill(
          label: '$errors',
          icon: HugeIcons.strokeRoundedAlert02,
          semantic: '$errors problem${errors > 1 ? 's' : ''} to fix',
          color: t.danger,
          onTap: () => state._setView(UiFormBuilderView.logic),
        ),
      if (changes.isNotEmpty)
        _Pill(
          label: narrow ? '${changes.length} change${changes.length > 1 ? 's' : ''}' : '${changes.length} unpublished change${changes.length > 1 ? 's' : ''}',
          semantic: '${changes.length} unpublished change${changes.length > 1 ? 's' : ''}',
          color: t.textSecondary,
          onTap: () => showUiModal<void>(
            context: context,
            title: 'Unpublished changes',
            size: UiModalSize.sm,
            builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 6, children: [
              for (final line in changes) Text('•  $line', style: context.uiText.body.copyWith(fontSize: 13, height: 1.4, color: t.text)),
            ]),
          ),
        ),
      if (!narrow && state._layout == UiFormBuilderLayout.medium && state._view == UiFormBuilderView.build)
        UiButton(label: 'Add', size: UiSize.sm, variant: UiButtonVariant.outline, icon: const UiIcon(HugeIcons.strokeRoundedAdd01), onPressed: () => state._openAdd(null)),
      ?state.widget.actions,
    ]);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: t.space3, vertical: 6),
      decoration: BoxDecoration(color: t.surface, border: Border(bottom: BorderSide(color: t.borderSubtle))),
      child: narrow
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 6, children: [
              // The tools keep their natural width (up to most of the row); the title takes the rest.
              LayoutBuilder(builder: (context, box) => Row(children: [
                Expanded(child: Align(alignment: Alignment.centerLeft, child: titleButton)),
                ConstrainedBox(constraints: BoxConstraints(maxWidth: box.maxWidth * 0.72), child: tools),
              ])),
              views,
            ])
          : Row(spacing: t.space3, children: [
              Flexible(child: titleButton),
              const Spacer(),
              views,
              const Spacer(),
              tools,
            ]),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.semantic, required this.color, required this.onTap, this.icon});
  final String label;
  final String semantic;
  final Color color;
  final VoidCallback onTap;
  final UiIconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return UiInteractive(
      onTap: onTap,
      semanticLabel: semantic,
      excludeChildSemantics: true,
      pressScale: false,
      builder: (context, s) => Container(
        height: 26,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: icon != null ? color.withValues(alpha: s.hovered ? 0.2 : 0.14) : (s.hovered ? t.border : t.surfaceHover),
          borderRadius: BorderRadius.circular(13),
          boxShadow: s.focused ? t.focusRing : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, spacing: 4, children: [
          if (icon != null) UiIcon(icon!, size: 14, color: color),
          Text(label, style: context.uiText.label.copyWith(fontSize: 12, color: color)),
        ]),
      ),
    );
  }
}
