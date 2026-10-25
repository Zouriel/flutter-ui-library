import 'package:flutter/widgets.dart';

import 'strings.dart';
import 'tokens.dart';

export 'strings.dart';

export 'tokens.dart' show UiGradientSpec, UiRingShadow, UiThemeName, UiTokens, uiThemeTokens, uiCompactDensityTokens, UiCompactDensity;

/// The package that ships the bundled fonts (Roboto, Space Grotesk, Bricolage Grotesque, JetBrains Mono,
/// Poppins).
const String uiFontPackage = 'zouriel_ui';

/// The font used for code when a theme names none: bundled, so code looks the same on every device.
const String uiDefaultMonoFamily = 'JetBrains Mono';

/// The UI font when a theme names none. The web library uses the system font, which is Roboto on
/// Android; bundling it makes Android, the web build and test screenshots render identically.
const String uiDefaultFamily = 'Roboto';

/// Below this logical width [UiDensity.auto] is compact (the web `UI_COMPACT_BELOW`, 600px).
const double uiCompactBelow = 600;

/// How big things are drawn (0.45.0), the web `UiConfig.density`.
///
/// [compact] makes things smaller, not tighter: type one step down (14 body), controls lower
/// (sm 24, md 26, lg 34), icons and the switch, checkbox and radio marks 10% smaller. Spacing, radii
/// and the 48dp touch targets do not change.
enum UiDensity {
  /// The library as it always was. The default.
  comfortable,

  /// Smaller sizes everywhere.
  compact,

  /// Compact when the screen is narrower than [uiCompactBelow], comfortable otherwise; follows
  /// resizes and rotation.
  auto;

  /// Whether this density draws compact on a screen [width] logical pixels wide.
  bool isCompactAt(double width) => this == compact || (this == auto && width < uiCompactBelow);
}

/// Where [UiChatBubble] puts your own (`mine`) messages (0.46.3), the web `UiChatBubbleSide`.
enum UiChatBubbleSide {
  /// The inline end: the right in LTR, the left in RTL. The default.
  end,

  /// Always the right, with the other side's on the left, in LTR and RTL alike (the chat-app habit).
  right,
}

/// Library-wide defaults, the Flutter twin of the web library's `provideUiConfig`.
@immutable
class UiConfig {
  const UiConfig({
    this.glass = false,
    this.radius = true,
    this.animations = true,
    this.fontFamily,
    this.strings = const UiStrings(),
    this.density = UiDensity.comfortable,
    this.fontFamilyFallback,
    this.chatMineSide = UiChatBubbleSide.end,
  });

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

  /// How big things are drawn (0.45.0, see [UiDensity]). [UiApp] resolves [UiDensity.auto] from the
  /// screen width; with a bare [UiTheme], pass [UiThemeData.new]'s `compact`.
  final UiDensity density;

  /// Fonts for the characters the theme's font lacks (0.46.0), the app's own families, e.g.
  /// `['Faruma', 'Noto Sans Thaana']` so Thaana draws in MV Faruma while Latin keeps the theme font.
  /// Added to every library text style (buttons, inputs, toasts, dialogs, tabs, chips…). On the web
  /// the app puts the same fonts in `--ui-font-default` (`provideUiConfig({ defaultFont })`).
  final List<String>? fontFamilyFallback;

  /// Where [UiChatBubble] puts your own messages when it has no `mineSide` of its own (0.46.3, the web
  /// `chatMineSide`). [UiChatBubbleSide.right] keeps them on the right in RTL too.
  final UiChatBubbleSide chatMineSide;

