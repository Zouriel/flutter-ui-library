import 'dart:ui' show Tristate;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

/// The drawn button's box (fill, stroke, radius) and its text style.
BoxDecoration _box(WidgetTester tester) => tester
    .widgetList<Container>(find.descendant(of: find.byType(UiGoogleSignInButton), matching: find.byType(Container)))
    .map((c) => c.decoration)
    .whereType<BoxDecoration>()
    .first;
TextStyle _text(WidgetTester tester) => tester.widget<Text>(find.descendant(of: find.byType(UiGoogleSignInButton), matching: find.byType(Text))).style!;

void main() {
  group('UiGoogleSignInButton colours (Google branding guidelines)', () {
    final cases = {
      UiGoogleButtonTheme.light: (const Color(0xFFFFFFFF), const Color(0xFF747775), const Color(0xFF1F1F1F)),
      UiGoogleButtonTheme.dark: (const Color(0xFF131314), const Color(0xFF8E918F), const Color(0xFFE3E3E3)),
      UiGoogleButtonTheme.neutral: (const Color(0xFFF2F2F2), null, const Color(0xFF1F1F1F)),
    };
    for (final MapEntry(key: theme, value: (fill, stroke, ink)) in cases.entries) {
      testWidgets('$theme: fill, stroke and text', (tester) async {
        await pumpUi(tester, UiGoogleSignInButton(onPressed: () {}, theme: theme));
        final box = _box(tester);
        expect(box.color, fill);
        if (stroke == null) {
          expect(box.border, isNull);
        } else {
          expect((box.border! as Border).top.color, stroke);
          expect((box.border! as Border).top.width, 1);
        }
        final style = _text(tester);
        expect(style.color, ink);
        expect(style.fontSize, 14);
        expect(style.fontSize! * style.height!, closeTo(20, 0.001));
        expect(style.fontWeight, FontWeight.w500);
      });
    }

    testWidgets('40 high, 12 before the logo, 10 between logo and text, 12 after the text', (tester) async {
      await pumpUi(tester, UiGoogleSignInButton(onPressed: () {}, theme: UiGoogleButtonTheme.light));
      final box = tester.getRect(find.descendant(of: find.byType(UiGoogleSignInButton), matching: find.byType(Container)).first);
      final logo = tester.getRect(find.byType(UiGoogleLogo));
      final text = tester.getRect(find.text('Sign in with Google'));
      expect(box.height, 40);
      expect(logo.size, const Size(20, 20));
      expect(logo.left - box.left, 12);
      expect(text.left - logo.right, 10);
      expect(box.right - text.right, 12);
      expect(_box(tester).borderRadius, BorderRadius.circular(4));
    });

    testWidgets('pill shape rounds fully', (tester) async {
      await pumpUi(tester, UiGoogleSignInButton(onPressed: () {}, shape: UiGoogleButtonShape.pill));
      expect(_box(tester).borderRadius, BorderRadius.circular(20));
    });
  });

  testWidgets('auto follows the UiApp theme: dark themes get the dark button, light ones the light', (tester) async {
    await pumpUi(tester, UiGoogleSignInButton(onPressed: () {}), theme: UiThemeName.maldivesDark);
    expect(_box(tester).color, const Color(0xFF131314));
    await pumpUi(tester, UiGoogleSignInButton(onPressed: () {}), theme: UiThemeName.maldives);
    expect(_box(tester).color, const Color(0xFFFFFFFF));
    await pumpUi(tester, UiGoogleSignInButton(onPressed: () {}), theme: UiThemeName.light);
    expect(_box(tester).color, const Color(0xFFFFFFFF));
    await pumpUi(tester, UiGoogleSignInButton(onPressed: () {}), theme: UiThemeName.dark);
    expect(_box(tester).color, const Color(0xFF131314));
  });

  testWidgets('the words come from UiStrings, one per text variant, and can be translated', (tester) async {
    const expected = {
      UiGoogleButtonText.signIn: 'Sign in with Google',
      UiGoogleButtonText.signUp: 'Sign up with Google',
      UiGoogleButtonText.continueWith: 'Continue with Google',
      UiGoogleButtonText.signInShort: 'Sign in',
    };
    for (final e in expected.entries) {
      await pumpUi(tester, UiGoogleSignInButton(onPressed: () {}, text: e.key));
      expect(find.text(e.value), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(UiApp(
      config: const UiConfig(strings: UiStrings(googleContinue: 'ގޫގުލް އިން ކުރިއަށް')),
      home: Align(alignment: Alignment.topLeft, child: UiGoogleSignInButton(onPressed: () {}, text: UiGoogleButtonText.continueWith)),
    ));
    expect(find.text('ގޫގުލް އިން ކުރިއަށް'), findsOneWidget);
  });

  testWidgets('taps call onPressed; null onPressed disables it and says so', (tester) async {
    var taps = 0;
    await pumpUi(tester, UiGoogleSignInButton(onPressed: () => taps++));
    await tester.tap(find.byType(UiGoogleSignInButton));
    expect(taps, 1);

    final handle = tester.ensureSemantics();
    await pumpUi(tester, const UiGoogleSignInButton(onPressed: null));
    final data = tester.getSemantics(find.byType(UiGoogleSignInButton)).getSemanticsData();
    expect(data.label, 'Sign in with Google');
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.flagsCollection.isEnabled, Tristate.isFalse);
    await tester.tap(find.byType(UiGoogleSignInButton), warnIfMissed: false);
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('loading: a spinner replaces the G, the width stays, taps are ignored, and it is announced', (tester) async {
    var taps = 0;
    await pumpUi(tester, UiGoogleSignInButton(onPressed: () => taps++));
    final idle = tester.getSize(find.byType(UiGoogleSignInButton));

    final handle = tester.ensureSemantics();
    await tester.pumpWidget(UiApp(home: Align(alignment: Alignment.topLeft, child: UiGoogleSignInButton(onPressed: () => taps++, loading: true))));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(UiGoogleLogo), findsNothing);
    expect(find.byType(UiSpinner), findsOneWidget);
    expect(tester.getSize(find.byType(UiGoogleSignInButton)), idle);
    await tester.tap(find.byType(UiGoogleSignInButton), warnIfMissed: false);
    expect(taps, 0);
    final data = tester.getSemantics(find.byType(UiGoogleSignInButton)).getSemanticsData();
    expect(data.label, 'Sign in with Google (busy)');
    expect(data.flagsCollection.isEnabled, Tristate.isFalse);
    handle.dispose();
  });

  testWidgets('semanticLabel replaces the accessible name', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, UiGoogleSignInButton(onPressed: () {}, semanticLabel: 'Sign in to Dhirumi with Google'));
    expect(tester.getSemantics(find.byType(UiGoogleSignInButton)).getSemanticsData().label, 'Sign in to Dhirumi with Google');
    handle.dispose();
  });

  testWidgets('a labelled button with a 48dp tap target', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, Padding(padding: const EdgeInsets.all(16), child: UiGoogleSignInButton(onPressed: () {}, text: UiGoogleButtonText.signInShort)));
    expect(tester.getSize(find.byType(UiGoogleSignInButton)).height, greaterThanOrEqualTo(48));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  testWidgets('expand fills the width; otherwise it hugs its content', (tester) async {
    await pumpUi(tester, SizedBox(width: 390, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      UiGoogleSignInButton(key: const Key('hug'), onPressed: () {}),
      UiGoogleSignInButton(key: const Key('full'), onPressed: () {}, expand: true),
    ])));
    expect(tester.getSize(find.byKey(const Key('full'))).width, 390);
    expect(tester.getSize(find.byKey(const Key('hug'))).width, lessThan(260));
  });

  testWidgets('RTL: the logo stays at the start (the right)', (tester) async {
    await pumpUi(tester, Directionality(textDirection: TextDirection.rtl, child: UiGoogleSignInButton(onPressed: () {})));
    final box = tester.getRect(find.descendant(of: find.byType(UiGoogleSignInButton), matching: find.byType(Container)).first);
    final logo = tester.getRect(find.byType(UiGoogleLogo));
    final text = tester.getRect(find.text('Sign in with Google'));
    expect(box.right - logo.right, 12);
    expect(logo.left, greaterThan(text.right));
    expect(logo.left - text.right, 10);
  });

  testWidgets('the G is drawn in its four official colours', (tester) async {
    await pumpUi(tester, const UiGoogleLogo(size: 20));
    final painter = tester.widget<CustomPaint>(find.descendant(of: find.byType(UiGoogleLogo), matching: find.byType(CustomPaint))).painter!;
    final colors = <Color>[];
    painter.paint(_RecordingCanvas(colors), const Size(20, 20));
    expect(colors.map((c) => c.toARGB32()), [0xFF4285F4, 0xFF34A853, 0xFFFBBC04, 0xFFE94235]);
  });

  testWidgets('golden: the themes and shapes', (tester) async {
    await expectThemedGolden(tester, 'google_sign_in_button', (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        UiGoogleSignInButton(onPressed: () {}),
        UiGoogleSignInButton(onPressed: () {}, theme: UiGoogleButtonTheme.light, shape: UiGoogleButtonShape.pill, text: UiGoogleButtonText.continueWith),
        UiGoogleSignInButton(onPressed: () {}, theme: UiGoogleButtonTheme.dark, text: UiGoogleButtonText.signUp),
        UiGoogleSignInButton(onPressed: () {}, theme: UiGoogleButtonTheme.neutral, shape: UiGoogleButtonShape.pill, text: UiGoogleButtonText.signInShort),
        UiGoogleSignInButton(onPressed: () {}, expand: true),
        const UiGoogleSignInButton(onPressed: null),
      ],
    ), height: 380);
  });
}

class _RecordingCanvas implements Canvas {
  _RecordingCanvas(this.colors);
  final List<Color> colors;

  @override
  void drawPath(Path path, Paint paint) => colors.add(paint.color);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
