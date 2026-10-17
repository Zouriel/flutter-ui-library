import 'package:hugeicons/hugeicons.dart';

import '../core/icon.dart';

/// Every icon the workflow widgets use, in one place (the web `WF_ICONS`); nothing unused.
abstract final class WfIcons {
  static const add01 = HugeIcons.strokeRoundedAdd01;
  static const alert02 = HugeIcons.strokeRoundedAlert02;
  static const arrowDataTransferHorizontal = HugeIcons.strokeRoundedArrowDataTransferHorizontal;
  static const arrowDown01 = HugeIcons.strokeRoundedArrowDown01;
  static const arrowRight01 = HugeIcons.strokeRoundedArrowRight01;
  static const arrowRight02 = HugeIcons.strokeRoundedArrowRight02;
  static const arrowTurnBackward = HugeIcons.strokeRoundedArrowTurnBackward;
  static const arrowUp01 = HugeIcons.strokeRoundedArrowUp01;
  static const calendar03 = HugeIcons.strokeRoundedCalendar03;
  static const cancel01 = HugeIcons.strokeRoundedCancel01;
  static const checkmarkBadge01 = HugeIcons.strokeRoundedCheckmarkBadge01;
  static const checkmarkCircle02 = HugeIcons.strokeRoundedCheckmarkCircle02;
  static const clock02 = HugeIcons.strokeRoundedClock02;
  static const cursorPointer02 = HugeIcons.strokeRoundedCursorPointer02;
  static const delete02 = HugeIcons.strokeRoundedDelete02;
  static const download04 = HugeIcons.strokeRoundedDownload04;
  static const dragDropVertical = HugeIcons.strokeRoundedDragDropVertical;
  static const edit02 = HugeIcons.strokeRoundedEdit02;
  static const exchange01 = HugeIcons.strokeRoundedExchange01;
  static const flag01 = HugeIcons.strokeRoundedFlag01;
  static const fileAdd = HugeIcons.strokeRoundedFileAdd;
  static const flag02 = HugeIcons.strokeRoundedFlag02;
  static const flash = HugeIcons.strokeRoundedFlash;
  static const gitFork = HugeIcons.strokeRoundedGitFork;
  static const gridView = HugeIcons.strokeRoundedGridView;
  static const hierarchySquare01 = HugeIcons.strokeRoundedHierarchySquare01;
  static const hourglass = HugeIcons.strokeRoundedHourglass;
  static const inbox = HugeIcons.strokeRoundedInbox;
  static const login03 = HugeIcons.strokeRoundedLogin03;
  static const moreHorizontal = HugeIcons.strokeRoundedMoreHorizontal;
  static const notification03 = HugeIcons.strokeRoundedNotification03;
  static const pencilEdit02 = HugeIcons.strokeRoundedPencilEdit02;
  static const play = HugeIcons.strokeRoundedPlay;
  static const plusSign = HugeIcons.strokeRoundedPlusSign;
  static const redo02 = HugeIcons.strokeRoundedRedo02;
  static const refresh = HugeIcons.strokeRoundedRefresh;
  static const repeat = HugeIcons.strokeRoundedRepeat;
  static const securityCheck = HugeIcons.strokeRoundedSecurityCheck;
  static const settings02 = HugeIcons.strokeRoundedSettings02;
  static const signal = HugeIcons.strokeRoundedSignal;
  static const taskDone01 = HugeIcons.strokeRoundedTaskDone01;
  static const tick02 = HugeIcons.strokeRoundedTick02;
  static const timeSchedule = HugeIcons.strokeRoundedTimeSchedule;
  static const undo02 = HugeIcons.strokeRoundedUndo02;
  static const variable = HugeIcons.strokeRoundedVariable;
  static const webhook = HugeIcons.strokeRoundedWebhook;
  static const workflowSquare03 = HugeIcons.strokeRoundedWorkflowSquare03;
  static const zap = HugeIcons.strokeRoundedZap;
}

/// The icon for each step type.
const Map<String, UiIconData> wfStepIcons = {
  'approval': WfIcons.checkmarkBadge01,
  'task': WfIcons.taskDone01,
  'branch': WfIcons.gitFork,
  'switch': WfIcons.arrowDataTransferHorizontal,
  'parallel': WfIcons.hierarchySquare01,
  'forEach': WfIcons.repeat,
  'goTo': WfIcons.arrowTurnBackward,
  'end': WfIcons.flag02,
  'wait': WfIcons.hourglass,
  'setFields': WfIcons.pencilEdit02,
  'createRecord': WfIcons.fileAdd,
  'applyTransition': WfIcons.exchange01,
  'setVariables': WfIcons.variable,
  'notify': WfIcons.notification03,
  'action': WfIcons.zap,
  'webhook': WfIcons.webhook,
  'subWorkflow': WfIcons.workflowSquare03,
};

/// The icon for each trigger type.
const Map<String, UiIconData> wfTriggerIcons = {
  'created': WfIcons.plusSign,
  'fieldChanged': WfIcons.edit02,
  'stateEntered': WfIcons.login03,
  'transitionApplied': WfIcons.arrowRight02,
  'deleted': WfIcons.delete02,
  'dateReached': WfIcons.calendar03,
  'schedule': WfIcons.timeSchedule,
  'manual': WfIcons.cursorPointer02,
  'signal': WfIcons.signal,
};

UiIconData wfStepIcon(String type) => wfStepIcons[type] ?? WfIcons.flash;
UiIconData wfTriggerIcon(String type) => wfTriggerIcons[type] ?? WfIcons.flash;
