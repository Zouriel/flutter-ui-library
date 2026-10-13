import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

void main() {
  testWidgets('chip remove button is named after the chip and calls onRemove', (tester) async {
    final handle = tester.ensureSemantics();
    var removed = 0;
    await pumpUi(tester, UiChip(label: 'flutter', onRemove: () => removed++));
    expect(find.bySemanticsLabel('Remove flutter'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Remove flutter'));
    expect(removed, 1);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('avatar shows initials, is named, and falls back when the image fails', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, const Row(children: [
      UiAvatar(name: 'Aminath Shareef'),
      UiAvatar(name: 'Cher'),
      UiAvatar(image: _FailingImage(), name: 'Ali Zahir', alt: 'Ali'),
    ]));
    expect(find.text('AS'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('AZ'), findsOneWidget);
    expect(find.bySemanticsLabel('Ali'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('avatar group caps at max and announces the rest', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, const UiAvatarGroup(max: 2, children: [
      UiAvatar(name: 'A One'), UiAvatar(name: 'B Two'), UiAvatar(name: 'C Three'), UiAvatar(name: 'D Four'),
    ]));
    expect(find.text('+2'), findsOneWidget);
    expect(find.bySemanticsLabel('2 more'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('badges hug their text instead of stretching', (tester) async {
    await pumpUi(tester, const SizedBox(width: 300, child: Wrap(children: [UiBadge(label: 'New')])));
    expect(tester.getSize(find.byType(UiBadge)).width, lessThan(60));
    expect(tester.getSize(find.byType(UiBadge)).height, 20);
  });

  testWidgets('golden: badges, chips and avatars', (tester) async {
    await expectThemedGolden(tester, 'badge_chip_avatar', height: 360, (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        const Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          UiBadge(label: 'Neutral'), UiBadge(label: 'New', tone: UiStatus.primary), UiBadge(label: 'Active', tone: UiStatus.success),
          UiBadge(label: 'Pending', tone: UiStatus.warning), UiBadge(label: '3', tone: UiStatus.danger), UiBadge(dot: true, tone: UiStatus.success),
        ]),
        Wrap(spacing: 8, runSpacing: 8, children: [
          UiChip(label: 'Removable', onRemove: () {}),
          const UiChip(label: 'Primary', tone: UiStatus.primary),
          const UiChip(label: 'Danger', tone: UiStatus.danger),
        ]),
        const Row(spacing: 8, children: [
          UiAvatar(name: 'Aminath Shareef', size: UiSize.sm), UiAvatar(name: 'Ali Zahir'), UiAvatar(name: 'Mariyam', size: UiSize.lg), UiAvatar(name: 'Sq', square: true),
        ]),
        const UiAvatarGroup(max: 3, children: [UiAvatar(name: 'A One'), UiAvatar(name: 'B Two'), UiAvatar(name: 'C Three'), UiAvatar(name: 'D Four')]),
      ],
    ));
  });
}

/// An image that always fails to load.
class _FailingImage extends ImageProvider<_FailingImage> {
  const _FailingImage();
  @override
  Future<_FailingImage> obtainKey(ImageConfiguration configuration) => Future.value(this);
  @override
  ImageStreamCompleter loadImage(_FailingImage key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(Future.error(Exception('404')));
}
