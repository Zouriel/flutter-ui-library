import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import 'behaviors_page.dart';
import 'buttons_page.dart';
import 'data_page.dart';
import 'design_tools_page.dart';
import 'feedback_page.dart';
import 'file_viewer_page.dart';
import 'find_doctor_page.dart';
import 'form_builder_page.dart';
import 'forms_page.dart';
import 'map_page.dart';
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
import 'workflow_components_page.dart';

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
  ShowcasePage('map', 'Components', 'Map', HugeIcons.strokeRoundedMaps, (_) => const MapPage()),
  ShowcasePage('file-viewer', 'Flagship', 'File viewer', HugeIcons.strokeRoundedFile02, (_) => const FileViewerPage()),
  ShowcasePage('form-builder', 'Flagship', 'Form builder', HugeIcons.strokeRoundedTask01, (_) => const FormBuilderPage()),
  ShowcasePage('workflow-builder', 'Flagship', 'Workflow builder', HugeIcons.strokeRoundedWorkflowSquare01, (_) => const WorkflowBuilderPage()),
  ShowcasePage('workflow-components', 'Flagship', 'Workflow components', HugeIcons.strokeRoundedWorkflowCircle01, (_) => const WorkflowComponentsPage()),
  ShowcasePage('window', 'Flagship', 'Window system', HugeIcons.strokeRoundedBrowser, (_) => const WindowPage()),
  ShowcasePage('design-tools', 'Flagship', 'Design tools', HugeIcons.strokeRoundedPenTool01, (_) => const DesignToolsPage()),
  ShowcasePage('fx', 'Motion', 'Motion & FX', HugeIcons.strokeRoundedMagicWand01, (_) => const FxPage()),
  ShowcasePage('behaviors', 'Motion', 'Behaviors', HugeIcons.strokeRoundedTouch01, (_) => const BehaviorsPage()),
  ShowcasePage('find-doctor', 'Examples', 'Find Doctor (Maldives)', HugeIcons.strokeRoundedStethoscope02, (_) => const FindDoctorPage()),
];

/// Old page ids that moved, and where they went.
const Map<String, String> _movedPages = {'workflow-panel': 'workflow-components'};

/// The page with [id] (an old id opens the page that replaced it), or null.
ShowcasePage? showcasePageById(String id) {
  final real = _movedPages[id] ?? id;
  return showcasePages.where((p) => p.id == real).firstOrNull;
}

/// Lets a page open another one (a link from one page to another).
class ShowcaseNav extends InheritedWidget {
  const ShowcaseNav({super.key, required this.go, required super.child});

  /// Opens the page with this id.
  final ValueChanged<String> go;

  static ShowcaseNav? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ShowcaseNav>();

  @override
  bool updateShouldNotify(ShowcaseNav oldWidget) => false;
}
