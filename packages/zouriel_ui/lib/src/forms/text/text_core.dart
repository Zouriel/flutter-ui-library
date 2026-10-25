import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerDeviceKind, TapDragUpDetails;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/interactive.dart';
import '../../core/types.dart';
import '../../theme/theme.dart';
import 'form_field.dart';

/// The focus ring an invalid field shows: the web `0 0 0 2px bg, 0 0 0 4px danger`.
List<BoxShadow> uiDangerRing(UiTokens t) => [
      // Flutter paints the last shadow on top: the outer ring first, the 2px gap over it.
      UiRingShadow(color: t.danger, spread: 4),
      UiRingShadow(color: t.bg, spread: 2),
    ];

/// Text size for a control size: sm / md / lg font tokens.
double uiFieldFontSize(UiTokens t, UiSize size) =>
    switch (size) { UiSize.sm => t.fontSizeSm, UiSize.md => t.fontSizeMd, UiSize.lg => t.fontSizeLg, UiSize.xl => t.fontSizeLg };

/// The text style fields type in: the theme body font at the size's font size.
TextStyle uiFieldTextStyle(BuildContext context, UiSize size) {
  final t = context.ui;
  return context.uiText.body.copyWith(fontSize: uiFieldFontSize(t, size), height: 1.25, color: t.text);
}

/// The bordered box every text-like field draws (the web `.ui-input`): surface fill, control
/// border, primary border plus the focus ring while focused, danger border when invalid.
///
/// [height] is the visual height. On touch platforms the box keeps that look but the widget lays
/// out at least [uiMinTouchTarget] tall, with the box centred, so the text area and any buttons in
/// the [child] row get full-height touch targets. With [height] null the box hugs its content
/// (multi-line fields).
class UiFieldFrame extends StatelessWidget {
  const UiFieldFrame({
    super.key,
    required this.child,
    this.height,
    this.focused = false,
    this.active = false,
    this.invalid = false,
    this.enabled = true,
    this.radius,
    this.borderRadius,
    this.padding = EdgeInsets.zero,
    this.borderColor,
  });

  final Widget child;
  final double? height;
  final bool focused;

  /// Primary border without the ring: the field's popover is open after a tap.
  final bool active;
  final bool invalid;
  final bool enabled;

  /// Rounded corners; defaults to the library config.
  final bool? radius;

  /// A specific corner radius (the search field is a pill).
  final double? borderRadius;
  final EdgeInsetsGeometry padding;

  /// Overrides the resting border colour.
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final rounded = radius ?? theme.config.radius;
    final r = rounded ? (borderRadius ?? t.radius) : 0.0;
    final border = invalid ? t.danger : focused || active ? t.primary : (borderColor ?? t.controlBorder);
    final ring = focused ? (invalid ? uiDangerRing(t) : t.focusRing) : const <BoxShadow>[];
    final animate = context.uiAnimate;
    final deco = BoxDecoration(
      color: t.surface,
      border: Border.all(color: border),
      borderRadius: BorderRadius.circular(r),
      boxShadow: ring,
    );
    Widget box({Widget? child, double? h}) => AnimatedContainer(
          duration: animate ? t.motionBase : Duration.zero,
          curve: t.easeStandard,
          height: h,
          decoration: deco,
          child: child,
        );

    Widget result;
    if (height == null) {
      result = box(child: Padding(padding: padding, child: child));
    } else {
      // Large text grows the box rather than clipping it (up to 2x and beyond).
      final scale = MediaQuery.textScalerOf(context).scale(t.fontSizeMd) / t.fontSizeMd;
      final h = scale > 1 ? height! * scale : height!;
      final outer = uiTouchPlatform(context) ? math.max(h, uiMinTouchTarget) : h;
      result = SizedBox(
        height: outer,
        child: Stack(children: [
          Positioned(left: 0, right: 0, top: (outer - h) / 2, height: h, child: box()),
          Positioned.fill(child: Padding(padding: padding, child: child)),
        ]),
      );
    }
    return Opacity(opacity: enabled ? 1 : 0.5, child: result);
  }
}

