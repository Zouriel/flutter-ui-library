import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';
import '../media/media_helpers.dart';
import 'fake_video.dart';

void main() {
  group('UiFileViewer type detection', () {
    test('kind as a type, a MIME type or an extension; else the name, else the src', () {
      UiFileType ty(String src, {String? name, String? kind}) => UiFileViewer.typeOf(src: src, name: name, kind: kind);
      expect(ty('x', kind: 'pdf'), UiFileType.pdf);
      expect(ty('x', kind: 'image/png'), UiFileType.image);
      expect(ty('x', kind: 'application/pdf'), UiFileType.pdf);
      expect(ty('x', kind: 'ts'), UiFileType.code);
      expect(ty('https://a.b/c/report.PDF?v=2'), UiFileType.pdf);
      expect(ty('https://a.b/download?id=7', name: 'clip.mp4'), UiFileType.video);
      expect(ty('song.m4a'), UiFileType.audio);
      expect(ty('notes.md'), UiFileType.text);
      expect(ty('logo.svg'), UiFileType.unknown);
      expect(ty('archive.zip'), UiFileType.unknown);
      expect(UiFileViewer.extensionFor(src: 'a/b/main.dart'), 'dart');
    });

    test('media time format', () {
      expect(uiFormatMediaTime(const Duration(seconds: 65)), '1:05');
      expect(uiFormatMediaTime(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
    });
  });

  testWidgets('UiFileViewer delegates to the matching viewer, or offers to open the file', (tester) async {
    FakeVideoPlatform.install();
    await pumpUi(tester, const SizedBox(width: 390, height: 400, child: UiFileViewer(src: 'assets/a.png')));
    expect(find.byType(UiImageViewer), findsOneWidget);
    await pumpUi(tester, const SizedBox(width: 390, height: 400, child: UiFileViewer(src: 'clip.mp4')));
    expect(find.byType(UiVideoPlayer), findsOneWidget);
    await pumpUi(tester, const SizedBox(width: 390, height: 400, child: UiFileViewer(src: 'x', name: 'tune.mp3')));
    expect(find.byType(UiAudioPlayer), findsOneWidget);
    var opened = 0;
    await pumpUi(tester, SizedBox(width: 390, height: 400, child: UiFileViewer(src: 'files/backup.zip', onOpenExternally: () => opened++)));
    expect(find.text('backup.zip'), findsOneWidget);
    expect(find.text('Preview not available for this file type.'), findsOneWidget);
    await tester.tap(find.text('Open'));
    expect(opened, 1);
  });

  group('UiImageViewer', () {
    testWidgets('zoom buttons, double tap and Fit', (tester) async {
      final img = await testImage(tester);
      await pumpUi(tester, SizedBox(width: 390, height: 400, child: UiImageViewer(image: img, alt: 'Beach')));
      expect(find.text('100%'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Zoom in'));
      await tester.pump();
      expect(find.text('125%'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Reset view'));
      await tester.pump();
      expect(find.text('100%'), findsOneWidget);
      final stage = find.bySemanticsLabel('Beach');
      await tester.tap(stage);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(stage);
      await tester.pumpAndSettle();
      expect(find.text('200%'), findsOneWidget);
      for (var i = 0; i < 7; i++) {
        await tester.tap(find.bySemanticsLabel('Zoom out'));
        await tester.pump();
      }
      expect(find.text('25%'), findsOneWidget);
      // At the floor the button is disabled.
      await tester.tap(find.bySemanticsLabel('Zoom out'));
      await tester.pump();
      expect(find.text('25%'), findsOneWidget);
    });

    testWidgets('swipe asks for the neighbour only where one exists; zoomed, a drag pans instead', (tester) async {
      final img = await testImage(tester);
      final asked = <String>[];
      Widget viewer({bool next = true, bool prev = false}) => SizedBox(
            width: 390,
            height: 400,
            child: UiImageViewer(image: img, alt: 'Beach', hasNext: next, hasPrevious: prev, onNext: () => asked.add('next'), onPrevious: () => asked.add('prev')),
          );
      await pumpUi(tester, viewer());
      final stage = find.bySemanticsLabel('Beach');
      await tester.fling(stage, const Offset(-150, 0), 1000);
      await tester.pumpAndSettle();
      expect(asked, ['next']);
      await tester.fling(stage, const Offset(150, 0), 1000);
      await tester.pumpAndSettle();
      expect(asked, ['next'], reason: 'nothing before the first image');
      expect(find.bySemanticsLabel('Previous image'), findsOneWidget);
      // Keyboard: Right asks for the next.
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(asked, ['next', 'next']);
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;

      await tester.tap(find.bySemanticsLabel('Zoom in'));
      await tester.tap(find.bySemanticsLabel('Zoom in'));
      await tester.pump();
      await tester.fling(stage, const Offset(-150, 0), 1000);
      await tester.pumpAndSettle();
      expect(asked, ['next', 'next'], reason: 'zoomed in, the drag pans');
    });

    testWidgets('bar buttons meet the touch guidelines', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final handle = tester.ensureSemantics();
      final img = await testImage(tester);
      await pumpUi(tester, SizedBox(width: 390, height: 400, child: UiImageViewer(image: img, alt: 'Beach', hasNext: true, onNext: () {})));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('players', () {
    testWidgets('video: initialises, plays, seeks, cycles speed, mutes', (tester) async {
      final fake = FakeVideoPlatform.install();
      await pumpUi(tester, const SizedBox(width: 390, child: UiVideoPlayer(src: 'https://example.com/clip.mp4')));
      expect(find.text('0:00'), findsOneWidget);
      expect(find.text('2:05'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Play'));
      await tester.pump();
      expect(fake.calls, contains('play 1'));
      expect(find.bySemanticsLabel('Pause'), findsOneWidget);
      // Tap half-way along the seek bar.
      final bar = find.byType(UiSeekBar);
      await tester.tapAt(tester.getCenter(bar));
      await tester.pump();
      expect(fake.calls.where((c) => c.startsWith('seek 1')), isNotEmpty);
      expect(int.parse(fake.calls.lastWhere((c) => c.startsWith('seek')).split(' ').last), closeTo(62, 3));
      final mute = tester.getRect(find.bySemanticsLabel('Mute'));
      await tester.tap(find.bySemanticsLabel('Playback speed 1×'));
      await tester.pump();
      expect(fake.speed[1], 1.5);
      expect(find.bySemanticsLabel('Playback speed 1.5×'), findsOneWidget);
      // The wider label keeps the button's width: nothing beside it moves.
      expect(tester.getRect(find.bySemanticsLabel('Mute')), mute);
      await tester.tap(find.bySemanticsLabel('Mute'));
      await tester.pump();
      expect(fake.volume[1], 0);
      expect(find.bySemanticsLabel('Unmute'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      expect(fake.calls, contains('dispose 1'));
    });

    testWidgets('video: an unplayable source says so', (tester) async {
      FakeVideoPlatform.install(fail: true);
      await pumpUiFrames(tester, const SizedBox(width: 390, child: UiVideoPlayer(src: 'bad.mp4')));
      expect(find.textContaining('could not be played'), findsOneWidget);
    });

    testWidgets('audio: title, play, and a seek slider for screen readers', (tester) async {
      final fake = FakeVideoPlatform.install(duration: const Duration(minutes: 3));
      final handle = tester.ensureSemantics();
      await pumpUi(tester, const SizedBox(width: 390, child: UiAudioPlayer(src: 'assets/a.mp3', title: 'Morning')));
      expect(find.text('Morning'), findsOneWidget);
      final seek = tester.getSemantics(find.bySemanticsLabel('Seek'));
      expect(seek.value, '0:00 of 3:00');
      tester.semantics.increase(find.semantics.byLabel('Seek'));
      await tester.pump();
      expect(fake.calls.last, 'seek 1 5');
      await tester.tap(find.bySemanticsLabel('Play'));
      await tester.pump();
      expect(fake.playing[1], isTrue);
      handle.dispose();
    });

    testWidgets('players meet the touch guidelines', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      FakeVideoPlatform.install();
      final handle = tester.ensureSemantics();
      await pumpUi(tester, const SizedBox(width: 390, child: Column(spacing: 16, children: [UiVideoPlayer(src: 'a.mp4'), UiAudioPlayer(src: 'a.mp3', title: 'Song')])));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('text and code', () {
    testWidgets('text viewer: content, loading then text, errors', (tester) async {
      await pumpUi(tester, const SizedBox(width: 300, child: UiTextViewer(content: 'Hello\nworld')));
      expect(find.text('Hello\nworld'), findsOneWidget);
      final done = <String, Future<String>>{};
      await pumpUi(tester, SizedBox(width: 300, child: UiTextViewer(src: 'a.txt', load: (s) => done[s] = Future.delayed(const Duration(seconds: 1), () => 'Loaded text'))));
      expect(find.text('Loading…'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.text('Loaded text'), findsOneWidget);
      await pumpUi(tester, SizedBox(width: 300, child: UiTextViewer(src: 'missing.txt', load: (_) => Future.error(Exception('HTTP 404')))));
      expect(find.text('HTTP 404'), findsOneWidget);
    });

    testWidgets('code viewer: line numbers, language label, copy', (tester) async {
      String? clip;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') clip = (call.arguments as Map)['text'] as String;
        return null;
      });
      const code = 'void main() {\n  print(1);\n}\n';
      await pumpUi(tester, const SizedBox(width: 300, child: UiCodeViewer(content: code, language: 'dart')));
      expect(find.text('1\n2\n3'), findsOneWidget, reason: 'a trailing newline is not a line');
      expect(find.text('DART'), findsOneWidget);
      await tester.tap(find.text('Copy'));
      await tester.pump();
      expect(clip, code);
      expect(find.text('Copied'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('UiFileExplorer', () {
    const root = UiFileNode.dir('project', children: [
      UiFileNode.file('readme.md'),
      UiFileNode.dir('src', children: [UiFileNode.file('main.ts'), UiFileNode.dir('empty')]),
      UiFileNode.file('Logo.png'),
      UiFileNode.dir('assets', children: [UiFileNode.file('song.mp3', url: 'https://x/song.mp3')]),
    ]);

    testWidgets('folders first, then files, by name; enter, open, crumbs, back', (tester) async {
      final opened = <String>[];
      await pumpUi(tester, SizedBox(width: 390, child: UiFileExplorer(root: root, onOpen: (n) => opened.add(n.name))));
      final names = tester.widgetList<Text>(find.descendant(of: find.byType(ListView), matching: find.byType(Text))).map((t) => t.data).toList();
      expect(names, ['assets', 'src', 'Logo.png', 'readme.md']);
      await tester.tap(find.text('src'));
      await tester.pumpAndSettle();
      expect(find.text('main.ts'), findsOneWidget);
      await tester.tap(find.text('empty'));
      await tester.pumpAndSettle();
      expect(find.text('Empty folder'), findsOneWidget);
      // The system back gesture goes up a level.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('main.ts'), findsOneWidget);
      await tester.tap(find.text('main.ts'));
      expect(opened, ['main.ts']);
      await tester.tap(find.text('project'));
      await tester.pumpAndSettle();
      expect(find.text('readme.md'), findsOneWidget);
    });

    testWidgets('rows meet the touch guidelines', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final handle = tester.ensureSemantics();
      await pumpUi(tester, SizedBox(width: 390, child: UiFileExplorer(root: root, onOpen: (_) {})));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
      debugDefaultTargetPlatformOverride = null;
    });
  });

  testWidgets('UiPdfViewer: loading, then the error in place of the page', (tester) async {
    final gate = Completer<PdfDocument>();
    final ref = PdfDocumentRefByLoader((_) => gate.future, key: PdfDocumentRefKey('test-pdf'));
    await pumpUiFrames(tester, SizedBox(width: 390, height: 400, child: UiPdfViewer(documentRef: ref)));
    expect(find.text('Loading PDF…'), findsOneWidget);
    expect(find.text('1 / —'), findsOneWidget);
    gate.completeError(Exception('Not a PDF file'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.textContaining('Not a PDF file'), findsOneWidget);
    // No pages: navigation and zoom stay disabled.
    await tester.tap(find.bySemanticsLabel('Next page'));
    await tester.pump();
    expect(find.text('1 / —'), findsOneWidget);
  });

  testWidgets('golden: image viewer, players, code, text, explorer', (tester) async {
    FakeVideoPlatform.install();
    final img = await testImage(tester, w: 320, h: 200);
    await expectThemedGoldenAfter(tester, 'file_viewers', height: 1100, (context) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 12, children: [
        UiImageViewer(image: img, alt: 'Beach', maxHeight: 230, hasNext: true, onNext: () {}),
        const UiVideoPlayer(src: 'clip.mp4', maxHeight: 120),
        const UiAudioPlayer(src: 'a.mp3', title: 'Morning tide'),
        const UiCodeViewer(language: 'ts', content: 'export function greet(name: string) {\n  return `Hello, \${name}!`; // a long line that scrolls sideways\n}'),
        const UiTextViewer(content: 'Plain text wraps at the edge of the viewer instead of scrolling sideways, like a note.'),
        const UiFileExplorer(root: UiFileNode.dir('project', children: [UiFileNode.dir('src'), UiFileNode.file('logo.png'), UiFileNode.file('notes.pdf'), UiFileNode.file('song.mp3')])),
      ]);
    }, before: (tester) async {
      await tester.runAsync(() => precacheImage(img, tester.element(find.byType(UiImageViewer).first)));
      await tester.pump(const Duration(milliseconds: 400));
    });
  });
}
