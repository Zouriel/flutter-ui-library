import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/widgets.dart';

import '../core/interactive.dart';
import '../feedback/spinner.dart';
import '../theme/theme.dart';
import 'apple_sign_in_button.dart' show UiAppleSignInButton;
import 'google_sign_in_button.dart' show UiGoogleLogo;

/// Which sign-in a [UiSocialSignInButton] is for.
enum UiSocialProvider { apple, google }

/// The words: the same wording for every provider, so a stack of buttons reads alike.
enum UiSocialButtonText {
  /// "Sign in with Apple" / "Sign in with Google".
  signIn,

  /// "Continue with Apple" / "Continue with Google".
  continueWith,

  /// "Sign up with Apple" / "Sign up with Google".
  signUp,
}

/// [light]: Apple's white button with an outline and Google's light one. [dark]: Apple's black
/// button and Google's dark one. [auto] (0.56.0) is [light] on every theme: white buttons read well on
/// light and dark backgrounds alike (Apple: white with an outline on light backgrounds, white on dark
/// ones; Google's light style is allowed on any background).
enum UiSocialButtonStyle { auto, dark, light }

/// [rounded] (0.56.0, the default): the theme's button corners (`context.ui.radius`, as on
/// [UiButton]), so the pair matches the app's own buttons (Apple: match the corner radius of your
/// other buttons). [rectangular]: 4px (Google's rectangular shape). [pill]: fully rounded.
enum UiSocialButtonShape { rounded, rectangular, pill }

/// The pair's shared measures and the brands' colours. With [UiGoogleBrand] and [UiAppleBrand], the
/// only literal colours outside the generated tokens: brands look the same in every theme
/// (`style_contract_test.dart` allows this file).
abstract final class UiSocialBrand {
  static const appleDarkFill = Color(0xFF000000);
  static const appleDarkText = Color(0xFFFFFFFF);
  static const appleLightFill = Color(0xFFFFFFFF);
  static const appleLightText = Color(0xFF000000);
  static const googleDarkFill = Color(0xFF131314);
  static const googleDarkText = Color(0xFFE3E3E3);
  static const googleLightFill = Color(0xFFFFFFFF);
  static const googleLightText = Color(0xFF1F1F1F);

  /// Google's strokes, also used on Apple's button beside it (Apple allows a stroke on the bezel).
  static const darkStroke = Color(0xFF8E918F);
  static const lightStroke = Color(0xFF747775);

  /// The same for both providers: 40 high, the same corners, a 44px logo slot at each end (measured from
  /// the outer edge), 17/20 Medium words (Apple: the title is 43% of the height).
  static const double height = 40;
  /// [UiSocialButtonShape.rectangular]'s corners.
  static const double radius = 4;
  static const double slot = 44;
  static const double minWidth = 140;
  static const double fontSize = 17;
  static const double lineHeight = 20;

  /// The Google "G" at its standard size, unaltered.
  static const double googleLogo = 20;
}

/// `ui-social-button`: Sign in with Apple and Sign in with Google as one matching pair. Both get the
/// same height (40), corners, 1px stroke, font (the system font on Apple platforms, else Roboto;
/// 17/20 Medium) and a 44px logo slot at the start with an equal one at the end, so a stack of them
/// lines up exactly and the words centre on one line. Each keeps its brand rules: Apple's own
/// left-aligned logo artwork at the button's full height in black or white (Human Interface
/// Guidelines, custom buttons), Google's standard multicolour "G" at 20px, 12px from the edge, and
/// Google's light and dark colours (branding guidelines).
///
/// It only draws the button: wire [onPressed] to the app's own sign-in. [onPressed] null disables
/// it; [loading] shows a spinner in place of the logo and ignores taps. Twin of Angular's
/// `ui-social-button`.
class UiSocialSignInButton extends StatelessWidget {
  const UiSocialSignInButton({
    super.key,
    required this.provider,
    required this.onPressed,
    this.text = UiSocialButtonText.signIn,
    this.buttonStyle = UiSocialButtonStyle.auto,
    this.shape = UiSocialButtonShape.rounded,
    this.loading = false,
    this.expand = false,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
  });

  final UiSocialProvider provider;
  final VoidCallback? onPressed;

  /// Which wording; use the same one for every button in a stack.
  final UiSocialButtonText text;
  final UiSocialButtonStyle buttonStyle;
  final UiSocialButtonShape shape;

