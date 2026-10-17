import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import 'behaviors_page.dart';
import 'buttons_page.dart';
import 'data_page.dart';
import 'design_tools_page.dart';
import 'feedback_page.dart';
import 'file_viewer_page.dart';
import 'form_builder_page.dart';
import 'forms_page.dart';
import 'foundation_page.dart';
import 'fx_page.dart';
import 'layout_page.dart';
import 'media_page.dart';
import 'navigation_page.dart';
import 'overlays_page.dart';
import 'overview_page.dart';
import 'typography_page.dart';
import 'window_page.dart';
import 'workflow_builder_page.dart';
import 'workflow_panel_page.dart';

/// A showcase page in the side menu, grouped like the web docs.
class ShowcasePage {
  const ShowcasePage(this.id, this.group, this.label, this.icon, this.builder);
  final String id;
  final String group;
  final String label;
  final List<List<dynamic>> icon;
  final WidgetBuilder builder;
}

final List<ShowcasePage> showcasePages = [
  ShowcasePage('overview', 'Getting started', 'Overview', HugeIcons.strokeRoundedHome01, (_) => const OverviewPage()),
  ShowcasePage('foundation', 'Getting started', 'Foundation', HugeIcons.strokeRoundedPaintBoard, (_) => const FoundationPage()),
  ShowcasePage('typography', 'Getting started', 'Typography', HugeIcons.strokeRoundedTextFont, (_) => const TypographyPage()),
  ShowcasePage('layout', 'Layout', 'Layout & grid', HugeIcons.strokeRoundedLayout01, (_) => const LayoutPage()),
  ShowcasePage('buttons', 'Components', 'Buttons & actions', HugeIcons.strokeRoundedCursorPointer02, (_) => const ButtonsPage()),
  ShowcasePage('forms', 'Components', 'Form controls', HugeIcons.strokeRoundedPencilEdit02, (_) => const FormsPage()),
  ShowcasePage('overlays', 'Components', 'Overlays & dialogs', HugeIcons.strokeRoundedLayers01, (_) => const OverlaysPage()),
  ShowcasePage('feedback', 'Components', 'Feedback & status', HugeIcons.strokeRoundedNotification01, (_) => const FeedbackPage()),
  ShowcasePage('navigation', 'Components', 'Navigation', HugeIcons.strokeRoundedNavigation03, (_) => const NavigationPage()),
  ShowcasePage('data', 'Components', 'Data display', HugeIcons.strokeRoundedTable01, (_) => const DataPage()),
  ShowcasePage('media', 'Components', 'Media', HugeIcons.strokeRoundedImage01, (_) => const MediaPage()),
  ShowcasePage('file-viewer', 'Flagship', 'File viewer', HugeIcons.strokeRoundedFile02, (_) => const FileViewerPage()),
  ShowcasePage('form-builder', 'Flagship', 'Form builder', HugeIcons.strokeRoundedTask01, (_) => const FormBuilderPage()),
  ShowcasePage('workflow-builder', 'Flagship', 'Workflow builder', HugeIcons.strokeRoundedWorkflowSquare01, (_) => const WorkflowBuilderPage()),
  ShowcasePage('workflow-panel', 'Flagship', 'Workflow panel', HugeIcons.strokeRoundedWorkflowCircle01, (_) => const WorkflowPanelPage()),
  ShowcasePage('window', 'Flagship', 'Window system', HugeIcons.strokeRoundedBrowser, (_) => const WindowPage()),
  ShowcasePage('design-tools', 'Flagship', 'Design tools', HugeIcons.strokeRoundedPenTool01, (_) => const DesignToolsPage()),
  ShowcasePage('fx', 'Motion', 'Motion & FX', HugeIcons.strokeRoundedMagicWand01, (_) => const FxPage()),
  ShowcasePage('behaviors', 'Motion', 'Behavior directives', HugeIcons.strokeRoundedTouch01, (_) => const BehaviorsPage()),
];
