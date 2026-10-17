import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../button/button.dart';
import '../button/segmented.dart';
import '../core/icon.dart';
import '../core/interactive.dart';
import '../core/types.dart';
import '../dialog/bottom_sheet.dart';
import '../dialog/modal.dart';
import '../theme/theme.dart';
import 'api.dart';
import 'bits.dart';
import 'canvas.dart';
import 'definition.dart';
import 'dnd.dart';
import 'icons.dart';
import 'inspector.dart';
import 'json.dart';
import 'lifecycle.dart';
import 'panels.dart';
import 'schema.dart';
import 'scope.dart';
import 'store.dart';

/// Which part of the builder is showing.
enum UiWorkflowBuilderView { build, versions, test }

/// `ui-workflow-builder`: design workflows for non-technical admins. Automations are a trigger and
/// a list of steps (approvals, waits, branches, parallel paths, loops, messages, record updates,
/// app actions…) with branches drawn as columns; lifecycles are a diagram of states and the
/// transitions between them, each with who may apply it, checks, a form and the steps it runs.
///
/// [definition] is plain JSON (the Zouriel Workflows spec format, the same as the web builder's);
/// every edit comes back through [onChanged]. Give it the engine's [api] and it loads the app's
/// record types, checks the workflow as you edit, saves, publishes and runs tests. Without one,
/// pass [schema] yourself; it then works offline (no problems list, versions or tests).
///
/// It lays itself out by its own width (see [UiWorkflowBuilderLayout]) and fills the space it is
/// given: put it in a bounded box. Keyboard: Ctrl/Cmd+Z and Ctrl/Cmd+Shift+Z (or Ctrl+Y) undo and
/// redo, Ctrl/Cmd+S saves, Delete deletes the selection, Escape clears it.
class UiWorkflowBuilder extends StatefulWidget {
  const UiWorkflowBuilder({
    super.key,
    this.definition,
    this.onChanged,
    this.controller,
    this.published,
    this.api,
    this.schema,
    this.settings,
    this.persist = false,
    this.readOnly,
    this.onProblemsChanged,
    this.onSaved,
    this.onDirtyChanged,
    this.actions,
  });

  /// The workflow being built. Handing back the definition from [onChanged] keeps everything; a
  /// workflow with another id replaces it and clears undo history.
  final UiWorkflowDefinition? definition;
  final ValueChanged<UiWorkflowDefinition>? onChanged;

  /// Drive the builder from outside (select, undo, read problems). One is made when not given.
  final UiWorkflowBuilderController? controller;

  /// The published version, if any (locks the record type; drives "unpublished changes").
  final UiWorkflowDefinition? published;

  /// The engine API.
  final UiWorkflowApi? api;

  /// The app's registry and step outputs, when there is no API (or to skip loading it).
  final UiWorkflowSchema? schema;

  /// Global settings (webhook connections…), when there is no API.
  final UiWorkflowSettings? settings;

  /// Save drafts and publish through the API from the builder's own header.
  final bool persist;

  /// Look without changing anything. Null (the default) asks the API (`me()`) whether this person
  /// may edit workflows; true or false decides it here. Read-only shows "View only", hides Save,
  /// Publish, Versions and Test, turns every control off, ignores edits and skips the engine check.
  final bool? readOnly;

  /// The engine's problems after each check (empty when none or offline).
  final ValueChanged<List<UiWfProblem>>? onProblemsChanged;

  /// After a successful save through the API.
  final ValueChanged<UiWorkflowDefinition>? onSaved;

  /// Whether there are edits not yet saved through the API (with [persist]), so the host can guard
  /// leaving the page.
  final ValueChanged<bool>? onDirtyChanged;

  /// Your own buttons at the end of the header.
  final Widget? actions;

  @override
  State<UiWorkflowBuilder> createState() => UiWorkflowBuilderState();
}

/// State of a [UiWorkflowBuilder]: [controller], [view], [layout], and [save].
class UiWorkflowBuilderState extends State<UiWorkflowBuilder> {
  UiWorkflowBuilderController? _own;
  late WfDnd _dnd;
  final WfBuilderUi _ui = WfBuilderUi();
  final FocusNode _root = FocusNode(debugLabel: 'workflow builder');
  UiWorkflowBuilderView _view = UiWorkflowBuilderView.build;
  int _sheetSnap = 0;
  WfDropTarget? _addTarget;
  bool _saving = false;
  String _saveError = '';
  String? _lastSaved;
  bool _savedOnce = false;
  Timer? _validateTimer;
  int _validateSeq = 0;
  UiWorkflowDefinition? _sent;
  UiWorkflowApi? _loadedFor;
  int _lastVersion = -1;

