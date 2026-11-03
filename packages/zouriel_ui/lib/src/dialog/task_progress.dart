import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../button/button.dart';
import '../core/types.dart';
import '../feedback/alert.dart';
import '../theme/app.dart';
import '../theme/theme.dart';
import 'modal.dart';
import 'route.dart';

/// Drives a [UiTaskProgress] (the web's `done` / `total` / `detail` / `stopping` inputs): the job
/// [update]s it as files go, the Cancel button [cancel]s it (the job checks [cancelled] and stops),
/// and the job [close]s it when it has finished or stopped, which closes [showUiTaskProgress].
class UiTaskProgressController extends ChangeNotifier {
  UiTaskProgressController({this._total = 0, this._done = 0, this._detail});

  int _done, _total;
  String? _detail;
  bool _cancelled = false, _closed = false;

  /// How many are finished.
  int get done => _done;

  /// How many there are; 0 while unknown (the bar is indeterminate).
  int get total => _total;

  /// A line under the count, e.g. the file being worked on.
  String? get detail => _detail;

  /// Whether Cancel was pressed (or [cancel] called): the job should stop and then [close].
  bool get cancelled => _cancelled;

  /// Whether the job is over; an open [showUiTaskProgress] closes itself.
  bool get closed => _closed;

  /// Changes what is given; null leaves a value as it is.
  void update({int? done, int? total, String? detail}) {
    var changed = false;
    if (done != null && done != _done) {
      _done = done;
      changed = true;
    }
    if (total != null && total != _total) {
      _total = total;
      changed = true;
    }
    if (detail != null && detail != _detail) {
      _detail = detail;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// Asks the job to stop. The progress shows Stopping until [close].
  void cancel() {
    if (_cancelled || _closed) return;
    _cancelled = true;
    notifyListeners();
  }

  /// Ends the job; an open dialog closes.
  void close() {
    if (_closed) return;
    _closed = true;
    notifyListeners();
  }
}

/// `ui-task-progress`: progress for a job over many files, with Cancel. Shows [title], "12 of 40"
/// ([UiStrings.taskCount]), the controller's detail line and a bar that fills as files finish (it
/// sweeps while the total is 0). Cancel calls [UiTaskProgressController.cancel] and then reads
/// Stopping, busy and disabled, until the job closes it. Open it in a dialog with [showUiTaskProgress],
/// or place it anywhere.
class UiTaskProgress extends StatelessWidget {
  const UiTaskProgress({super.key, required this.controller, required this.title, this.cancelLabel});

  final UiTaskProgressController controller;
  final String title;

  /// [UiStrings.cancel] when null.
  final String? cancelLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final strings = context.uiStrings;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        final known = c.total > 0;
        final muted = context.uiText.body.copyWith(fontSize: t.fontSizeSm, color: t.textMuted, height: 1.35);
        final stopping = c.cancelled && !c.closed;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              namesRoute: true,
              child: Text(title, style: context.uiText.body.copyWith(fontWeight: FontWeight.w600, fontSize: t.fontSizeMd, height: 1.35, color: t.text)),
            ),
            SizedBox(height: t.space1),
            if (known)
              Text(
                uiFormatString(strings.taskCount, {'done': c.done.clamp(0, c.total), 'total': c.total}),
                style: muted.copyWith(color: t.text, fontWeight: FontWeight.w500, fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            if (c.detail case final d? when d.isNotEmpty) Text(d, maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
            SizedBox(height: t.space3),
            UiProgressBar(value: known ? c.done.clamp(0, c.total) / c.total * 100 : null, label: title),
            SizedBox(height: t.space3),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: UiButton(
                label: stopping ? strings.taskStopping : (cancelLabel ?? strings.cancel),
                variant: UiButtonVariant.outline,
                size: UiSize.sm,
                loading: stopping,
                onPressed: c.cancelled || c.closed ? null : c.cancel,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Opens a [UiTaskProgress] in a small dialog on the library's [UiDialogRoute] (like
/// [showUiConfirm]). The backdrop doesn't close it; back and Escape cancel, like the Cancel button.
/// It closes itself when [UiTaskProgressController.close] is called (also when that happens before
/// it has finished opening, or before this is called at all) and completes once it has closed.
Future<void> showUiTaskProgress({
  required BuildContext context,
  required UiTaskProgressController controller,
  required String title,
  String? cancelLabel,
  bool useRootNavigator = true,
}) async {
  if (controller.closed) return;
  await uiNavigatorOf(context, rootNavigator: useRootNavigator).push<void>(UiDialogRoute<void>.themed(
    context,
    dismissible: false,
    transitions: uiScaleTransition,
    builder: (context) => _TaskProgressDialog(controller: controller, title: title, cancelLabel: cancelLabel),
  ));
}

class _TaskProgressDialog extends StatefulWidget {
  const _TaskProgressDialog({required this.controller, required this.title, this.cancelLabel});
  final UiTaskProgressController controller;
  final String title;
  final String? cancelLabel;

  @override
  State<_TaskProgressDialog> createState() => _TaskProgressDialogState();
}

class _TaskProgressDialogState extends State<_TaskProgressDialog> {
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
    // close() may have come before this route was built.
    SchedulerBinding.instance.addPostFrameCallback((_) => _onChange());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (!mounted || _leaving || !widget.controller.closed) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase != SchedulerPhase.idle && phase != SchedulerPhase.postFrameCallbacks) {
      // Called from a build or layout: leave once the frame is done.
      SchedulerBinding.instance.addPostFrameCallback((_) => _onChange());
      return;
    }
    final route = ModalRoute.of(context);
    if (route == null || !route.isActive) return;
    _leaving = true;
    final nav = route.navigator!;
    if (route.isCurrent) {
      nav.pop();
    } else {
      // Something opened over it: take it out from under without disturbing that.
      nav.removeRoute(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return PopScope(
      canPop: false,
      // Back (and anything else that asks politely) cancels; the job closes the dialog.
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) c.cancel();
      },
      child: UiModal(
        size: UiModalSize.sm,
        onClose: c.cancel,
        child: UiTaskProgress(controller: c, title: widget.title, cancelLabel: widget.cancelLabel),
      ),
    );
  }
}
