import 'package:flutter/widgets.dart';

import 'tokens.dart';

export 'tokens.dart' show UiGradientSpec, UiRingShadow, UiThemeName, UiTokens, uiThemeTokens;

/// The package that ships the bundled fonts (Roboto, Space Grotesk, Bricolage Grotesque, JetBrains Mono,
/// Poppins).
const String uiFontPackage = 'zouriel_ui';

/// The font used for code when a theme names none: bundled, so code looks the same on every device.
const String uiDefaultMonoFamily = 'JetBrains Mono';

/// The UI font when a theme names none. The web library uses the system font, which is Roboto on
/// Android; bundling it makes Android, the web build and test screenshots render identically.
const String uiDefaultFamily = 'Roboto';

/// Library-wide defaults, the Flutter twin of the web library's `provideUiConfig`.
@immutable
class UiConfig {
  const UiConfig({this.glass = false, this.radius = true, this.animations = true, this.fontFamily, this.strings = const UiStrings()});

  /// Frosted, translucent surfaces on components that support them (navbar, bottom nav, cards).
  final bool glass;

  /// Rounded corners. Off gives square corners everywhere that honours it.
  final bool radius;

  /// Motion on. Off removes the library's transitions (the OS "remove animations" setting does too).
  final bool animations;

  /// Overrides the theme's default font family.
  final String? fontFamily;

  /// The library's built-in words (the web `provideUiStrings`).
  final UiStrings strings;

  UiConfig copyWith({bool? glass, bool? radius, bool? animations, String? fontFamily, UiStrings? strings}) => UiConfig(
        glass: glass ?? this.glass,
        radius: radius ?? this.radius,
        animations: animations ?? this.animations,
        fontFamily: fontFamily ?? this.fontFamily,
        strings: strings ?? this.strings,
      );
}

/// The library's own words: names of icon-only buttons and a few default labels (the web
/// `UiStrings`, same keys). English by default; give the app's language with
/// `UiConfig(strings: UiStrings(close: 'ބަންދުކުރޭ', …))` (the rest stay English). Read them with
/// `context.uiStrings`. Text from the app (titles, labels, items) is never here.
@immutable
class UiStrings {
  const UiStrings({
    this.close = 'Close',
    this.dismiss = 'Dismiss',
    this.clear = 'Clear',
    this.clearAll = 'Clear all',
    this.clearSearch = 'Clear search',
    this.previousPage = 'Previous page',
    this.nextPage = 'Next page',
    this.previousMonth = 'Previous month',
    this.nextMonth = 'Next month',
    this.chooseDate = 'Choose a date',
    this.moreActions = 'More actions',
    this.uploadLabel = 'Tap to upload',
    this.uploadHint = 'or drag & drop',
    this.holdHint = 'Press and hold to confirm',
    this.confirmTitle = 'Are you sure?',
    this.confirm = 'Confirm',
    this.cancel = 'Cancel',
    this.zoomIn = 'Zoom in',
    this.zoomOut = 'Zoom out',
    this.placePinAtCentre = 'Place the pin at the centre',
    this.mapLocate = 'Show my location',
    this.mapLocationOff = 'Location is off',
    this.mapYourLocation = 'Your location',
    this.mapOpen = 'Open map',
    this.googleSignIn = 'Sign in with Google',
    this.googleSignUp = 'Sign up with Google',
    this.googleContinue = 'Continue with Google',
    this.googleSignInShort = 'Sign in',
    this.sidebarToggle = 'Toggle navigation',
    this.sidebarClose = 'Close navigation',
    this.sidebarLabel = 'Navigation',
  });

  /// Close buttons of modal, drawer, bottom sheet, lightbox.
  final String close;

  /// Dismiss buttons of toast, alert, hint.
  final String dismiss;
  final String clear, clearAll, clearSearch;
  final String previousPage, nextPage, previousMonth, nextMonth, chooseDate;

  /// The split button's menu button.
  final String moreActions;

  /// File upload: the action (in bold; "Tap" on a phone, where the web says "Click") and what
  /// follows it when drops are enabled.
  final String uploadLabel, uploadHint;

  /// Hold button: what holding does (read with the button), and its confirm dialog.
  final String holdHint, confirmTitle, confirm, cancel;

  /// Map: the zoom buttons, and placing the pin at the centre (keyboard / screen reader).
  final String zoomIn, zoomOut, placePinAtCentre;

  /// Map: the "my location" button, its off state (location off or denied), and the "you are here" dot.
  final String mapLocate, mapLocationOff, mapYourLocation;

  /// Map preview (0.43.0): the still map's one button, which opens the full map.
  final String mapOpen;

  /// Google sign-in button: Google's approved wordings (translations must keep the meaning:
  /// signing in to this app with a Google account, not creating one).
  final String googleSignIn, googleSignUp, googleContinue, googleSignInShort;