  /// The last check failed (offline, refused or broken), so "Ready" would be a guess.
  bool _checkFailed = false;

  /// What `me()` said about editing; an API without it (or an error) leaves editing on, and the
  /// server still decides.
  bool _mayEdit = true;
  bool? _lastDirty;

  UiWorkflowBuilderController get controller => widget.controller ?? (_own ??= UiWorkflowBuilderController(definition: widget.definition));
  UiWorkflowBuilderView get view => _view;
  UiWorkflowBuilderLayout get layout => _ui.layout;
  bool get _dirty => _lastSaved != jsonStringify(controller.def.json);

  @override
  void initState() {
    super.initState();
    _dnd = WfDnd(controller);
    _wireUi();
    controller.addListener(_changed);
    _configure();
    _validateSoon();
  }

  @override
  void didUpdateWidget(UiWorkflowBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _own)?.removeListener(_changed);
      controller.addListener(_changed);
      _dnd.dispose();
      _dnd = WfDnd(controller);
    }
    _configure();
  }

  @override
  void dispose() {
    controller.removeListener(_changed);
    _validateTimer?.cancel();
    _dnd.dispose();
    _ui.dispose();
    _own?.dispose();
    _root.dispose();
    super.dispose();
  }

  void _wireUi() {
    _ui.onAddRequest = _openAdd;
    _ui.onDeleteRequest = (id) => _askDelete('step', id);
    _ui.onInspect = () {
      if (_ui.layout == UiWorkflowBuilderLayout.narrow && controller.selection != null) setState(() => _sheetSnap = 1);
    };
  }

  void _applyReadOnly() {
    final ro = widget.readOnly ?? !_mayEdit;
    controller.readOnly = ro;
    if (ro && _view != UiWorkflowBuilderView.build) _view = UiWorkflowBuilderView.build;
  }

  /// Definition in; context loaded once per API.
  void _configure() {
    final c = controller;
    final d = widget.definition;
    if (d != null && !identical(d, c.def) && !identical(d, _sent)) {
      c.load(d);
      _sent = c.def;
    }
    if (!identical(c.published, widget.published)) c.published = widget.published;
    if (widget.schema != null && !identical(c.schema, widget.schema)) c.schema = widget.schema;
    if (widget.settings != null && !identical(c.settings, widget.settings)) c.settings = widget.settings;
    _applyReadOnly();
    final api = widget.api;
    if (!identical(c.api, api)) c.api = api;
    if (!identical(_loadedFor, api)) {
      _loadedFor = api;
      _loadContext(api);
      _validateSoon();
    }
  }

  /// Definition out, and a check by the engine shortly after each change.
  void _changed() {
    final d = controller.def;
    if (!identical(d, _sent) && !identical(d, widget.definition)) {
      _sent = d;
      widget.onChanged?.call(d);
    }
    if (controller.version != _lastVersion) _validateSoon();
    // A cleared selection on a phone closes the settings sheet rather than leaving it open on nothing.
    if (controller.selection == null && _ui.layout == UiWorkflowBuilderLayout.narrow) _sheetSnap = 0;
    _reportDirty();
    if (mounted) setState(() {});
  }

  Future<void> _loadContext(UiWorkflowApi? api) async {
    if (api == null) return;
    try {
      final schema = widget.schema ?? await api.schema();
      final others = await api.definitions().catchError((Object _) => <UiWfDefinitionSummary>[]);
      if (!mounted) return;
      controller.schema = schema;
      controller.others = others;
      if (others.any((o) => o.id == controller.def.id)) {
        setState(() {
          _savedOnce = true;
          _lastSaved = jsonStringify(controller.def.json);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _saveError = e is UiWfApiError ? e.message : 'Could not load the app’s record types.');
    }
    // Settings are optional for builders (only admins can read them).
    api.settings().then((s) {
      if (mounted) controller.settings = s.settings;
    }).catchError((Object _) {});
    // Whether this person may edit.
    // Future.sync: an API without me() (one that throws) leaves editing on.
    Future.sync(api.me).then((me) {
      if (!mounted) return;
      setState(() {
        _mayEdit = me.canEdit;
        _applyReadOnly();
      });
    }).catchError((Object _) {});
  }

  /// Tells the host whether leaving now would lose edits.
  void _reportDirty() {
    final d = widget.persist && controller.api != null && _dirty;
    if (d == _lastDirty) return;
    _lastDirty = d;
    final cb = widget.onDirtyChanged;
    if (cb != null) scheduleMicrotask(() => cb(d));
  }

  void _validateSoon() {
    _lastVersion = controller.version;
    _validateTimer?.cancel();
    final api = controller.api;
    // Checking needs the right to edit.
    if (api == null || controller.readOnly) return;
    final def = controller.def;
    final seq = ++_validateSeq;
    // Not notified here: this runs while building.
    scheduleMicrotask(() {
      if (mounted && seq == _validateSeq) controller.validating = true;
    });
    _validateTimer = Timer(const Duration(milliseconds: 450), () async {
      // me() may have answered "only looking" meanwhile.
      if (controller.readOnly) {
        if (mounted && seq == _validateSeq) controller.validating = false;
        return;
      }
      try {
        final problems = await api.validate(def);
        if (!mounted || seq != _validateSeq) return;
        if (_checkFailed) setState(() => _checkFailed = false);
        controller.serverProblems = problems;
        widget.onProblemsChanged?.call(problems);
      } catch (_) {
        // A failed check leaves the previous problems in place and says the workflow wasn't checked.
        if (mounted && seq == _validateSeq) setState(() => _checkFailed = true);
      } finally {
        if (mounted && seq == _validateSeq) controller.validating = false;
      }
    });
  }

  /// Saves the draft through the API (creates it the first time).
  Future<void> save() async {
    final api = controller.api;
    if (api == null || _saving) return;
    setState(() {
      _saving = true;
      _saveError = '';
    });
    final def = controller.def;
    try {
      if (_savedOnce) {
        await api.saveDraft(def);
      } else {
        await api.createDefinition(def);
      }
      if (!mounted) return;
      setState(() {
        _savedOnce = true;
        _lastSaved = jsonStringify(def.json);
      });
      _reportDirty();
      widget.onSaved?.call(def);
      final others = await api.definitions().catchError((Object _) => controller.others);
      if (mounted) controller.others = others;
    } catch (e) {
      if (mounted) setState(() => _saveError = e is UiWfApiError ? e.message : 'Saving failed.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Publishing or rolling back left the engine's draft equal to [def].
  void _synced(UiWorkflowDefinition def) {
    if (!mounted) return;
    setState(() {
      _savedOnce = true;
      _lastSaved = jsonStringify(def.json);
    });
    _reportDirty();
    widget.onSaved?.call(def);
  }

  void _setView(UiWorkflowBuilderView v) => setState(() {
    _view = v;
    _sheetSnap = 0;
  });

  // ── Adding ──────────────────────────────────────────────────────────────────────────────

  /// The list new steps go to when nothing says otherwise.
  String? _defaultList() {
    final def = controller.def;
    if (def.kind == 'automation') return 'root';
    final s = controller.selection;
    if (s?.kind == 'transition') return 'transition:${s!.id}';
    if (s?.kind == 'state') return 'onEnter:${s!.id}';
    return null;
  }

  /// Tapping a step in the side palette adds it after the selection (or at the end).
  void _addFromPalette(String type) {
    final sel = controller.selection;
    final loc = sel?.kind == 'step' ? controller.steps[sel!.id] : null;
    if (loc != null) {
      controller.addStep(type, loc.listId, loc.index + 1);
      return;
    }
    final listId = _defaultList();
    if (listId == null) return;
    controller.addStep(type, listId, listSteps(controller.def, listId)?.length ?? 0);
  }

  void _addAt(WfDropTarget t, String type) {
    controller.addStep(type, t.listId, t.index);
    _ui.inspect();
  }

  void _openAdd(WfDropTarget target) {
    if (_ui.layout == UiWorkflowBuilderLayout.narrow) {
      setState(() {
        _addTarget = target;
        _sheetSnap = 0;
      });
      return;
    }
    showUiModal<String>(
      context: context,
      title: 'Add a step',
      size: UiModalSize.lg,
      builder: (ctx) => SizedBox(height: 460, child: WfStepPicker(compact: true, onChosen: (type) => Navigator.of(ctx).pop(type))),
    ).then((type) {
      if (type != null && mounted) _addAt(target, type);
    });
  }

  // ── Deleting ────────────────────────────────────────────────────────────────────────────

  void _requestDeleteSelected() {
    if (controller.readOnly) return;
    final s = controller.selection;
    if (s == null || s.id == null) return;
    if (s.kind == 'step' || s.kind == 'state' || s.kind == 'transition') _askDelete(s.kind, s.id!);
  }

  void _askDelete(String kind, String id) {
    final def = controller.def;
    String name;
    final detail = <String>[];
    if (kind == 'step') {
      final idx = indexSteps(def);
      final loc = idx[id];
      if (loc == null) return;
      final inner = idx.values.where((l) => l.path.any((p) => p.startsWith('$id/'))).length;
      final refs = stepReferences(def, id);
      if (inner > 0) detail.add('The $inner step${inner == 1 ? '' : 's'} inside it will be deleted too.');
      if (refs.isNotEmpty) detail.add('${refs.map((r) => '“${stepName(r)}”').join(', ')} use${refs.length == 1 ? 's' : ''} its results and will show a problem.');
      // Nothing inside and nothing depends on it: delete straight away (it can be undone).
      if (detail.isEmpty) {
        controller.removeStep(id);
        return;
      }
      name = stepName(loc.step);
    } else if (kind == 'state') {
      final lc = def.lifecycle;
      final st = lc?.states.where((s) => s.id == id).firstOrNull;
      if (st == null) return;
      final n = lc!.transitions.where((t) => t.to == id || (!t.fromAny && t.from.contains(id))).length;
      name = st.label;
      detail.add(n > 0 ? 'The $n transition${n == 1 ? '' : 's'} into or out of it will be deleted too.' : 'Records in this state will be shown as out of sync.');
    } else {
      final tr = def.lifecycle?.transitions.where((x) => x.id == id).firstOrNull;
      if (tr == null) return;
      name = tr.label;
      final n = tr.steps?.length ?? 0;
      if (n > 0) detail.add('Its $n step${n == 1 ? '' : 's'} will be deleted too.');
    }
    final t = context.ui;
    showUiModal<bool>(
      context: context,
      size: UiModalSize.sm,
      title: 'Delete “$name”?',
      builder: (ctx) => DefaultTextStyle.merge(
        style: context.uiText.body.copyWith(fontSize: 14, height: 1.5, color: t.text),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, spacing: t.space2, children: [
          for (final d in detail) Text(d),
          const FbHint('You can undo this.'),
        ]),
      ),
      footerBuilder: (ctx) => Row(children: [
        UiButton(label: 'Cancel', variant: UiButtonVariant.ghost, onPressed: () => Navigator.of(ctx).pop(false)),
        const Spacer(),
        UiButton(label: 'Delete', variant: UiButtonVariant.destructive, onPressed: () => Navigator.of(ctx).pop(true)),
      ]),
    ).then((ok) {
      if (ok != true || !mounted) return;
      if (kind == 'step') {
        controller.removeStep(id);
      } else if (kind == 'state') {
        controller.removeState(id);
      } else {
        controller.removeTransition(id);
      }
      controller.selection = null;
      setState(() => _sheetSnap = 0);
    });
  }

  // ── Problems ────────────────────────────────────────────────────────────────────────────

  String _whereOf(UiWfProblem p) {
    final node = p.node;
    if (node == null) return 'Workflow';
    final step = controller.steps[node]?.step;
    if (step != null) return stepName(step);
    final lc = controller.def.lifecycle;
    return lc?.states.where((s) => s.id == node).firstOrNull?.label ?? lc?.transitions.where((t) => t.id == node).firstOrNull?.label ?? '';
  }

  void _goToProblem(UiWfProblem p) {
    final node = p.node;
    final lc = controller.def.lifecycle;
    setState(() => _view = UiWorkflowBuilderView.build);
    if (node == null) {
      final triggerish = controller.def.kind == 'automation' && RegExp('trigger|field|watch|value|signal|cron|lifecycle', caseSensitive: false).hasMatch(p.code);
      controller.selection = triggerish ? UiWfSelection.trigger : UiWfSelection.workflow;
    } else if (controller.steps.containsKey(node)) {
      controller.selection = UiWfSelection.step(node);
    } else if (lc?.states.any((s) => s.id == node) ?? false) {
      controller.selection = UiWfSelection.state(node);
    } else if (lc?.transitions.any((t) => t.id == node) ?? false) {
      controller.selection = UiWfSelection.transition(node);
    }
    _ui.inspect();
  }

  void _showProblems() {
    final t = context.ui;
    showUiModal<UiWfProblem>(
      context: context,
      title: 'Problems to fix',
      size: UiModalSize.md,
      builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 4, children: [
        for (final p in controller.problems)
          UiInteractive(
            onTap: () => Navigator.of(ctx).pop(p),
            semanticLabel: '${p.message}, ${_whereOf(p)}',
            excludeChildSemantics: true,
            pressScale: false,
            builder: (context, s) {
              final c = p.isError ? t.danger : t.warning;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: s.hovered ? 0.15 : 0.09),
                  border: Border(left: BorderSide(color: c, width: 3)),
                  borderRadius: BorderRadius.circular(t.radiusXs),
                  boxShadow: s.focused ? t.focusRing : null,
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
                  Text(p.message, style: context.uiText.body.copyWith(fontSize: 13, color: t.text)),
                  Text(_whereOf(p), style: context.uiText.body.copyWith(fontSize: 11.5, color: t.textMuted)),
                ]),
              );
            },
          ),
      ]),
    ).then((p) {
      if (p != null && mounted) _goToProblem(p);
    });
  }

  // ── Keyboard ────────────────────────────────────────────────────────────────────────────

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final typing = FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<EditableText>() != null;
    final keys = HardwareKeyboard.instance;
    final mod = keys.isControlPressed || keys.isMetaPressed;
    final k = e.logicalKey;
    if (mod && k == LogicalKeyboardKey.keyS) {
      // Only where the host turned saving on.
      if (!widget.persist || controller.api == null) return KeyEventResult.ignored;
      save();
      return KeyEventResult.handled;
    }
    if (typing) return KeyEventResult.ignored;
    if (mod && k == LogicalKeyboardKey.keyZ) {
      keys.isShiftPressed ? controller.redo() : controller.undo();
      return KeyEventResult.handled;
    }
    if (mod && k == LogicalKeyboardKey.keyY) {
      controller.redo();
      return KeyEventResult.handled;
    }
    if ((k == LogicalKeyboardKey.delete || k == LogicalKeyboardKey.backspace) && controller.selection != null && _view == UiWorkflowBuilderView.build) {
      _requestDeleteSelected();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.escape && _dnd.payload == null && controller.selection != null) {
      controller.selection = null;
      setState(() => _sheetSnap = 0);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ── Layout ──────────────────────────────────────────────────────────────────────────────

  String get _sheetTitle {
    final s = controller.selection;
    if (s == null || s.kind == 'workflow') return 'Settings';
    if (s.kind == 'trigger') return 'What starts it';
    if (s.kind == 'step') return controller.selectedStep != null ? stepName(controller.selectedStep!) : 'Step';
    if (s.kind == 'state') return controller.selectedState?.label ?? 'State';
    return controller.selectedTransition?.label ?? 'Transition';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return WfBuilderScope(
      controller: controller,
      ui: _ui,
      dnd: _dnd,
      child: Focus(
        focusNode: _root,
        onKeyEvent: _onKey,
        child: Listener(
          onPointerDown: (_) {
            if (!_root.hasFocus && FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<EditableText>() == null) _root.requestFocus();
          },
          child: LayoutBuilder(builder: (context, box) {
            final w = box.maxWidth;
            final next = w >= 1100 ? UiWorkflowBuilderLayout.wide : (w >= 720 ? UiWorkflowBuilderLayout.medium : UiWorkflowBuilderLayout.narrow);
            if (next != _ui.layout) {
              // The parts below read it while this builds; the ones that didn't rebuild are told
              // after the frame.
              _ui.setLayoutQuietly(next);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _ui.announceLayout();
              });
            }
            final narrow = next == UiWorkflowBuilderLayout.narrow;
            return Container(
              key: _dnd.rootKey,
              decoration: BoxDecoration(
                color: t.bg,
                border: narrow ? Border(top: BorderSide(color: t.borderSubtle), bottom: BorderSide(color: t.borderSubtle)) : Border.all(color: t.borderSubtle),
                borderRadius: narrow ? null : BorderRadius.circular(t.radius),
              ),
              clipBehavior: Clip.antiAlias,
              child: DefaultTextStyle.merge(
                style: context.uiText.body.copyWith(fontSize: t.fontSizeSm, color: t.text),
                child: Stack(children: [
                  Positioned.fill(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      _TopBar(state: this, layout: next),
                      if (_saveError.isNotEmpty) _banner(context),
                      Expanded(child: _main(context, next)),
                    ]),
                  ),
                  if (narrow && _view == UiWorkflowBuilderView.build)
                    UiBottomSheet(
                      snaps: const [0, 0.62, 0.94],
                      snap: _sheetSnap,
                      onSnapChanged: (s) => setState(() => _sheetSnap = s),
                      title: _sheetTitle,
                      builder: (context, scroll) => WfInspector(showHead: false, scrollController: scroll, onDeleteRequest: _requestDeleteSelected),
                    ),
                  if (narrow)
                    UiBottomSheet(
                      snaps: const [0, 0.78],
                      snap: _addTarget != null ? 1 : 0,
                      backdrop: true,
                      title: 'Add a step',
                      onSnapChanged: (s) {
                        if (s == 0) setState(() => _addTarget = null);
                      },
                      builder: (context, scroll) => Padding(
                        padding: EdgeInsets.fromLTRB(t.space3, t.space3, t.space3, 0),
                        child: WfStepPicker(
                          compact: true,
                          scrollController: scroll,
                          onChosen: (type) {
                            final target = _addTarget;
                            setState(() => _addTarget = null);
                            if (target != null) _addAt(target, type);
                          },
                        ),
                      ),
                    ),
                  _DragLayer(dnd: _dnd),
                ]),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _banner(BuildContext context) {
    final t = context.ui;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: t.space3, vertical: 6),
        decoration: BoxDecoration(color: Color.alphaBlend(t.danger.withValues(alpha: 0.12), t.surface), border: Border(bottom: BorderSide(color: t.border))),
        child: Wrap(spacing: t.space2, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(_saveError, style: context.uiText.body.copyWith(fontSize: 13, color: t.text)),
          FbLink(label: 'Dismiss', fontSize: 12, onTap: () => setState(() => _saveError = '')),
        ]),
      ),
    );
  }

  Widget _main(BuildContext context, UiWorkflowBuilderLayout layout) {
    final t = context.ui;
    switch (_view) {
      case UiWorkflowBuilderView.versions:
        return WfVersions(saved: _savedOnce, onSynced: _synced);
      case UiWorkflowBuilderView.test:
        return const WfTest();
      case UiWorkflowBuilderView.build:
        final narrow = layout == UiWorkflowBuilderLayout.narrow;
        final Widget center;
        if (controller.def.kind == 'lifecycle') {
          final idle = WfLifecycleRuns.isIdle(controller);
          center = LayoutBuilder(builder: (context, box) {
            final diagram = const WfLifecycleCanvas();
            if (idle) {
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(child: diagram),
                Container(decoration: BoxDecoration(border: Border(top: BorderSide(color: t.border))), child: const WfLifecycleRuns()),
              ]);
            }
            // The diagram gets 1.25 parts and the steps 1, each with a minimum height.
            final minDiagram = narrow ? 200.0 : 240.0;
            final total = box.maxHeight;
            var dh = narrow ? total / 2 : total * 1.25 / 2.25;
            if (total - dh < 180) dh = total - 180;
            if (dh < minDiagram) dh = minDiagram > total ? total : minDiagram;
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(height: dh, child: diagram),
              Expanded(child: Container(decoration: BoxDecoration(border: Border(top: BorderSide(color: t.border))), child: const WfLifecycleRuns())),
            ]);
          });
        } else {
          center = const WfAutomationCanvas();
        }
        if (narrow) return center;
        BoxDecoration side(bool left) => BoxDecoration(
          color: t.surface,
          border: Border(left: left ? BorderSide.none : BorderSide(color: t.borderSubtle), right: left ? BorderSide(color: t.borderSubtle) : BorderSide.none),
        );
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (layout == UiWorkflowBuilderLayout.wide)
            Container(
              width: 224,
              padding: EdgeInsets.fromLTRB(t.space2, t.space3, t.space2, 0),
              decoration: side(true),
              child: Semantics(
                container: true,
                label: 'Steps to add',
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Padding(
                    padding: EdgeInsets.only(bottom: t.space2),
                    child: Semantics(header: true, child: Text('Add a step', style: context.uiText.label.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: t.textSecondary))),
                  ),
                  Expanded(child: WfReadOnly(readOnly: controller.readOnly, child: WfStepPicker(dnd: _dnd, onChosen: _addFromPalette))),
                ]),
              ),
            ),
          Expanded(child: center),
          Container(
            width: layout == UiWorkflowBuilderLayout.wide ? 352 : 320,
            decoration: side(false),
            child: Semantics(container: true, label: 'Settings', child: WfInspector(onDeleteRequest: _requestDeleteSelected)),
          ),
        ]);
    }
  }
}

