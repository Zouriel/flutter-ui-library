import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// The floating control strip of a viewer in fill mode: a pill on the glass panel surface (blurred,
/// with the raised shadow), sized to its buttons and centred by the caller. Shared with UiPdfViewer.
Widget uiViewerOverlayBar(BuildContext context, List<Widget> children, {required bool touch}) {
  final t = context.ui;
  final radius = BorderRadius.circular(t.radiusPill);
  return Semantics(
    container: true,
    explicitChildNodes: true,
    child: DecoratedBox(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: t.shadow2),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: t.glassBlur / 2, sigmaY: t.glassBlur / 2),
          child: Container(
            color: t.glassPanelBg,
            padding: EdgeInsets.symmetric(horizontal: t.space2, vertical: t.space1),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisSize: MainAxisSize.min, spacing: touch ? 0 : t.space1, children: children),
            ),
          ),
        ),
      ),
    ),
  );
}
