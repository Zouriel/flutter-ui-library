import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

const _roles = [
  UiComboboxOption(label: 'VIP', value: 'vip'),
  UiComboboxOption(label: 'Family', value: 'family'),
  UiComboboxOption(label: 'Host', value: 'host'),
];

const _menuItems = [
  UiMenuItem(label: 'Edit', value: 'edit'),
  UiMenuItem(label: 'Remove', value: 'remove', danger: true),
];

void main() {
  group('OverlayPortal popups inside showUiModal', () {
    testWidgets('UiPhoneInput country picker paints, receives taps, and Escape closes only the picker', (tester) async {
      tester.view.physicalSize = const Size(800, 700) * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);

      String? phone;
      String? pickedCountry;
      late BuildContext hostContext;

      await tester.pumpWidget(UiApp(
        home: Builder(builder: (ctx) {
          hostContext = ctx;
          return const SizedBox.shrink();
        }),
      ));

      final future = showUiModal<void>(
        context: hostContext,
        title: 'Add client',
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, set) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              UiPhoneInput(
                value: phone,
                defaultCountry: 'GB',
                onChanged: (v) => set(() => phone = v),
                onCountryChanged: (c) => pickedCountry = c,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Add client'), findsOneWidget);

      // Open country dropdown and close it with Escape; the modal must stay open.
      await tester.tap(find.byKey(const ValueKey('ui-phone-trigger')));
      await tester.pumpAndSettle();
      expect(find.text('Maldives'), findsNothing); // scrolled below GB, verify search works
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Add client'), findsOneWidget);

      // Re-open, filter for Maldives, and tap the option inside the overlay.
      await tester.tap(find.byKey(const ValueKey('ui-phone-trigger')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).last, 'Maldiv');
      await tester.pumpAndSettle();
      expect(find.text('Maldives'), findsOneWidget);

      await tester.tap(find.text('Maldives'));
      await tester.pumpAndSettle();
      expect(pickedCountry, 'MV');
      expect(find.text('Add client'), findsOneWidget);

      Navigator.of(hostContext, rootNavigator: true).pop();
      await tester.pumpAndSettle();
      await future;
    });

    testWidgets('UiMultiSelect dropdown paints, receives taps, and Escape closes only the dropdown', (tester) async {
      tester.view.physicalSize = const Size(800, 700) * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);

      var selected = <String>[];
      late BuildContext hostContext;

      await tester.pumpWidget(UiApp(
        home: Builder(builder: (ctx) {
          hostContext = ctx;
          return const SizedBox.shrink();
        }),
      ));

      final future = showUiModal<void>(
        context: hostContext,
        title: 'Edit guest',
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, set) => UiMultiSelect(
            options: _roles,
            value: selected,
            label: 'Roles',
            onChanged: (v) => set(() => selected = v),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(UiMultiSelect));
      await tester.pumpAndSettle();
      expect(find.text('VIP'), findsOneWidget);
      expect(find.text('Family'), findsOneWidget);

      await tester.tap(find.text('VIP'));
      await tester.pumpAndSettle();
      expect(selected, ['vip']);

      // First Escape closes only the multi-select listbox, keeping the modal open.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Family'), findsNothing);
      expect(find.text('Edit guest'), findsOneWidget);

      // Second Escape closes the modal.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Edit guest'), findsNothing);
      await future;
    });

    testWidgets('UiMenu inside showUiModal opens above the modal and handles taps', (tester) async {
      tester.view.physicalSize = const Size(800, 700) * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);

      String? chosen;
      late BuildContext hostContext;

      await tester.pumpWidget(UiApp(
        home: Builder(builder: (ctx) {
          hostContext = ctx;
          return const SizedBox.shrink();
        }),
      ));

      final future = showUiModal<void>(
        context: hostContext,
        title: 'Guest actions',
        builder: (ctx) => UiMenu(
          items: _menuItems,
          onSelect: (item) => chosen = item.value,
          builder: (ctx, toggle, open) => UiButton(label: 'More', onPressed: toggle),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(chosen, 'edit');
      expect(find.text('Guest actions'), findsOneWidget);

      Navigator.of(hostContext, rootNavigator: true).pop();
      await tester.pumpAndSettle();
      await future;
    });
  });

  group('OverlayPortal popups inside UiBottomSheet', () {
    testWidgets('UiPhoneInput and UiMultiSelect popups paint and receive taps above UiBottomSheet', (tester) async {
      tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);

      String? pickedCountry;
      var selected = <String>[];

      await tester.pumpWidget(UiApp(
        home: StatefulBuilder(
          builder: (ctx, set) => Stack(
            children: [
              const SizedBox.expand(),
              UiBottomSheet(
                snaps: const [0, 0.85],
                snap: 1,
                backdrop: true,
                title: 'Guest form',
                onSnapChanged: (_) {},
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: ctx.ui.space3,
                  children: [
                    UiPhoneInput(
                      defaultCountry: 'GB',
                      onCountryChanged: (c) => set(() => pickedCountry = c),
                    ),
                    UiMultiSelect(
                      options: _roles,
                      value: selected,
                      label: 'Roles',
                      onChanged: (v) => set(() => selected = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Open UiPhoneInput country list above the bottom sheet and pick Maldives.
      await tester.tap(find.byKey(const ValueKey('ui-phone-trigger')));
      await tester.pumpAndSettle();
      final phoneSearch = find.byWidgetPredicate((w) => w is EditableText && w.focusNode.debugLabel == 'phone country search');
      await tester.enterText(phoneSearch, 'Maldiv');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Maldives'));
      await tester.pumpAndSettle();
      expect(pickedCountry, 'MV');

      // Open UiMultiSelect above the bottom sheet and pick Family.
      await tester.tap(find.byType(UiMultiSelect));
      await tester.pumpAndSettle();
      expect(find.text('Family'), findsOneWidget);
      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();
      expect(selected, ['family']);
    });
  });
}