/// The drag ghost and the drop line, above everything.
class _DragLayer extends StatelessWidget {
  const _DragLayer({required this.dnd});
  final WfDnd dnd;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Positioned.fill(
      child: IgnorePointer(
        child: ListenableBuilder(
          listenable: dnd,
          builder: (context, _) {
            final p = dnd.payload;
            final children = <Widget>[];
            if (p != null) {
              final at = dnd.position;
              final drop = dnd.drop;
              if (drop?.line case final l?) {
                children.add(Positioned.fromRect(
                  rect: l,
                  child: Container(
                    decoration: BoxDecoration(
                      color: drop!.valid ? t.primary : t.danger,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: drop.valid ? [BoxShadow(color: t.primary.withValues(alpha: 0.22), spreadRadius: 3)] : null,
                    ),
                  ),
                ));
              }
              children.add(Positioned(
                left: at.dx + 12,
                top: at.dy + 8,
                child: Container(
                  height: 28,
                  padding: EdgeInsets.symmetric(horizontal: t.space3),
                  decoration: BoxDecoration(color: t.surfaceRaised, border: Border.all(color: t.primary), borderRadius: BorderRadius.circular(t.radius), boxShadow: t.shadow3),
                  child: Row(mainAxisSize: MainAxisSize.min, spacing: 6, children: [
                    UiIcon(p.icon, size: 14, color: t.text),
                    Text(p.label, style: context.uiText.label.copyWith(fontSize: 13, fontWeight: FontWeight.w500, color: t.text)),
                  ]),
                ),
              ));
            }
            children.add(Semantics(liveRegion: true, label: dnd.announcement, child: const SizedBox.shrink()));
            return Stack(children: children);
          },
        ),
      ),
    );
  }
}

