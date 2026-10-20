import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

/// The visible box of a field: the UiFieldFrame's AnimatedContainer.
Rect _box(WidgetTester tester, Finder field) =>
    tester.getRect(find.descendant(of: find.descendant(of: field, matching: find.byType(UiFieldFrame)), matching: find.byType(AnimatedContainer)).first);

Widget _composer({UiTextDir? dir, int rows = 1, String? value, VoidCallback? onSend, TextStyle? textStyle, bool invalid = false}) => SizedBox(
      width: 320,
      child: UiTextarea(
        value: value,
        rows: rows,
        autosize: true,
        dir: dir,
        invalid: invalid,
        textStyle: textStyle,
        semanticLabel: 'Message',
        leading: UiIcon(HugeIcons.strokeRoundedAttachment01, key: const Key('clip')),
        trailing: UiIconButton(key: const Key('send'), label: 'Send', size: UiSize.sm, onPressed: onSend, icon: UiIcon(HugeIcons.strokeRoundedSent)),
      ),
    );

void main() {
  testWidgets('textarea slots sit inside the border at the inline edges, with the text between them', (tester) async {
    await pumpUi(tester, _composer());
    final box = _box(tester, find.byType(UiTextarea));
    final clip = tester.getRect(find.byKey(const Key('clip')));
    final send = tester.getRect(find.byKey(const Key('send')));
    final text = tester.getRect(find.byType(EditableText));
    expect(box.contains(clip.center) && box.contains(send.center), isTrue);
    expect(clip.right, lessThanOrEqualTo(text.left));
    expect(send.left, greaterThanOrEqualTo(text.right));
    expect(clip.left, lessThan(send.left), reason: 'leading is on the left in LTR');
  });

  testWidgets('textarea slots stay on the last line as autosize grows', (tester) async {
    var value = 'one';
    late StateSetter set;
    await pumpUi(tester, StatefulBuilder(builder: (context, s) {
      set = s;
      return _composer(value: value);
    }));
    final one = _box(tester, find.byType(UiTextarea));
    final sendOne = tester.getRect(find.byKey(const Key('send')));
    expect((sendOne.center.dy - (one.bottom - 20)).abs(), lessThan(2), reason: 'centred on the last line box (38.5 / 2 from the bottom)');
    set(() => value = 'one\ntwo\nthree');
    await tester.pumpAndSettle();
    final three = _box(tester, find.byType(UiTextarea));
    final sendThree = tester.getRect(find.byKey(const Key('send')));
    expect(three.height, greaterThan(one.height + 40));
    expect((three.bottom - sendThree.center.dy) - (one.bottom - sendOne.center.dy), closeTo(0, 0.5));
  });

  testWidgets('a slot button keeps a 48dp touch target without making the box taller', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, _composer(onSend: () {}));
    final plain = await (() async {
      await tester.pumpWidget(const SizedBox());
      await pumpUi(tester, const SizedBox(width: 320, child: UiTextarea(rows: 1, autosize: true, semanticLabel: 'Plain')));
      return _box(tester, find.byType(UiTextarea)).height;
    })();
    await tester.pumpWidget(const SizedBox());
    await pumpUi(tester, _composer(onSend: () {}));
    expect(_box(tester, find.byType(UiTextarea)).height, closeTo(plain, 0.01));
    // The button's tap area is 48x48 and inside the widget's bounds (a hit test stops at them),
    // so a tap at its top or bottom edge still reaches it.
    final hit = tester.getRect(find.descendant(of: find.byKey(const Key('send')), matching: find.byType(UiTouchTarget)));
    expect(hit.width, greaterThanOrEqualTo(48));
    expect(hit.height, greaterThanOrEqualTo(48));
    final field = tester.getRect(find.byType(UiTextarea));
    expect(field.top <= hit.top && hit.bottom <= field.bottom, isTrue, reason: '$hit inside $field');
    expect(tester.getSemantics(find.byKey(const Key('send'))).rect.height, greaterThanOrEqualTo(48));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('a tap on empty slot space focuses the field; a tap on a slot button does not', (tester) async {
    var sent = 0;
    await pumpUi(tester, _composer(onSend: () => sent++));
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    await tester.tap(find.byKey(const Key('clip')));
    await tester.pump();
    expect(editable.focusNode.hasFocus, isTrue);
    editable.focusNode.unfocus();
    await tester.pump();
    await tester.tap(find.byKey(const Key('send')));
    await tester.pump();
    expect(sent, 1);
    expect(editable.focusNode.hasFocus, isFalse);
  });

  testWidgets('slots swap sides in RTL, from Directionality, dir or dir auto on Thaana', (tester) async {
    Future<bool> leadingOnRight(Widget w) async {
      await tester.pumpWidget(const SizedBox());
      await pumpUi(tester, w);
      return tester.getRect(find.byKey(const Key('clip'))).left > tester.getRect(find.byKey(const Key('send'))).left;
    }

    expect(await leadingOnRight(_composer()), isFalse);
    expect(await leadingOnRight(Directionality(textDirection: TextDirection.rtl, child: _composer())), isTrue);
    expect(await leadingOnRight(_composer(dir: UiTextDir.rtl)), isTrue);
    expect(await leadingOnRight(_composer(dir: UiTextDir.auto, value: 'ދިވެހި')), isTrue);
    expect(await leadingOnRight(_composer(dir: UiTextDir.auto, value: 'Hi ދިވެހި')), isFalse);
    // Typing changes it.
    await tester.enterText(find.byType(EditableText), 'ދިވެހި');
    await tester.pump();
    expect(tester.getRect(find.byKey(const Key('clip'))).left > tester.getRect(find.byKey(const Key('send'))).left, isTrue);
  });

  testWidgets('focus ring and invalid border are on the whole box', (tester) async {
    await pumpUi(tester, _composer(invalid: true));
    expect(tester.widget<UiFieldFrame>(find.byType(UiFieldFrame)).invalid, isTrue);
    await tester.tap(find.byType(EditableText));
    await tester.pump();
    final frame = tester.widget<UiFieldFrame>(find.byType(UiFieldFrame));
    expect(frame.focused, isTrue);
    expect(_box(tester, find.byType(UiTextarea)).contains(tester.getRect(find.byKey(const Key('send'))).center), isTrue);
  });

  testWidgets('textStyle reaches the editor and the placeholder (an app font for Thaana)', (tester) async {
    const style = TextStyle(fontFamily: 'Faruma', fontFamilyFallback: ['Noto Sans Thaana']);
    await pumpUi(tester, const SizedBox(width: 300, child: UiTextarea(placeholder: 'ލިޔުއްވާ', textStyle: style, semanticLabel: 'Note')));
    final editor = tester.widget<EditableText>(find.byType(EditableText));
    expect(editor.style.fontFamily, 'Faruma');
    expect(editor.style.fontFamilyFallback, ['Noto Sans Thaana']);
    expect(editor.style.fontSize, isNotNull, reason: 'merged over the field style, not replacing it');
    expect(tester.widget<Text>(find.text('ލިޔުއްވާ')).style!.fontFamily, 'Faruma');
    await tester.pumpWidget(const SizedBox());
    await pumpUi(tester, const SizedBox(width: 300, child: UiInput(textStyle: style, semanticLabel: 'Name')));
    expect(tester.widget<EditableText>(find.byType(EditableText)).style.fontFamily, 'Faruma');
  });

  testWidgets('input slots: inline edges, centred, 48dp field, RTL swap', (tester) async {
    final handle = tester.ensureSemantics();
    Widget input({UiTextDir? dir}) => SizedBox(
          width: 300,
          child: UiInput(
            dir: dir,
            semanticLabel: 'Email',
            leading: UiIcon(HugeIcons.strokeRoundedMail01, key: const Key('mail')),
            trailing: UiIconButton(key: const Key('clear'), label: 'Clear', size: UiSize.sm, onPressed: () {}, icon: UiIcon(HugeIcons.strokeRoundedCancel01)),
          ),
        );
    await pumpUi(tester, input());
    expect(tester.getSize(find.byType(UiInput)).height, 48);
    final box = _box(tester, find.byType(UiInput));
    final mail = tester.getRect(find.byKey(const Key('mail')));
    expect(box.contains(mail.center), isTrue);
    expect((mail.center.dy - box.center.dy).abs(), lessThan(1));
    expect(mail.right, lessThanOrEqualTo(tester.getRect(find.byType(EditableText)).left));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await tester.pumpWidget(const SizedBox());
    await pumpUi(tester, input(dir: UiTextDir.rtl));
    expect(tester.getRect(find.byKey(const Key('mail'))).left, greaterThan(tester.getRect(find.byKey(const Key('clear'))).left));
    handle.dispose();
  });

  test('uiTextDirection follows the first strong character', () {
    expect(uiTextDirection('ދިވެހި'), TextDirection.rtl);
    expect(uiTextDirection('مرحبا'), TextDirection.rtl);
    expect(uiTextDirection('12 ދ'), TextDirection.rtl);
    expect(uiTextDirection('Hi ދ'), TextDirection.ltr);
    expect(uiTextDirection('123 !?'), isNull);
    expect(uiResolvedDir(null, 'ދ'), isNull);
    expect(uiResolvedDir(UiTextDir.ltr, 'ދ'), TextDirection.ltr);
  });

  testWidgets('golden: field slots in maldives and maldives-dark, LTR and RTL', (tester) async {
    await expectThemedGolden(tester, 'field_slots', height: 330, themes: const [UiThemeName.maldives, UiThemeName.maldivesDark], (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            _composer(value: 'Hello'),
            _composer(value: 'One\nTwo\nThree'),
            // The test font has no Thaana glyphs; Latin text shows the RTL layout as well.
            Directionality(textDirection: TextDirection.rtl, child: _composer(value: 'Right to left')),
            UiInput(
              placeholder: 'you@example.com',
              semanticLabel: 'Email',
              leading: UiIcon(HugeIcons.strokeRoundedMail01),
            ),
          ],
        ));
  });
}