/// A small icon button inside a field (clear, show/hide, steppers): a [visual] circle or square that
/// lights on hover, inside a hit area of [hitWidth] x the field's height (48dp wide on touch).
class UiFieldButton extends StatelessWidget {
  const UiFieldButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.visual = 24,
    this.hitWidth,
    this.round = false,
    this.focusable = false,
    this.enabled = true,
  });

  final String label;
  final Widget icon;
  final VoidCallback? onTap;
  final double visual;
  final double? hitWidth;
  final bool round;

  /// In the tab order. The web keeps most field buttons out of it (tabindex -1).
  final bool focusable;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final touch = uiTouchPlatform(context);
    final w = hitWidth ?? (touch ? uiMinTouchTarget : visual);
    final button = UiInteractive(
      onTap: onTap,
      enabled: enabled,
      semanticLabel: label,
      excludeChildSemantics: true,
      padTouchTarget: false,
      builder: (context, s) => SizedBox(
        width: w,
        child: Center(
          child: AnimatedContainer(
            duration: t.motionFast,
            width: visual,
            height: visual,
            decoration: BoxDecoration(
              color: s.hovered || s.pressed ? t.surfaceHover : null,
              shape: round ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: round ? null : BorderRadius.circular(context.uiTheme.radius(t.radiusXs)),
              boxShadow: s.focused ? t.focusRing : const [],
            ),
            child: IconTheme.merge(
              data: IconThemeData(size: math.min(16, visual - 6), color: t.icon ?? (s.hovered || s.pressed ? t.text : t.textMuted)),
              child: Center(child: icon),
            ),
          ),
        ),
      ),
    );
    return focusable ? button : ExcludeFocus(child: button);
  }
}

/// Shared state for controls that edit text: an owned or given controller and focus node, kept in
/// sync with a controlled `value`.
mixin UiTextControllerMixin<W extends StatefulWidget> on State<W> {
  TextEditingController? _ownController;
  FocusNode? _ownFocus;

  TextEditingController? get externalController;
  FocusNode? get externalFocusNode;
  String? get controlledValue;

  TextEditingController get controller => externalController ?? (_ownController ??= TextEditingController(text: controlledValue ?? ''));
  FocusNode get focusNode => externalFocusNode ?? (_ownFocus ??= FocusNode());

  /// Call from didUpdateWidget: writes a new value from outside into the field.
  void syncControlledValue() {
    final v = controlledValue;
    if (v != null && v != controller.text) {
      controller.value = TextEditingValue(text: v, selection: TextSelection.collapsed(offset: v.length));
    }
  }

  void disposeTextController() {
    _ownController?.dispose();
    _ownFocus?.dispose();
  }
}

/// The library's text editor: an [EditableText] with themed caret and selection, a placeholder,
/// touch selection (handles, magnifier-free) with a themed copy/paste toolbar, tap/long-press/drag
/// gestures, and one text-field semantics node named by [semanticLabel] (or the surrounding
/// [UiFormField]'s label).
///
/// Field widgets put it inside a [UiFieldFrame]; the gestures cover the whole [frame] so a tap on
/// the padding still focuses the text.
class UiTextEditor extends StatefulWidget {
  const UiTextEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.style,
    this.placeholder,
    this.placeholderStyle,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.minLines,
    this.autofillHints,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.textAlign = TextAlign.start,
    this.semanticLabel,
    this.autofocus = false,
    this.onKeyEvent,
    this.selectAllOnFocus = false,
    this.showCursor,
    this.scrollPadding = const EdgeInsets.all(20),
    this.semanticsMaxLength,
    this.onTap,
    this.padding = EdgeInsets.zero,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final TextStyle style;
  final String? placeholder;
  final TextStyle? placeholderStyle;
  final bool enabled;
  final bool readOnly;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int? maxLines;
  final int? minLines;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;
  final TextAlign textAlign;
  final String? semanticLabel;
  final bool autofocus;

  /// Sees keys before the text editing shortcuts do (arrow keys in a combobox, Backspace in OTP).
  final KeyEventResult Function(FocusNode node, KeyEvent event)? onKeyEvent;
  final bool selectAllOnFocus;
  final bool? showCursor;
  final EdgeInsets scrollPadding;
  final int? semanticsMaxLength;

  /// Called after a tap in the text has placed the caret (a combobox reopens its list).
  final VoidCallback? onTap;

  /// Space around the text inside the editor's own tap and semantics area, so a multi-line field's
  /// node covers its whole box rather than only the lines of text.
  final EdgeInsetsGeometry padding;

