import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../button/button.dart';
import '../../core/types.dart';
import '../../dialog/confirm.dart';
import '../../theme/theme.dart';
import '../engine/definition.dart';
import '../engine/revisions.dart';
import '../engine/schema.dart';
import 'builder_bits.dart';

String _when(String iso) {
  final d = DateTime.tryParse(iso);
  return d == null ? iso : DateFormat.yMMMd().add_jm().format(d.toLocal());
}

String _reason(Object e) {
  final m = (e is UiFbRevisionError ? e.message : e.toString()).replaceFirst(RegExp(r'^(Exception|Bad state|Error): '), '');
  return m;
}

/// `ui-fb-revisions`: the published versions of a form, newest first. Each can be opened to see what
/// changed, compared with the draft, or restored: restoring replaces the draft with that version's
/// content (nothing goes live until the form is published again). [onRestore] carries the new draft.
///
/// The [store] may answer at once or later; a slow or failing store shows a loading or error line.
/// The list loads again when [formId] or [store] changes.
class UiFbRevisionPanel extends StatefulWidget {
  const UiFbRevisionPanel({super.key, required this.store, required this.formId, required this.current, this.onRestore});

  final UiFbRevisionStore store;
  final String formId;

  /// The draft being edited, for "Compare with draft" and to carry over saved answers on restore.
  final UiFormDefinition current;

  /// The new draft after a restore.
  final ValueChanged<UiFormDefinition>? onRestore;

  @override
  State<UiFbRevisionPanel> createState() => _UiFbRevisionPanelState();
}

class _UiFbRevisionPanelState extends State<UiFbRevisionPanel> {
  List<UiFbRevision> _items = const [];
  bool _loading = true;
  String _error = '';
  String _restoreError = '';
  bool _busy = false;
  int? _open;
  int? _compare;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(UiFbRevisionPanel old) {
    super.didUpdateWidget(old);
    if (old.formId != widget.formId || !identical(old.store, widget.store)) _load();
  }

  void _load() {
    final run = ++_seq;
    _open = null;
    _compare = null;
    _restoreError = '';
    FutureOr<List<UiFbRevision>> result;
    try {
      result = widget.store.listRevisions(widget.formId);
    } catch (e) {
      _fail(e);
      return;
    }
    if (result is Future<List<UiFbRevision>>) {
      _loading = true;
      _error = '';
      result.then((r) {
        if (run == _seq && mounted) setState(() => _set(r));
      }, onError: (Object e) {
        if (run == _seq && mounted) setState(() => _fail(e));
      });
    } else {
      _set(result);
    }
  }

  void _set(List<UiFbRevision> list) {
    _items = [...list]..sort((a, b) => b.revision.compareTo(a.revision));
    _loading = false;
    _error = '';
  }

  void _fail(Object e) {
    _loading = false;
    final reason = _reason(e);
    _error = 'The versions couldn’t be loaded${reason.isNotEmpty ? ': $reason' : '.'}';
  }

  /// What version [r] changed: the stored diff, else computed against the version before it. Null for the first version.
  List<String>? _changes(UiFbRevision r, int index) {
    if (r.diff != null) return r.diff!.summary;
    final before = index + 1 < _items.length ? _items[index + 1] : null;
    return before == null ? null : diffDefinitions(before.definition, r.definition).summary;
  }

  List<String> _vsDraft(UiFbRevision r) => diffDefinitions(r.definition, widget.current).summary;

  Future<void> _ask(UiFbRevision r) async {
    setState(() => _restoreError = '');
    final ok = await showUiConfirm(
      context: context,
      title: 'Restore version ${r.revision}?',
      message:
          'The draft is replaced by version ${r.revision}. Questions you added since then are archived, not deleted, so answers already saved are kept. Nothing goes live until you publish.',
      confirmLabel: 'Restore this version',
    );
    if (ok == true && mounted) await _restore(r);
  }

