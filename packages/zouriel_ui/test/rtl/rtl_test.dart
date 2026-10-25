import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

// 0.46.0: every widget the Dhirumi patient apps use mirrors in right-to-left text. Each test measures
// where things land (or which way they move) in RTL, mostly against the LTR result.

const _phone = Size(390, 844);

Future<void> _pump(WidgetTester tester, Widget child, {TextDirection dir = TextDirection.rtl, Size size = _phone}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UiApp(textDirection: dir, home: Align(alignment: AlignmentDirectional.topStart, child: child)));
  await tester.pumpAndSettle();
}

/// The colour at ([x], [y]) of the RepaintBoundary keyed [key] (logical px).
Future<Color> _pixel(WidgetTester tester, Key key, double x, double y) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  final image = (await tester.runAsync(() => boundary.toImage()))!;
  final bytes = (await tester.runAsync(() => image.toByteData()))!;
  final ratio = image.width / boundary.size.width;
  final px = (x * ratio).round(), py = (y * ratio).round();
  final i = (py * image.width + px) * 4;
  final b = bytes.buffer.asUint8List();
  image.dispose();
  return Color.fromARGB(b[i + 3], b[i], b[i + 1], b[i + 2]);
}

double _distance(Color a, Color b) =>
    (a.r - b.r).abs() + (a.g - b.g).abs() + (a.b - b.b).abs();

