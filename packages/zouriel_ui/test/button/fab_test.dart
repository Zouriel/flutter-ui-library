import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

/// 0.44.0: UiFab top / centre placements, the danger tone and the extended text (SOS).

const _status = 32.0;

Future<void> _host(WidgetTester tester, UiFabPosition position, {TextDirection dir = TextDirection.ltr, UiFabTone tone = UiFabTone.primary, String? text, VoidCallback? onPressed, Widget? child}) async {
  tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
  tester.view.padding = FakeViewPadding(top: _status * tester.view.devicePixelRatio, bottom: 16 * tester.view.devicePixelRatio);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UiApp(
    home: Directionality(
      textDirection: dir,
      child: UiFabHost(
        position: position,
        fab: UiFab(icon: const UiIcon(HugeIcons.strokeRoundedAlert02), label: 'Emergency SOS', tone: tone, text: text, onPressed: onPressed ?? () {}),
        child: child ?? const SizedBox.expand(),
      ),
    ),
  ));
  await tester.pump();
}

BoxDecoration _decoration(WidgetTester tester) => tester
    .widgetList<AnimatedContainer>(find.descendant(of: find.byType(UiFab), matching: find.byType(AnimatedContainer)))
    .map((c) => c.decoration)
    .whereType<BoxDecoration>()
    .first;

