import 'package:flutter/widgets.dart';

import '../button/button.dart';
import '../core/types.dart';
import '../theme/app.dart';
import '../theme/theme.dart';
import 'modal.dart';
import 'route.dart';

/// Asks a yes/no question in a small [UiConfirmDialog]. Completes with true for the confirm
/// button, false for the cancel button, and null when dismissed another way (the close button,
/// Escape, the backdrop or the back button), like the web where `(cancel)` fires only for Cancel.
Future<bool?> showUiConfirm({
  required BuildContext context,
  String title = 'Are you sure?',
  String message = '',
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
  bool useRootNavigator = true,
}) {
  return uiNavigatorOf(context, rootNavigator: useRootNavigator).push<bool>(UiDialogRoute<bool>.themed(
    context,
    transitions: uiScaleTransition,
    builder: (context) => UiConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
      onConfirm: () => Navigator.pop(context, true),
      onCancel: () => Navigator.pop(context, false),
    ),
  ));
}

/// `ui-confirm-dialog`: a confirm/cancel prompt on a small [UiModal], so it traps and returns
/// focus the same way. Both buttons normally sit right-aligned; with [destructive] the confirm
/// button turns red and Cancel moves to the far left, away from it. Open it with [showUiConfirm].
class UiConfirmDialog extends StatelessWidget {
  const UiConfirmDialog({
    super.key,
    required this.onConfirm,
    required this.onCancel,
    this.title = 'Are you sure?',
    this.message = '',
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.destructive = false,
  });

  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final cancel = UiButton(label: cancelLabel, variant: UiButtonVariant.outline, size: UiSize.sm, onPressed: onCancel);
    final confirm = UiButton(
      label: confirmLabel,
      variant: destructive ? UiButtonVariant.destructive : UiButtonVariant.primary,
      size: UiSize.sm,
      onPressed: onConfirm,
    );
    return UiModal(
      title: title,
      size: UiModalSize.sm,
      footer: destructive
          ? Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [cancel, confirm])
          : Row(mainAxisSize: MainAxisSize.min, spacing: t.space2, children: [cancel, confirm]),
      child: Text(message, style: context.uiText.body.copyWith(color: t.textMuted, fontSize: t.fontSizeSm, height: 1.35)),
    );
  }
}
