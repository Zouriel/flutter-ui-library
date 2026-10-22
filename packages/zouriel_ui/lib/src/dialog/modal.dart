import 'dart:math' as math;
import 'dart:ui' show ImageFilter, SemanticsRole;

import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../button/button.dart';
import '../core/icon.dart';
import '../core/interactive.dart';
import '../core/types.dart';
import '../theme/app.dart';
import '../theme/theme.dart';
import 'route.dart';

/// Modal widths, the web `size`: 360, 480 and 720px, or the whole screen.
enum UiModalSize { sm, md, lg, full }

/// Opens a [UiModal] on a [UiDialogRoute] and completes with what it is popped with
/// (`Navigator.pop(context, value)`), or null when dismissed.
///
/// [builder] is the body; [footerBuilder] the actions (right-aligned). The barrier closes it when
/// [closeOnBackdrop]; Escape when [closeOnEscape]; the Android back button always does.
Future<T?> showUiModal<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
  WidgetBuilder? footerBuilder,
  UiModalSize size = UiModalSize.md,
  bool closeOnBackdrop = true,
  bool closeOnEscape = true,
  bool? glass,
  bool? radius,
  bool useRootNavigator = true,
  RouteSettings? settings,
}) {
  return uiNavigatorOf(context, rootNavigator: useRootNavigator).push<T>(UiDialogRoute<T>.themed(
    context,
    dismissible: closeOnBackdrop,
    settings: settings,
    transitions: uiScaleTransition,
    builder: (context) => UiModal(
      title: title,
      size: size,
      closeOnEscape: closeOnEscape,
      glass: glass,
      radius: radius,
      footer: footerBuilder?.call(context),
      child: Builder(builder: builder),
    ),
  ));
}

/// The web `ui-scale-enter` / `ui-scale-leave` for a dialog: fade plus a slight scale.
Widget uiScaleTransition(BuildContext context, Animation<double> animation, Widget child) {
  final t = context.ui;
  final curved = CurvedAnimation(parent: animation, curve: t.easeSpring, reverseCurve: t.easeStandard);
  return FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: t.easeStandard),
    child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(curved), child: child),
  );
}

/// `ui-modal`: a centred dialog with a header (title and close button), a body that scrolls on
/// its own so the header and footer stay put, and an optional [footer] of actions.
///
/// Open it with [showUiModal] (or push it on any route). The route provides the backdrop, the
/// focus trap and focus return, blocks the page for screen readers and scrolling, and closes on
/// the back button. The panel takes focus when it opens so Escape works at once (Tab then moves to
/// its first control); Escape closes it unless [closeOnEscape] is false. It is announced as a
/// dialog named by [title]. Without a title there is no header or close button, so give the
/// dialog a way out in its content. [UiModalSize.full] fills the screen with no padding and no
/// rounding, for editors.
class UiModal extends StatelessWidget {
  const UiModal({
    super.key,
    required this.child,
    this.title,
    this.footer,
    this.size = UiModalSize.md,
    this.closeOnEscape = true,
    this.glass,
    this.radius,
    this.onClose,
  });

  final Widget child;
  final String? title;
  final Widget? footer;
  final UiModalSize size;
  final bool closeOnEscape;
  final bool? glass;
  final bool? radius;

  /// The close button and Escape. Defaults to `Navigator.maybePop`.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final full = size == UiModalSize.full;
    final isGlass = glass ?? theme.config.glass;
    final r = full || !(radius ?? theme.config.radius) ? 0.0 : t.radiusLg;
    final close = onClose ?? () => Navigator.maybePop(context);
    final mq = MediaQuery.of(context);
    final footerPad = uiTouchPlatform(context) ? t.space1 : t.space3;