  @override
  State<UiTextEditor> createState() => _UiTextEditorState();
}

class _UiTextEditorState extends State<UiTextEditor> implements TextSelectionGestureDetectorBuilderDelegate {
  @override
  final GlobalKey<EditableTextState> editableTextKey = GlobalKey<EditableTextState>();

  late final TextSelectionGestureDetectorBuilder _gestures = _EditorGestures(this);
  UiFieldLink? _link;

  @override
  bool get forcePressEnabled => false;

  @override
  bool get selectionEnabled => widget.enabled;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_focusChanged);
    widget.controller.addListener(_textChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final link = UiFieldScope.maybeOf(context)?.link;
    if (link != _link) {
      _link?.detach(widget.focusNode);
      _link = link;
      _link?.attach(widget.focusNode);
    }
  }

  @override
  void didUpdateWidget(UiTextEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_focusChanged);
      widget.focusNode.addListener(_focusChanged);
      _link?.detach(oldWidget.focusNode);
      _link?.attach(widget.focusNode);
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_textChanged);
      widget.controller.addListener(_textChanged);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_focusChanged);
    widget.controller.removeListener(_textChanged);
    _link?.detach(widget.focusNode);
    super.dispose();
  }

  bool _wasFocused = false;

  void _focusChanged() {
    final f = widget.focusNode.hasFocus;
    if (f && !_wasFocused && widget.selectAllOnFocus) {
      // Selected at once so the first typed character replaces the value (see UiNumberInput).
      final text = widget.controller.text;
      widget.controller.selection = TextSelection(baseOffset: 0, extentOffset: text.length);
    }
    _wasFocused = f;
    if (mounted) setState(() {});
  }

  void _textChanged() {
    if (mounted) setState(() {});
  }

  void _requestKeyboard() {
    if (!widget.focusNode.hasFocus) {
      widget.focusNode.requestFocus();
    } else {
      editableTextKey.currentState?.requestKeyboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final scope = UiFieldScope.maybeOf(context);
    final label = widget.semanticLabel ?? scope?.label;
    final focused = widget.focusNode.hasFocus;
    final selection = t.primary.withValues(alpha: 0.35);
    final empty = widget.controller.text.isEmpty;
    final multiline = widget.maxLines != 1;

    Widget editable = EditableText(
      key: editableTextKey,
      controller: widget.controller,
      focusNode: widget.focusNode,
      readOnly: widget.readOnly || !widget.enabled,
      obscureText: widget.obscureText,
      style: widget.style,
      cursorColor: t.primary,
      backgroundCursorColor: t.textMuted,
      selectionColor: focused ? selection : null,
      selectionControls: widget.enabled ? uiTextSelectionControls : null,
      contextMenuBuilder: widget.enabled ? uiTextContextMenu : null,
      keyboardType: widget.keyboardType ?? (multiline ? TextInputType.multiline : TextInputType.text),
      textInputAction: widget.textInputAction ?? (multiline ? TextInputAction.newline : TextInputAction.done),
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      minLines: widget.minLines,
      autofillHints: widget.autofillHints,
      inputFormatters: widget.inputFormatters,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      onEditingComplete: widget.onEditingComplete,
      textAlign: widget.textAlign,
      autofocus: widget.autofocus,
      showCursor: widget.showCursor,
      cursorWidth: 1.5,
      cursorOpacityAnimates: context.uiAnimate,
      rendererIgnoresPointer: true,
      mouseCursor: MouseCursor.defer,
      scrollPadding: widget.scrollPadding,
      enableInteractiveSelection: widget.enabled,
      showSelectionHandles: _handles,
      onSelectionChanged: _onSelectionChanged,
      onTapOutside: (e) {
        // Mouse clicks elsewhere blur the field as on the web; touch scrolls keep it focused.
        if (e.kind == PointerDeviceKind.mouse) widget.focusNode.unfocus();
      },
    );

    if (widget.placeholder != null && widget.placeholder!.isNotEmpty) {
      editable = Stack(
        alignment: AlignmentDirectional.topStart,
        children: [
          if (empty)
            Positioned.fill(
              child: ExcludeSemantics(
                child: IgnorePointer(
                  child: Text(
                    widget.placeholder!,
                    // inherit: false, so Text does not merge it into the ambient DefaultTextStyle: that
                    // merge re-applies the library font package to an already resolved family and an app
                    // font ('Faruma' became 'packages/zouriel_ui/Faruma', Poppins doubly prefixed).
                    style: (widget.placeholderStyle ?? widget.style.copyWith(color: t.textMuted)).copyWith(inherit: false),
                    maxLines: multiline ? null : 1,
                    overflow: multiline ? null : TextOverflow.ellipsis,
                    textAlign: widget.textAlign,
                  ),
                ),
              ),
            ),
          editable,
        ],
      );
    }

    if (widget.onKeyEvent != null) {
      editable = Focus(canRequestFocus: false, skipTraversal: true, onKeyEvent: widget.onKeyEvent, child: editable);
    }

    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.text : SystemMouseCursors.forbidden,
      child: TextFieldTapRegion(
        child: IgnorePointer(
          ignoring: !widget.enabled,
          // One node for the field: the editable's own text-field node merges into this one, which
          // spans the whole (touch-height) text area and carries the name and tap action.
          child: MergeSemantics(child: Semantics(
            enabled: widget.enabled,
            label: label,
            hint: empty ? widget.placeholder : null,
            isRequired: scope?.required == true ? true : null,
            maxValueLength: widget.semanticsMaxLength,
            onTap: widget.enabled && !widget.readOnly
                ? () {
                    if (!widget.controller.selection.isValid) {
                      widget.controller.selection = TextSelection.collapsed(offset: widget.controller.text.length);
                    }
                    _requestKeyboard();
                  }
                : null,
            child: _gestures.buildGestureDetector(
              behavior: HitTestBehavior.translucent,
              child: Padding(
                padding: widget.padding,
                child: Align(alignment: AlignmentDirectional.centerStart, heightFactor: multiline ? 1 : null, child: editable),
              ),
            ),
          )),
        ),
      ),
    );
  }

  // Selection handles are for touch: a mouse click or the keyboard never shows them (as TextField).
  bool _handles = false;

  bool _shouldShowHandles(SelectionChangedCause? cause) {
    if (!_gestures.shouldShowSelectionToolbar || cause == SelectionChangedCause.keyboard || !widget.enabled) return false;
    if (widget.readOnly && widget.controller.selection.isCollapsed) return false;
    if (cause == SelectionChangedCause.longPress || cause == SelectionChangedCause.stylusHandwriting) return true;
    return widget.controller.text.isNotEmpty;
  }

  void _onSelectionChanged(TextSelection selection, SelectionChangedCause? cause) {
    final handles = _shouldShowHandles(cause);
    if (handles != _handles) setState(() => _handles = handles);
    // Show the handles after touch interactions, as text fields do on Android.
    final state = editableTextKey.currentState;
    if (state == null) return;
    if (cause == SelectionChangedCause.longPress || cause == SelectionChangedCause.drag) {
      state.bringIntoView(selection.extent);
    }
    if (cause == SelectionChangedCause.keyboard) state.hideToolbar(false);
  }
}

