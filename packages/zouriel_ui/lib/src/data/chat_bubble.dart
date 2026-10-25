import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' show Bidi;

import '../theme/theme.dart';

/// `ui-chat-bubble`: one message in a conversation. The person's own ([mine]) sit at the inline end
/// in the primary colour; the other side's at the inline start on the raised surface. Both follow
/// the text direction (in RTL, mine sit on the left). [meta] is a small line under the text: the
/// time, a read status. The corner nearest the speaker is tucked in.
///
/// [mineSide] [UiChatBubbleSide.right] (0.46.3) keeps yours on the physical right and theirs on the
/// left in LTR and RTL alike, with the tucked corners and the meta line following (as in LTR); a Text
/// or RichText child then takes its own direction from its first strong character (the web
/// `dir="auto"`: Thaana right to left, Latin left to right). Unset follows
/// `UiConfig.chatMineSide`, whose default, [UiChatBubbleSide.end], is unchanged.
///
/// Put bubbles in a Column and they align themselves, whatever its crossAxisAlignment: each takes
/// the whole row and text wraps at 80% of it. Inside an IntrinsicWidth it reports a width that keeps
/// its text on one line where it fits; in a Row (unbounded width) it wraps at 80% of the screen.
/// [semanticLabel] names the message ("You, 09:41") when the text alone doesn't say who sent it.
class UiChatBubble extends StatelessWidget {
  const UiChatBubble({super.key, required this.child, this.mine = false, this.meta, this.semanticLabel, this.mineSide});

  /// The message, usually a Text.
  final Widget child;
  final bool mine;
  final String? meta;
  final String? semanticLabel;

  /// Where your own messages sit: [UiChatBubbleSide.end] the inline end (left in RTL),
  /// [UiChatBubbleSide.right] always the right. Null follows `UiConfig.chatMineSide`.
  final UiChatBubbleSide? mineSide;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final theme = context.uiTheme;
    final right = (mineSide ?? theme.config.chatMineSide) == UiChatBubbleSide.right;
    final big = theme.radius(t.radiusLg), small = theme.radius(t.radiusXs);
    final fg = mine ? t.primaryContrast : t.text;
    final body = context.uiText.body.copyWith(color: fg, height: 1.45);
    Widget message = DefaultTextStyle.merge(style: body, child: child);
    final ownDirection = right ? uiChatTextDirection(child) : null;
    if (ownDirection != null) message = Directionality(textDirection: ownDirection, child: message);
    // The tucked corner: at the speaker's inline side by default; physical (as in LTR) when right.
    final BorderRadiusGeometry corners = right
        ? BorderRadius.only(
            topLeft: Radius.circular(big),
            topRight: Radius.circular(big),
            bottomLeft: Radius.circular(mine ? big : small),
            bottomRight: Radius.circular(mine ? small : big),
          )
        : BorderRadiusDirectional.only(
            topStart: Radius.circular(big),
            topEnd: Radius.circular(big),
            bottomStart: Radius.circular(mine ? big : small),
            bottomEnd: Radius.circular(mine ? small : big),
          );
    final bubble = Container(
      padding: EdgeInsets.symmetric(horizontal: t.space3, vertical: t.space2),
      decoration: BoxDecoration(
        color: mine ? t.primary : t.surfaceRaised,
        border: mine ? null : Border.all(color: t.border),
        borderRadius: corners,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        message,
        if (meta != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              meta!,
              textAlign: right ? TextAlign.right : TextAlign.end,
              style: body.copyWith(fontSize: 12, height: 1.35, color: mine ? t.primaryContrast.withValues(alpha: 0.8) : t.textMuted, fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
      ]),
    );
    return Semantics(
      container: true,
      label: semanticLabel,
      child: _BubbleRow(mine: mine, right: right, screenWidth: MediaQuery.maybeSizeOf(context)?.width, child: IntrinsicWidth(child: bubble)),
    );
  }
}

