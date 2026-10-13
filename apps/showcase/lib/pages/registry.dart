import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import 'buttons_page.dart';
import 'data_page.dart';
import 'feedback_page.dart';
import 'foundation_page.dart';
import 'overview_page.dart';
import 'typography_page.dart';

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
  ShowcasePage('buttons', 'Components', 'Buttons & actions', HugeIcons.strokeRoundedCursorPointer02, (_) => const ButtonsPage()),
  ShowcasePage('feedback', 'Components', 'Feedback & status', HugeIcons.strokeRoundedNotification01, (_) => const FeedbackPage()),
  ShowcasePage('data', 'Components', 'Data display', HugeIcons.strokeRoundedTable01, (_) => const DataPage()),
];