  /// Waiting for sign-in: a spinner replaces the logo, the size stays, taps are ignored.
  final bool loading;

  /// Fill the available width (the logo stays at the start, the words centre).
  final bool expand;

  /// The accessible name, when the visible words aren't enough. Defaults to the words.
  final String? semanticLabel;
  final FocusNode? focusNode;
  final bool autofocus;

  /// The words for [provider] and [text] in the current [UiStrings].
  static String label(BuildContext context, UiSocialProvider provider, UiSocialButtonText text) {
    final s = context.uiStrings;
    final apple = provider == UiSocialProvider.apple;
    return switch (text) {
      UiSocialButtonText.signIn => apple ? s.appleSignIn : s.googleSignIn,
      UiSocialButtonText.continueWith => apple ? s.appleContinue : s.googleContinue,
      UiSocialButtonText.signUp => apple ? s.appleSignUp : s.googleSignUp,
    };
  }

  /// The style [style] resolves to here: [UiSocialButtonStyle.auto] is [UiSocialButtonStyle.light]
  /// on every theme (kept as a function so a theme-dependent rule can return without an API change).
  static UiSocialButtonStyle resolve(BuildContext context, UiSocialButtonStyle style) {
    return style == UiSocialButtonStyle.auto ? UiSocialButtonStyle.light : style;
  }

