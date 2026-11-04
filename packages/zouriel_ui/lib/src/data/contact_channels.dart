import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../button/button.dart';
import '../button/messenger_button.dart';
import '../core/icon.dart';
import '../core/types.dart';
import '../feedback/spinner.dart';
import '../overlay/tooltip.dart';
import '../theme/theme.dart';

/// Where an email to the contact stands (the web `'none' | 'skipped' | 'sent' | 'delivered' |
/// 'failed' | 'bounced'`).
enum UiEmailStatus { none, skipped, sent, delivered, failed, bounced }

/// One messenger button in a [UiContactChannels] (the web `UiMessengerChannel`).
@immutable
class UiMessengerChannel {
  const UiMessengerChannel({required this.app, this.ticked = false, this.tickLabel, this.semanticLabel, this.hidden = false});

  final UiMessengerApp app;

  /// Show the tick badge (e.g. the chat was already opened).
  final bool ticked;
  final String? tickLabel;

  /// The button's accessible name (the web `ariaLabel`).
  final String? semanticLabel;

  /// Leave this button out.
  final bool hidden;
}

/// `ui-contact-channels`: how to reach one person, as rows that share three columns
/// (label | value | status): the email address with its status (a Send button, a sent tick, a
/// Retry button with the error under it, or a spinner while [emailBusy]); the phone number; and
/// under it, starting at the value column, a messenger button per channel in equal columns. The
/// buttons show their names when every whole name fits its equal share of the width, else all show
/// their logos alone (a phone-width card); a row never mixes the two, and the full names stay for
/// screen readers. It measures its width, so it can't sit inside intrinsic sizing.
///
/// The email row shows only with a non-empty [email], the number and messenger rows only with a
/// non-empty [phone] (shown as given). Twin of Angular's `ui-contact-channels`.
class UiContactChannels extends StatelessWidget {
  const UiContactChannels({
    super.key,
    this.email,
    this.emailStatus = UiEmailStatus.none,
    this.emailTickLabel,
    this.emailError,
    this.emailBusy = false,
    this.phone,
    this.messengers = const [],
    this.emailLabel,
    this.numberLabel,
    this.onEmailSend,
    this.onEmailRetry,
    this.onMessengerPressed,
  });

  final String? email;
  final UiEmailStatus emailStatus;

  /// The sent tick's tooltip and name ("Sent 14:05"); default [UiStrings.contactEmailSent].
  final String? emailTickLabel;

  /// Shown under the email row when it failed or bounced (and describes the Retry button).
  final String? emailError;

  /// A spinner in place of the status while an email is on its way.
  final bool emailBusy;
  final String? phone;
  final List<UiMessengerChannel> messengers;

  /// The email row's label; default [UiStrings.contactEmail].
  final String? emailLabel;

  /// The number row's label; default [UiStrings.contactNumber].
  final String? numberLabel;
  final VoidCallback? onEmailSend;
  final VoidCallback? onEmailRetry;
  final ValueChanged<UiMessengerApp>? onMessengerPressed;

  /// The label column's minimum width.
  static const double labelMinWidth = 64;

  /// The status column's minimum width.
  static const double statusMinWidth = 44;

  /// A row's minimum height.
  static const double rowMinHeight = 32;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final s = context.uiStrings;
    final hasEmail = (email ?? '').isNotEmpty;
    final hasPhone = (phone ?? '').isNotEmpty;
    final visible = hasPhone ? [for (final m in messengers) if (!m.hidden) m] : const <UiMessengerChannel>[];
    final emailText = emailLabel ?? s.contactEmail;
    final numberText = numberLabel ?? s.contactNumber;
    final labelStyle = context.uiText.body.copyWith(fontSize: t.fontSizeSm, fontWeight: FontWeight.w600, height: 20 / t.fontSizeSm, color: t.textMuted);
    final valueStyle = context.uiText.body.copyWith(fontSize: t.fontSizeMd, height: 20 / t.fontSizeMd, color: t.text);

    // The label column: as wide as the widest label shown, at least 64.
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    double measure(String text) {
      final p = TextPainter(text: TextSpan(text: text, style: labelStyle), textDirection: direction, textScaler: scaler, maxLines: 1)..layout();
      final w = p.width;
      p.dispose();
      return w;
    }

    var labelWidth = labelMinWidth;
    if (hasEmail) labelWidth = math.max(labelWidth, measure(emailText).ceilToDouble());
    if (hasPhone) labelWidth = math.max(labelWidth, measure(numberText).ceilToDouble());
    final valueStart = labelWidth + t.space3;