/// The direction a chat message's own text reads in, from its first strong character (the web
/// `dir="auto"`): RTL for Thaana, Arabic or Hebrew, LTR for Latin; null when [child] isn't a Text or
/// RichText or has no strong character (digits only), so it keeps the ambient direction.
TextDirection? uiChatTextDirection(Widget child) {
  final String? text = switch (child) {
    Text(:final data?) => data,
    Text(:final textSpan?) => textSpan.toPlainText(),
    RichText(:final text) => text.toPlainText(),
    _ => null,
  };
  if (text == null) return null;
  if (Bidi.startsWithRtl(text)) return TextDirection.rtl;
  if (Bidi.startsWithLtr(text)) return TextDirection.ltr;
  return null;
}

/// Lays the bubble out in its row: the row's full width (when bounded), the bubble at most 80% of
/// it at the inline end (yours) or start. Unlike a LayoutBuilder it answers intrinsic sizes, so an
/// IntrinsicWidth around it works (0.42.2): its max intrinsic width is the bubble's over 80%, so the
/// bubble then fits its text on one line. With unbounded width (a Row) it caps at 80% of the screen.
class _BubbleRow extends SingleChildRenderObjectWidget {
  const _BubbleRow({required this.mine, required this.right, required this.screenWidth, required super.child});

  final bool mine;

  /// mineSide right: placed as in LTR whatever the ambient direction.
  final bool right;
  final double? screenWidth;

  @override
  _RenderBubbleRow createRenderObject(BuildContext context) =>
      _RenderBubbleRow(mine, screenWidth, right ? TextDirection.ltr : Directionality.of(context));

  @override
  void updateRenderObject(BuildContext context, _RenderBubbleRow renderObject) => renderObject
    ..mine = mine
    ..screenWidth = screenWidth
    ..textDirection = right ? TextDirection.ltr : Directionality.of(context);
}

class _RenderBubbleRow extends RenderShiftedBox {
  _RenderBubbleRow(this._mine, this._screenWidth, this._textDirection) : super(null);

  static const _share = 0.8;
  // Intrinsic widths are the bubble's over [_share]; a hair extra so share x width can't round to
  // just under the text's own width and wrap it.
  static const _slack = 0.01;

  bool _mine;
  set mine(bool v) {
    if (v == _mine) return;
    _mine = v;
    markNeedsLayout();
  }

  double? _screenWidth;
  set screenWidth(double? v) {
    if (v == _screenWidth) return;
    _screenWidth = v;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection v) {
    if (v == _textDirection) return;
    _textDirection = v;
    markNeedsLayout();
  }

  /// The widest the bubble may be in a row [width] wide.
  double _cap(double width) {
    final row = width.isFinite ? width : (_screenWidth ?? double.infinity);
    return row * _share;
  }

  BoxConstraints _childConstraints(BoxConstraints c) => BoxConstraints(maxWidth: math.min(_cap(c.maxWidth), c.maxWidth), maxHeight: c.maxHeight);

  Size _sizeFor(BoxConstraints c, Size child) => c.constrain(Size(c.hasBoundedWidth ? c.maxWidth : child.width, child.height));

  @override
  double computeMinIntrinsicWidth(double height) => (child?.getMinIntrinsicWidth(height) ?? 0) / _share + _slack;

  @override
  double computeMaxIntrinsicWidth(double height) => (child?.getMaxIntrinsicWidth(height) ?? 0) / _share + _slack;

  @override
  double computeMinIntrinsicHeight(double width) => child?.getMinIntrinsicHeight(_cap(width)) ?? 0;

  @override
  double computeMaxIntrinsicHeight(double width) => child?.getMaxIntrinsicHeight(_cap(width)) ?? 0;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final c = child;
    if (c == null) return constraints.smallest;
    return _sizeFor(constraints, c.getDryLayout(_childConstraints(constraints)));
  }

  @override
  void performLayout() {
    final c = child;
    if (c == null) {
      size = constraints.smallest;
      return;
    }
    c.layout(_childConstraints(constraints), parentUsesSize: true);
    size = _sizeFor(constraints, c.size);
    final alignment = (_mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart).resolve(_textDirection);
    (c.parentData! as BoxParentData).offset = alignment.alongOffset(size - c.size as Offset);
  }
}
