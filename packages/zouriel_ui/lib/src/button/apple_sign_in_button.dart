import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/widgets.dart';

import '../core/interactive.dart';
import '../feedback/spinner.dart';
import '../theme/theme.dart';

/// The words on the button: Apple's approved wordings, read from [UiStrings] so apps can translate.
enum UiAppleButtonText {
  /// "Sign in with Apple".
  signIn,

  /// "Continue with Apple".
  continueWith,

  /// "Sign up with Apple".
  signUp,
}

/// Apple's three button styles (black, white, white with an outline), plus [auto]: white on a dark library theme, black otherwise.
enum UiAppleButtonTheme { auto, black, white, whiteOutline }

/// Corners: [rectangular] (6px) or fully rounded.
enum UiAppleButtonShape { rectangular, pill }

/// Apple's colours and this button's measures, from the Human Interface Guidelines ("Sign in with
/// Apple": black, white or white with an outline; the logo and words in black or white only). Like
/// [UiGoogleBrand], the only literal colours outside the generated tokens: the brand looks the same in
/// every theme (`style_contract_test.dart` allows this one file).
abstract final class UiAppleBrand {
  static const black = Color(0xFF000000);
  static const white = Color(0xFFFFFFFF);

  /// The same height as [UiGoogleSignInButton], so the two line up and neither is the smaller one
  /// (Apple asks for its button to be at least as prominent as other sign-in buttons).
  static const double height = 40;
  static const double radius = 6;
  static const double padding = 16;
  static const double logoGap = 6;

  /// The words' size; the logo is drawn as tall as the words.
  static const double fontSize = 17;

  /// The logo's width for its height (the drawing is 25 by 31).
  static const double logoAspect = 25 / 31;
}

/// `ui-apple-button`: a "Sign in with Apple" button drawn to Apple's Human Interface Guidelines (the
/// Apple logo and Apple's wording in the system font, black, white or white with an outline, logo
/// and words centred together).
///
/// It only draws the button: wire [onPressed] to the app's own Sign in with Apple flow (in Flutter,
/// the `sign_in_with_apple` package; the library doesn't depend on it). [onPressed] null disables it;
/// [loading] shows a spinner in place of the logo at the same width and ignores taps.
class UiAppleSignInButton extends StatelessWidget {
  const UiAppleSignInButton({
    super.key,
    required this.onPressed,
    this.text = UiAppleButtonText.signIn,
    this.theme = UiAppleButtonTheme.auto,
    this.shape = UiAppleButtonShape.rectangular,
    this.loading = false,
    this.expand = false,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
  });

  final VoidCallback? onPressed;
  final UiAppleButtonText text;
  final UiAppleButtonTheme theme;
  final UiAppleButtonShape shape;

  /// Waiting for sign-in: a spinner replaces the logo, the width stays, taps are ignored.
  final bool loading;

  /// Fill the available width; the logo and words stay centred together.
  final bool expand;

  /// The accessible name, when the visible words aren't enough. Defaults to the words.
  final String? semanticLabel;
  final FocusNode? focusNode;
  final bool autofocus;

  /// The words for [text] in the current [UiStrings].
  static String label(BuildContext context, UiAppleButtonText text) {
    final s = context.uiStrings;
    return switch (text) {
      UiAppleButtonText.signIn => s.appleSignIn,
      UiAppleButtonText.continueWith => s.appleContinue,
      UiAppleButtonText.signUp => s.appleSignUp,
    };
  }

  /// Apple asks for the system font: San Francisco on its own platforms ('CupertinoSystemText' is
  /// the engine's name for it). Elsewhere (Android, the web, tests) the library's bundled Roboto,
  /// the Google button's font, so the two match.
  static String fontFamilyFor(TargetPlatform platform) =>
      platform == TargetPlatform.iOS || platform == TargetPlatform.macOS ? 'CupertinoSystemText' : 'packages/$uiFontPackage/Roboto';