  /// Sidebar layout: the menu button, the drawer's close control (the backdrop, for screen
  /// readers) and the drawer's name.
  final String sidebarToggle, sidebarClose, sidebarLabel;
}

/// The type scale from the web `ui-text` variants, built from a theme's tokens.
@immutable
class UiTypography {
  const UiTypography({
    required this.h1,
    required this.h2,
    required this.h3,
    required this.h4,
    required this.h5,
    required this.h6,
    required this.body,
    required this.caption,
    required this.label,
    required this.code,
    required this.quote,
  });

  factory UiTypography.from(UiTokens t, {String? fontFamily}) {
    final family = fontFamily ?? t.fontDefault ?? uiDefaultFamily;
    final base = TextStyle(
      fontFamily: family,
      package: uiFontPackage,
      color: t.text,
      fontSize: t.fontSizeMd,
      height: 1.35,
      decoration: TextDecoration.none,
    );
    final display = base.copyWith(fontFamily: t.fontDisplay ?? family, package: uiFontPackage);
    TextStyle sized(TextStyle s, double size, FontWeight w, {double height = 1.35, double tracking = 0}) =>
        s.copyWith(fontSize: size, fontWeight: w, height: height, letterSpacing: tracking * size);
    return UiTypography(
      h1: sized(display, 40, FontWeight.w700, height: 1.1, tracking: t.trackingTighter),
      h2: sized(display, 30, FontWeight.w700, height: 1.18, tracking: t.trackingTight),
      h3: sized(display, 22, FontWeight.w600, tracking: t.trackingTight),
      h4: sized(base, t.fontSizeLg, FontWeight.w600),
      h5: sized(base, 16, FontWeight.w600),
      // Rendered upper-case by UiText; TextStyle has no text-transform.
      h6: sized(base, 14.4, FontWeight.w600, tracking: 0.04).copyWith(color: t.textMuted),
      body: base.copyWith(fontSize: t.fontSizeMd, height: 1.45),
      caption: base.copyWith(fontSize: t.fontSizeSm, color: t.textMuted),
      label: base.copyWith(fontSize: t.fontSizeSm, fontWeight: FontWeight.w600),
      code: base.copyWith(
        fontFamily: t.fontMono ?? uiDefaultMonoFamily,
        package: uiFontPackage,
        fontSize: t.fontSizeMd * 0.88,
      ),
      quote: base.copyWith(color: t.textSecondary, height: 1.45, fontStyle: FontStyle.italic),
    );
  }

  final TextStyle h1, h2, h3, h4, h5, h6, body, caption, label, code, quote;
}

/// Everything a component needs from the current theme.
@immutable
class UiThemeData {
  UiThemeData({required this.name, UiTokens? tokens, this.config = const UiConfig()})
      : tokens = tokens ?? uiThemeTokens[name]!,
        typography = UiTypography.from(tokens ?? uiThemeTokens[name]!, fontFamily: config.fontFamily);

  const UiThemeData._raw({required this.name, required this.tokens, required this.config, required this.typography});

  final UiThemeName name;
  final UiTokens tokens;
  final UiConfig config;
  final UiTypography typography;

  /// Light or dark, from the background's luminance (the web themes set `color-scheme` the same way).
  Brightness get brightness => tokens.bg.computeLuminance() > 0.4 ? Brightness.light : Brightness.dark;

  /// Corner radius honouring [UiConfig.radius].
  double radius([double? value]) => config.radius ? (value ?? tokens.radius) : 0;

  UiThemeData copyWith({UiThemeName? name, UiConfig? config}) =>
      UiThemeData(name: name ?? this.name, config: config ?? this.config);

  /// For animated theme changes: tokens and type interpolate; the name switches half-way.
  static UiThemeData lerp(UiThemeData a, UiThemeData b, double t) {
    if (t <= 0) return a;
    if (t >= 1) return b;
    final tokens = a.tokens.lerp(b.tokens, t);
    return UiThemeData._raw(
      name: t < 0.5 ? a.name : b.name,
      tokens: tokens,
      config: t < 0.5 ? a.config : b.config,
      typography: UiTypography.from(tokens, fontFamily: (t < 0.5 ? a.config : b.config).fontFamily),
    );
  }

  @override
  bool operator ==(Object other) => other is UiThemeData && other.name == name && identical(other.tokens, tokens) && other.config == config;

  @override
  int get hashCode => Object.hash(name, tokens, config);
}

/// Provides a [UiThemeData] to the subtree. Use [UiThemeScope] for a scoped theme inside a page.
class UiTheme extends InheritedWidget {
  const UiTheme({super.key, required this.data, required super.child});

  final UiThemeData data;

  /// The nearest theme. Falls back to Winter Dark, the library's base, when none is provided.
  static UiThemeData of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<UiTheme>()?.data ?? _fallback;

  static final UiThemeData _fallback = UiThemeData(name: UiThemeName.dark);