  Future<void> _restore(UiFbRevision r) async {
    setState(() => _busy = true);
    try {
      final draft = await widget.store.rollback(widget.formId, r.revision, widget.current);
      widget.onRestore?.call(draft);
    } catch (e) {
      final reason = _reason(e);
      if (mounted) setState(() => _restoreError = 'Version ${r.revision} couldn’t be restored${reason.isNotEmpty ? ': $reason' : '.'}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _note(BuildContext context, String text, {bool bad = false}) {
    final t = context.ui;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: EdgeInsets.all(t.space3),
        decoration: BoxDecoration(
          color: bad ? Color.alphaBlend(t.danger.withValues(alpha: 0.12), t.surface) : t.surfaceSubtle,
          borderRadius: BorderRadius.circular(t.radiusSm),
        ),
        child: Text(text, style: context.uiText.body.copyWith(fontSize: t.fontSizeSm, color: bad ? t.text : t.textSecondary)),
      ),
    );
  }

  Widget _detail(BuildContext context, String label, List<String>? lines, String empty) {
    final t = context.ui;
    final small = context.uiText.body.copyWith(fontSize: 12, color: t.textMuted);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: t.space3, vertical: t.space2),
      decoration: BoxDecoration(color: t.surfaceSubtle, borderRadius: BorderRadius.circular(t.radiusSm)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: t.space1,
        children: [
          Text(label, style: small),
          if (lines == null || lines.isEmpty)
            Text(empty, style: small)
          else
            for (final l in lines)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: t.space2,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: DecoratedBox(decoration: BoxDecoration(color: t.textMuted, shape: BoxShape.circle), child: const SizedBox(width: 4, height: 4)),
                  ),
                  Expanded(child: Text(l, style: context.uiText.body.copyWith(fontSize: t.fontSizeSm))),
                ],
              ),
        ],
      ),
    );
  }

  Widget _item(BuildContext context, UiFbRevision r, int i) {
    final t = context.ui;
    final muted = context.uiText.body.copyWith(fontSize: 12, color: t.textMuted);
    final opened = _open == r.revision, comparing = _compare == r.revision;
    final by = (r.publishedBy ?? '').isEmpty ? '' : ' · ${r.publishedBy}';
    return Container(
      padding: EdgeInsets.all(t.space3),
      decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radius)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: t.space2,
        children: [
          Wrap(
            spacing: t.space2,
            runSpacing: t.space1,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Version ${r.revision}', style: context.uiText.body.copyWith(fontWeight: FontWeight.w600)),
              if (i == 0) const FbChip('Latest', tone: FbTone.ok),
              Text('${_when(r.publishedAt)}$by', style: muted),
            ],
          ),
          if ((r.summary ?? '').isNotEmpty) Text(r.summary!, style: context.uiText.body.copyWith(fontSize: t.fontSizeSm, color: t.textSecondary)),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: t.space1,
                  runSpacing: t.space1,
                  children: [
                    UiButton(
                      label: opened ? 'Hide what changed' : 'What changed',
                      size: UiSize.sm,
                      variant: UiButtonVariant.ghost,
                      onPressed: () => setState(() => _open = opened ? null : r.revision),
                    ),
                    UiButton(
                      label: comparing ? 'Hide comparison' : 'Compare with draft',
                      size: UiSize.sm,
                      variant: UiButtonVariant.ghost,
                      onPressed: () => setState(() => _compare = comparing ? null : r.revision),
                    ),
                  ],
                ),
              ),
              UiButton(label: 'Restore', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: _busy ? null : () => _ask(r)),
            ],
          ),
          if (opened)
            () {
              final lines = _changes(r, i);
              return _detail(context, 'Changed in version ${r.revision}', lines, lines == null ? 'This was the first version.' : 'No changes to the questions.');
            }(),
          if (comparing) _detail(context, 'What the draft has changed since version ${r.revision}', _vsDraft(r), 'The draft is the same as this version.'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Version history',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: t.space3,
        children: [
          if (_loading)
            _note(context, 'Loading versions…')
          else if (_error.isNotEmpty)
            _note(context, _error, bad: true)
          else if (_items.isEmpty)
            _note(context, 'Nothing has been published yet. Each time you publish, the version is saved here so you can look back or restore it.')
          else
            for (var i = 0; i < _items.length; i++) _item(context, _items[i], i),
          if (_restoreError.isNotEmpty) _note(context, _restoreError, bad: true),
        ],
      ),
    );
  }
}
