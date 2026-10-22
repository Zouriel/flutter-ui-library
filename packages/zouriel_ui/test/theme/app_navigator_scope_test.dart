import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

/// 0.44.1: widgets placed by UiApp.builder sit above the app's Navigator (an SOS fab that floats over
/// dialogs and drawers); the library's dialogs opened from there use the app's navigator.

Widget _sos(List<String> log) => UiFab(
      icon: const UiIcon(HugeIcons.strokeRoundedAlert02),
      label: 'Emergency SOS',
      text: 'SOS',
      tone: UiFabTone.danger,
      hold: const Duration(seconds: 2),
      confirmTitle: 'Send an SOS?',
      confirmLabel: 'Send SOS',
      destructive: true,
      onPressed: () => log.add('sos'),
    );

Widget _app(List<String> log, {GlobalKey<NavigatorState>? navigatorKey}) => UiApp(
      theme: UiThemeName.light,
      navigatorKey: navigatorKey,
      home: const Center(child: Text('Job')),
      builder: (context, child) => UiFabHost(position: UiFabPosition.topEnd, fab: _sos(log), child: child!),
    );

void main() {
  testWidgets('a held fab in UiApp.builder: a tap opens its confirm on the app navigator, which sends once', (tester) async {
    final log = <String>[];
    await tester.pumpWidget(_app(log));
    await tester.tap(find.byType(UiFab));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Send an SOS?'), findsOneWidget);
    await tester.tap(find.text('Send SOS'));
    await tester.pumpAndSettle();
    expect(log, ['sos']);
    expect(find.text('Send an SOS?'), findsNothing);
    expect(find.text('Job'), findsOneWidget, reason: 'the page under it is still there');
  });

  testWidgets("the app's own navigatorKey is the one used", (tester) async {
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_app(<String>[], navigatorKey: key));
    await tester.tap(find.byType(UiFab));
    await tester.pumpAndSettle();
    expect(key.currentState!.canPop(), isTrue, reason: 'the confirm was pushed onto the given navigator');
  });

  testWidgets('showUiConfirm, showUiModal and showUiDrawer open from above the navigator', (tester) async {
    late BuildContext above;
    await tester.pumpWidget(UiApp(
      theme: UiThemeName.light,
      home: const SizedBox(),
      builder: (context, child) => Stack(children: [
        child!,
        Builder(builder: (context) {
          above = context;
          return const SizedBox();
        }),
      ]),
    ));
    expect(Navigator.maybeOf(above), isNull, reason: 'really above the Navigator');

    final answer = showUiConfirm(context: above, title: 'Sure?', confirmLabel: 'Yes');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    expect(await answer, isTrue);

    showUiModal<void>(context: above, title: 'Modal', builder: (_) => const Text('In the modal'));
    await tester.pumpAndSettle();
    expect(find.text('In the modal'), findsOneWidget);
    uiNavigatorOf(above).pop();
    await tester.pumpAndSettle();

    showUiDrawer<void>(context: above, title: 'Drawer', builder: (_) => const Text('In the drawer'));
    await tester.pumpAndSettle();
    expect(find.text('In the drawer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('with no navigator anywhere it still throws as Navigator.of does', (tester) async {
    late BuildContext bare;
    await tester.pumpWidget(Builder(builder: (context) {
      bare = context;
      return const SizedBox();
    }));
    expect(() => uiNavigatorOf(bare), throwsA(isA<FlutterError>()));
  });
}