  /// Fill, stroke and ink (words and Apple's logo) for a provider in a resolved style.
  static (Color, Color, Color) colors(UiSocialProvider provider, UiSocialButtonStyle look) {
    final light = look == UiSocialButtonStyle.light;
    return switch (provider) {
      UiSocialProvider.apple => light
          ? (UiSocialBrand.appleLightFill, UiSocialBrand.lightStroke, UiSocialBrand.appleLightText)
          : (UiSocialBrand.appleDarkFill, UiSocialBrand.darkStroke, UiSocialBrand.appleDarkText),
      UiSocialProvider.google => light
          ? (UiSocialBrand.googleLightFill, UiSocialBrand.lightStroke, UiSocialBrand.googleLightText)
          : (UiSocialBrand.googleDarkFill, UiSocialBrand.darkStroke, UiSocialBrand.googleDarkText),
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final words = label(context, provider, text);
    final (fill, stroke, ink) = colors(provider, resolve(context, buttonStyle));
    final radius = BorderRadius.circular(switch (shape) {
      UiSocialButtonShape.pill => UiSocialBrand.height / 2,
      UiSocialButtonShape.rectangular => UiSocialBrand.radius,
      UiSocialButtonShape.rounded => t.radius,
    });
    final body = context.uiText.body;
    final style = TextStyle(
      inherit: false,
      color: ink,
      // One font for both providers: the system font on Apple platforms, Roboto elsewhere.
      fontFamily: UiAppleSignInButton.fontFamilyFor(defaultTargetPlatform),
      // Then the app's fallbacks for scripts the font lacks (Thaana).
      fontFamilyFallback: [?body.fontFamily, ...?body.fontFamilyFallback],
      fontSize: UiSocialBrand.fontSize,
      height: UiSocialBrand.lineHeight / UiSocialBrand.fontSize,
      fontWeight: FontWeight.w500,
      decoration: TextDecoration.none,
      textBaseline: TextBaseline.alphabetic,
    );
    // The slots are measured from the outer edge; the 1px stroke sits inside them.
    const slotInside = UiSocialBrand.slot - 1;

    return UiInteractive(
      onTap: loading ? null : onPressed,
      enabled: onPressed != null && !loading,
      focusNode: focusNode,
      autofocus: autofocus,
      semanticLabel: loading ? '${semanticLabel ?? words} (busy)' : (semanticLabel ?? words),
      excludeChildSemantics: true,
      builder: (context, s) {
        final Widget logo = loading
            ? UiSpinner(size: 16, color: ink, decorative: true)
            : provider == UiSocialProvider.apple
                // Apple: the artwork as tall as the whole button, over the stroke.
                ? OverflowBox(maxHeight: UiSocialBrand.height, child: UiAppleLogoArtwork(height: UiSocialBrand.height, color: ink))
                : const UiGoogleLogo(size: UiSocialBrand.googleLogo);
        final wordsText = Text(words, style: style, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center);
        final row = Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          children: [
            // The logo centres on the 44px slot measured from the outer edge (22px in), so the "G" has
            // 12px before it and after it.
            SizedBox(
              key: const ValueKey('ui-social-slot'),
              width: slotInside,
              child: Padding(padding: const EdgeInsetsDirectional.only(end: 1), child: Center(child: logo)),
            ),
            if (expand) Expanded(child: wordsText) else Flexible(child: wordsText),
            const SizedBox(key: ValueKey('ui-social-end'), width: slotInside),
          ],
        );
        final wash = s.pressed ? 0.12 : s.hovered ? 0.08 : 0.0;
        final box = Container(
          key: const ValueKey('ui-social-box'),
          height: UiSocialBrand.height,
          constraints: const BoxConstraints(minWidth: UiSocialBrand.minWidth),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: radius,
            border: Border.all(color: stroke),
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

/// Apple's "Sign in with Apple - Left Aligned - Medium" logo artwork (Apple Design Resources,
/// Logo-Sign-in-with-Apple.dmg), unmodified, in [color] (Apple allows black or white only). Drawn
/// [height] tall in its 31x44 box, which holds Apple's own padding: Apple asks for the file's height
/// to match the button's. The file's background rectangle is left out (the button's own fill).
class UiAppleLogoArtwork extends StatelessWidget {
  const UiAppleLogoArtwork({super.key, this.height = 44, required this.color});

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox(
          width: height * 31 / 44,
          height: height,
          child: CustomPaint(painter: _ArtworkPainter(color)),
        ),
      );
}

/// The artwork's path, verbatim from the SVG (shared with Angular's `UI_APPLE_LOGO_LEFT_MEDIUM_PATH`).
const uiAppleLogoLeftMediumPath =
    'M15.7099491,14.8846154 C16.5675461,14.8846154 17.642562,14.3048315 18.28274,13.5317864 C18.8625238,12.8312142 19.2852829,11.852829 19.2852829,10.8744437 C19.2852829,10.7415766 19.2732041,10.6087095 19.2490464,10.5 C18.2948188,10.5362365 17.1473299,11.140178 16.4588366,11.9494596 C15.9152893,12.56548 15.4200572,13.5317864 15.4200572,14.5222505 C15.4200572,14.6671964 15.4442149,14.8121424 15.4562937,14.8604577 C15.5166879,14.8725366 15.6133185,14.8846154 15.7099491,14.8846154 Z M12.6902416,29.5 C13.8618881,29.5 14.3812778,28.714876 15.8428163,28.714876 C17.3285124,28.714876 17.6546408,29.4758423 18.9591545,29.4758423 C20.2395105,29.4758423 21.0971074,28.292117 21.9063891,27.1325493 C22.8123013,25.8038779 23.1867451,24.4993643 23.2109027,24.4389701 C23.1263509,24.4148125 20.6743484,23.4122695 20.6743484,20.5979021 C20.6743484,18.1579784 22.6069612,17.0588048 22.7156707,16.974253 C21.4353147,15.1382708 19.490623,15.0899555 18.9591545,15.0899555 C17.5217737,15.0899555 16.3501271,15.9596313 15.6133185,15.9596313 C14.8161157,15.9596313 13.7652575,15.1382708 12.521138,15.1382708 C10.1536872,15.1382708 7.75,17.0950413 7.75,20.7911634 C7.75,23.0861411 8.64383344,25.513986 9.74300699,27.0842339 C10.6851558,28.4129053 11.5065162,29.5 12.6902416,29.5 Z';

final Path _artworkPath = _parseMcz(uiAppleLogoLeftMediumPath);

/// Parses the absolute `M`, `C` and `Z` commands the artwork uses (numbers split by spaces or
/// commas); throws on anything else.
Path _parseMcz(String d) {
  final path = Path();
  final tokens = RegExp(r'[A-Za-z]|-?\d*\.?\d+').allMatches(d).map((m) => m.group(0)!).toList();
  var i = 0;
  var cmd = 'M';
  double n() => double.parse(tokens[i++]);
  while (i < tokens.length) {
    if (RegExp(r'^[A-Za-z]$').hasMatch(tokens[i])) cmd = tokens[i++];
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

class _ArtworkPainter extends CustomPainter {
  const _ArtworkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 31, size.height / 44);
    canvas.drawPath(_artworkPath, Paint()..color = color..isAntiAlias = true);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ArtworkPainter old) => old.color != color;
}