  UiConfig copyWith({
    bool? glass,
    bool? radius,
    bool? animations,
    String? fontFamily,
    UiStrings? strings,
    UiDensity? density,
    List<String>? fontFamilyFallback,
    UiChatBubbleSide? chatMineSide,
  }) =>
      UiConfig(
        glass: glass ?? this.glass,
        radius: radius ?? this.radius,
        animations: animations ?? this.animations,
        fontFamily: fontFamily ?? this.fontFamily,
        strings: strings ?? this.strings,
        density: density ?? this.density,
        fontFamilyFallback: fontFamilyFallback ?? this.fontFamilyFallback,
        chatMineSide: chatMineSide ?? this.chatMineSide,
      );
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

  factory UiTypography.from(UiTokens t, {String? fontFamily, List<String>? fontFamilyFallback}) {
    final family = fontFamily ?? t.fontDefault ?? uiDefaultFamily;
    // The bundled families are named with their package prefix rather than through `package:`, which
    // would prefix the app's own fallback fonts too ('Faruma' -> 'packages/zouriel_ui/Faruma').
    final base = TextStyle(
      fontFamily: 'packages/$uiFontPackage/$family',
      fontFamilyFallback: fontFamilyFallback,
      color: t.text,
      fontSize: t.fontSizeMd,
      height: 1.35,
      decoration: TextDecoration.none,
    );
    final display = base.copyWith(fontFamily: 'packages/$uiFontPackage/${t.fontDisplay ?? family}');
    TextStyle sized(TextStyle s, double size, FontWeight w, {double height = 1.35, double tracking = 0}) =>
        s.copyWith(fontSize: size, fontWeight: w, height: height, letterSpacing: tracking * size);
    return UiTypography(
      h1: sized(display, t.fontSizeH1, FontWeight.w700, height: 1.1, tracking: t.trackingTighter),
      h2: sized(display, t.fontSizeH2, FontWeight.w700, height: 1.18, tracking: t.trackingTight),
      h3: sized(display, t.fontSizeH3, FontWeight.w600, tracking: t.trackingTight),
      h4: sized(base, t.fontSizeLg, FontWeight.w600),
      h5: sized(base, t.fontSizeH5, FontWeight.w600),
      // Rendered upper-case by UiText; TextStyle has no text-transform.
      h6: sized(base, t.fontSizeH6, FontWeight.w600, tracking: 0.04).copyWith(color: t.textMuted),
      body: base.copyWith(fontSize: t.fontSizeMd, height: 1.45),
      caption: base.copyWith(fontSize: t.fontSizeSm, color: t.textMuted),
      label: base.copyWith(fontSize: t.fontSizeSm, fontWeight: FontWeight.w600),
      code: base.copyWith(
        fontFamily: 'packages/$uiFontPackage/${t.fontMono ?? uiDefaultMonoFamily}',
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
  /// The theme [name] (or custom [tokens]) with [config]. [compact] says whether compact density is
  /// drawn (0.45.0); by default it is when `config.density` is [UiDensity.compact] ([UiApp] also
  /// resolves [UiDensity.auto] from the screen width).
  factory UiThemeData({required UiThemeName name, UiTokens? tokens, UiConfig config = const UiConfig(), bool? compact}) {
    final base = tokens ?? uiThemeTokens[name]!;
    final isCompact = compact ?? config.density == UiDensity.compact;
    final drawn = isCompact ? base.withCompactDensity() : base;
    return UiThemeData._raw(
      name: name,
      tokens: drawn,
      baseTokens: base,
      config: config,
      compact: isCompact,
      typography: UiTypography.from(drawn, fontFamily: config.fontFamily, fontFamilyFallback: config.fontFamilyFallback),
    );
  }

  const UiThemeData._raw({
    required this.name,
    required this.tokens,
    required this.baseTokens,
    required this.config,
    required this.compact,
    required this.typography,
  });

  final UiThemeName name;

  /// The tokens components draw with: [baseTokens] with compact density applied when [compact].
  final UiTokens tokens;

  /// The theme's tokens before density.
  final UiTokens baseTokens;
  final UiConfig config;

  /// Whether compact density is drawn (0.45.0).
  final bool compact;
  final UiTypography typography;

  /// This theme drawn compact or comfortable.
  UiThemeData withCompact(bool compact) =>
      compact == this.compact ? this : UiThemeData(name: name, tokens: baseTokens, config: config, compact: compact);

  /// Light or dark, from the background's luminance (the web themes set `color-scheme` the same way).
  Brightness get brightness => tokens.bg.computeLuminance() > 0.4 ? Brightness.light : Brightness.dark;

  /// Corner radius honouring [UiConfig.radius].
  double radius([double? value]) => config.radius ? (value ?? tokens.radius) : 0;

  /// A copy with another theme or config. The density stays as it was resolved unless [config]
  /// changes it.
  UiThemeData copyWith({UiThemeName? name, UiConfig? config}) => UiThemeData(
        name: name ?? this.name,
        config: config ?? this.config,
        compact: config == null || config.density == this.config.density ? compact : null,
      );

  /// For animated theme changes: tokens and type interpolate; the name switches half-way.
  static UiThemeData lerp(UiThemeData a, UiThemeData b, double t) {
    if (t >= 1) return b;
    if (t <= 0) {
      return identical(a.config.strings, b.config.strings) ? a : UiThemeData._raw(name: a.name, tokens: a.tokens, baseTokens: a.baseTokens, config: a.config.copyWith(strings: b.config.strings), compact: a.compact, typography: a.typography);
    }
    final tokens = a.tokens.lerp(b.tokens, t);
    return UiThemeData._raw(
      name: t < 0.5 ? a.name : b.name,
      tokens: tokens,
      baseTokens: a.baseTokens.lerp(b.baseTokens, t),
      // Words switch at once (a language toggle), the rest of the config half-way.
      config: t < 0.5 ? a.config.copyWith(strings: b.config.strings) : b.config,
      compact: t < 0.5 ? a.compact : b.compact,
      typography: UiTypography.from(tokens, fontFamily: (t < 0.5 ? a.config : b.config).fontFamily, fontFamilyFallback: (t < 0.5 ? a.config : b.config).fontFamilyFallback),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is UiThemeData && other.name == name && identical(other.baseTokens, baseTokens) && other.config == config && other.compact == compact;

  @override
  int get hashCode => Object.hash(name, baseTokens, config, compact);
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

  // Tween.transform returns begin untouched at 0; lerp gives it the new words already.
  @override
  UiThemeData transform(double t) => lerp(t);
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
        name: theme,
        tokens: paintBackground ? base : base.copyWith(glassBg: base.glassPanelBg),
        config: parent.config,
        compact: parent.compact);
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
  /// The theme data. [UiDensity.auto] is drawn comfortable here; [UiApp] resolves it from the screen
  /// width.
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

  /// Switches the library's built-in words at runtime (0.46.0), e.g. `setStrings(UiStrings.dv)` for a
  /// Dhivehi toggle: everything reading `context.uiStrings` rebuilds (the web
  /// `UiStringsService.set`).
  void setStrings(UiStrings strings) => setConfig(_config.copyWith(strings: strings));

  /// Flips between the Winter dark and light themes (from any other theme it goes to dark).
  void toggle() => set(_theme == UiThemeName.dark ? UiThemeName.light : UiThemeName.dark);
}

/// Draws a subtree in another density (0.45.0), the web `data-density` on an element:
/// [UiDensity.auto] follows the screen width here too.
class UiDensityScope extends StatelessWidget {
  const UiDensityScope({super.key, required this.density, required this.child});

  final UiDensity density;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final parent = UiTheme.of(context);
    final width = MediaQuery.maybeSizeOf(context)?.width ?? double.infinity;
    final data = parent.withCompact(density.isCompactAt(width));
    if (identical(data, parent)) return child;
    return UiTheme(data: data, child: DefaultTextStyle.merge(style: TextStyle(fontSize: data.typography.body.fontSize), child: child));
  }
}