  @override
  bool updateShouldNotify(UiTheme oldWidget) => oldWidget.data != data;
}

/// Shorthands: `context.ui` (tokens), `context.uiTheme`, `context.uiText`.
extension UiThemeContext on BuildContext {
  UiThemeData get uiTheme => UiTheme.of(this);
  UiTokens get ui => UiTheme.of(this).tokens;
  UiTypography get uiText => UiTheme.of(this).typography;

  /// Whether motion should play: the library config and the OS "remove animations" setting.
  bool get uiAnimate => UiTheme.of(this).config.animations && !(MediaQuery.maybeDisableAnimationsOf(this) ?? false);

  /// The library's built-in words in effect ([UiConfig.strings]).
  UiStrings get uiStrings => UiTheme.of(this).config.strings;
}

/// Animates between themes when [data] changes, the way the web tokens transition.
class AnimatedUiTheme extends ImplicitlyAnimatedWidget {
  const AnimatedUiTheme({
    super.key,
    required this.data,
    required this.child,
    super.duration = const Duration(milliseconds: 200),
    super.curve = const Cubic(0.2, 0, 0, 1),
  });

  final UiThemeData data;
  final Widget child;

  @override
  AnimatedWidgetBaseState<AnimatedUiTheme> createState() => _AnimatedUiThemeState();
}

class _UiThemeDataTween extends Tween<UiThemeData> {
  _UiThemeDataTween({super.begin});
  @override
  UiThemeData lerp(double t) => UiThemeData.lerp(begin!, end!, t);
}

class _AnimatedUiThemeState extends AnimatedWidgetBaseState<AnimatedUiTheme> {
  _UiThemeDataTween? _data;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _data = visitor(_data, widget.data, (v) => _UiThemeDataTween(begin: v as UiThemeData)) as _UiThemeDataTween?;
  }

  @override
  Widget build(BuildContext context) => UiTheme(data: _data!.evaluate(animation), child: widget.child);
}

/// A different theme for one part of the page (the web `ui-theme-provider`): sets the theme and
/// paints its background and default text style, so the island looks right on any page.
class UiThemeScope extends StatelessWidget {
  const UiThemeScope({super.key, required this.theme, required this.child, this.paintBackground = true});

  final UiThemeName theme;
  final Widget child;
  final bool paintBackground;

  @override
  Widget build(BuildContext context) {
    final parent = UiTheme.of(context);
    // Without its own background the island sits over another theme's ground, which its thin glass
    // tint wasn't tuned for (a near-white "dark" card with light text), so glass inside uses the
    // panel recipe, as on the web (`ui-theme-provider` without `ui-surface`).
    final base = uiThemeTokens[theme]!;
    final data = UiThemeData(
        name: theme, tokens: paintBackground ? base : base.copyWith(glassBg: base.glassPanelBg), config: parent.config);
    Widget content = IconTheme(
      data: IconThemeData(color: data.tokens.icon ?? data.tokens.text, size: 20),
      child: DefaultTextStyle(style: data.typography.body, child: child),
    );
    if (paintBackground) content = ColoredBox(color: data.tokens.bg, child: content);
    return UiTheme(data: data, child: content);
  }
}

/// Makes a [UiThemeController] reachable below it with [UiThemeController.maybeOf]. [UiApp]
/// provides its controller this way, so any widget can switch the app's theme, as an Angular
/// component injects `UiThemeService`.
class UiThemeControllerScope extends InheritedWidget {
  const UiThemeControllerScope({super.key, required this.controller, required super.child});

  final UiThemeController controller;

  @override
  bool updateShouldNotify(UiThemeControllerScope oldWidget) => oldWidget.controller != controller;
}

/// Holds the app's current theme, the twin of the web `UiThemeService`. Persist [theme] yourself.
class UiThemeController extends ChangeNotifier {
  /// The controller of the nearest [UiApp] (or [UiThemeControllerScope]), or null when the app has a
  /// fixed theme.
  static UiThemeController? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<UiThemeControllerScope>()?.controller;

  // Named parameters can't be private, so these can't be initializing formals.
  UiThemeController({UiThemeName theme = UiThemeName.dark, UiConfig config = const UiConfig()})
      : _theme = theme, // ignore: prefer_initializing_formals
        _config = config; // ignore: prefer_initializing_formals

  UiThemeName _theme;
  UiConfig _config;

  UiThemeName get theme => _theme;
  UiConfig get config => _config;
  UiThemeData get data => UiThemeData(name: _theme, config: _config);

  void set(UiThemeName theme) {
    if (theme == _theme) return;
    _theme = theme;
    notifyListeners();
  }

  void setConfig(UiConfig config) {
    _config = config;
    notifyListeners();
  }

  /// Flips between the Winter dark and light themes (from any other theme it goes to dark).
  void toggle() => set(_theme == UiThemeName.dark ? UiThemeName.light : UiThemeName.dark);
}