/// Title, Build / Versions / Test, undo and redo, problems, Save and Publish, and the host's buttons.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.state, required this.layout});
  final UiWorkflowBuilderState state;
  final UiWorkflowBuilderLayout layout;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final store = state.controller;
    final def = store.def;
    final narrow = layout == UiWorkflowBuilderLayout.narrow;
    final errors = store.errorCount;
    final warnings = store.problems.length - errors;
    final problemsLabel = '$errors problem${errors == 1 ? '' : 's'} to fix${warnings > 0 ? ', $warnings warning${warnings == 1 ? '' : 's'}' : ''}';
    final title = def.title.isNotEmpty ? def.title : 'Untitled workflow';
    final persist = state.widget.persist && store.api != null;
    final saveState = state._saving ? 'Saving…' : (state._dirty ? 'Unsaved changes' : (state._savedOnce ? 'Saved' : ''));

    final titleButton = UiInteractive(
      onTap: () {
        store.selection = UiWfSelection.workflow;
        state._ui.inspect();
      },
      semanticLabel: '$title, workflow settings',
      excludeChildSemantics: true,
      pressScale: false,
      builder: (context, s) => Container(
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: s.hovered || s.pressed ? t.surfaceHover : null, borderRadius: BorderRadius.circular(t.radiusXs), boxShadow: s.focused ? t.focusRing : null),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(def.kind == 'lifecycle' ? 'LIFECYCLE' : 'AUTOMATION', style: context.uiText.label.copyWith(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.55, color: t.textMuted)),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.uiText.label.copyWith(fontSize: 14, fontWeight: FontWeight.w600, color: t.text)),
        ]),
      ),
    );

    final views = UiSegmented<UiWorkflowBuilderView>(
      label: 'View',
      size: UiSize.sm,
      value: state._view,
      options: [
        const UiSegmentedOption(value: UiWorkflowBuilderView.build, label: 'Build'),
        // Publishing and test runs need the right to edit.
        if (store.api != null && !store.readOnly) ...const [
          UiSegmentedOption(value: UiWorkflowBuilderView.versions, label: 'Versions'),
          UiSegmentedOption(value: UiWorkflowBuilderView.test, label: 'Test'),
        ],
      ],
      onChanged: state._setView,
    );

    final tools = Wrap(crossAxisAlignment: WrapCrossAlignment.center, alignment: WrapAlignment.end, spacing: 4, runSpacing: 4, children: [
      FbIconButton(icon: WfIcons.undo02, label: 'Undo', onPressed: store.canUndo ? store.undo : null),
      FbIconButton(icon: WfIcons.redo02, label: 'Redo', onPressed: store.canRedo ? store.redo : null),
      if (store.readOnly)
        // Checking needs the right to edit; someone only looking gets no status.
        const SizedBox.shrink()
      else if (errors > 0)
        UiInteractive(
          onTap: state._showProblems,
          semanticLabel: problemsLabel,
          excludeChildSemantics: true,
          pressScale: false,
          builder: (context, s) => Container(
            height: 24,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(color: t.danger.withValues(alpha: s.hovered ? 0.2 : 0.14), borderRadius: BorderRadius.circular(12), boxShadow: s.focused ? t.focusRing : null),
            child: Row(mainAxisSize: MainAxisSize.min, spacing: 4, children: [
              UiIcon(WfIcons.alert02, size: 13, strokeWidth: 1.9, color: t.danger),
              Text('$errors', style: context.uiText.label.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: t.danger)),
            ]),
          ),
        )
      else if (state._checkFailed)
        Semantics(
          label: 'Not checked: the engine could not check this workflow, so problems may be missing.',
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(mainAxisSize: MainAxisSize.min, spacing: 3, children: [
                UiIcon(WfIcons.alert02, size: 13, strokeWidth: 1.9, color: t.warning),
                if (!narrow) Text('Not checked', style: context.uiText.label.copyWith(fontSize: 12, fontWeight: FontWeight.w500, color: t.warning)),
              ]),
            ),
          ),
        )
      else if (store.api != null && !store.validating)
        UiInteractive(
          onTap: warnings > 0 ? state._showProblems : null,
          enabled: true,
          semanticLabel: warnings > 0 ? 'Ready, $warnings warning${warnings == 1 ? '' : 's'} (nothing blocks publishing)' : 'Ready, no problems found',
          excludeChildSemantics: true,
          pressScale: false,
          padTouchTarget: warnings > 0,
          cursor: warnings > 0 ? SystemMouseCursors.click : MouseCursor.defer,
          builder: (context, s) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(t.radiusXs), boxShadow: s.focused ? t.focusRing : null),
            child: Row(mainAxisSize: MainAxisSize.min, spacing: 3, children: [
              UiIcon(WfIcons.tick02, size: 13, strokeWidth: 2, color: t.success),
              if (!narrow) Text('Ready', style: context.uiText.label.copyWith(fontSize: 12, fontWeight: FontWeight.w500, color: t.success)),
            ]),
          ),
        ),
      if (store.readOnly)
        Semantics(
          label: 'View only: you can look at this workflow but not change it.',
          child: ExcludeSemantics(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: t.surfaceHover, borderRadius: BorderRadius.circular(10)),
              child: Text('View only', style: context.uiText.body.copyWith(fontSize: 12, color: t.textSecondary)),
            ),
          ),
        )
      else if (persist) ...[
        if (!narrow && saveState.isNotEmpty)
          Semantics(liveRegion: true, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text(saveState, style: context.uiText.body.copyWith(fontSize: 12, color: t.textMuted)))),
        UiButton(label: 'Save', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: state._saving || !state._dirty ? null : state.save),
        UiButton(label: 'Publish…', size: UiSize.sm, onPressed: () => state._setView(UiWorkflowBuilderView.versions)),
      ],
      ?state.widget.actions,
    ]);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: t.space3, vertical: 6),
      decoration: BoxDecoration(color: t.surface, border: Border(bottom: BorderSide(color: t.borderSubtle))),
      child: narrow
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 6, children: [
              LayoutBuilder(builder: (context, box) => Row(children: [
                Expanded(child: Align(alignment: Alignment.centerLeft, child: titleButton)),
                ConstrainedBox(constraints: BoxConstraints(maxWidth: box.maxWidth * 0.66), child: tools),
              ])),
              views,
            ])
          : Row(spacing: t.space3, children: [
              Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: titleButton)),
              views,
              Expanded(flex: 3, child: Align(alignment: Alignment.centerRight, child: tools)),
            ]),
    );
  }
}
