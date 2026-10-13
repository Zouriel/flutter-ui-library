import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../theme/theme.dart';

/// An undecorated single text run on [EditableText] with the platform's tap, double-tap and
/// long-press selection gestures, a placeholder, and an accessible name. The choice-area fields
/// (hex, chip and token inputs) draw their own box around it. Not exported.
class UiBareInput extends StatefulWidget {
  const UiBareInput({
    super.key,
    required this.controller,
    required this.focusNode,
    this.style,
    this.placeholder,
    this.enabled = true,
    this.maxLines = 1,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.inputFormatters,
    this.semanticLabel,
    this.textAlign = TextAlign.start,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final TextStyle? style;
  final String? placeholder;
  final bool enabled;
  final int? maxLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final String? semanticLabel;
  final TextAlign textAlign;

  @override
  State<UiBareInput> createState() => UiBareInputState();
}

class UiBareInputState extends State<UiBareInput> implements TextSelectionGestureDetectorBuilderDelegate {
  @override
  final GlobalKey<EditableTextState> editableTextKey = GlobalKey<EditableTextState>();
  @override
  bool get forcePressEnabled => false;
  @override
  bool get selectionEnabled => widget.enabled;

  late final _gestures = TextSelectionGestureDetectorBuilder(delegate: this);

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final style = widget.style ?? context.uiText.body.copyWith(color: t.text);
    final editable = EditableText(
      key: editableTextKey,
      controller: widget.controller,
      focusNode: widget.focusNode,
      readOnly: !widget.enabled,
      style: style,
      textAlign: widget.textAlign,
      cursorColor: t.primary,
      backgroundCursorColor: t.textMuted,
      selectionColor: t.primary.withValues(alpha: 0.3),
      maxLines: widget.maxLines,
      keyboardType: widget.keyboardType ?? (widget.maxLines == 1 ? TextInputType.text : TextInputType.multiline),
      textInputAction: widget.textInputAction,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      // Keep focus after Enter: the chip input adds a chip and carries on typing.
      onEditingComplete: () {},
      inputFormatters: widget.inputFormatters,
      rendererIgnoresPointer: true,
      enableInteractiveSelection: widget.enabled,
      showSelectionHandles: false,
      mouseCursor: widget.enabled ? SystemMouseCursors.text : SystemMouseCursors.forbidden,
    );
    return Semantics(
      label: widget.semanticLabel,
      child: Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [
          if (widget.placeholder != null)
            ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) => widget.controller.text.isEmpty
                  ? IgnorePointer(
                      child: ExcludeSemantics(
                        child: Text(widget.placeholder!, maxLines: 1, overflow: TextOverflow.ellipsis, style: style.copyWith(color: t.textMuted)),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          _gestures.buildGestureDetector(behavior: HitTestBehavior.translucent, child: editable),
        ],
      ),
    );
  }
}