void main() {
  testWidgets('topCenter: centred, below the status bar by the safe area plus 24', (tester) async {
    await _host(tester, UiFabPosition.topCenter);
    final r = tester.getRect(find.byType(UiFab));
    expect(r.center.dx, 195);
    expect(r.top, _status + 24);
    expect(r.top, greaterThan(_status));
  });

  testWidgets('bottomCenter: centred above the gesture bar', (tester) async {
    await _host(tester, UiFabPosition.bottomCenter);
    final r = tester.getRect(find.byType(UiFab));
    expect(r.center.dx, 195);
    expect(r.bottom, 844 - 16 - 24);
  });

  testWidgets('topEnd sits at the inline end: right in LTR, left in RTL; topStart the other way', (tester) async {
    await _host(tester, UiFabPosition.topEnd);
    var r = tester.getRect(find.byType(UiFab));
    expect(r.right, 390 - 24);
    expect(r.top, _status + 24);
    await _host(tester, UiFabPosition.topEnd, dir: TextDirection.rtl);
    r = tester.getRect(find.byType(UiFab));
    expect(r.left, 24);
    await _host(tester, UiFabPosition.topStart);
    r = tester.getRect(find.byType(UiFab));
    expect(r.left, 24);
    expect(r.top, _status + 24);
  });

  testWidgets('danger: the danger fill, a raised-surface ring and a danger halo; primary has neither', (tester) async {
    await _host(tester, UiFabPosition.topCenter, tone: UiFabTone.danger);
    final t = UiTheme.of(tester.element(find.byType(UiFab))).tokens;
    var d = _decoration(tester);
    expect(d.color, t.danger);
    expect(d.boxShadow!.where((s) => s.color == t.surfaceRaised && s.spreadRadius == 3), hasLength(1));
    expect(d.boxShadow!.where((s) => s.color == t.danger.withValues(alpha: 0.30) && s.spreadRadius == 9), hasLength(1));
    final icon = tester.widget<IconTheme>(find.descendant(of: find.byType(UiFab), matching: find.byType(IconTheme)).last);
    expect(icon.data.color, t.dangerContrast);
    await _host(tester, UiFabPosition.topCenter);
    d = _decoration(tester);
    expect(d.color, t.primary);
    expect(d.boxShadow!.where((s) => s.spreadRadius > 0), isEmpty);
  });

  testWidgets('text: an extended pill with the text after the icon, still named by its label', (tester) async {
    final sem = tester.ensureSemantics();
    var taps = 0;
    await _host(tester, UiFabPosition.topCenter, tone: UiFabTone.danger, text: 'SOS', onPressed: () => taps++);
    final r = tester.getRect(find.byType(UiFab));
    expect(r.height, 52);
    expect(r.width, greaterThan(80));
    // It hugs its icon and text: not stretched across the host.
    expect(r.width, lessThan(160));
    expect(r.center.dx, closeTo(195, 0.01));
    expect(find.text('SOS'), findsOneWidget);
    expect(tester.getRect(find.text('SOS')).left, greaterThan(tester.getRect(find.byType(UiIcon)).right));
    await tester.tap(find.bySemanticsLabel('Emergency SOS'));
    expect(taps, 1);
    sem.dispose();
  });

  testWidgets('stays above an open bottom sheet in the page: a tap over the sheet reaches the button', (tester) async {
    var taps = 0;
    await _host(
      tester,
      UiFabPosition.bottomCenter,
      tone: UiFabTone.danger,
      onPressed: () => taps++,
      child: const Stack(children: [
        SizedBox.expand(),
        UiBottomSheet(snaps: [0, 0.6], snap: 1, title: 'Results', child: SizedBox(height: 600)),
      ]),
    );
    await tester.pump(const Duration(milliseconds: 500));
    final fab = tester.getCenter(find.byType(UiFab));
    // The sheet really is under it.
    expect(tester.getRect(find.byType(UiBottomSheet)).contains(fab), isTrue);
    await tester.tapAt(fab);
    expect(taps, 1);
  });

  testWidgets('meets the tap-target, label and contrast guidelines on Android (danger, extended)', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final sem = tester.ensureSemantics();
    await _host(tester, UiFabPosition.topCenter, tone: UiFabTone.danger, text: 'SOS');
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    sem.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('golden: SOS (danger, extended), danger round and primary', (tester) async {
    await expectThemedGolden(
      tester,
      'fab_sos',
      (context) => Wrap(spacing: 24, runSpacing: 24, crossAxisAlignment: WrapCrossAlignment.center, children: [
        UiFab(icon: const UiIcon(HugeIcons.strokeRoundedAlert02), label: 'Emergency SOS', tone: UiFabTone.danger, text: 'SOS', onPressed: () {}),
        UiFab(icon: const UiIcon(HugeIcons.strokeRoundedAlert02), label: 'Emergency SOS', tone: UiFabTone.danger, onPressed: () {}),
        UiFab(icon: const UiIcon(HugeIcons.strokeRoundedAdd01), label: 'New', onPressed: () {}),
        UiFab(icon: const UiIcon(HugeIcons.strokeRoundedAlert02), label: 'SOS', tone: UiFabTone.danger, text: 'SOS', size: UiFabSize.sm, onPressed: () {}),
      ]),
      height: 140,
    );
  });

  testWidgets('UiFabHost.bottomOffset (0.47.1) lifts a bottom button above a sheet\'s peek, easing when it changes; top ones ignore it', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
    tester.view.padding = FakeViewPadding(bottom: 16 * tester.view.devicePixelRatio);
    addTearDown(tester.view.reset);
    var peek = 72.0;
    var position = UiFabPosition.bottomEnd;
    late StateSetter set;
    await tester.pumpWidget(UiApp(
      home: StatefulBuilder(builder: (context, s) {
        set = s;
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: false),
          child: UiFabHost(
            position: position,
            bottomOffset: peek,
            fab: UiFab(icon: const UiIcon(HugeIcons.strokeRoundedAdd01), label: 'New item', onPressed: () {}),
            child: const SizedBox.expand(),
          ),
        );
      }),
    ));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(UiFab)).bottom, 844 - 16 - 24 - 72);
    set(() => peek = 160);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final mid = tester.getRect(find.byType(UiFab)).bottom;
    expect(mid, lessThan(844 - 16 - 24 - 72));
    expect(mid, greaterThan(844 - 16 - 24 - 160));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(UiFab)).bottom, 844 - 16 - 24 - 160);
    set(() => position = UiFabPosition.topEnd);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(UiFab)).top, 24);
  });
}