void main() {
  group('UiApp.textDirection', () {
    Future<TextDirection> dirOf(WidgetTester tester, UiApp Function(Widget home) app) async {
      late TextDirection seen;
      await tester.pumpWidget(app(Builder(builder: (context) {
        seen = Directionality.of(context);
        return const SizedBox();
      })));
      return seen;
    }

    testWidgets('follows the locale (dv, ar are RTL), and an explicit direction wins', (tester) async {
      expect(await dirOf(tester, (h) => UiApp(home: h)), TextDirection.ltr);
      expect(await dirOf(tester, (h) => UiApp(locale: const Locale('dv'), home: h)), TextDirection.rtl);
      expect(await dirOf(tester, (h) => UiApp(locale: const Locale('ar'), home: h)), TextDirection.rtl);
      expect(await dirOf(tester, (h) => UiApp(locale: const Locale('en'), home: h)), TextDirection.ltr);
      expect(await dirOf(tester, (h) => UiApp(locale: const Locale('dv'), textDirection: TextDirection.ltr, home: h)), TextDirection.ltr);
      expect(await dirOf(tester, (h) => UiApp(textDirection: TextDirection.rtl, home: h)), TextDirection.rtl);
    });

    testWidgets("covers what the app's builder places above the navigator", (tester) async {
      late TextDirection seen;
      await tester.pumpWidget(UiApp(
        textDirection: TextDirection.rtl,
        builder: (context, child) => Stack(children: [child!, Builder(builder: (context) {
          seen = Directionality.of(context);
          return const SizedBox();
        })]),
        home: const SizedBox(),
      ));
      expect(seen, TextDirection.rtl);
    });
  });

  group('UiDrawer start / end', () {
    Future<BuildContext> host(WidgetTester tester, TextDirection dir) async {
      late BuildContext ctx;
      await _pump(tester, Builder(builder: (context) {
        ctx = context;
        return const SizedBox(width: 10, height: 10);
      }), dir: dir);
      return ctx;
    }

    for (final dir in TextDirection.values) {
      testWidgets('${dir.name}: start sits on the ${dir == TextDirection.rtl ? 'right' : 'left'} and slides in from there; end opposite', (tester) async {
        final ctx = await host(tester, dir);
        final rtl = dir == TextDirection.rtl;
        for (final side in [UiDrawerSide.start, UiDrawerSide.end]) {
          showUiDrawer<void>(context: ctx, side: side, title: 'Drawer', builder: (context) => const Text('Body'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 60));
          final moving = tester.getRect(find.byType(UiDialogScope));
          await tester.pumpAndSettle();
          final rest = tester.getRect(find.byType(UiDialogScope));
          final onRight = (side == UiDrawerSide.start) == rtl;
          expect(rest, onRight ? const Rect.fromLTWH(390 - 351, 0, 351, 844) : const Rect.fromLTWH(0, 0, 351, 844), reason: '$side');
          // Mid-slide it is still off toward its own edge.
          expect(onRight ? moving.left > rest.left : moving.left < rest.left, isTrue, reason: '$side slides from its edge');
          Navigator.pop(ctx);
          await tester.pumpAndSettle();
        }
      });
    }

    test('resolve: start / end become left / right; physical sides stay', () {
      expect(UiDrawerSide.start.resolve(TextDirection.rtl), UiDrawerSide.right);
      expect(UiDrawerSide.end.resolve(TextDirection.rtl), UiDrawerSide.left);
      expect(UiDrawerSide.start.resolve(TextDirection.ltr), UiDrawerSide.left);
      expect(UiDrawerSide.left.resolve(TextDirection.rtl), UiDrawerSide.left);
      expect(UiDrawerSide.top.resolve(TextDirection.rtl), UiDrawerSide.top);
    });
  });

  group('UiToastHost start / end', () {
    Future<UiToastController> host(WidgetTester tester, UiToastPosition? position) async {
      tester.view.physicalSize = _phone * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);
      final c = UiToastController();
      addTearDown(c.dispose);
      await tester.pumpWidget(UiApp(
        textDirection: TextDirection.rtl,
        builder: (context, child) => position == null
            ? UiToastHost(controller: c, child: child!)
            : UiToastHost(controller: c, position: position, child: child!),
        home: const SizedBox.expand(),
      ));
      return c;
    }

    testWidgets('RTL: the default (bottomEnd) sits bottom-left and slides in from the left; bottomStart bottom-right', (tester) async {
      var c = await host(tester, null);
      c.info('Saved', duration: Duration.zero);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final moving = tester.getRect(find.byType(UiToastView));
      await tester.pumpAndSettle();
      final rest = tester.getRect(find.byType(UiToastView));
      expect(rest.left, 16);
      expect(rest.bottom, 844 - 16);
      expect(moving.left, lessThan(rest.left), reason: 'enters from the left edge');

      await tester.pumpWidget(const SizedBox());
      c = await host(tester, UiToastPosition.bottomStart);
      c.info('Saved', duration: Duration.zero);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(UiToastView)).right, 390 - 16);

      await tester.pumpWidget(const SizedBox());
      c = await host(tester, UiToastPosition.topEnd);
      c.info('Saved', duration: Duration.zero);
      await tester.pumpAndSettle();
      final top = tester.getRect(find.byType(UiToastView));
      expect((top.left, top.top), (16.0, 16.0));
    });
  });

  testWidgets('UiAlert: the tone edge is on the start side (the right in RTL)', (tester) async {
    const k = ValueKey('alert');
    Future<(Color, Color)> edges(TextDirection dir) async {
      await _pump(tester, const RepaintBoundary(key: k, child: SizedBox(width: 300, child: UiAlert(message: 'Your visit is booked'))), dir: dir);
      final size = tester.getSize(find.byKey(k));
      return (await _pixel(tester, k, 1.5, size.height / 2), await _pixel(tester, k, size.width - 1.5, size.height / 2));
    }

    final (ltrLeft, ltrRight) = await edges(TextDirection.ltr);
    final (rtlLeft, rtlRight) = await edges(TextDirection.rtl);
    final info = UiTheme.of(tester.element(find.byKey(k))).tokens.info;
    expect(_distance(ltrLeft, info), lessThan(_distance(ltrRight, info)), reason: 'LTR: accent at the left');
    expect(_distance(rtlRight, info), lessThan(_distance(rtlLeft, info)), reason: 'RTL: accent at the right');
    expect(_distance(rtlRight, info), lessThan(0.15));
  });

  testWidgets('UiListItem: the selected bar is on the start side (the right in RTL)', (tester) async {
    const k = ValueKey('item');
    await _pump(tester, const RepaintBoundary(key: k, child: SizedBox(width: 300, child: UiListItem(selected: true, child: Text('Dr Aisha')))));
    final primary = UiTheme.of(tester.element(find.byKey(k))).tokens.primary;
    final size = tester.getSize(find.byKey(k));
    final right = await _pixel(tester, k, size.width - 1, size.height / 2);
    final left = await _pixel(tester, k, 1, size.height / 2);
    expect(_distance(right, primary), lessThan(_distance(left, primary)));
    expect(_distance(right, primary), lessThan(0.15));
  });

  testWidgets("UiChip: the remove button is at the chip's end (the left in RTL) with the start padding on the right", (tester) async {
    await _pump(tester, UiChip(label: 'Malé', onRemove: () {}), dir: TextDirection.ltr);
    final ltrStart = tester.getRect(find.text('Malé')).left - tester.getRect(find.byType(UiChip)).left;
    await _pump(tester, UiChip(label: 'Malé', onRemove: () {}));
    final chip = tester.getRect(find.byType(UiChip));
    final x = tester.getRect(find.byType(UiIcon).last);
    final text = tester.getRect(find.text('Malé'));
    expect(x.center.dx, lessThan(text.center.dx), reason: 'remove button left of the label');
    expect(chip.right - text.right, moreOrLessEquals(ltrStart, epsilon: 0.5), reason: 'the start padding is on the right');
  });

  testWidgets('UiAvatarGroup: the first avatar sits at the start (the right in RTL)', (tester) async {
    await _pump(tester, const UiAvatarGroup(children: [UiAvatar(name: 'Aisha Ali'), UiAvatar(name: 'Hassan Ahmed'), UiAvatar(name: 'Mariyam Musa')]));
    final first = tester.getRect(find.byType(UiAvatar).first);
    final last = tester.getRect(find.byType(UiAvatar).last);
    expect(first.left, greaterThan(last.left));
  });

  testWidgets('UiMeter: the warning tick is measured from the start edge (the right in RTL)', (tester) async {
    Future<Rect> tick(TextDirection dir) async {
      await _pump(tester, const SizedBox(width: 300, child: UiMeter(value: 30, warnAt: 25)), dir: dir);
      final ticks = find.byWidgetPredicate((w) => w is ColoredBox && w.color.a < 0.9 && w.color.a > 0.7);
      final bar = tester.getRect(find.byType(UiMeter));
      final r = tester.getRect(ticks.first);
      return Rect.fromLTRB(r.left - bar.left, 0, bar.right - r.right, 0);
    }

    final ltr = await tick(TextDirection.ltr);
    final rtl = await tick(TextDirection.rtl);
    expect(ltr.left + 1, moreOrLessEquals(300 * 0.25, epsilon: 1.5), reason: 'LTR: from the left');
    expect(rtl.right + 1, moreOrLessEquals(300 * 0.25, epsilon: 1.5), reason: 'RTL: from the right');
  });

  testWidgets('UiStepper (vertical): the line runs down the marker column at the start (the right in RTL)', (tester) async {
    await _pump(tester, const SizedBox(width: 300, child: UiStepper(axis: Axis.vertical, active: 1, steps: [UiStep(label: 'Book'), UiStep(label: 'Pay'), UiStep(label: 'Visit')])));
    final stepper = tester.getRect(find.byType(UiStepper));
    final lines = find.descendant(of: find.byType(UiStepper), matching: find.byWidgetPredicate((w) => w is Container && w.constraints?.maxWidth == 1));
    final line = tester.getRect(lines.first);
    expect(line.center.dx, greaterThan(stepper.right - 30), reason: 'line beside the right-hand markers');
  });

  testWidgets('UiCarousel: the next slide is on the left, a rightward drag goes to it, and the arrows mirror', (tester) async {
    // The arrows show on mouse platforms only.
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final slides = [for (var i = 0; i < 3; i++) UiCarouselSlide(image: MemoryImage(Uint8List(0)), alt: 'Photo ${i + 1}', caption: 'Slide ${i + 1}')];
    await _pump(tester, SizedBox(width: 390, height: 260, child: UiCarousel(slides: slides)));
    final handle = tester.ensureSemantics();
    final next = tester.getRect(find.bySemanticsLabel('Next slide'));
    final prev = tester.getRect(find.bySemanticsLabel('Previous slide'));
    expect(next.center.dx, lessThan(prev.center.dx), reason: 'next arrow on the left in RTL');
    final carousel = tester.getRect(find.byType(UiCarousel));
    final shownAt = tester.getRect(find.text('Slide 1')).left;
    // Slide 2 waits off the left edge.
    await tester.drag(find.byType(UiCarousel), const Offset(60, 0));
    await tester.pump();
    expect(tester.getRect(find.text('Slide 2')).right, lessThan(carousel.left + 60 + 1));
    await tester.pumpAndSettle();
    await tester.fling(find.byType(UiCarousel), const Offset(250, 0), 1500);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Slide 2')).left, moreOrLessEquals(shownAt, epsilon: 0.5), reason: 'a rightward drag brought slide 2 in');
    handle.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('UiIcon.matchTextDirection flips direction icons (pagination arrows) only in RTL', (tester) async {
    bool flipped(WidgetTester tester, String label) {
      final t = find.descendant(of: find.bySemanticsLabel(label), matching: find.byType(Transform));
      return t.evaluate().any((e) => (e.widget as Transform).transform.storage[0] == -1);
    }

    final handle = tester.ensureSemantics();
    await _pump(tester, UiPagination(page: 3, total: 9, onChanged: (_) {}), dir: TextDirection.ltr);
    expect(flipped(tester, 'Previous page'), isFalse);
    await _pump(tester, UiPagination(page: 3, total: 9, onChanged: (_) {}));
    expect(flipped(tester, 'Previous page'), isTrue);
    expect(flipped(tester, 'Next page'), isTrue);
    expect(tester.getRect(find.bySemanticsLabel('Previous page')).left, greaterThan(tester.getRect(find.bySemanticsLabel('Next page')).left));
    handle.dispose();
  });

  testWidgets('UiSplitter (side by side): the first pane is on the right, the divider follows it and a leftward drag grows it', (tester) async {
    // 30/70, so a divider on the wrong side would sit nowhere near the panes' border.
    await _pump(tester, const SizedBox(width: 380, height: 200, child: UiSplitter(
      initialRatio: 30,
      first: SizedBox.expand(key: ValueKey('a')),
      second: SizedBox.expand(key: ValueKey('b')),
    )));
    final a = tester.getRect(find.byKey(const ValueKey('a')));
    final box = tester.getRect(find.byType(UiSplitter));
    expect(a.right, moreOrLessEquals(box.right, epsilon: 0.5), reason: 'first pane at the start (right)');
    expect(a.width, closeTo(379 * 0.3, 0.5));
    await tester.dragFrom(Offset(a.left, 100), const Offset(-95, 0));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const ValueKey('a'))).width, closeTo(379 * 0.3 + 95, 1));
    final handle = tester.ensureSemantics();
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    final before = tester.getSize(find.byKey(const ValueKey('a'))).width;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(tester.getSize(find.byKey(const ValueKey('a'))).width, greaterThan(before), reason: 'ArrowLeft moves the divider left: the right-hand pane grows');
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
    handle.dispose();
  });

  testWidgets('UiTabs: in RTL ArrowLeft moves to the next tab', (tester) async {
    var selected = 0;
    await _pump(tester, StatefulBuilder(builder: (context, set) => SizedBox(width: 360, height: 120, child: UiTabs(
      selectedIndex: selected,
      onChanged: (i) => set(() => selected = i),
      tabs: const [UiTab(label: 'Doctors', child: SizedBox()), UiTab(label: 'Nurses', child: SizedBox()), UiTab(label: 'Clinics', child: SizedBox())],
    ))));
    expect(tester.getRect(find.text('Doctors')).left, greaterThan(tester.getRect(find.text('Nurses')).left));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(selected, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(selected, 0);
  });

  testWidgets('UiOtpInput: the cells keep left-to-right order in an RTL app', (tester) async {
    await _pump(tester, const UiOtpInput(length: 4, value: '1234'));
    final ones = tester.getRect(find.text('1'));
    final fours = tester.getRect(find.text('4'));
    expect(ones.left, lessThan(fours.left));
  });

  testWidgets('UiImagePicker: a tile badge sits at the top end (top-left in RTL)', (tester) async {
    await _pump(tester, SizedBox(width: 360, child: UiImagePicker(items: [UiImagePickerItem(id: 'a', image: MemoryImage(Uint8List(0)), label: 'Slip', badge: 'New')])));
    final badge = tester.getRect(find.text('New'));
    final tile = tester.getRect(find.ancestor(of: find.text('New'), matching: find.byType(Stack)).first);
    expect(badge.left - tile.left, lessThan(tile.right - badge.right));
  });

  testWidgets('UiScrollProgress: the bar fills from the start edge (the right in RTL)', (tester) async {
    await _pump(tester, SizedBox(width: 390, height: 400, child: UiScrollProgress(child: ListView(children: [for (var i = 0; i < 40; i++) SizedBox(height: 50, child: Text('Row $i'))]))));
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    final fill = tester.getRect(find.descendant(of: find.byType(FractionallySizedBox), matching: find.byType(DecoratedBox)).first);
    expect(fill.right, moreOrLessEquals(390, epsilon: 0.5));
    expect(fill.left, greaterThan(0));
  });

  testWidgets('UiPanelSection chevron points at the title (left in RTL) and turns down when open', (tester) async {
    await _pump(tester, const SizedBox(width: 300, child: UiPanelSection(title: 'Filters', collapsible: true, child: Text('Body'))));
    final flip = find.descendant(of: find.byType(UiPanelSection), matching: find.byType(Transform));
    expect(flip.evaluate().any((e) => (e.widget as Transform).transform.storage[0] == -1), isTrue);
    final rotation = tester.widget<AnimatedRotation>(find.byType(AnimatedRotation));
    // Open by default: a left-pointing chevron turns a quarter anticlockwise to point down.
    expect(rotation.turns, -0.25);
  });

  group('UiCodeBlock in RTL', () {
    testWidgets('the code reads left to right: its first line starts at the left of the block', (tester) async {
      await _pump(tester, const SizedBox(width: 300, child: UiCodeBlock(code: 'const a = 1;', language: 'ts')));
      final text = find.text('const a = 1;');
      expect(Directionality.of(tester.element(text)), TextDirection.ltr);
      final block = tester.getRect(find.byType(UiCodeBlock));
      final line = tester.getRect(text);
      expect(line.left - block.left, lessThan(block.right - line.right));
    });
  });
}