class _EditorGestures extends TextSelectionGestureDetectorBuilder {
  _EditorGestures(this._state) : super(delegate: _state);
  final _UiTextEditorState _state;

  @override
  void onSingleTapUp(TapDragUpDetails details) {
    super.onSingleTapUp(details);
    _state.widget.onTap?.call();
  }
}

// ---------------------------------------------------------------------------------------------
// Touch selection: handles and the copy/paste menu, drawn with the theme instead of Material's.

const double _kHandle = 20;

/// Selection handles in the theme's primary colour: a circle with one square corner pointing at
/// the text, like Android's.
class UiTextSelectionControls extends TextSelectionControls with TextSelectionHandleControls {
  @override
  Size getHandleSize(double textLineHeight) => const Size(_kHandle, _kHandle);

  @override
  Widget buildHandle(BuildContext context, TextSelectionHandleType type, double textLineHeight, [VoidCallback? onTap]) {
    final color = context.ui.primary;
    final handle = SizedBox.square(
      dimension: _kHandle,
      child: CustomPaint(
        painter: _HandlePainter(color),
        child: GestureDetector(onTap: onTap, behavior: HitTestBehavior.translucent),
      ),
    );
    return switch (type) {
      TextSelectionHandleType.left => Transform.rotate(angle: math.pi / 2, child: handle),
      TextSelectionHandleType.right => handle,
      TextSelectionHandleType.collapsed => Transform.rotate(angle: math.pi / 4, child: handle),
    };
  }

