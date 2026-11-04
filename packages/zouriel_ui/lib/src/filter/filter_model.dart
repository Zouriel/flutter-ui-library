/// One choice in a filter section: a person, "Videos", a month (the web `UiFilterOption`).
class UiFilterOption {
  const UiFilterOption({required this.id, required this.label, this.count});

  /// What the value holds.
  final String id;
  final String label;

  /// How many items it matches, shown at the end of its row; null for none.
  final int? count;
}

/// One section of a filter panel ("Uploaded by", "Type"), the web `UiFilterSection`. Nothing chosen
/// in a section means everything passes it; its "all" row ([allLabel], or the strings' filterAll)
/// is checked then, and choosing it clears the section.
class UiFilterSection {
  const UiFilterSection({
    required this.id,
    required this.title,
    required this.options,
    this.multiple = false,
    this.allLabel,
    this.allCount,
    this.searchAt = 8,
  });

  final String id;
  final String title;
  final List<UiFilterOption> options;

  /// Several options at once (checkboxes, any of them passes) or one (radios).
  final bool multiple;

  /// The "everything" row's words ("Everyone"); null: the strings' filterAll ("All").
  final String? allLabel;

  /// The "everything" row's count.
  final int? allCount;

  /// From this many options the section gets a search field.
  final int searchAt;
}

/// What is chosen, by section id. A section that's missing or empty lets everything through.
typedef UiFilterValue = Map<String, List<String>>;

/// One filter that's on, for a chip: which section and option, and the option's label.
class UiActiveFilter {
  const UiActiveFilter({required this.section, required this.option, required this.label});
  final String section;
  final String option;
  final String label;

  @override
  bool operator ==(Object other) => other is UiActiveFilter && other.section == section && other.option == option && other.label == label;

  @override
  int get hashCode => Object.hash(section, option, label);

  @override
  String toString() => 'UiActiveFilter($section, $option, $label)';
}

/// How many options are chosen across every section: the filter button's badge.
int uiFilterCount(UiFilterValue? value) => (value ?? const {}).values.fold(0, (n, ids) => n + ids.length);

/// The chosen options that exist in [sections], in the panel's order.
List<UiActiveFilter> uiActiveFilters(List<UiFilterSection> sections, UiFilterValue? value) => [
      for (final s in sections)
        if (value?[s.id]?.isNotEmpty ?? false)
          for (final o in s.options)
            if (value![s.id]!.contains(o.id)) UiActiveFilter(section: s.id, option: o.id, label: o.label),
    ];

/// [value] without choices that [sections] no longer offer (someone's photos all removed), and
/// without empty sections. An app filters with this so a stale choice never empties the screen.
UiFilterValue uiFilterPrune(List<UiFilterSection> sections, UiFilterValue? value) {
  final out = <String, List<String>>{};
  for (final s in sections) {
    final chosen = value?[s.id];
    if (chosen == null || chosen.isEmpty) continue;
    final kept = [for (final o in s.options) if (chosen.contains(o.id)) o.id];
    if (kept.isNotEmpty) out[s.id] = s.multiple ? kept : kept.take(1).toList();
  }
  return out;
}

/// [value] with [section] set to [ids] (removed when empty).
UiFilterValue uiFilterSet(UiFilterValue? value, String section, List<String> ids) {
  final out = <String, List<String>>{...?value};
  if (ids.isEmpty) {
    out.remove(section);
  } else {
    out[section] = [...ids];
  }
  return out;
}

/// [value] after tapping [option] in [section]: a checkbox flips; a radio is chosen, or cleared when
/// it already was.
UiFilterValue uiFilterToggle(UiFilterSection section, UiFilterValue? value, String option) {
  final chosen = value?[section.id] ?? const <String>[];
  final on = chosen.contains(option);
  if (section.multiple) return uiFilterSet(value, section.id, on ? [for (final id in chosen) if (id != option) id] : [...chosen, option]);
  return uiFilterSet(value, section.id, on ? const [] : [option]);
}

/// [value] with one option turned off (a chip's remove button).
UiFilterValue uiFilterRemove(UiFilterValue? value, String section, String option) =>
    uiFilterSet(value, section, [for (final id in value?[section] ?? const <String>[]) if (id != option) id]);