    final header = title == null
        ? null
        : UiDialogHeader(title: title!, onClose: close, padding: full ? EdgeInsets.only(top: mq.padding.top) : EdgeInsets.zero);
    final body = full
        ? Expanded(child: child)
        : Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: t.space4, vertical: t.space3),
              child: child,
            ),
          );
    Widget panel = DecoratedBox(
      decoration: BoxDecoration(
        color: isGlass ? t.glassPanelBg : t.surface,
        borderRadius: BorderRadius.circular(r),
        border: full ? null : Border.all(color: isGlass ? t.glassBorder : t.border),
        boxShadow: full ? null : t.shadow3,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: DefaultTextStyle.merge(
          style: const TextStyle(height: 1.35),
          child: Column(
            mainAxisSize: full ? MainAxisSize.max : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ?header,
              body,
              if (footer != null)
                Container(
                  // Footer buttons carry 48dp touch areas on phones; the padding gives that room back.
                  padding: EdgeInsets.fromLTRB(t.space4, footerPad, t.space4, footerPad + (full ? mq.padding.bottom : 0)),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: t.border))),
                  child: Align(alignment: AlignmentDirectional.centerEnd, child: footer),
                ),
            ],
          ),
        ),
      ),
    );
    if (isGlass) {
      panel = ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: t.glassBlur, sigmaY: t.glassBlur), child: panel),
      );
    }
    panel = UiDialogScope(label: title, closeOnEscape: closeOnEscape, onClose: close, child: panel);

    if (full) return panel;
    final maxWidth = switch (size) { UiModalSize.sm => 360.0, UiModalSize.lg => 720.0, _ => 480.0 };
    // Above the on-screen keyboard, inside the safe area, 16px from the edges.
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(t.space4),
          child: Center(
            child: LayoutBuilder(
              builder: (context, box) => ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: math.min(box.maxHeight, mq.size.height * 0.85)),
                child: panel,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What every library dialog panel shares: announced as a dialog named by [label], takes focus
/// when it opens (so Escape works before anything inside is focused), and Escape calls [onClose]
/// — or does nothing when [closeOnEscape] is false, without letting the route close itself.
class UiDialogScope extends StatelessWidget {
  const UiDialogScope({super.key, required this.child, required this.onClose, this.label, this.closeOnEscape = true, this.autofocus = true});

  final Widget child;
  final VoidCallback onClose;
  final String? label;
  final bool closeOnEscape;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      role: SemanticsRole.dialog,
      namesRoute: label != null,
      label: label,
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(onInvoke: (_) {
            if (closeOnEscape) onClose();
            return null;
          }),
        },
        child: Focus(autofocus: autofocus, skipTraversal: true, child: child),
      ),
    );
  }
}

/// The header row of a dialog: title, optional [actions], and a close button.
class UiDialogHeader extends StatelessWidget {
  const UiDialogHeader({super.key, required this.title, this.onClose, this.actions, this.padding = EdgeInsets.zero, this.border = true});

  final String title;
  final VoidCallback? onClose;
  final Widget? actions;
  final EdgeInsets padding;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    // On touch the close button claims 48dp; take that out of the padding so the header keeps
    // the web's compact height instead of growing by the whole touch target.
    final slop = onClose != null && uiTouchPlatform(context) ? (uiMinTouchTarget - t.sizeSm) / 2 : 0.0;
    return Container(
      padding: padding.add(EdgeInsets.symmetric(horizontal: t.space4, vertical: math.max(0, t.space3 - slop))),
      decoration: BoxDecoration(border: border ? Border(bottom: BorderSide(color: t.border)) : null),
      child: Row(
        spacing: t.space3,
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, fontSize: t.fontSizeMd, letterSpacing: t.trackingTight * t.fontSizeMd, height: 1.35),
            ),
          ),
          ?actions,
          if (onClose != null) UiDialogCloseButton(onPressed: onClose!),
        ],
      ),
    );
  }
}

/// The small close button in dialog headers (the web `.x`): 26px, 48dp to the touch.
class UiDialogCloseButton extends StatelessWidget {
  const UiDialogCloseButton({super.key, required this.onPressed, this.label, this.edgePadding, this.outset = 0});

  final VoidCallback onPressed;

  /// Its accessible name; defaults to the built-in close string ([UiStrings.close]).
  final String? label;

  /// How far the visible box is pulled past the padding edge. 0 (dialogs, sheets): its right edge
  /// lines up with the body and footer buttons, 16px in. The toast pulls it 4px out.
  final double outset;

  /// The padding between the button and its container's edge. The button shifts toward the edge
  /// by at most this much, so its touch area never sticks out of the container (and get clipped).
  final double? edgePadding;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    // The invisible part of the 48dp touch area sticks out; shift it so the visible box sits
    // where the web's does.
    final shift = math.min(outset + (uiTouchPlatform(context) ? (uiMinTouchTarget - t.sizeSm) / 2 : 0), edgePadding ?? double.infinity);
    return Transform.translate(
      offset: Offset(Directionality.of(context) == TextDirection.ltr ? shift : -shift, 0),
      child: UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedCancel01), label: label ?? context.uiStrings.close, size: UiSize.sm, onPressed: onPressed),
    );
  }
}
