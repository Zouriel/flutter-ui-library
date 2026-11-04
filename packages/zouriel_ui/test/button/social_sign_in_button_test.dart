import 'package:flutter/foundation.dart' show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

Finder _in(Key key, Finder f) => find.descendant(of: find.byKey(key), matching: f);
Rect _box(WidgetTester tester, Key key) => tester.getRect(_in(key, find.byKey(const ValueKey('ui-social-box'))));
Rect _slot(WidgetTester tester, Key key) => tester.getRect(_in(key, find.byKey(const ValueKey('ui-social-slot'))));
Rect _end(WidgetTester tester, Key key) => tester.getRect(_in(key, find.byKey(const ValueKey('ui-social-end'))));
BoxDecoration _deco(WidgetTester tester, Key key) =>
    tester.widget<Container>(_in(key, find.byKey(const ValueKey('ui-social-box')))).decoration! as BoxDecoration;
TextStyle _style(WidgetTester tester, Key key) => tester.widget<Text>(_in(key, find.byType(Text))).style!;

const _a = Key('apple');
const _g = Key('google');

Widget _pair({UiSocialButtonText text = UiSocialButtonText.continueWith, UiSocialButtonStyle style = UiSocialButtonStyle.auto, bool expand = true, UiSocialButtonShape shape = UiSocialButtonShape.rounded}) =>
    SizedBox(
      width: 342,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UiSocialSignInButton(key: _a, provider: UiSocialProvider.apple, text: text, buttonStyle: style, expand: expand, shape: shape, onPressed: () {}),
          const SizedBox(height: 12),
          UiSocialSignInButton(key: _g, provider: UiSocialProvider.google, text: text, buttonStyle: style, expand: expand, shape: shape, onPressed: () {}),
        ],
      ),
    );

