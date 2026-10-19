import 'dart:ui' show ImageFilter;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../core/interactive.dart';
import '../theme/theme.dart';

/// `ui-navbar`: the top bar of an app or page (an app bar): [brand] on the left, [links] in the
/// middle and [actions] on the right, 52px tall.
///
/// Narrower than [breakpoint] it wraps instead of truncating, as the web bar does: brand and actions
/// stay on the first row and the links move to a full-width second row that scrolls sideways. Put it
/// at the top of a `Column` (or in a `Stack` over the content for a [glass] bar). With [label] it is a
/// navigation landmark for screen readers; set one when a screen has more than one navigation.
class UiNavbar extends StatelessWidget {
  const UiNavbar({
    super.key,
    this.brand,
    this.links = const [],
    this.actions = const [],
    this.label,
    this.glass,
    this.radius,
    this.breakpoint = 768,
    this.safeArea = false,
  });

  /// Logo and/or app name. Text inside is bold with tight tracking.
  final Widget? brand;
  final List<Widget> links;
  final List<Widget> actions;
  final String? label;
  final bool? glass;
  final bool? radius;

  /// Width below which the links move to their own row.
  final double breakpoint;

  /// Pad the top by the status bar height, for a bar drawn edge to edge at the top of the screen.
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final isGlass = glass ?? theme.config.glass;
    final r = (radius ?? theme.config.radius) ? t.radius : 0.0;
    final brandStyle = theme.typography.body.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: t.trackingTight * t.fontSizeMd,
      color: t.text,
      height: 1.35,
    );
    final top = safeArea ? MediaQuery.paddingOf(context).top : 0.0;

    final brandW = brand == null
        ? null
        : DefaultTextStyle.merge(style: brandStyle, child: IconTheme.merge(data: IconThemeData(color: t.icon ?? t.text, size: 20), child: brand!));
    final actionsRow = Row(mainAxisSize: MainAxisSize.min, spacing: t.space2, children: actions);

    Widget content = LayoutBuilder(builder: (context, box) {
      final narrow = box.maxWidth < breakpoint;
      // Scrolls sideways when there are more links than room. With a mouse the vertical padding
      // keeps focus rings inside the scroller's clip; on touch the padded targets already leave room.
      final touch = uiTouchPlatform(context);
      Widget linksRow() => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(vertical: touch ? 0 : t.space1),
            child: Row(mainAxisSize: MainAxisSize.min, spacing: t.space2, children: links),
          );

      if (!narrow) {
        return SizedBox(
          height: 52,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: t.space4),
            child: Row(spacing: t.space4, children: [
              ?brandW,
              Expanded(child: links.isEmpty ? const SizedBox.shrink() : Align(alignment: AlignmentDirectional.centerStart, child: linksRow())),
              if (actions.isNotEmpty) actionsRow,
            ]),
          ),
        );
      }
      // The links row starts a ghost button's padding (space3) further out than the brand row, so
      // the first link's label lines up with the brand rather than sitting 12px in.
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: t.space4 - t.space3, vertical: touch ? 0 : t.space2),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, spacing: touch ? 0 : t.space2, children: [
          Container(
            constraints: BoxConstraints(minHeight: touch ? uiMinTouchTarget : 36),
            padding: EdgeInsets.symmetric(horizontal: t.space3),
            child: Row(spacing: t.space2, children: [
              Expanded(child: Align(alignment: AlignmentDirectional.centerStart, child: brandW ?? const SizedBox.shrink())),
              if (actions.isNotEmpty) actionsRow,
            ]),
          ),
          if (links.isNotEmpty) linksRow(),
        ]),
      );
    });

    Widget bar = Container(
      padding: EdgeInsets.only(top: top),
      decoration: BoxDecoration(
        color: isGlass ? t.glassBg : t.surface,
        border: Border.all(color: isGlass ? t.glassBorder : t.border),
        borderRadius: BorderRadius.circular(r),
      ),
      child: content,
    );
    if (isGlass) {
      bar = ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: t.glassBlur / 2, sigmaY: t.glassBlur / 2), child: bar),
      );
    }
    return Semantics(
      container: true,
      explicitChildNodes: true,
      role: label == null ? null : SemanticsRole.navigation,
      label: label,
      child: bar,
    );
  }
}
