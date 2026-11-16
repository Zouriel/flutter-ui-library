import 'dart:ui' show Tristate;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

// 0.87.0: UiLinkScope, UiButton / UiIconButton href, UiLink and UiButton current.

TextStyle _style(WidgetTester tester, String text) => tester.renderObject<RenderParagraph>(find.text(text)).text.style!;

Widget _scoped(List<String> went, Widget child, {bool Function(String)? isCurrent}) => UiLinkScope(navigate: went.add, isCurrent: isCurrent, child: child);

const _icon = UiIcon(HugeIcons.strokeRoundedHome01);

BoxDecoration _box(WidgetTester tester, String text) =>
    tester.widget<AnimatedContainer>(find.ancestor(of: find.text(text), matching: find.byType(AnimatedContainer)).first).decoration! as BoxDecoration;

void main() {
  group('UiLinkScope', () {
    testWidgets('maybeOf finds the nearest scope, null without one', (tester) async {
      UiLinkScope? found;
      await pumpUi(tester, Builder(builder: (context) {
        found = UiLinkScope.maybeOf(context);
        return const SizedBox();
      }));
      expect(found, isNull);
      await pumpUi(tester, _scoped([], Builder(builder: (context) {
        found = UiLinkScope.maybeOf(context);
        return const SizedBox();
      }), isCurrent: (h) => h == '/a'));
      expect(found, isNotNull);
      expect(found!.current('/a'), isTrue);
      expect(found!.current('/b'), isFalse);
      expect(UiLinkScope(navigate: (_) {}, child: const SizedBox()).current('/a'), isFalse, reason: 'no isCurrent: never current');
    });
  });

  group('UiButton / UiIconButton href', () {
    testWidgets('a tap goes through the scope when there is no onPressed', (tester) async {
      final went = <String>[];
      await pumpUi(tester, _scoped(went, Row(mainAxisSize: MainAxisSize.min, children: const [
        UiButton(label: 'Media', href: '/media', onPressed: null),
        UiIconButton(icon: _icon, label: 'Home', href: '/', onPressed: null),
      ])));
      await tester.tap(find.text('Media'));
      await tester.tap(find.byType(UiIconButton));
      expect(went, ['/media', '/']);
    });

    testWidgets('onPressed still wins over the href', (tester) async {
      final went = <String>[];
      var pressed = 0;
      await pumpUi(tester, _scoped(went, Row(mainAxisSize: MainAxisSize.min, children: [
        UiButton(label: 'Media', href: '/media', onPressed: () => pressed++),
        UiIconButton(icon: _icon, label: 'Home', href: '/', onPressed: () => pressed++),
      ])));
      await tester.tap(find.text('Media'));
      await tester.tap(find.byType(UiIconButton));
      expect(pressed, 2);
      expect(went, isEmpty);
    });

    testWidgets('no scope: a tap does nothing and nothing breaks', (tester) async {
      await pumpUi(tester, const Row(mainAxisSize: MainAxisSize.min, children: [
        UiButton(label: 'Media', href: '/media', onPressed: null),
        UiIconButton(icon: _icon, label: 'Home', href: '/', onPressed: null),
      ]));
      await tester.tap(find.text('Media'));
      await tester.tap(find.byType(UiIconButton));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('semantics: a link with its address, not a button', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, _scoped([], Row(mainAxisSize: MainAxisSize.min, children: [
        const UiButton(label: 'Media', href: '/media', onPressed: null),
        const UiIconButton(icon: _icon, label: 'Home', href: '/', onPressed: null),
        UiButton(label: 'Save', onPressed: () {}),
      ])));
      for (final (label, url) in [('Media', '/media'), ('Home', '/')]) {
        final data = tester.getSemantics(find.bySemanticsLabel(label)).getSemanticsData();
        expect(data.flagsCollection.isLink, isTrue, reason: label);
        expect(data.flagsCollection.isButton, isFalse, reason: label);
        expect(data.linkUrl, Uri.parse(url), reason: label);
        expect(data.hasAction(SemanticsAction.tap), isTrue, reason: label);
      }
      // Its twin: a button without an href stays a button.
      final save = tester.getSemantics(find.bySemanticsLabel('Save')).getSemanticsData();
      expect(save.flagsCollection.isButton, isTrue);
      expect(save.flagsCollection.isLink, isFalse);
      handle.dispose();
    });

    testWidgets('guidelines: link buttons keep the tap target and a name', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, _scoped([], const Row(mainAxisSize: MainAxisSize.min, children: [
        UiButton(label: 'Media', href: '/media', onPressed: null),
        UiIconButton(icon: _icon, label: 'Home', href: '/', onPressed: null),
      ])));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });

  group('UiLink through the scope', () {
    testWidgets('no onTap: a tap hands the href to the scope; onTap wins', (tester) async {
      final went = <String>[];
      var taps = 0;
      await pumpUi(tester, _scoped(went, Column(mainAxisSize: MainAxisSize.min, children: [
        const UiLink('Media', href: '/media'),
        UiLink('Docs', href: '/docs', onTap: () => taps++),
      ])));
      await tester.tap(find.text('Media'));
      await tester.tap(find.text('Docs'));
      expect(went, ['/media']);
      expect(taps, 1);
    });

    testWidgets('no scope: a tap does nothing and nothing breaks', (tester) async {
      await pumpUi(tester, const UiLink('Media', href: '/media'));
      await tester.tap(find.text('Media'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('current page', () {
    testWidgets('UiLink: current from the scope, or set; selected semantics; the current look', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, _scoped([], const Column(mainAxisSize: MainAxisSize.min, children: [
        UiLink('Media', href: '/media'),
        UiLink('News', href: '/news'),
        UiLink('Set', current: true),
        UiLink('Away', href: '/media', external: true),
        UiLink('Off', href: '/media', current: false),
      ]), isCurrent: (h) => h == '/media'));
      final t = tester.element(find.text('Media')).ui;
      bool selected(String l) => tester.getSemantics(find.bySemanticsLabel(RegExp('^$l'))).getSemanticsData().flagsCollection.isSelected == Tristate.isTrue;
      expect(selected('Media'), isTrue);
      expect(selected('Set'), isTrue);
      expect(selected('News'), isFalse);
      expect(selected('Away'), isFalse, reason: 'an external link is never asked');
      expect(selected('Off'), isFalse, reason: 'current: false wins over the scope');
      final on = _style(tester, 'Media'), off = _style(tester, 'News');
      expect(on.color, t.text);
      expect(on.fontWeight, FontWeight.w600);
      expect(on.decoration, TextDecoration.underline);
      expect(on.decorationColor, t.text, reason: 'a solid underline');
      expect(on.decorationThickness, 2);
      expect(off.color, t.primary);
      expect(off.fontWeight, isNot(FontWeight.w600));
      expect(off.decorationColor!.a, lessThan(1));
      handle.dispose();
    });

    testWidgets('UiButton: ghost and outline take the selected background and primary text', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, _scoped([], const Column(mainAxisSize: MainAxisSize.min, children: [
        UiButton(label: 'Media', href: '/media', variant: UiButtonVariant.ghost, onPressed: null),
        UiButton(label: 'Outline', href: '/media', variant: UiButtonVariant.outline, onPressed: null),
        UiButton(label: 'News', href: '/news', variant: UiButtonVariant.ghost, onPressed: null),
        UiButton(label: 'Primary', href: '/media', onPressed: null),
        UiButton(label: 'Forced', current: true, variant: UiButtonVariant.ghost, onPressed: null),
      ]), isCurrent: (h) => h == '/media'));
      final t = tester.element(find.text('Media')).ui;
      bool selected(String l) => tester.getSemantics(find.bySemanticsLabel(l)).getSemanticsData().flagsCollection.isSelected == Tristate.isTrue;
      expect(selected('Media'), isTrue);
      expect(selected('Primary'), isTrue);
      expect(selected('Forced'), isTrue);
      expect(selected('News'), isFalse);
      expect(_box(tester, 'Media').color, t.selected);
      expect(_box(tester, 'Outline').color, t.selected);
      expect(_box(tester, 'Outline').border, Border.all(color: t.border));
      expect(_style(tester, 'Media').color, t.primary);
      expect(_box(tester, 'News').color, isNull);
      expect(_style(tester, 'News').color, t.text);
      // A filled variant keeps its own look; only its semantics (and weight) say current.
      expect(_box(tester, 'Primary').color, t.primary);
      expect(_style(tester, 'Media').fontWeight, FontWeight.w600);
      expect(_style(tester, 'News').fontWeight, FontWeight.w500);
      handle.dispose();
    });

    testWidgets('UiButton link variant: the text colour and a heavier underline', (tester) async {
      await pumpUi(tester, _scoped([], const Column(mainAxisSize: MainAxisSize.min, children: [
        UiButton(label: 'Media', href: '/media', variant: UiButtonVariant.link, onPressed: null),
        UiButton(label: 'News', href: '/news', variant: UiButtonVariant.link, onPressed: null),
      ]), isCurrent: (h) => h == '/media'));
      final t = tester.element(find.text('Media')).ui;
      expect(_style(tester, 'Media').color, t.text);
      expect(_style(tester, 'Media').decorationThickness, 2);
      expect(_style(tester, 'News').color, t.primary);
      expect(_style(tester, 'News').decorationThickness, isNot(2));
    });

    testWidgets('UiIconButton: current from the scope, selected semantics and background', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, _scoped([], const Row(mainAxisSize: MainAxisSize.min, children: [
        UiIconButton(icon: _icon, label: 'Home', href: '/', onPressed: null),
        UiIconButton(icon: _icon, label: 'Media', href: '/media', onPressed: null),
        UiIconButton(icon: _icon, label: 'Off', href: '/', current: false, onPressed: null),
      ]), isCurrent: (h) => h == '/'));
      final t = tester.element(find.byType(UiIconButton).first).ui;
      bool selected(String l) => tester.getSemantics(find.bySemanticsLabel(l)).getSemanticsData().flagsCollection.isSelected == Tristate.isTrue;
      expect(selected('Home'), isTrue);
      expect(selected('Media'), isFalse);
      expect(selected('Off'), isFalse, reason: 'current: false wins over the scope');
      BoxDecoration box(int i) => tester.widget<AnimatedContainer>(find.descendant(of: find.byType(UiIconButton).at(i), matching: find.byType(AnimatedContainer)).first).decoration! as BoxDecoration;
      expect(box(0).color, t.selected);
      expect(box(1).color, isNull);
      handle.dispose();
    });

    testWidgets('golden: current link and current ghost / outline buttons', (tester) async {
      await expectThemedGolden(
        tester,
        'link_current',
        (context) => _scoped([], const Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 12, children: [
          Row(spacing: 16, children: [UiLink('Home', href: '/'), UiLink('Media', href: '/media'), UiLink('News', href: '/news')]),
          Row(spacing: 8, children: [
            UiButton(label: 'Home', href: '/', variant: UiButtonVariant.ghost, onPressed: null),
            UiButton(label: 'Media', href: '/media', variant: UiButtonVariant.ghost, onPressed: null),
            UiButton(label: 'News', href: '/news', variant: UiButtonVariant.outline, onPressed: null),
          ]),
          Row(spacing: 8, children: [
            UiButton(label: 'Media', icon: UiIcon(HugeIcons.strokeRoundedImage01), href: '/media', variant: UiButtonVariant.outline, onPressed: null),
            UiButton(label: 'News', href: '/news', variant: UiButtonVariant.outline, onPressed: null),
            UiIconButton(icon: _icon, label: 'Media', href: '/media', onPressed: null),
            UiButton(label: 'Media', href: '/media', variant: UiButtonVariant.link, onPressed: null),
          ]),
        ]), isCurrent: (h) => h == '/media'),
        height: 210,
      );
    });
  });
}
