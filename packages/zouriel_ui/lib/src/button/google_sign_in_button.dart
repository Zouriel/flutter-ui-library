import 'package:flutter/widgets.dart';

import '../core/interactive.dart';
import '../feedback/spinner.dart';
import '../theme/theme.dart';

/// The words on the button: Google's approved wordings, read from [UiStrings] so apps can translate.
enum UiGoogleButtonText {
  /// "Sign in with Google".
  signIn,

  /// "Sign up with Google".
  signUp,

  /// "Continue with Google".
  continueWith,

  /// "Sign in" (the short form, for narrow spaces).
  signInShort,
}

/// Google's three button themes, plus [auto]: dark on a dark library theme, light otherwise.
enum UiGoogleButtonTheme { auto, light, dark, neutral }

/// Google's pre-approved shapes: 4px corners or fully rounded.
enum UiGoogleButtonShape { rectangular, pill }

/// Google's brand colours for the button, from https://developers.google.com/identity/branding-guidelines
/// ("Colors": the same values on Android, iOS and Web). The only literal colours in the library
/// outside the generated tokens: the brand must look the same in every theme
/// (`style_contract_test.dart` allows this one file).
abstract final class UiGoogleBrand {
  static const lightFill = Color(0xFFFFFFFF);
  static const lightStroke = Color(0xFF747775);
  static const lightText = Color(0xFF1F1F1F);
  static const darkFill = Color(0xFF131314);
  static const darkStroke = Color(0xFF8E918F);
  static const darkText = Color(0xFFE3E3E3);
  static const neutralFill = Color(0xFFF2F2F2);
  static const neutralText = Color(0xFF1F1F1F);

  /// The "G" mark's four colours, from Google's sample button SVG.
  static const blue = Color(0xFF4285F4);
  static const green = Color(0xFF34A853);
  static const yellow = Color(0xFFFBBC04);
  static const red = Color(0xFFE94235);

  /// Button height, logo size, corner radius and padding (Android and Web: 12px before the logo,
  /// 10px between logo and text, 12px after the text), from the guideline and its asset bundle.
  static const double height = 40;
  static const double logoSize = 20;
  static const double radius = 4;
  static const double padStart = 12;
  static const double logoGap = 10;
  static const double padEnd = 12;
}

/// `ui-google-button`: a "Sign in with Google" button drawn to Google's branding guidelines (the
/// official multicolour "G", Google's colours, 40px high, Google Sans / Roboto Medium 14/20).
///
/// It only draws the button: wire [onPressed] to the app's own sign-in (in Flutter, the
/// `google_sign_in` package; the library doesn't depend on it). [onPressed] null disables it;
/// [loading] shows a spinner in place of the "G" at the same width and ignores taps. The logo is
/// always at the start (left in LTR, right in RTL).
class UiGoogleSignInButton extends StatelessWidget {
  const UiGoogleSignInButton({
    super.key,
    required this.onPressed,
    this.text = UiGoogleButtonText.signIn,
    this.theme = UiGoogleButtonTheme.auto,
    this.shape = UiGoogleButtonShape.rectangular,
    this.loading = false,
    this.expand = false,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
  });

  final VoidCallback? onPressed;
  final UiGoogleButtonText text;
  final UiGoogleButtonTheme theme;
  final UiGoogleButtonShape shape;

  /// Waiting for sign-in: a spinner replaces the "G", the width stays, taps are ignored.
  final bool loading;

  /// Fill the available width (the logo stays at the start, the words centre in the rest).
  final bool expand;

  /// The accessible name, when the visible words aren't enough. Defaults to the words.
  final String? semanticLabel;
  final FocusNode? focusNode;
  final bool autofocus;

  /// The words for [text] in the current [UiStrings].
  static String label(BuildContext context, UiGoogleButtonText text) {
    final s = context.uiStrings;
    return switch (text) {
      UiGoogleButtonText.signIn => s.googleSignIn,
      UiGoogleButtonText.signUp => s.googleSignUp,
      UiGoogleButtonText.continueWith => s.googleContinue,
      UiGoogleButtonText.signInShort => s.googleSignInShort,
    };
  }