  @override
  Offset getHandleAnchor(TextSelectionHandleType type, double textLineHeight) => switch (type) {
        TextSelectionHandleType.collapsed => const Offset(_kHandle / 2, -4),
        TextSelectionHandleType.left => const Offset(_kHandle, 0),
        TextSelectionHandleType.right => Offset.zero,
      };
}

/// Shared instance used by every library text field.
final UiTextSelectionControls uiTextSelectionControls = UiTextSelectionControls();

class _HandlePainter extends CustomPainter {
  _HandlePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final r = size.width / 2;
    canvas.drawCircle(Offset(r, r), r, paint);
    canvas.drawRect(Rect.fromLTWH(0, 0, r, r), paint);
  }

  @override
  bool shouldRepaint(_HandlePainter old) => old.color != color;
}

String _menuLabel(BuildContext context, ContextMenuButtonItem item) => item.label ?? switch (item.type) {
      ContextMenuButtonType.cut => context.uiStrings.cut,
      ContextMenuButtonType.copy => context.uiStrings.copy,
      ContextMenuButtonType.paste => context.uiStrings.paste,
      ContextMenuButtonType.selectAll => context.uiStrings.selectAll,
      ContextMenuButtonType.delete => context.uiStrings.delete,
      ContextMenuButtonType.lookUp => context.uiStrings.lookUp,
      ContextMenuButtonType.searchWeb => context.uiStrings.searchWeb,
      ContextMenuButtonType.share => context.uiStrings.share,
      ContextMenuButtonType.liveTextInput => context.uiStrings.scanText,
      ContextMenuButtonType.custom => '',
    };

/// The copy / cut / paste / select-all menu shown over a selection, as a raised themed bar.
Widget uiTextContextMenu(BuildContext context, EditableTextState state) {
  final items = state.contextMenuButtonItems.where((i) => _menuLabel(context, i).isNotEmpty).toList();
  if (items.isEmpty) return const SizedBox.shrink();
  return UiTextContextMenu(anchors: state.contextMenuAnchors, items: items);
}

/// The themed text selection menu, positioned above the selection (below when there's no room).
class UiTextContextMenu extends StatelessWidget {
  const UiTextContextMenu({super.key, required this.anchors, required this.items});

  final TextSelectionToolbarAnchors anchors;
  final List<ContextMenuButtonItem> items;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final mq = MediaQuery.of(context);
    final top = mq.padding.top + 8;
    final above = anchors.primaryAnchor - const Offset(0, 8);
    final below = (anchors.secondaryAnchor ?? anchors.primaryAnchor) + const Offset(0, 20);
    final bar = Container(
      padding: EdgeInsets.all(t.space1),
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(context.uiTheme.radius()),
        boxShadow: t.shadow2,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in items)
            UiInteractive(
              onTap: item.onPressed,
              semanticLabel: _menuLabel(context, item),
              excludeChildSemantics: true,
              builder: (context, s) => Container(
                height: uiTouchPlatform(context) ? 40 : t.sizeMd,
                padding: EdgeInsets.symmetric(horizontal: t.space3),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: s.hovered || s.pressed ? t.elevatedHover : null,
                  borderRadius: BorderRadius.circular(context.uiTheme.radius(t.radiusXs)),
                  boxShadow: s.focused ? t.focusRing : const [],
                ),
                child: Text(_menuLabel(context, item), style: context.uiText.body.copyWith(fontSize: t.fontSizeSm, fontWeight: FontWeight.w500)),
              ),
            ),
        ],
      ),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(8, top, 8, 8),
      child: CustomSingleChildLayout(
        delegate: TextSelectionToolbarLayoutDelegate(anchorAbove: above - Offset(8, top), anchorBelow: below - Offset(8, top)),
        child: bar,
      ),
    );
  }
}

/// Runs [fn] after the current frame (for notifying listeners from build-time code).
void uiAfterFrame(VoidCallback fn) {
  if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
    fn();
  } else {
    SchedulerBinding.instance.addPostFrameCallback((_) => fn());
  }
}
