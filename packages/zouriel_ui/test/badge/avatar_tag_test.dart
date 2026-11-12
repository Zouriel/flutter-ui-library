import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

const _long = 'The Sunset Ballroom at Kurumba Maldives Resort';

/// A 160dp photo tile with the tag in its top corner, 4dp in, as on an album cover.
Widget _tile(Widget tag) => SizedBox(
      width: 160,
      height: 160,
      child: Stack(children: [
        Positioned(top: 4, left: 4, right: 4, child: Align(alignment: AlignmentDirectional.centerStart, child: tag)),
      ]),
    );

BoxDecoration _pill(WidgetTester tester) =>
    tester.widget<DecoratedBox>(find.byKey(const ValueKey('ui-avatar-tag-pill'))).decoration as BoxDecoration;

RenderParagraph _name(WidgetTester tester) => tester.renderObject<RenderParagraph>(find.byKey(const ValueKey('ui-avatar-tag-name')));

void main() {
  test('uiAvatarTagLetter takes the first letter, upper case, and ? for no name', () {
    expect(uiAvatarTagLetter('coco Palm'), 'C');
    expect(uiAvatarTagLetter('  étoile'), 'É');
    expect(uiAvatarTagLetter(''), '?');
    expect(uiAvatarTagLetter(null), '?');
  });

  testWidgets('shows the picture beside the name, without the letter', (tester) async {
    await pumpUi(tester, const UiAvatarTag(name: 'Coco Palm', image: _PendingImage()));
    expect(find.byType(Image), findsOneWidget);
    expect(tester.widget<Image>(find.byType(Image)).excludeFromSemantics, isTrue);
    expect(find.text('C'), findsNothing);
    expect(find.text('Coco Palm'), findsOneWidget);
  });

  testWidgets('shows the first letter without a picture, and when the picture fails', (tester) async {
    await pumpUi(tester, const Column(children: [
      UiAvatarTag(name: 'Bandos Hall'),
      UiAvatarTag(name: 'dharubaaruge', image: _FailingImage()),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('B'), findsOneWidget);
    expect(find.text('D'), findsOneWidget);
  });

  testWidgets('is read out as the prefix and the name, as one image', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, const Column(children: [
      UiAvatarTag(name: 'Coco Palm', prefix: 'At'),
      UiAvatarTag(name: 'Bandos Hall'),
    ]));
    expect(find.bySemanticsLabel('At Coco Palm'), findsOneWidget);
    expect(find.bySemanticsLabel('Bandos Hall'), findsOneWidget);
    expect(find.bySemanticsLabel('Coco Palm'), findsNothing);
    final data = tester.getSemantics(find.bySemanticsLabel('At Coco Palm')).getSemanticsData();
    expect(data.flagsCollection.isImage, isTrue);
    handle.dispose();
  });

  testWidgets('overlay is the media scrim with on-scrim text; plain is the raised surface', (tester) async {
    await pumpUi(tester, const UiAvatarTag(name: 'Coco Palm'));
    final t = UiThemeData(name: UiThemeName.dark).tokens;
    expect(_pill(tester).color, t.mediaScrim.withValues(alpha: 0.62));
    expect(_name(tester).text.style!.color, t.mediaOnScrim);
    expect(find.byType(BackdropFilter), findsNothing);

    await pumpUi(tester, const UiAvatarTag(name: 'Coco Palm', variant: UiAvatarTagVariant.plain));
    expect(_pill(tester).color, t.surfaceRaised);
    expect(_name(tester).text.style!.color, t.text);
  });

  testWidgets('glass follows the theme config, and its own flag over it', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const UiApp(config: UiConfig(glass: true), home: Center(child: UiAvatarTag(name: 'Coco Palm'))));
    expect(find.byType(BackdropFilter), findsOneWidget);
    await tester.pumpWidget(const UiApp(config: UiConfig(glass: true), home: Center(child: UiAvatarTag(name: 'Coco Palm', glass: false))));
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('a long name ellipsises inside a 160dp tile; a short one hugs', (tester) async {
    await pumpUi(tester, _tile(const UiAvatarTag(name: _long, size: UiAvatarTagSize.xs)));
    final tile = tester.getRect(find.byType(Stack));
    final tag = tester.getRect(find.byType(UiAvatarTag));
    expect(tag.left, greaterThanOrEqualTo(tile.left + 4));
    expect(tag.right, lessThanOrEqualTo(tile.right - 4));
    expect(_name(tester).didExceedMaxLines, isTrue);
    expect(tester.takeException(), isNull);

    await pumpUi(tester, _tile(const UiAvatarTag(name: 'Coco Palm', size: UiAvatarTagSize.xs)));
    expect(_name(tester).didExceedMaxLines, isFalse);
    expect(tester.getSize(find.byType(UiAvatarTag)).width, lessThan(100));
  });

  testWidgets('sizes: xs is a 16dp picture in a 20dp pill, sm a 20dp picture', (tester) async {
    await pumpUi(tester, const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      UiAvatarTag(key: Key('sm'), name: 'Bandos Hall'),
      UiAvatarTag(key: Key('xs'), name: 'Bandos Hall', size: UiAvatarTagSize.xs),
    ]));
    double pic(String k) => tester.getSize(find.descendant(of: find.byKey(Key(k)), matching: find.byType(ClipOval))).width;
    expect(pic('sm'), 20);
    expect(pic('xs'), 16);
    expect(tester.getSize(find.byKey(const Key('xs'))).height, 20);
  });

  testWidgets('golden: over light and dark photos, and plain', (tester) async {
    await expectThemedGolden(tester, 'avatar_tag', (context) {
      final t = context.ui;
      Widget photo(Color a, Color b, Widget tag) => SizedBox(
            width: 160,
            height: 96,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(t.radius),
                gradient: LinearGradient(colors: [a, b], begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              child: Padding(padding: const EdgeInsets.all(4), child: Align(alignment: AlignmentDirectional.topStart, child: tag)),
            ),
          );
      return Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 12, children: [
        Row(spacing: 12, children: [
          photo(t.primary, t.accent, const UiAvatarTag(name: 'Coco Palm', size: UiAvatarTagSize.xs)),
          photo(t.mediaOnScrim, t.surfaceRaised, const UiAvatarTag(name: _long, size: UiAvatarTagSize.xs)),
        ]),
        const Row(spacing: 8, children: [
          UiAvatarTag(name: 'Bandos Hall', variant: UiAvatarTagVariant.plain),
          UiAvatarTag(name: 'Bandos Hall', variant: UiAvatarTagVariant.plain, size: UiAvatarTagSize.xs),
          UiAvatarTag(name: 'Glass', variant: UiAvatarTagVariant.plain, glass: true),
        ]),
        photo(t.success, t.warning, const UiAvatarTag(name: 'Dharubaaruge', glass: true)),
      ]);
    }, height: 300);
  });
}

/// An image that never finishes loading (stands in for a network picture).
class _PendingImage extends ImageProvider<_PendingImage> {
  const _PendingImage();
  @override
  Future<_PendingImage> obtainKey(ImageConfiguration configuration) => Future.value(this);
  @override
  ImageStreamCompleter loadImage(_PendingImage key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(Completer<ImageInfo>().future);
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