  /// The Google theme [theme] resolves to here: [UiGoogleButtonTheme.auto] follows the library
  /// theme's brightness.
  static UiGoogleButtonTheme resolve(BuildContext context, UiGoogleButtonTheme theme) {
    if (theme != UiGoogleButtonTheme.auto) return theme;
    return context.uiTheme.brightness == Brightness.dark ? UiGoogleButtonTheme.dark : UiGoogleButtonTheme.light;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final words = label(context, text);
    final look = resolve(context, theme);
    final (fill, stroke, ink) = switch (look) {
      UiGoogleButtonTheme.dark => (UiGoogleBrand.darkFill, UiGoogleBrand.darkStroke, UiGoogleBrand.darkText),
      UiGoogleButtonTheme.neutral => (UiGoogleBrand.neutralFill, null, UiGoogleBrand.neutralText),
      _ => (UiGoogleBrand.lightFill, UiGoogleBrand.lightStroke, UiGoogleBrand.lightText),
    };
    final inset = stroke == null ? 0.0 : 1.0;
    final radius = BorderRadius.circular(shape == UiGoogleButtonShape.pill ? UiGoogleBrand.height / 2 : UiGoogleBrand.radius);
    final body = context.uiText.body;
    final style = TextStyle(
      inherit: false,
      color: ink,
      // The library's bundled Roboto Medium (the guideline now names Google Sans, which the
      // library doesn't bundle), then the app's font for scripts Roboto lacks (Thaana, Arabic).
      fontFamily: 'packages/$uiFontPackage/Roboto',
      // UiConfig.fontFamilyFallback (0.46.0) follows, so a Dhivehi label draws in the app's Thaana font.
      fontFamilyFallback: [?body.fontFamily, ...?body.fontFamilyFallback],
      fontSize: 14,
      height: 20 / 14,
      fontWeight: FontWeight.w500,
      decoration: TextDecoration.none,
      textBaseline: TextBaseline.alphabetic,
    );

    return UiInteractive(
      onTap: loading ? null : onPressed,
      enabled: onPressed != null && !loading,
      focusNode: focusNode,
      autofocus: autofocus,
      semanticLabel: loading ? '${semanticLabel ?? words} (busy)' : (semanticLabel ?? words),
      excludeChildSemantics: true,
      builder: (context, s) {
        final logo = SizedBox.square(
          dimension: UiGoogleBrand.logoSize,
          child: loading
              ? Center(child: UiSpinner(size: 16, color: ink, decorative: true))
              : const UiGoogleLogo(size: UiGoogleBrand.logoSize),
        );
        final wordsText = Text(words, style: style, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center);
        final row = Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          children: [
            logo,
            const SizedBox(width: UiGoogleBrand.logoGap),
            if (expand)
              // Centre the words in the space after the logo, balanced against the start padding.
              Expanded(child: Padding(padding: const EdgeInsetsDirectional.only(end: UiGoogleBrand.logoSize + UiGoogleBrand.logoGap), child: wordsText))
            else
              Flexible(child: wordsText),
          ],
        );
        // State layer (Material's 8% hover, 12% press) in the button's own text colour.
        final wash = s.pressed ? 0.12 : s.hovered ? 0.08 : 0.0;
        final box = Container(
          height: UiGoogleBrand.height,
          // The guideline's padding is measured from the outer edge; the 1px stroke sits inside it.
          padding: EdgeInsetsDirectional.only(start: UiGoogleBrand.padStart - inset, end: UiGoogleBrand.padEnd - inset),
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

/// Google's standard multicolour "G" (from the guideline's sample button SVG), unmodified: the
/// path data below is copied verbatim and drawn at [size] (20 by default, as on the button).
class UiGoogleLogo extends StatelessWidget {
  const UiGoogleLogo({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox.square(dimension: size, child: CustomPaint(painter: _GPainter())),
      );
}

/// The four paths of the "G", in the 40x40 viewBox of Google's sample SVG, where the mark occupies
/// the 20x20 square at (10, 10).
const _gPaths = <(String, Color)>[
  ('M29.6 20.2273C29.6 19.5182 29.5364 18.8364 29.4182 18.1818H20V22.05H25.3818C25.15 23.3 24.4455 24.3591 23.3864 25.0682V27.5773H26.6182C28.5091 25.8364 29.6 23.2727 29.6 20.2273Z', UiGoogleBrand.blue),
  ('M20 30C22.7 30 24.9636 29.1045 26.6181 27.5773L23.3863 25.0682C22.4909 25.6682 21.3454 26.0227 20 26.0227C17.3954 26.0227 15.1909 24.2636 14.4045 21.9H11.0636V24.4909C12.7091 27.7591 16.0909 30 20 30Z', UiGoogleBrand.green),
  ('M14.4045 21.9C14.2045 21.3 14.0909 20.6591 14.0909 20C14.0909 19.3409 14.2045 18.7 14.4045 18.1V15.5091H11.0636C10.3864 16.8591 10 18.3864 10 20C10 21.6136 10.3864 23.1409 11.0636 24.4909L14.4045 21.9Z', UiGoogleBrand.yellow),
  ('M20 13.9773C21.4681 13.9773 22.7863 14.4818 23.8227 15.4727L26.6909 12.6045C24.9591 10.9909 22.6954 10 20 10C16.0909 10 12.7091 12.2409 11.0636 15.5091L14.4045 18.1C15.1909 15.7364 17.3954 13.9773 20 13.9773Z', UiGoogleBrand.red),
];

final List<(Path, Color)> _gParsed = [for (final (d, c) in _gPaths) (_parseSvgPath(d), c)];

/// Parses the absolute commands the "G" uses (M, L, H, V, C, Z).
Path _parseSvgPath(String d) {
  final path = Path();
  final tokens = RegExp(r'[MLHVCZ]|-?\d*\.?\d+').allMatches(d).map((m) => m.group(0)!).toList();
  var i = 0;
  var x = 0.0, y = 0.0;
  String cmd = 'M';
  double n() => double.parse(tokens[i++]);
  while (i < tokens.length) {
    if (RegExp(r'^[MLHVCZ]$').hasMatch(tokens[i])) cmd = tokens[i++];
    switch (cmd) {
      case 'M':
        x = n();
        y = n();
        path.moveTo(x, y);
        cmd = 'L';
      case 'L':
        x = n();
        y = n();
        path.lineTo(x, y);
      case 'H':
        x = n();
        path.lineTo(x, y);
      case 'V':
        y = n();
        path.lineTo(x, y);
      case 'C':
        final x1 = n(), y1 = n(), x2 = n(), y2 = n();
        x = n();
        y = n();
        path.cubicTo(x1, y1, x2, y2, x, y);
      case 'Z':
        path.close();
      default:
        throw FormatException('Unsupported SVG path command $cmd');
    }
  }
  return path;
}

class _GPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 20, size.height / 20);
    canvas.translate(-10, -10);
    for (final (p, c) in _gParsed) {
      canvas.drawPath(p, Paint()..color = c..isAntiAlias = true);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GPainter old) => false;
}
