import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

/// 0.41.3: onCoverChanged follows every change of the sheet's resting top, not only snap changes.
/// Found by Dhirumi's nurse app: an SOS button appearing at the peek made the app's content-sized
/// peek snap taller (new snaps, same index), and the map's insets stayed at the old height.

/// A page that sizes its first snap to [peek] px of content, as the nurse app does.
class _Page extends StatefulWidget {
  const _Page({required this.covers});
  final List<double> covers;
  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  double peek = 160;
  double inset = 0;
  void setPeek(double v) => setState(() => peek = v);
  void touch() => setState(() {});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final room = box.maxHeight - inset;
        return Stack(children: [
          UiBottomSheet(
            snaps: [peek / room, 1],
            snap: 0,
            closable: false,
            topInset: inset,
            onCoverChanged: widget.covers.add,
            child: SizedBox(height: peek),
          ),
        ]);
      });
}

void main() {
  testWidgets('content growing at a resting snap (new snaps, same index): the cover follows, once per change', (tester) async {
    final dpr = tester.view.devicePixelRatio;
    tester.view.physicalSize = const Size(390, 844) * dpr;
    addTearDown(tester.view.reset);
    final covers = <double>[];
    await tester.pumpWidget(UiApp(theme: UiThemeName.maldives, home: _Page(covers: covers)));
    await tester.pumpAndSettle();
    expect(covers.last, closeTo(160, 0.01));
    final state = tester.state<_PageState>(find.byType(_Page));

    state.setPeek(230); // the SOS button appears under the step button
    await tester.pumpAndSettle();
    expect(covers.last, closeTo(230, 0.01), reason: 'the map inset must follow the taller peek');
    final sheetTop = tester.getRect(find.byType(DraggableScrollableSheet)).bottom - covers.last;
    expect(sheetTop, closeTo(844 - 230, 1));

    state.setPeek(120);
    await tester.pumpAndSettle();
    expect(covers.last, closeTo(120, 0.01));

    // Nothing moved: no repeat reports.
    final n = covers.length;
    state.touch();
    await tester.pumpAndSettle();
    expect(covers.length, n);
  });

  testWidgets('the keyboard and the room changing without a snap change: the cover follows', (tester) async {
    final dpr = tester.view.devicePixelRatio;
    tester.view.physicalSize = const Size(390, 844) * dpr;
    addTearDown(tester.view.reset);
    final covers = <double>[];
    await tester.pumpWidget(UiApp(
      theme: UiThemeName.maldives,
      home: Stack(children: [UiBottomSheet(snaps: const [0.5, 1], snap: 0, closable: false, onCoverChanged: covers.add, child: const SizedBox(height: 100))]),
    ));
    await tester.pumpAndSettle();
    expect(covers.last, closeTo(422, 0.01));
    tester.view.viewInsets = FakeViewPadding(bottom: 300 * dpr);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    // Half of the 544 px above the keyboard, plus the keyboard it rests on.
    expect(covers.last, closeTo(272 + 300, 0.01));
  });
}