  /// The theme [theme] resolves to here: [UiAppleButtonTheme.auto] is white on a dark library theme
  /// (Apple: white on dark backgrounds) and black otherwise.
  static UiAppleButtonTheme resolve(BuildContext context, UiAppleButtonTheme theme) {
    if (theme != UiAppleButtonTheme.auto) return theme;
    return context.uiTheme.brightness == Brightness.dark ? UiAppleButtonTheme.white : UiAppleButtonTheme.black;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final words = label(context, text);
    final look = resolve(context, theme);
    final (fill, ink, stroke) = switch (look) {
      UiAppleButtonTheme.white => (UiAppleBrand.white, UiAppleBrand.black, null),
      UiAppleButtonTheme.whiteOutline => (UiAppleBrand.white, UiAppleBrand.black, UiAppleBrand.black),
      _ => (UiAppleBrand.black, UiAppleBrand.white, null),
    };
    final radius = BorderRadius.circular(shape == UiAppleButtonShape.pill ? UiAppleBrand.height / 2 : UiAppleBrand.radius);
    final body = context.uiText.body;
    final textStyle = TextStyle(
      inherit: false,
      color: ink,
      fontFamily: fontFamilyFor(defaultTargetPlatform),
      // Then the app's fallbacks for scripts the font lacks (Thaana).
      fontFamilyFallback: [?body.fontFamily, ...?body.fontFamilyFallback],
      fontSize: UiAppleBrand.fontSize,
      height: 20 / UiAppleBrand.fontSize,
      fontWeight: FontWeight.w500,
      decoration: TextDecoration.none,
      textBaseline: TextBaseline.alphabetic,
    );
    const logoHeight = UiAppleBrand.fontSize;
    const logoWidth = logoHeight * UiAppleBrand.logoAspect;

    return UiInteractive(
      onTap: loading ? null : onPressed,
      enabled: onPressed != null && !loading,
      focusNode: focusNode,
      autofocus: autofocus,
      semanticLabel: loading ? '${semanticLabel ?? words} (busy)' : (semanticLabel ?? words),
      excludeChildSemantics: true,
      builder: (context, s) {
        final logo = SizedBox(
          width: logoWidth,
          height: logoHeight,
          child: loading
              ? OverflowBox(maxWidth: logoHeight, child: Center(child: UiSpinner(size: 14, color: ink, decorative: true)))
              : UiAppleLogo(height: logoHeight, color: ink),
        );
        // Logo and words centred together, also when expanded.
        final row = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            logo,
            const SizedBox(width: UiAppleBrand.logoGap),
            Flexible(child: Text(words, style: textStyle, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
        );
        final wash = s.pressed ? 0.12 : s.hovered ? 0.08 : 0.0;
        final box = Container(
          height: UiAppleBrand.height,
          padding: const EdgeInsets.symmetric(horizontal: UiAppleBrand.padding),
          alignment: expand ? Alignment.center : null,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: radius,
            border: stroke == null ? null : Border.all(color: stroke),
            boxShadow: s.focused ? t.focusRing : null,
          ),
          foregroundDecoration: wash > 0 ? BoxDecoration(color: ink.withValues(alpha: wash), borderRadius: radius) : null,
          child: row,
        );
        return Opacity(
          opacity: s.disabled && !loading ? 0.5 : 1,
          child: expand ? SizedBox(width: double.infinity, child: box) : box,
        );
      },
    );
  }
}

/// The Apple logo, [height] tall (25:31 wide), in [color] (Apple allows black or white only).
///
/// The shape is the Apple logo as drawn by the MIT-licensed `sign_in_with_apple` Flutter package
/// (Copyright 2019 sign_in_with_apple authors), written in a 25 by 31 box; the web twin uses the same
/// path in an SVG.
class UiAppleLogo extends StatelessWidget {
  const UiAppleLogo({super.key, this.height = 17, required this.color});

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox(
          width: height * UiAppleBrand.logoAspect,
          height: height,
          child: CustomPaint(painter: _ApplePainter(color)),
        ),
      );
}

/// The logo's outline: the leaf, then the apple, in the 25x31 box (`M`, `C` and `Z` only).
const uiAppleLogoPath =
    'M 12.69475 8.90692 C 11.4825 8.90692 9.606 7.51471 7.62975 7.56524 C 5.0225 7.59872 2.63125 9.09168 1.28625 11.45667 '
    'C -1.42075 16.2037 0.58875 23.21528 3.229 27.07323 C 4.52425 28.95214 6.05225 31.06541 8.07825 30.99845 '
    'C 10.021 30.91444 10.75175 29.72373 13.10975 29.72373 C 15.45125 29.72373 16.1155 30.99845 18.17475 30.94823 '
    'C 20.26725 30.91444 21.59575 29.03584 22.8745 27.1405 C 24.35225 24.95965 24.96675 22.84638 25 22.72889 '
    'C 24.95025 22.71215 20.9315 21.15223 20.8815 16.45542 C 20.8485 12.5302 24.0535 10.6516 24.203 10.56759 '
    'C 22.37625 7.86718 19.56975 7.56524 18.59 7.49797 C 16.0325 7.29678 13.89025 8.90692 12.69475 8.90692 Z '
    'M 17.01225 4.94822 C 18.09175 3.64002 18.80575 1.81164 18.6065 0 C 17.06225 0.06696 15.20225 1.04005 14.08975 2.34825 '
    'C 13.09325 3.50579 12.22975 5.36765 12.46225 7.14581 C 14.17275 7.28004 15.933 6.25673 17.01225 4.94822 Z';

final Path _applePath = _parse(uiAppleLogoPath);

/// Parses the absolute `M`, `C` and `Z` commands the logo uses; throws on anything else.
Path _parse(String d) {
  final path = Path();
  final tokens = RegExp(r'[MCZ]|-?\d*\.?\d+').allMatches(d).map((m) => m.group(0)!).toList();
  var i = 0;
  var cmd = 'M';
  double n() => double.parse(tokens[i++]);
  while (i < tokens.length) {
    if (RegExp(r'^[MCZ]$').hasMatch(tokens[i])) cmd = tokens[i++];
    switch (cmd) {
      case 'M':
        path.moveTo(n(), n());
      case 'C':
        path.cubicTo(n(), n(), n(), n(), n(), n());
      case 'Z':
        path.close();
      default:
        throw FormatException('Unsupported SVG path command $cmd');
    }
  }
  return path;
}

class _ApplePainter extends CustomPainter {
  const _ApplePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 25, size.height / 31);
    canvas.drawPath(_applePath, Paint()..color = color..isAntiAlias = true);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ApplePainter old) => old.color != color;
}
