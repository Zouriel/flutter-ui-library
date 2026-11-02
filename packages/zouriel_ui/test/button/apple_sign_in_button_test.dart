import 'dart:ui' show Tristate;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

/// The drawn button's box (fill, stroke, radius) and its text style.
BoxDecoration _box(WidgetTester tester) => tester
    .widgetList<Container>(find.descendant(of: find.byType(UiAppleSignInButton), matching: find.byType(Container)))
    .map((c) => c.decoration)
    .whereType<BoxDecoration>()
    .first;
Rect _boxRect(WidgetTester tester) =>
    tester.getRect(find.descendant(of: find.byType(UiAppleSignInButton), matching: find.byType(Container)).first);
TextStyle _text(WidgetTester tester) =>
    tester.widget<Text>(find.descendant(of: find.byType(UiAppleSignInButton), matching: find.byType(Text))).style!;
Color _logoColor(WidgetTester tester) => tester.widget<UiAppleLogo>(find.byType(UiAppleLogo)).color;

void main() {
  group('UiAppleSignInButton colours (Apple Human Interface Guidelines)', () {
    final cases = {
      UiAppleButtonTheme.black: (const Color(0xFF000000), const Color(0xFFFFFFFF), null),
      UiAppleButtonTheme.white: (const Color(0xFFFFFFFF), const Color(0xFF000000), null),
      UiAppleButtonTheme.whiteOutline: (const Color(0xFFFFFFFF), const Color(0xFF000000), const Color(0xFF000000)),
    };
    for (final MapEntry(key: theme, value: (fill, ink, stroke)) in cases.entries) {
      testWidgets('$theme: fill, logo, words and outline', (tester) async {
        await pumpUi(tester, UiAppleSignInButton(onPressed: () {}, theme: theme));
        final box = _box(tester);
        expect(box.color, fill);
        if (stroke == null) {
          expect(box.border, isNull);
        } else {
          expect((box.border! as Border).top.color, stroke);
          expect((box.border! as Border).top.width, 1);
        }
        expect(_text(tester).color, ink);
        expect(_logoColor(tester), ink);
      });
    }

    testWidgets('system font at 17, medium; 40 high like the Google button; 6px corners', (tester) async {
      await pumpUi(tester, UiAppleSignInButton(onPressed: () {}, theme: UiAppleButtonTheme.black));
      final style = _text(tester);
      expect(style.fontFamily, 'packages/zouriel_ui/Roboto');
      expect(style.fontSize, 17);
      expect(style.fontWeight, FontWeight.w500);
      expect(_boxRect(tester).height, 40);
      expect(_box(tester).borderRadius, BorderRadius.circular(6));
    });

    testWidgets('pill shape rounds fully', (tester) async {
      await pumpUi(tester, UiAppleSignInButton(onPressed: () {}, shape: UiAppleButtonShape.pill));
      expect(_box(tester).borderRadius, BorderRadius.circular(20));
    });

    testWidgets('logo 17 tall and 25:31 wide, 6 before the words, 16 padding each side', (tester) async {
      await pumpUi(tester, UiAppleSignInButton(onPressed: () {}));
      final box = _boxRect(tester);
      final logo = tester.getRect(find.byType(UiAppleLogo));
      final words = tester.getRect(find.text('Sign in with Apple'));
      expect(logo.height, 17);
      expect(logo.width, closeTo(17 * 25 / 31, 0.001));
      expect(words.left - logo.right, 6);
      expect(logo.left - box.left, 16);
      expect(box.right - words.right, 16);
    });
  });

  test('the system font on Apple platforms, Roboto elsewhere', () {
    expect(UiAppleSignInButton.fontFamilyFor(TargetPlatform.iOS), 'CupertinoSystemText');
    expect(UiAppleSignInButton.fontFamilyFor(TargetPlatform.macOS), 'CupertinoSystemText');
    expect(UiAppleSignInButton.fontFamilyFor(TargetPlatform.android), 'packages/zouriel_ui/Roboto');
  });

  testWidgets('auto follows the UiApp theme: white on dark themes, black on light ones', (tester) async {
    await pumpUi(tester, UiAppleSignInButton(onPressed: () {}), theme: UiThemeName.dark);
    expect(_box(tester).color, const Color(0xFFFFFFFF));
    await pumpUi(tester, UiAppleSignInButton(onPressed: () {}), theme: UiThemeName.maldivesDark);
    expect(_box(tester).color, const Color(0xFFFFFFFF));
    await pumpUi(tester, UiAppleSignInButton(onPressed: () {}), theme: UiThemeName.light);
    expect(_box(tester).color, const Color(0xFF000000));
    await pumpUi(tester, UiAppleSignInButton(onPressed: () {}), theme: UiThemeName.maldives);
    expect(_box(tester).color, const Color(0xFF000000));
  });

  testWidgets('the words come from UiStrings, one per text variant, and can be translated', (tester) async {
    const expected = {
      UiAppleButtonText.signIn: 'Sign in with Apple',
      UiAppleButtonText.continueWith: 'Continue with Apple',
      UiAppleButtonText.signUp: 'Sign up with Apple',
    };
    for (final e in expected.entries) {
      await pumpUi(tester, UiAppleSignInButton(onPressed: () {}, text: e.key));
      expect(find.text(e.value), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(UiApp(
      config: const UiConfig(strings: UiStrings.dv),
      home: Align(alignment: Alignment.topLeft, child: UiAppleSignInButton(onPressed: () {}, text: UiAppleButtonText.continueWith)),
    ));
    expect(find.text(UiStrings.dv.appleContinue), findsOneWidget);
    expect(UiStrings.dv.appleContinue, isNot('Continue with Apple'));
  });

  testWidgets('taps call onPressed; null onPressed disables it and says so', (tester) async {
    var taps = 0;
    await pumpUi(tester, UiAppleSignInButton(onPressed: () => taps++));
    await tester.tap(find.byType(UiAppleSignInButton));
    expect(taps, 1);

    final handle = tester.ensureSemantics();
    await pumpUi(tester, const UiAppleSignInButton(onPressed: null));
    final data = tester.getSemantics(find.byType(UiAppleSignInButton)).getSemanticsData();
    expect(data.label, 'Sign in with Apple');
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.flagsCollection.isEnabled, Tristate.isFalse);
    await tester.tap(find.byType(UiAppleSignInButton), warnIfMissed: false);
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('loading: a spinner replaces the logo, the width stays, taps are ignored, and it is announced', (tester) async {
    var taps = 0;
    await pumpUi(tester, UiAppleSignInButton(onPressed: () => taps++));
    final idle = tester.getSize(find.byType(UiAppleSignInButton));

    final handle = tester.ensureSemantics();
    await tester.pumpWidget(UiApp(home: Align(alignment: Alignment.topLeft, child: UiAppleSignInButton(onPressed: () => taps++, loading: true))));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(UiAppleLogo), findsNothing);
    expect(find.byType(UiSpinner), findsOneWidget);
    expect(tester.getSize(find.byType(UiAppleSignInButton)), idle);
    await tester.tap(find.byType(UiAppleSignInButton), warnIfMissed: false);
    expect(taps, 0);
    final data = tester.getSemantics(find.byType(UiAppleSignInButton)).getSemanticsData();
    expect(data.label, 'Sign in with Apple (busy)');
    expect(data.flagsCollection.isEnabled, Tristate.isFalse);
    handle.dispose();
  });

  testWidgets('semanticLabel replaces the accessible name; the logo adds nothing to it', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, UiAppleSignInButton(onPressed: () {}, semanticLabel: 'Sign in to invites.blog with Apple'));
    expect(tester.getSemantics(find.byType(UiAppleSignInButton)).getSemanticsData().label, 'Sign in to invites.blog with Apple');
    handle.dispose();
  });

  testWidgets('a labelled button with a 48dp tap target and readable text', (tester) async {
    final handle = tester.ensureSemantics();
    for (final theme in [UiAppleButtonTheme.black, UiAppleButtonTheme.white, UiAppleButtonTheme.whiteOutline]) {
      await pumpUi(tester, Padding(padding: const EdgeInsets.all(16), child: UiAppleSignInButton(onPressed: () {}, theme: theme)));
      expect(tester.getSize(find.byType(UiAppleSignInButton)).height, greaterThanOrEqualTo(48));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    }
    handle.dispose();
  });

  testWidgets('expand fills the width with logo and words centred together; otherwise it hugs them', (tester) async {
    await pumpUi(tester, SizedBox(width: 390, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      UiAppleSignInButton(key: const Key('hug'), onPressed: () {}),
      UiAppleSignInButton(key: const Key('full'), onPressed: () {}, expand: true),
    ])));
    final full = tester.getRect(find.byKey(const Key('full')));
    expect(full.width, 390);
    expect(tester.getSize(find.byKey(const Key('hug'))).width, lessThan(250));
    final logo = tester.getRect(find.descendant(of: find.byKey(const Key('full')), matching: find.byType(UiAppleLogo)));
    final words = tester.getRect(find.descendant(of: find.byKey(const Key('full')), matching: find.text('Sign in with Apple')));
    final groupCentre = (logo.left + words.right) / 2;
    expect(groupCentre, closeTo(full.center.dx, 1));
  });

  testWidgets('as tall and as wide as the Google button when both are expanded', (tester) async {
    await pumpUi(tester, SizedBox(width: 360, child: Column(children: [
      UiAppleSignInButton(onPressed: () {}, expand: true),
      UiGoogleSignInButton(onPressed: () {}, expand: true),
    ])));
    expect(tester.getSize(find.byType(UiAppleSignInButton)), tester.getSize(find.byType(UiGoogleSignInButton)));
  });

  testWidgets('RTL: the logo comes first in reading order (on the right)', (tester) async {
    await pumpUi(tester, Directionality(textDirection: TextDirection.rtl, child: UiAppleSignInButton(onPressed: () {})));
    final logo = tester.getRect(find.byType(UiAppleLogo));
    final words = tester.getRect(find.text('Sign in with Apple'));
    expect(logo.left - words.right, 6);
  });

  test('the logo path is the shared one, and every command in it is one the parser draws', () {
    expect(uiAppleLogoPath, startsWith('M 12.69475 8.90692 C 11.4825 8.90692'));
    expect(uiAppleLogoPath, endsWith('C 13.09325 3.50579 12.22975 5.36765 12.46225 7.14581 C 14.17275 7.28004 15.933 6.25673 17.01225 4.94822 Z'));
    expect(RegExp('[A-Za-z]').allMatches(uiAppleLogoPath).map((m) => m.group(0)).toSet(), {'M', 'C', 'Z'});
  });

  testWidgets('the logo is drawn in one colour, filling its 25:31 box', (tester) async {
    await pumpUi(tester, const UiAppleLogo(height: 31, color: Color(0xFF000000)));
    final painter = tester.widget<CustomPaint>(find.descendant(of: find.byType(UiAppleLogo), matching: find.byType(CustomPaint))).painter!;
    final canvas = _RecordingCanvas();
    painter.paint(canvas, const Size(25, 31));
    expect(canvas.colors.map((c) => c.toARGB32()), [0xFF000000]);
    final bounds = canvas.paths.single.getBounds();
    // Bounds include control points: the left curve's control point sits just past the edge.
    expect(bounds.top, closeTo(0, 0.01));
    expect(bounds.right, closeTo(25, 0.05));
    expect(bounds.bottom, closeTo(31, 0.2));
    expect(bounds.left, inInclusiveRange(-1.5, 0));
  });

  testWidgets('golden: the styles and shapes', (tester) async {
    await expectThemedGolden(tester, 'apple_sign_in_button', (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        UiAppleSignInButton(onPressed: () {}),
        UiAppleSignInButton(onPressed: () {}, theme: UiAppleButtonTheme.black, shape: UiAppleButtonShape.pill, text: UiAppleButtonText.continueWith),
        UiAppleSignInButton(onPressed: () {}, theme: UiAppleButtonTheme.white, text: UiAppleButtonText.signUp),
        UiAppleSignInButton(onPressed: () {}, theme: UiAppleButtonTheme.whiteOutline, shape: UiAppleButtonShape.pill),
        UiAppleSignInButton(onPressed: () {}, expand: true, text: UiAppleButtonText.continueWith),
        UiGoogleSignInButton(onPressed: () {}, expand: true, text: UiGoogleButtonText.continueWith),
        const UiAppleSignInButton(onPressed: null),
      ],
    ), height: 480);
  });
}

class _RecordingCanvas implements Canvas {
  final colors = <Color>[];
  final paths = <Path>[];

  @override
  void drawPath(Path path, Paint paint) {
    colors.add(paint.color);
    paths.add(path);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
