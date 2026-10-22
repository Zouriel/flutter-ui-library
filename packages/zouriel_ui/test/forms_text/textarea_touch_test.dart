import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

/// 0.44.2: a one-row UiTextarea is at least 48dp on touch screens at every size, whatever the text
/// scaling or textStyle (the Dhirumi visit chat box was 46dp). It used to work its margin out from
/// font size x 1.5 x scale(1), which Android's non-linear font scaling, a textStyle line height and
/// the engine's line rounding all made too tall, so the margin came out short.

/// Android 14's non-linear font scaling, roughly: 130% for tiny sizes, less for body text.
class _NonLinear extends TextScaler {
  const _NonLinear();
  @override
  double scale(double fontSize) => fontSize < 8 ? fontSize * 1.3 : fontSize * 1.15;
  @override
  double get textScaleFactor => 1.3;
  @override
  bool operator ==(Object other) => other is _NonLinear;
  @override
  int get hashCode => 1;
}

const _scalers = <String, TextScaler>{
  'none': TextScaler.noScaling,
  'non-linear': _NonLinear(),
  '90%': TextScaler.linear(0.9),
  '115%': TextScaler.linear(1.15),
};
const _styles = <String, TextStyle?>{
  'library font': null,
  'line height 1.2': TextStyle(height: 1.2),
  'Thaana fallback': TextStyle(fontFamilyFallback: ['Faruma', 'Noto Sans Thaana']),
};

/// The visible box of a field: the UiFieldFrame's AnimatedContainer.
Rect _box(WidgetTester tester) =>
    tester.getRect(find.descendant(of: find.descendant(of: find.byType(UiTextarea), matching: find.byType(UiFieldFrame)), matching: find.byType(AnimatedContainer)).first);

Future<void> _pump(WidgetTester tester, Widget field, TextScaler scaler) async {
  await tester.pumpWidget(const SizedBox());
  await pumpUi(
    tester,
    Builder(builder: (context) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: scaler), child: SizedBox(width: 320, child: field))),
  );
}

void main() {
  testWidgets('a one-row textarea is at least 48dp at every size, text scaling and textStyle; its field node too', (tester) async {
    final handle = tester.ensureSemantics();
    final short = <String>[];
    for (final size in UiSize.values) {
      for (final s in _scalers.entries) {
        for (final st in _styles.entries) {
          await _pump(tester, UiTextarea(rows: 1, autosize: true, size: size, textStyle: st.value, semanticLabel: 'Message'), s.value);
          final what = '$size, ${s.key}, ${st.key}';
          final h = tester.getSize(find.byType(UiTextarea)).height;
          if (h < 48) short.add('$what: ${h}dp');
          final node = tester.getSemantics(find.byType(EditableText)).rect.height;
          if (node < 48) short.add('$what: field node ${node}dp');
          // The visible box is centred in it: the margin is the same above and below.
          final field = tester.getRect(find.byType(UiTextarea)), box = _box(tester);
          expect(box.top - field.top, closeTo(field.bottom - box.bottom, 0.01), reason: what);
        }
      }
    }
    expect(short, isEmpty);
    handle.dispose();
  });

  testWidgets('with no room to spare (a 48dp box or taller) there is no margin: the multi-row look is unchanged', (tester) async {
    for (final size in UiSize.values) {
      for (final s in _scalers.entries) {
        await _pump(tester, UiTextarea(rows: 3, size: size, semanticLabel: 'Notes'), s.value);
        final what = '$size, ${s.key}';
        final box = _box(tester);
        expect(box.height, greaterThan(48), reason: what);
        expect(tester.getSize(find.byType(UiTextarea)).height, closeTo(box.height, 0.01), reason: '$what: hugs its box');
        // Three of the editor's lines, the padding and the border: nothing added.
        final t = tester.element(find.byType(UiTextarea)).ui;
        final padY = size == UiSize.sm ? t.space1 : t.space2;
        final editor = tester.getSize(find.byType(EditableText)).height;
        expect(box.height, closeTo(editor + 2 * padY + 2, 0.01), reason: what);
      }
    }
  });

  testWidgets('pointer platforms: no touch margin, the widget is its box', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await _pump(tester, const UiTextarea(rows: 1, autosize: true, semanticLabel: 'Message'), TextScaler.noScaling);
      expect(tester.getSize(find.byType(UiTextarea)).height, closeTo(_box(tester).height, 0.01));
      expect(_box(tester).height, lessThan(48));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('one row with a trailing send button: the button takes its taps, the field the rest, at every size', (tester) async {
    for (final size in UiSize.values) {
      for (final s in _scalers.entries) {
        var sent = 0;
        final focus = FocusNode();
        addTearDown(focus.dispose);
        await _pump(
          tester,
          UiTextarea(
            rows: 1,
            autosize: true,
            size: size,
            focusNode: focus,
            semanticLabel: 'Message',
            trailing: UiIconButton(key: const Key('send'), label: 'Send', size: UiSize.sm, round: true, onPressed: () => sent++, icon: UiIcon(HugeIcons.strokeRoundedSent)),
          ),
          s.value,
        );
        final what = '$size, ${s.key}';
        final field = tester.getRect(find.byType(UiTextarea));
        expect(field.height, greaterThanOrEqualTo(48), reason: what);
        final hit = tester.getRect(find.descendant(of: find.byKey(const Key('send')), matching: find.byType(UiTouchTarget)));
        expect(field.top <= hit.top + 0.01 && hit.bottom <= field.bottom + 0.01, isTrue, reason: '$what: $hit inside $field');
        // The top and bottom edges of the button's 48dp area still reach it (inside the widget).
        for (final p in [hit.center, Offset(hit.center.dx, hit.top + 1), Offset(hit.center.dx, hit.bottom - 1)]) {
          final before = sent;
          await tester.tapAt(p);
          await tester.pump(const Duration(milliseconds: 300));
          expect(sent, before + 1, reason: '$what: tap at $p sends');
        }
        expect(focus.hasFocus, isFalse, reason: '$what: the button taps do not focus the field');
        // Well left of the button, at the widget's top edge (in the touch margin), the field focuses.
        await tester.tapAt(Offset(field.left + 40, field.top + 1));
        await tester.pump(const Duration(milliseconds: 300));
        expect(focus.hasFocus, isTrue, reason: '$what: a tap in the margin focuses the field');
        expect(sent, 3, reason: what);
        focus.unfocus();
      }
    }
  });

  testWidgets('a single-line UiInput is 48dp on touch at every size and scaling (unchanged)', (tester) async {
    for (final size in UiSize.values) {
      for (final s in _scalers.entries) {
        await tester.pumpWidget(const SizedBox());
        await pumpUi(
          tester,
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: s.value),
              child: SizedBox(width: 320, child: UiInput(size: size, semanticLabel: 'Name')),
            ),
          ),
        );
        expect(tester.getSize(find.byType(UiInput)).height, greaterThanOrEqualTo(48), reason: '$size, ${s.key}');
      }
    }
  });
}
