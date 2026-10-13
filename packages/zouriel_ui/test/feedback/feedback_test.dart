import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

void main() {
  testWidgets('alert shows heading and message, is a live region, and dismisses', (tester) async {
    final handle = tester.ensureSemantics();
    var dismissed = 0;
    await pumpUi(tester, UiAlert(tone: UiAlertTone.danger, heading: 'Payment failed', message: 'Try again.', onDismiss: () => dismissed++));
    expect(find.text('Payment failed'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Dismiss'));
    expect(dismissed, 1);
    final live = tester.getSemantics(find.text('Payment failed')).getSemanticsData();
    expect(live.label, contains('Payment failed'));
    handle.dispose();
  });

  testWidgets('progress bar announces its value; indeterminate has no value', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(const UiApp(home: Column(children: [UiProgressBar(value: 42, label: 'Upload'), UiProgressBar(label: 'Busy')])));
    await tester.pump();
    expect(tester.getSemantics(find.bySemanticsLabel('Upload')).getSemanticsData().value, '42%');
    expect(tester.getSemantics(find.bySemanticsLabel('Busy')).getSemanticsData().value, '');
    handle.dispose();
  });

  testWidgets('animations off stops the skeleton shimmer', (tester) async {
    await tester.pumpWidget(const UiApp(config: UiConfig(animations: false), home: UiSkeleton(width: 100)));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('golden: alerts, progress, spinner, skeleton', (tester) async {
    await expectThemedGolden(tester, 'feedback', height: 470, (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        const UiAlert(tone: UiAlertTone.info, heading: 'Heads up', message: 'A new version is available.'),
        const UiAlert(tone: UiAlertTone.success, message: 'Saved.'),
        const UiAlert(tone: UiAlertTone.warning, message: 'Storage almost full.'),
        UiAlert(tone: UiAlertTone.danger, heading: 'Payment failed', message: 'Check the card details.', onDismiss: () {}),
        const UiProgressBar(value: 40),
        const UiProgressBar(value: 70, tone: UiStatus.success),
        const UiProgressBar(value: 60, tone: UiStatus.neutral),
        const Row(spacing: 12, children: [UiSpinner(), UiSpinner(size: 24), UiSkeleton(width: 32, shape: UiSkeletonShape.circle), Expanded(child: UiSkeleton(height: 32))]),
      ],
    ));
  });
}
