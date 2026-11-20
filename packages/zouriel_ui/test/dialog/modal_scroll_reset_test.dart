import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

/// A reused modal or sheet whose title or content is swapped must show the new content from its top.
/// Mirrors the Angular spec `modal-scroll-reset.spec.ts`.

class _Host extends StatefulWidget {
  const _Host({super.key, this.sheet = false, this.reset = true});
  final bool sheet;
  final bool reset;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool colours = false;
  String title = 'Options';

  void swap({String? newTitle, bool? toColours}) => setState(() {
        colours = toColours ?? colours;
        title = newTitle ?? title;
      });

  Widget get _content => colours
      ? Column(children: [for (var i = 0; i < 40; i++) SizedBox(key: ValueKey('c$i'), height: 50, child: const Text('Colour'))])
      : Column(children: [for (var i = 0; i < 40; i++) SizedBox(key: ValueKey('o$i'), height: 50, child: const Text('Option'))]);

  @override
  Widget build(BuildContext context) {
    // Different keys, so the two contents are different widgets to the framework (an app's @if / switch).
    final child = KeyedSubtree(key: ValueKey(colours), child: _content);
    if (widget.sheet) {
      return UiBottomSheet(snaps: const [0, 1], snap: 1, title: title, resetScroll: widget.reset, child: child);
    }
    return UiModal(title: title, resetScroll: widget.reset, child: child);
  }
}

void main() {
  for (final sheet in [false, true]) {
    final name = sheet ? 'UiBottomSheet' : 'UiModal';
    Future<ScrollController?> pump(WidgetTester tester, GlobalKey<_HostState> key, {bool reset = true}) async {
      tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(UiApp(theme: UiThemeName.light, home: Stack(children: [_Host(key: key, sheet: sheet, reset: reset)])));
      await tester.pump(const Duration(milliseconds: 400));
      return null;
    }

    double offset(WidgetTester tester) => tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;

    testWidgets('$name: swapping the content scrolls the body back to the top', (tester) async {
      final key = GlobalKey<_HostState>();
      await pump(tester, key);
      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -600));
      await tester.pump();
      expect(offset(tester), greaterThan(100));
      key.currentState!.swap(toColours: true);
      await tester.pump();
      expect(offset(tester), 0);
    });

    testWidgets('$name: a new title scrolls the body back to the top', (tester) async {
      final key = GlobalKey<_HostState>();
      await pump(tester, key);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
      await tester.pump();
      expect(offset(tester), greaterThan(100));
      key.currentState!.swap(newTitle: 'Colours');
      await tester.pump();
      expect(offset(tester), 0);
    });

    testWidgets('$name: resetScroll off keeps the position', (tester) async {
      final key = GlobalKey<_HostState>();
      await pump(tester, key, reset: false);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
      await tester.pump();
      final before = offset(tester);
      expect(before, greaterThan(100));
      key.currentState!.swap(toColours: true, newTitle: 'Colours');
      await tester.pump();
      expect(offset(tester), before);
    });
  }
}
