import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';
import 'host.dart';

/// The hex field's EditableText (the only one in a colour picker).
Finder _hexField() => find.descendant(of: find.byType(UiColorPicker), matching: find.byType(EditableText));

void main() {
  group('hex helpers', () {
    test('normalise #rgb and rrggbb, reject partial and junk', () {
      expect(uiNormalizeHex('#ABC'), '#aabbcc');
      expect(uiNormalizeHex('3d5a80'), '#3d5a80');
      expect(uiNormalizeHex(' #3D5A80 '), '#3d5a80');
      expect(uiNormalizeHex('#3d'), isNull);
      expect(uiNormalizeHex('#3d5a8'), isNull);
      expect(uiNormalizeHex('red'), isNull);
      expect(uiColorToHex(uiHexToColor('#1b3d59')!), '#1b3d59');
    });
  });

  group('UiColorPicker', () {
    testWidgets('the hex field commits only whole colours, lower-cased', (tester) async {
      final seen = <String>[];
      await pumpUi(tester, Host<String>(initial: '#1b3d59', builder: (v, set) => UiColorPicker(value: v, onChanged: (n) { seen.add(n); set(n); })));
      await tester.enterText(_hexField(), '#3d');
      await tester.pump();
      expect(seen, isEmpty, reason: 'a partial colour is not passed on');
      await tester.enterText(_hexField(), '#3D5');
      await tester.pump();
      await tester.enterText(_hexField(), '#3D5A80');
      await tester.pump();
      expect(seen, ['#33dd55', '#3d5a80']);
    });

    testWidgets('leaving the field puts the current colour back', (tester) async {
      await pumpUi(tester, Column(children: [
        UiColorPicker(value: '#1b3d59', onChanged: (_) {}),
        UiButton(label: 'Elsewhere', onPressed: () {}),
      ]));
      await tester.enterText(_hexField(), '#12');
      await tester.pump();
      expect(tester.widget<EditableText>(_hexField()).controller.text, '#12');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(tester.widget<EditableText>(_hexField()).controller.text, '#1b3d59');
    });

    testWidgets('swatches set the colour and mark the chosen one', (tester) async {
      final handle = tester.ensureSemantics();
      String? last;
      await pumpUi(tester, Host<String>(initial: '#1b3d59', builder: (v, set) => UiColorPicker(value: v, onChanged: (n) { last = n; set(n); })));
      expect(tester.getSemantics(find.bySemanticsLabel('#1b3d59')), isSemantics(isSelected: true, isButton: true));
      await tester.tap(find.bySemanticsLabel('#a83a3f'));
      await tester.pump();
      expect(last, '#a83a3f');
      expect(tester.getSemantics(find.bySemanticsLabel('#a83a3f')), isSemantics(isSelected: true));
      expect(tester.widget<EditableText>(_hexField()).controller.text, '#a83a3f', reason: 'the field follows outside changes');
      handle.dispose();
    });

    testWidgets('the well opens a hue / saturation panel that changes the colour', (tester) async {
      final handle = tester.ensureSemantics();
      String? last;
      await pumpUi(tester, Host<String>(initial: '#ff0000', builder: (v, set) => UiColorPicker(value: v, onChanged: (n) { last = n; set(n); })));
      await tester.tap(find.bySemanticsLabel('Pick colour'));
      await tester.pumpAndSettle();
      final hue = find.bySemanticsLabel('Hue');
      expect(hue, findsOneWidget);
      // Halfway along the hue strip is cyan.
      final r = tester.getRect(hue);
      await tester.tapAt(Offset(r.left + r.width / 2, r.center.dy));
      await tester.pump();
      expect(last, '#00ffff');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.tapAt(const Offset(380, 830));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Hue'), findsNothing);
      handle.dispose();
    });

    testWidgets('disabled: no panel, swatches and field ignore input', (tester) async {
      var changed = false;
      await pumpUi(tester, UiColorPicker(value: '#1b3d59', onChanged: null, key: const Key('cp')));
      await tester.tap(find.byType(UiInteractive).first);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Hue'), findsNothing);
      expect(tester.widget<EditableText>(_hexField()).readOnly, isTrue);
      expect(changed, isFalse);
    });
  });

  group('UiFileUpload', () {
    const png = UiPickedFile(name: 'photo.PNG', size: 2048, mimeType: 'image/png');
    const pdf = UiPickedFile(name: 'doc.pdf', size: 3 * 1024 * 1024, mimeType: 'application/pdf');
    const txt = UiPickedFile(name: 'notes.txt', size: 12, mimeType: 'text/plain');

    test('accept matching: extensions, exact MIME, wildcards, empty', () {
      expect(uiFileMatchesAccept(png, '.png'), isTrue);
      expect(uiFileMatchesAccept(png, 'image/*'), isTrue);
      expect(uiFileMatchesAccept(pdf, 'image/*, .pdf'), isTrue);
      expect(uiFileMatchesAccept(txt, 'image/*,.pdf'), isFalse);
      expect(uiFileMatchesAccept(txt, 'text/plain'), isTrue);
      expect(uiFileMatchesAccept(txt, null), isTrue);
      expect(uiAcceptRules(' .PDF , image/* ,'), ['.pdf', 'image/*']);
    });

    testWidgets('tapping opens the app picker with the accept rules; files are listed with sizes', (tester) async {
      ({bool multiple, List<String> accept})? asked;
      List<UiPickedFile>? got;
      await pumpUi(tester, SizedBox(width: 360, child: UiFileUpload(
        multiple: true,
        accept: 'image/*,.pdf',
        picker: ({required multiple, required accept}) async {
          asked = (multiple: multiple, accept: accept);
          return [png, pdf];
        },
        onFilesSelected: (f) => got = f,
      )));
      await tester.tap(find.text('Tap to upload'));
      await tester.pumpAndSettle();
      expect(asked?.multiple, isTrue);
      expect(asked?.accept, ['image/*', '.pdf']);
      expect(got, [png, pdf]);
      expect(find.text('photo.PNG'), findsOneWidget);
      expect(find.text('2.0 KB'), findsOneWidget);
      expect(find.text('3.0 MB'), findsOneWidget);
    });

    testWidgets('dropped files are filtered by accept: rejects reported, single keeps the first', (tester) async {
      final key = GlobalKey<UiFileUploadState>();
      List<UiPickedFile>? got, rejected;
      await pumpUi(tester, SizedBox(width: 360, child: UiFileUpload(
        key: key,
        accept: 'image/*,.pdf',
        dropEnabled: true,
        picker: ({required multiple, required accept}) async => null,
        onFilesSelected: (f) => got = f,
        onRejected: (f) => rejected = f,
      )));
      expect(find.text(' or drag & drop', findRichText: true), findsNothing);
      expect(find.textContaining('drag & drop', findRichText: true), findsOneWidget);
      key.currentState!.addFiles([txt, pdf, png]);
      await tester.pump();
      expect(rejected, [txt]);
      expect(got, [pdf], reason: 'not multiple: only the first accepted file');
      expect(UiFileUploadState.formatSize(12), '12 B');
    });

    testWidgets('showFiles: false keeps the picked files out of the box (the app lists them itself)', (tester) async {
      final key = GlobalKey<UiFileUploadState>();
      List<UiPickedFile>? got;
      await pumpUi(tester, SizedBox(width: 360, child: UiFileUpload(
        key: key,
        multiple: true,
        showFiles: false,
        picker: ({required multiple, required accept}) async => null,
        onFilesSelected: (f) => got = f,
      )));
      key.currentState!.addFiles([png, pdf]);
      await tester.pump();
      expect(got, [png, pdf]);
      expect(find.text(png.name), findsNothing);
      expect(find.text(pdf.name), findsNothing);

      final shown = GlobalKey<UiFileUploadState>();
      await pumpUi(tester, SizedBox(width: 360, child: UiFileUpload(
        key: shown,
        multiple: true,
        picker: ({required multiple, required accept}) async => null,
      )));
      shown.currentState!.addFiles([png]);
      await tester.pump();
      expect(find.text(png.name), findsOneWidget, reason: 'listed by default');
    });

    testWidgets('disabled ignores taps and drops', (tester) async {
      final key = GlobalKey<UiFileUploadState>();
      var asked = false;
      List<UiPickedFile>? got;
      await pumpUi(tester, SizedBox(width: 360, child: UiFileUpload(
        key: key,
        enabled: false,
        picker: ({required multiple, required accept}) async { asked = true; return [png]; },
        onFilesSelected: (f) => got = f,
      )));
      await tester.tap(find.text('Tap to upload'), warnIfMissed: false);
      key.currentState!.addFiles([png]);
      await tester.pump();
      expect(asked, isFalse);
      expect(got, isNull);
    });

    // A 1x1 transparent PNG, so the preview has a real picture to decode.
    final pixel = MemoryImage(Uint8List.fromList(const [
      137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137,
      0, 0, 0, 13, 73, 68, 65, 84, 120, 156, 99, 0, 1, 0, 0, 5, 0, 1, 13, 10, 45, 180, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
    ]));

    testWidgets('with a picture: the same box shows it, tapping picks a replacement, Remove sits under it (0.79)', (tester) async {
      var asked = 0;
      var removed = 0;
      List<UiPickedFile>? got;
      await pumpUi(tester, SizedBox(width: 300, child: UiFileUpload(
        accept: 'image/*',
        preview: pixel,
        previewSemanticLabel: 'Your logo',
        previewFit: BoxFit.contain,
        previewAspectRatio: 1,
        picker: ({required multiple, required accept}) async { asked++; return [png]; },
        onFilesSelected: (f) => got = f,
        onRemove: () => removed++,
      )));
      expect(find.text('Tap to upload'), findsNothing);
      expect(find.text('Tap to change'), findsOneWidget);
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, pixel);
      expect(image.fit, BoxFit.contain);
      // Square box at the given aspect ratio.
      final box = tester.getSize(find.byType(AspectRatio));
      expect(box.width, 300);
      expect(box.height, 300);
      expect(find.bySemanticsLabel('Your logo. Tap to change'), findsOneWidget);

      await tester.tap(find.byType(Image));
      await tester.pumpAndSettle();
      expect(asked, 1);
      expect(got, [png]);
      // The picture is the feedback: no file list under it.
      expect(find.text('photo.PNG'), findsNothing);

      final remove = find.widgetWithText(UiButton, 'Remove');
      expect(remove, findsOneWidget);
      expect(tester.getTopLeft(remove).dy, greaterThanOrEqualTo(tester.getBottomLeft(find.byType(AspectRatio)).dy));
      await tester.tap(remove);
      await tester.pump();
      expect(removed, 1);
    });

    testWidgets('with a picture and no onRemove there is no Remove button; no picture is the plain dropzone', (tester) async {
      await pumpUi(tester, SizedBox(width: 300, child: UiFileUpload(
        preview: pixel,
        picker: ({required multiple, required accept}) async => null,
      )));
      expect(find.text('Remove'), findsNothing);
      expect(find.text('Tap to change'), findsOneWidget);
      await pumpUi(tester, SizedBox(width: 300, child: UiFileUpload(
        picker: ({required multiple, required accept}) async => null,
        onRemove: () {},
      )));
      expect(find.text('Tap to upload'), findsOneWidget);
      expect(find.text('Remove'), findsNothing);
      expect(find.byType(Image), findsNothing);
    });
  });

  group('UiChipInput', () {
    testWidgets('Enter and comma add trimmed chips; Backspace in an empty field removes the last', (tester) async {
      List<String>? last;
      await pumpUi(tester, SizedBox(width: 360, child: Host<List<String>>(initial: const [], builder: (v, set) => UiChipInput(value: v, label: 'Tags', onChanged: (n) { last = n; set(n); }))));
      final field = find.byType(EditableText);
      await tester.showKeyboard(field);
      tester.testTextInput.updateEditingValue(const TextEditingValue(text: '​  flutter ', selection: TextSelection.collapsed(offset: 11)));
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(last, ['flutter']);
      tester.testTextInput.updateEditingValue(const TextEditingValue(text: '​dart, web', selection: TextSelection.collapsed(offset: 10)));
      await tester.pump();
      expect(last, ['flutter', 'dart']);
      expect(tester.widget<EditableText>(field).controller.text, '​web');
      // Clear the typed text, then one more Backspace (the sentinel goes) removes the last chip.
      tester.testTextInput.updateEditingValue(const TextEditingValue(text: '​', selection: TextSelection.collapsed(offset: 1)));
      await tester.pump();
      expect(last, ['flutter', 'dart']);
      tester.testTextInput.updateEditingValue(const TextEditingValue(text: '', selection: TextSelection.collapsed(offset: 0)));
      await tester.pump();
      expect(last, ['flutter']);
      expect(tester.widget<EditableText>(field).controller.text, '​', reason: 'the sentinel is put back');
      expect(FocusManager.instance.primaryFocus, tester.widget<EditableText>(field).focusNode, reason: 'focus stays in the field');
    });

    testWidgets('Backspace at the start of typed text does not remove a chip', (tester) async {
      List<String>? last;
      await pumpUi(tester, SizedBox(width: 360, child: Host<List<String>>(initial: const ['a'], builder: (v, set) => UiChipInput(value: v, onChanged: (n) { last = n; set(n); }))));
      await tester.showKeyboard(find.byType(EditableText));
      tester.testTextInput.updateEditingValue(const TextEditingValue(text: 'xyz', selection: TextSelection.collapsed(offset: 0)));
      await tester.pump();
      expect(last, isNull);
      expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, '​xyz');
    });

    testWidgets('chip remove buttons remove that chip; placeholder only when empty', (tester) async {
      final handle = tester.ensureSemantics();
      List<String>? last;
      await pumpUi(tester, SizedBox(width: 360, child: Host<List<String>>(initial: const ['one', 'two', 'two'], builder: (v, set) => UiChipInput(value: v, onChanged: (n) { last = n; set(n); }))));
      expect(find.text('Add tag…'), findsNothing);
      await tester.tap(find.bySemanticsLabel('Remove one'));
      await tester.pump();
      expect(last, ['two', 'two'], reason: 'duplicates are kept');
      await tester.pumpWidget(UiApp(home: Align(alignment: Alignment.topLeft, child: SizedBox(width: 360, child: UiChipInput(value: const [], onChanged: (_) {})))));
      expect(find.text('Add tag…'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('tapping the box focuses the field; disabled ignores it', (tester) async {
      await pumpUi(tester, SizedBox(width: 360, child: UiChipInput(value: const ['a'], onChanged: (_) {})));
      await tester.tapAt(tester.getRect(find.byType(UiChipInput)).centerRight - const Offset(8, 0));
      await tester.pump();
      expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus, isTrue);

      await pumpUi(tester, SizedBox(width: 360, child: const UiChipInput(value: ['a'], onChanged: null)));
      expect(find.bySemanticsLabel('Remove a'), findsNothing);
      expect(tester.widget<EditableText>(find.byType(EditableText)).readOnly, isTrue);
    });
  });

  group('UiTokenInput', () {
    final key = GlobalKey<UiTokenInputState>();
    EditableText editable(WidgetTester tester) => tester.widget<EditableText>(find.byType(EditableText));

    testWidgets('renders runs with chips, reports typed text as runs', (tester) async {
      List<UiTokenRun>? last;
      await pumpUi(tester, SizedBox(width: 360, child: Host<List<UiTokenRun>>(
        initial: const [UiTokenRun.text('Hi '), UiTokenRun.token('guest.name'), UiTokenRun.text('!')],
        builder: (v, set) => UiTokenInput(key: key, value: v, label: 'Message', tokenLabel: (t) => t == 'guest.name' ? 'Guest name' : t, onChanged: (n) { last = n; set(n); }),
      )));
      expect(find.text('Guest name'), findsOneWidget);
      expect(editable(tester).controller.text, 'Hi ￼!');
      await tester.showKeyboard(find.byType(EditableText));
      tester.testTextInput.updateEditingValue(const TextEditingValue(text: 'Hi ￼! Bye', selection: TextSelection.collapsed(offset: 9)));
      await tester.pump();
      expect(last, const [UiTokenRun.text('Hi '), UiTokenRun.token('guest.name'), UiTokenRun.text('! Bye')]);
    });

    testWidgets('one Backspace after a chip removes the whole token', (tester) async {
      List<UiTokenRun>? last;
      await pumpUi(tester, SizedBox(width: 360, child: Host<List<UiTokenRun>>(
        initial: const [UiTokenRun.text('a'), UiTokenRun.token('x'), UiTokenRun.text('b')],
        builder: (v, set) => UiTokenInput(value: v, onChanged: (n) { last = n; set(n); }),
      )));
      await tester.showKeyboard(find.byType(EditableText));
      editable(tester).controller.selection = const TextSelection.collapsed(offset: 2);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      expect(last, const [UiTokenRun.text('ab')]);
    });

    testWidgets('insertToken goes at the caret, or at the end before the field had focus', (tester) async {
      List<UiTokenRun>? last;
      await pumpUi(tester, SizedBox(width: 360, child: Host<List<UiTokenRun>>(
        initial: const [UiTokenRun.text('Dear ,')],
        builder: (v, set) => UiTokenInput(key: key, value: v, onChanged: (n) { last = n; set(n); }),
      )));
      key.currentState!.insertToken('end');
      await tester.pump();
      expect(last, const [UiTokenRun.text('Dear ,'), UiTokenRun.token('end')]);
      await tester.showKeyboard(find.byType(EditableText));
      editable(tester).controller.selection = const TextSelection.collapsed(offset: 5);
      key.currentState!.insertToken('name');
      await tester.pump();
      expect(last, const [UiTokenRun.text('Dear '), UiTokenRun.token('name'), UiTokenRun.text(','), UiTokenRun.token('end')]);
      expect(editable(tester).controller.selection, const TextSelection.collapsed(offset: 6));
    });

    testWidgets('Ctrl+B / Ctrl+I toggle marks on the selection and for what is typed next', (tester) async {
      List<UiTokenRun>? last;
      await pumpUi(tester, SizedBox(width: 360, child: Host<List<UiTokenRun>>(
        initial: const [UiTokenRun.text('hello world')],
        builder: (v, set) => UiTokenInput(value: v, onChanged: (n) { last = n; set(n); }),
      )));
      await tester.showKeyboard(find.byType(EditableText));
      editable(tester).controller.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(last, const [UiTokenRun.text('hello', bold: true), UiTokenRun.text(' world')]);
      // Collapsed caret at the end: Ctrl+I then typing makes italic text.
      editable(tester).controller.selection = const TextSelection.collapsed(offset: 11);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      tester.testTextInput.updateEditingValue(const TextEditingValue(text: 'hello world!', selection: TextSelection.collapsed(offset: 12)));
      await tester.pump();
      expect(last, const [UiTokenRun.text('hello', bold: true), UiTokenRun.text(' world'), UiTokenRun.text('!', italic: true)]);
    });

    testWidgets('typed text never makes chips: object characters are stripped', (tester) async {
      List<UiTokenRun>? last;
      await pumpUi(tester, SizedBox(width: 360, child: Host<List<UiTokenRun>>(
        initial: const [UiTokenRun.token('t')],
        builder: (v, set) => UiTokenInput(value: v, onChanged: (n) { last = n; set(n); }),
      )));
      await tester.showKeyboard(find.byType(EditableText));
      tester.testTextInput.updateEditingValue(const TextEditingValue(text: '￼a￼b', selection: TextSelection.collapsed(offset: 4)));
      await tester.pump();
      expect(editable(tester).controller.text, '￼ab');
      expect(last, const [UiTokenRun.token('t'), UiTokenRun.text('ab')]);
    });

    testWidgets('single-line: Ctrl+V pastes plain text with line breaks folded to spaces', (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.getData') return {'text': 'one \n  two\nthree'};
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      List<UiTokenRun>? last;
      await pumpUi(tester, SizedBox(width: 360, child: Host<List<UiTokenRun>>(
        initial: const [UiTokenRun.text('>')],
        builder: (v, set) => UiTokenInput(value: v, multiline: false, onChanged: (n) { last = n; set(n); }),
      )));
      await tester.showKeyboard(find.byType(EditableText));
      editable(tester).controller.selection = const TextSelection.collapsed(offset: 1);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(last, const [UiTokenRun.text('>one two three')]);
    });

    testWidgets('tapping a chip reports it', (tester) async {
      String? tapped;
      await pumpUi(tester, SizedBox(width: 360, child: UiTokenInput(
        value: const [UiTokenRun.text('Hi '), UiTokenRun.token('who')], onChanged: (_) {}, onTokenTap: (t) => tapped = t)));
      await tester.tap(find.text('who'));
      expect(tapped, 'who');
    });

    test('normalizeRuns merges like marks and drops empties; JSON round-trips', () {
      expect(uiNormalizeRuns(const [UiTokenRun.text('a'), UiTokenRun.text(''), UiTokenRun.text('b'), UiTokenRun.text('c', bold: true), UiTokenRun.token('x'), UiTokenRun.text('d')]),
          const [UiTokenRun.text('ab'), UiTokenRun.text('c', bold: true), UiTokenRun.token('x'), UiTokenRun.text('d')]);
      expect(const UiTokenRun.token('x', italic: true).toJson(), {'token': 'x', 'italic': true});
      expect(UiTokenRun.fromJson(const {'text': 'hi', 'bold': true}), const UiTokenRun.text('hi', bold: true));
    });
  });

  testWidgets('meets the Android tap-target, labelled-target and contrast guidelines', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final handle = tester.ensureSemantics();
    await pumpUi(tester, Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 12, children: [
        UiColorPicker(value: '#1b3d59', onChanged: (_) {}),
        UiFileUpload(picker: ({required multiple, required accept}) async => null, accept: '.pdf'),
        UiChipInput(value: const ['design', 'mobile'], label: 'Tags', onChanged: (_) {}),
        UiTokenInput(value: const [UiTokenRun.text('Hello '), UiTokenRun.token('name')], label: 'Greeting', onChanged: (_) {}),
      ]),
    ));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('golden: colour picker, file upload, chip input, token input', (tester) async {
    await expectThemedGolden(tester, 'fields', height: 600, (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        UiColorPicker(value: '#6a97c0', onChanged: (_) {}),
        UiFileUpload(picker: ({required multiple, required accept}) async => null, accept: 'image/*,.pdf', acceptLabel: 'PNG, JPEG or PDF', dropEnabled: true),
        UiChipInput(value: const ['design', 'mobile', 'a rather long tag'], onChanged: (_) {}),
        UiChipInput(value: const [], invalid: true, onChanged: (_) {}),
        UiTokenInput(
          value: const [UiTokenRun.text('Dear '), UiTokenRun.token('guest.name'), UiTokenRun.text(', see you on '), UiTokenRun.token('event.date', bold: true), UiTokenRun.text('.', bold: true)],
          tokenLabel: (t) => t == 'guest.name' ? 'Guest name' : 'Event date',
          onChanged: (_) {},
        ),
        UiTokenInput(value: const [], placeholder: 'Subject line', multiline: false, onChanged: (_) {}),
      ],
    ));
  });

  testWidgets('golden: file upload with chosen files, and the open colour panel', (tester) async {
    final upload = GlobalKey<UiFileUploadState>();
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(390, 520) * 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UiApp(theme: UiThemeName.light, home: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 16, children: [
        UiFileUpload(key: upload, multiple: true, picker: ({required multiple, required accept}) async => null),
        UiColorPicker(value: '#2e6b50', onChanged: (_) {}),
      ]),
    )));
    upload.currentState!.addFiles(const [
      UiPickedFile(name: 'invitation-final-v3-with-a-very-long-name-that-must-ellipsize.pdf', size: 482113),
      UiPickedFile(name: 'photo.png', size: 912),
    ]);
    upload.currentState!.setDragOver(true);
    await tester.tap(find.bySemanticsLabel('Pick colour'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(UiApp), matchesGoldenFile('goldens/fields_open.png'));
  });

  testWidgets('golden: file upload with a picture in it (photo + Remove, logo contained) (0.79)', (tester) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(390, 560) * 2;
    addTearDown(tester.view.reset);
    final photo = MemoryImage(Uint8List.fromList(const [
      137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 8, 0, 0, 0, 4, 8, 6, 0, 0, 0, 179, 205, 126, 240, 0,
      0, 0, 47, 73, 68, 65, 84, 120, 156, 99, 216, 98, 19, 245, 127, 75, 64, 212, 255, 45, 41, 81, 255, 183, 84, 68, 253, 223, 210,
      19, 245, 127, 203, 130, 168, 255, 91, 182, 68, 253, 223, 114, 34, 234, 63, 3, 237, 21, 0, 0, 221, 96, 81, 225, 225, 53, 211,
      73, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
    ]));
    Future<List<UiPickedFile>?> none({required bool multiple, required List<String> accept}) async => null;
    await tester.pumpWidget(UiApp(theme: UiThemeName.light, home: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 16, children: [
        UiFileUpload(picker: none, preview: photo, previewSemanticLabel: 'Cover picture', onRemove: () {}),
        Align(alignment: Alignment.centerLeft,
            child: SizedBox(width: 140, child: UiFileUpload(picker: none, preview: photo, previewFit: BoxFit.contain, previewAspectRatio: 1))),
      ]),
    )));
    await tester.runAsync(() async {
      for (final e in find.byType(Image).evaluate()) {
        await precacheImage(photo, e);
      }
    });
    await tester.pumpAndSettle();
    await expectLater(find.byType(UiApp), matchesGoldenFile('goldens/fields_upload_preview.png'));
  });
}
