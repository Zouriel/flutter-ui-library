import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// A term and its detail in a [UiDescriptionList].
@immutable
class UiDescriptionItem {
  const UiDescriptionItem({required this.term, required this.detail});
  final String term;
  final String detail;
}

/// Layouts of a [UiDescriptionList].
enum UiDescriptionLayout { row, stacked }

/// `ui-description-list`: key/value pairs (the web `<dl>`). [UiDescriptionLayout.row] puts the term
/// in a [termWidth] column beside the detail; [UiDescriptionLayout.stacked] puts it above. A row list
/// narrower than [stackBelow] stacks, so details never get squeezed into a sliver on a phone. Each
/// pair is read together ("Status, Active").
class UiDescriptionList extends StatelessWidget {
  const UiDescriptionList({super.key, required this.items, this.layout = UiDescriptionLayout.row, this.termWidth = 140, this.stackBelow = 300});

  final List<UiDescriptionItem> items;
  final UiDescriptionLayout layout;
  final double termWidth;
  final double stackBelow;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final term = context.uiText.caption.copyWith(height: 1.35);
    final detail = context.uiText.body.copyWith(height: 1.35);
    return LayoutBuilder(builder: (context, box) {
      final row = layout == UiDescriptionLayout.row && box.maxWidth >= stackBelow;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: t.space2,
        children: [
          for (final it in items)
            MergeSemantics(
              child: row
                  ? Row(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space4, children: [
                      // Baseline-aligned by hand: the term is smaller, so it drops to the detail's first line.
                      SizedBox(
                        width: termWidth,
                        child: Padding(padding: EdgeInsets.only(top: (detail.fontSize! - term.fontSize!) * 1.35 / 2), child: Text(it.term, style: term)),
                      ),
                      Expanded(child: Text(it.detail, style: detail)),
                    ])
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [Text(it.term, style: term), Text(it.detail, style: detail)]),
            ),
        ],
      );
    });
  }
}
