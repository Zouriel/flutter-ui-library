import 'package:flutter/widgets.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../docs/doc.dart';
import 'navdata_sections.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  bool _showAlert = true;
  double _progress = 40;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return DocPage(
      eyebrow: 'Components',
      title: 'Feedback & status',
      lead: 'Alerts, progress, meters, spinners, skeletons, empty states and results: telling people what is happening.',
      children: [
        DocSection(
          name: 'Alert',
          widget: 'UiAlert',
          summary: 'An inline message with a tone icon and optional heading. Danger and warning are announced straight away; info and success politely. onDismiss adds a dismiss button; the alert only reports the tap, so hide it yourself.',
          demo: Column(spacing: t.space2, children: [
            const UiAlert(tone: UiAlertTone.info, heading: 'Heads up', message: 'A new version is available.'),
            const UiAlert(tone: UiAlertTone.success, message: 'Your changes were saved.'),
            const UiAlert(tone: UiAlertTone.warning, heading: 'Storage almost full', message: 'You have used 92% of your space.'),
            if (_showAlert)
              UiAlert(tone: UiAlertTone.danger, heading: 'Payment failed', message: 'Check the card details and try again.', onDismiss: () => setState(() => _showAlert = false))
            else
              UiButton(label: 'Show the dismissed alert', variant: UiButtonVariant.outline, size: UiSize.sm, onPressed: () => setState(() => _showAlert = true)),
          ]),
          code: "UiAlert(\n  tone: UiAlertTone.danger,\n  heading: 'Payment failed',\n  message: 'Check the card details.',\n  onDismiss: () => setState(() => show = false),\n)",
          api: const [
            ApiRow('tone', 'UiAlertTone', 'info, success, warning, danger.', def: 'info'),
            ApiRow('heading', 'String?', 'Bold first line.'),
            ApiRow('message / child', 'String? / Widget?', 'Body text, or any widget.'),
            ApiRow('onDismiss', 'VoidCallback?', 'Shows the dismiss button.'),
          ],
        ),
        DocSection(
          name: 'Progress bar',
          widget: 'UiProgressBar',
          summary: 'Determinate when value (0–100) is set, otherwise an indeterminate sweep. Announced with its label and percentage. tone colours the fill; neutral uses the muted text colour, which keeps at least 3:1 against the track.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
            UiProgressBar(value: _progress, label: 'Upload'),
            Row(spacing: t.space2, children: [
              UiButton(label: '−10', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: () => setState(() => _progress = (_progress - 10).clamp(0, 100))),
              UiButton(label: '+10', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: () => setState(() => _progress = (_progress + 10).clamp(0, 100))),
              UiText('${_progress.round()}%', variant: UiTextVariant.caption),
            ]),
            const UiProgressBar(value: 70, tone: UiStatus.success),
            const UiProgressBar(value: 55, tone: UiStatus.warning),
            const UiProgressBar(value: 30, tone: UiStatus.danger),
            const UiProgressBar(value: 60, tone: UiStatus.neutral),
            const UiProgressBar(label: 'Loading'),
          ]),
          code: "UiProgressBar(value: 40, label: 'Upload')\nUiProgressBar(value: 70, tone: UiStatus.success)\nUiProgressBar() // indeterminate",
          api: const [
            ApiRow('value', 'double?', '0–100; null for indeterminate.'),
            ApiRow('tone', 'UiStatus', 'neutral, primary, success, warning, danger.', def: 'primary'),
            ApiRow('label', 'String', 'Accessible name.', def: "'Progress'"),
          ],
        ),
        DocSection(
          name: 'Progress circle',
          widget: 'UiProgressCircle',
          summary: 'The round sibling of the progress bar: determinate with a value (0–100), a turning arc without one. showValue writes the percentage in the middle; child goes in the middle instead, such as a countdown\'s seconds. Announced with its label and percentage.',
          demo: Wrap(spacing: t.space4, runSpacing: t.space3, crossAxisAlignment: WrapCrossAlignment.center, children: [
            UiProgressCircle(value: _progress, showValue: true, label: 'Upload'),
            const UiProgressCircle(label: 'Loading'),
            const UiProgressCircle(value: 40, size: 96, strokeWidth: 6, tone: UiStatus.success, label: 'Seconds left', child: Text('12')),
          ]),
          code: "UiProgressCircle(value: left / 30 * 100, size: 96, strokeWidth: 6, label: 'Seconds left', child: Text('\$left'))",
          api: const [
            ApiRow('value', 'double?', '0–100; null for an indeterminate arc.'),
            ApiRow('size / strokeWidth', 'double', 'Diameter and ring thickness.', def: '40 / 4'),
            ApiRow('tone', 'UiStatus', 'Arc colour.', def: 'primary'),
            ApiRow('label', 'String', 'Accessible name.', def: "'Progress'"),
            ApiRow('showValue', 'bool', 'Write the percentage in the middle.', def: 'false'),
            ApiRow('child', 'Widget?', 'Shown in the middle instead (countdown seconds).'),
          ],
        ),
        DocSection(
          name: 'Spinner',
          widget: 'UiSpinner',
          summary: 'An indeterminate loading ring, announced as "Loading". Under reduced motion it keeps turning, slower: a frozen spinner reads as a hang.',
          demo: Row(spacing: t.space4, children: [
            const UiSpinner(),
            const UiSpinner(size: 24, strokeWidth: 2.5),
            UiSpinner(size: 32, strokeWidth: 3, color: t.success),
          ]),
          code: 'UiSpinner(size: 24)',
          api: const [
            ApiRow('size', 'double', 'Diameter.', def: '16'),
            ApiRow('strokeWidth', 'double', 'Ring thickness.', def: '2'),
            ApiRow('color', 'Color?', 'Defaults to the surrounding text colour.'),
            ApiRow('label', 'String', 'Accessible name.', def: "'Loading'"),
            ApiRow('decorative', 'bool', 'Hide from screen readers when something else announces it.', def: 'false'),
          ],
        ),
        DocSection(
          name: 'Skeleton',
          widget: 'UiSkeleton',
          summary: 'A shimmering placeholder in rect, circle or text shape. Hidden from screen readers, so announce the loading state elsewhere. The shimmer stops under reduced motion.',
          demo: Row(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space3, children: [
            const UiSkeleton(width: 40, shape: UiSkeletonShape.circle),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space2, children: const [
                UiSkeleton(width: 160, shape: UiSkeletonShape.text),
                UiSkeleton(shape: UiSkeletonShape.text),
                UiSkeleton(height: 80),
              ]),
            ),
          ]),
          code: 'UiSkeleton(width: 40, shape: UiSkeletonShape.circle)\nUiSkeleton(shape: UiSkeletonShape.text)\nUiSkeleton(height: 80)',
          api: const [
            ApiRow('shape', 'UiSkeletonShape', 'rect, circle, text.', def: 'rect'),
            ApiRow('width / height', 'double?', 'Size; text height follows the font size.'),
          ],
        ),
        ...navdataFeedbackSections(),
      ],
    );
  }
}
