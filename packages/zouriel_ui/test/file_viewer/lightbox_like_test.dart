import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../media/media_helpers.dart';

/// onDoubleTap / leadingActions (0.63.0): a double tap likes instead of zooming, the heart pops only
/// when the app says so, and the like button in the top bar follows the item on screen.
void main() {
  testWidgets('double tap reports the item and point instead of zooming; the heart pops only when asked', (tester) async {
    final a = await testImage(tester, w: 300, h: 200, seed: 0);
    final b = await testImage(tester, w: 300, h: 200, seed: 1);
    final got = <String>[];
    var like = true;
    var index = 0;
    tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UiApp(theme: UiThemeName.dark, home: StatefulBuilder(builder: (context, set) => UiMediaLightbox(
          items: [UiMediaItem.image(a), UiMediaItem.image(b)],
          index: index,
          onIndexChanged: (i) => set(() => index = i),
          onClose: () {},
          onDoubleTap: (item, i, at) {
            got.add('double $i');
            return like;
          },
          leadingActions: (context, item, i) => Text('like for $i'),
        ))));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('like for 0'), findsOneWidget);
    // At the bottom, below the picture: never in the top bar with the actions.
    expect(tester.getCenter(find.text('like for 0')).dy, greaterThan(844 / 2));

    final centre = tester.getCenter(find.byType(UiMediaLightbox));
    await tester.tapAt(centre);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(centre);
    await tester.pump(const Duration(milliseconds: 150));
    expect(got, ['double 0']);
    expect(find.descendant(of: find.byType(UiHeartBurst), matching: find.byType(CustomPaint)), findsOneWidget);
    expect(find.textContaining('· Fit'), findsNothing); // not zoomed
    await tester.pump(const Duration(seconds: 1));

    like = false;
    await tester.tapAt(centre);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(centre);
    await tester.pump(const Duration(milliseconds: 150));
    expect(got, ['double 0', 'double 0']);
    expect(find.descendant(of: find.byType(UiHeartBurst), matching: find.byType(CustomPaint)), findsNothing);
    await tester.pump(const Duration(seconds: 1));
  });
}