void main() {
  testWidgets('Apple and Google render at the same size, corners, font and logo slot', (tester) async {
    await pumpUi(tester, _pair());
    final a = _box(tester, _a), g = _box(tester, _g);
    expect(a.size, g.size);
    expect(a.height, 40);
    expect(a.width, 342);
    expect(_deco(tester, _a).borderRadius, _deco(tester, _g).borderRadius);
    // The theme's button corners, as on UiButton (rounded is the default).
    expect(_deco(tester, _a).borderRadius, BorderRadius.circular(tester.element(find.byKey(_a)).ui.radius));
    expect(tester.element(find.byKey(_a)).ui.radius, greaterThan(4));
    expect((_deco(tester, _a).border! as Border).top.width, (_deco(tester, _g).border! as Border).top.width);
    final sa = _style(tester, _a), sg = _style(tester, _g);
    expect((sa.fontFamily, sa.fontSize, sa.fontWeight, sa.height), (sg.fontFamily, sg.fontSize, sg.fontWeight, sg.height));
    expect(sa.fontSize, 17);
    expect(sa.fontWeight, FontWeight.w500);
    // The logo slot: 44 from the outer edge at the start, an equal one at the end, in both.
    expect(_slot(tester, _a).left - a.left, 1);
    expect(_slot(tester, _a).width, 43);
    expect(_slot(tester, _g).width, 43);
    expect(a.right - _end(tester, _a).right, 1);
    expect(_end(tester, _a).width, _slot(tester, _a).width);
    // Logos share one centre line; the words centre on the same line too.
    final appleLogo = tester.getRect(find.byType(UiAppleLogoArtwork));
    final gLogo = tester.getRect(find.byType(UiGoogleLogo));
    expect(appleLogo.center.dx - a.left, closeTo(gLogo.center.dx - g.left, 0.01));
    expect(gLogo.center.dx - g.left, 22);
    expect(tester.getRect(find.text('Continue with Apple')).center.dx, closeTo(a.center.dx, 0.01));
    expect(tester.getRect(find.text('Continue with Google')).center.dx, closeTo(g.center.dx, 0.01));
  });

  testWidgets('not expanded, both still share height, slots and minimum width', (tester) async {
    await pumpUi(tester, _pair(expand: false, text: UiSocialButtonText.signIn));
    expect(_box(tester, _a).height, _box(tester, _g).height);
    expect(_box(tester, _a).width, greaterThanOrEqualTo(140));
    expect(_end(tester, _a).width, 43);
    expect(_end(tester, _g).width, 43);
  });

  testWidgets('Apple artwork as tall as the button; the G at its standard 20px, 12px from the edge', (tester) async {
    await pumpUi(tester, _pair());
    final a = _box(tester, _a), g = _box(tester, _g);
    final art = tester.getRect(find.byType(UiAppleLogoArtwork));
    expect(art.height, 40);
    expect(art.width, closeTo(40 * 31 / 44, 0.001));
    expect(art.top, a.top);
    final gl = tester.getRect(find.byType(UiGoogleLogo));
    expect(gl.size, const Size(20, 20));
    expect(gl.left - g.left, 12);
    // Apple: at least 8% of the width after the title.
    final words = tester.getRect(find.text('Continue with Apple'));
    expect(a.right - words.right, greaterThanOrEqualTo(a.width * 0.08));
  });

  testWidgets('the same words for both: one wording per text', (tester) async {
    for (final (t, apple, google) in [
      (UiSocialButtonText.signIn, 'Sign in with Apple', 'Sign in with Google'),
      (UiSocialButtonText.continueWith, 'Continue with Apple', 'Continue with Google'),
      (UiSocialButtonText.signUp, 'Sign up with Apple', 'Sign up with Google'),
    ]) {
      await pumpUi(tester, _pair(text: t));
      expect(find.text(apple), findsOneWidget);
      expect(find.text(google), findsOneWidget);
    }
  });

  group('colours', () {
    for (final theme in [UiThemeName.light, UiThemeName.dark]) {
      testWidgets('auto on $theme: both white, outlined (Apple white with outline, Google light)', (tester) async {
        await pumpUi(tester, _pair(), theme: theme);
        expect(_deco(tester, _a).color, const Color(0xFFFFFFFF));
        expect(_style(tester, _a).color, const Color(0xFF000000));
        expect(tester.widget<UiAppleLogoArtwork>(find.byType(UiAppleLogoArtwork)).color, const Color(0xFF000000));
        expect(_deco(tester, _g).color, const Color(0xFFFFFFFF));
        expect(_style(tester, _g).color, const Color(0xFF1F1F1F));
        expect((_deco(tester, _a).border! as Border).top.color, const Color(0xFF747775));
        expect((_deco(tester, _g).border! as Border).top.color, const Color(0xFF747775));
      });
    }

    testWidgets('dark style: Apple black, Google dark', (tester) async {
      await pumpUi(tester, _pair(style: UiSocialButtonStyle.dark), theme: UiThemeName.light);
      expect(_deco(tester, _a).color, const Color(0xFF000000));
      expect(_style(tester, _a).color, const Color(0xFFFFFFFF));
      expect(tester.widget<UiAppleLogoArtwork>(find.byType(UiAppleLogoArtwork)).color, const Color(0xFFFFFFFF));
      expect(_deco(tester, _g).color, const Color(0xFF131314));
      expect(_style(tester, _g).color, const Color(0xFFE3E3E3));
      expect((_deco(tester, _a).border! as Border).top.color, const Color(0xFF8E918F));
      expect((_deco(tester, _g).border! as Border).top.color, const Color(0xFF8E918F));
    });
  });

  testWidgets('rectangular is 4px for both', (tester) async {
    await pumpUi(tester, _pair(shape: UiSocialButtonShape.rectangular));
    expect(_deco(tester, _a).borderRadius, BorderRadius.circular(4));
    expect(_deco(tester, _g).borderRadius, BorderRadius.circular(4));
  });

  testWidgets('pill rounds both fully', (tester) async {
    await pumpUi(tester, _pair(shape: UiSocialButtonShape.pill));
    expect(_deco(tester, _a).borderRadius, BorderRadius.circular(20));
    expect(_deco(tester, _g).borderRadius, BorderRadius.circular(20));
  });

  testWidgets('the system font on iOS for both', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await pumpUi(tester, _pair());
    expect(_style(tester, _a).fontFamily, 'CupertinoSystemText');
    expect(_style(tester, _g).fontFamily, 'CupertinoSystemText');
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('taps; null disables; loading shows a spinner and ignores taps', (tester) async {
    var taps = 0;
    Widget b({bool loading = false, bool enabled = true}) => UiSocialSignInButton(
        provider: UiSocialProvider.apple, loading: loading, onPressed: enabled ? () => taps++ : null);
    await pumpUi(tester, b());
    await tester.tap(find.byType(UiSocialSignInButton));
    expect(taps, 1);
    await pumpUi(tester, b(enabled: false));
    await tester.tap(find.byType(UiSocialSignInButton));
    expect(taps, 1);
    await tester.pumpWidget(UiApp(theme: UiThemeName.dark, home: Align(alignment: Alignment.topLeft, child: b(loading: true))));
    await tester.pump();
    expect(find.byType(UiSpinner), findsOneWidget);
    expect(find.byType(UiAppleLogoArtwork), findsNothing);
    await tester.tap(find.byType(UiSocialSignInButton));
    expect(taps, 1);
    expect(find.bySemanticsLabel('Sign in with Apple (busy)'), findsOneWidget);
  });

  test('the artwork path is Apple\'s, shared with Angular', () {
    expect(uiAppleLogoLeftMediumPath, startsWith('M15.7099491,14.8846154 C16.5675461'));
    expect(uiAppleLogoLeftMediumPath, endsWith('C10.6851558,28.4129053 11.5065162,29.5 12.6902416,29.5 Z'));
  });

  testWidgets('golden: the pair, light and dark', (tester) async {
    await expectThemedGolden(tester, 'social_sign_in_button', (context) => Padding(padding: const EdgeInsets.all(16), child: _pair()), height: 200);
  });
}