    Widget label(String text) => SizedBox(
          key: const ValueKey('ui-contact-label'),
          width: labelWidth,
          child: Text(text, style: labelStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
        );
    Widget value(String text) => UiTooltip(
          message: text,
          child: Text(text, key: const ValueKey('ui-contact-value'), style: valueStyle, maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false),
        );
    Widget row(List<Widget> children) => ConstrainedBox(
          constraints: const BoxConstraints(minHeight: rowMinHeight),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, spacing: t.space3, children: children),
        );

    final failed = emailStatus == UiEmailStatus.failed || emailStatus == UiEmailStatus.bounced;
    final error = emailError ?? '';
    final children = <Widget>[
      if (hasEmail)
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, spacing: t.space1, children: [
        row([
          label(emailText),
          Expanded(child: value(email!)),
          ConstrainedBox(
            key: const ValueKey('ui-contact-status'),
            constraints: const BoxConstraints(minWidth: statusMinWidth),
            child: Align(alignment: AlignmentDirectional.centerEnd, widthFactor: 1, child: _status(context, failed ? error : null)),
          ),
        ]),
        // 4px under the row (the web's row gap less space1).
        if (failed && error.isNotEmpty)
          Padding(
            padding: EdgeInsetsDirectional.only(start: valueStart),
            child: Text(error, key: const ValueKey('ui-contact-error'), style: context.uiText.body.copyWith(fontSize: t.fontSizeSm, height: 1.35, color: t.danger)),
          ),
        ]),
      if (hasPhone) row([label(numberText), Expanded(child: value(phone!))]),
      if (visible.isNotEmpty)
        Padding(
          key: const ValueKey('ui-contact-messengers'),
          // Room above for the tick badges.
          padding: EdgeInsetsDirectional.only(start: valueStart, top: 6),
          child: LayoutBuilder(builder: (context, box) {
            UiMessengerButton button(UiMessengerChannel m, UiMessengerCompact compact) => UiMessengerButton(
                  key: ValueKey(m.app),
                  app: m.app,
                  expand: true,
                  compact: compact,
                  ticked: m.ticked,
                  tickLabel: m.tickLabel,
                  semanticLabel: m.semanticLabel,
                  onPressed: onMessengerPressed == null ? null : () => onMessengerPressed!(m.app),
                );
            // One rule for the whole row, so it never mixes names and logos: names only when every
            // visible button's whole name fits its equal share of the width.
            final each = (box.maxWidth - t.space2 * (visible.length - 1)) / visible.length;
            final fits = visible.every((m) => button(m, UiMessengerCompact.off).labelledWidth(context) <= each);
            final compact = fits ? UiMessengerCompact.off : UiMessengerCompact.on;
            return Row(spacing: t.space2, children: [
              for (final m in visible) Expanded(child: button(m, compact)),
            ]);
          }),
        ),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, spacing: t.space2, children: children);
  }

  Widget _status(BuildContext context, String? error) {
    final t = context.ui;
    final s = context.uiStrings;
    if (emailBusy) return const UiSpinner(key: ValueKey('ui-contact-busy'));
    switch (emailStatus) {
      case UiEmailStatus.sent || UiEmailStatus.delivered:
        final name = emailTickLabel ?? s.contactEmailSent;
        Widget tick = Semantics(
          key: const ValueKey('ui-contact-sent'),
          container: true,
          label: name,
          child: SizedBox(
            width: statusMinWidth,
            height: rowMinHeight,
            child: Center(child: ExcludeSemantics(child: UiIcon(HugeIcons.strokeRoundedTick02, size: 20, strokeWidth: 2, color: t.success))),
          ),
        );
        if (emailTickLabel != null && emailTickLabel!.isNotEmpty) tick = UiTooltip(message: emailTickLabel!, child: tick);
        return tick;
      case UiEmailStatus.failed || UiEmailStatus.bounced:
        return UiButton(
          key: const ValueKey('ui-contact-retry'),
          label: s.contactRetry,
          size: UiSize.sm,
          variant: UiButtonVariant.outline,
          semanticHint: error == null || error.isEmpty ? null : error,
          onPressed: onEmailRetry,
        );
      case UiEmailStatus.none || UiEmailStatus.skipped:
        return UiButton(
          key: const ValueKey('ui-contact-send'),
          label: s.contactSend,
          size: UiSize.sm,
          variant: UiButtonVariant.outline,
          onPressed: onEmailSend,
        );
    }
  }
}
