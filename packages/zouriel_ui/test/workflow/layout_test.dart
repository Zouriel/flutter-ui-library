import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

/// The fixtures list only what matters for layout; fill in the rest of a valid lifecycle.
UiWfLifecycle lifecycleOf(Map<String, Object?> c) {
  final lc = c['lifecycle'] as Map<String, Object?>;
  return UiWfLifecycle.fromJson({
    'field': 'status',
    'mode': 'enforce',
    'states': [
      for (final s in lc['states'] as List) {'key': (s as Map)['id'], 'label': s['id'], 'category': 'active', ...s},
    ],
    'transitions': [
      for (final t in lc['transitions'] as List) {'key': (t as Map)['id'], 'label': t['id'], 'who': <Object?>[], ...t},
    ],
    'layout': ?lc['layout'],
  });
}

void main() {
  final cases = (jsonDecode(File('test/workflow/fixtures/layout.json').readAsStringSync()) as List).cast<Map<String, Object?>>();

  // Shared with the Angular library (`projects/ui/workflow/src/fixtures/layout.json`): both must lay out alike.
  group('autoLayout (shared fixtures)', () {
    for (final c in cases) {
      test(c['name'] as String, () {
        final l = autoLayout(lifecycleOf(c), keepManual: (c['keepManual'] as bool?) ?? true);
        final expected = c['expect'] as Map<String, Object?>;
        expect({for (final e in l.positions.entries) e.key: [e.value.dx, e.value.dy]}, expected['positions']);
        expect([l.width, l.height], [expected['width'], expected['height']]);
        expect([for (final e in l.edges) {'id': e.id, 'back': e.back}], expected['edges']);
      });
    }
  });

  group('autoLayout', () {
    final fork = lifecycleOf(cases[1]);

    test('ignores manual positions when asked to tidy', () {
      final lc = fork.patch({'layout': {'review': [5, 5]}});
      expect(autoLayout(lc).positions['review'], const Offset(5, 5));
      expect(autoLayout(lc, keepManual: false).positions['review'], const Offset(wfNodeW + 96, 48));
    });

    test('is deterministic and never overlaps cards', () {
      final a = autoLayout(fork);
      final b = autoLayout(fork);
      expect(b.positions, a.positions);
      final boxes = a.positions.values.toList();
      for (var i = 0; i < boxes.length; i++) {
        for (var j = i + 1; j < boxes.length; j++) {
          final overlap = (boxes[i].dx - boxes[j].dx).abs() < wfNodeW && (boxes[i].dy - boxes[j].dy).abs() < wfNodeH;
          expect(overlap, isFalse);
        }
      }
    });

    test('handles an empty lifecycle', () {
      final l = autoLayout(UiWfLifecycle.fromJson({'field': 'status', 'mode': 'enforce', 'states': <Object?>[], 'transitions': <Object?>[]}));
      expect(l.positions, isEmpty);
      expect(l.edges, isEmpty);
      expect([l.width, l.height], [wfNodeW, wfNodeH]);
    });
  });

  test('lifecycleEdges: one arrow per source state, skipping "any state", self-loops and unknown states', () {
    final lc = lifecycleOf({
      'lifecycle': {
        'states': [{'id': 'a'}, {'id': 'b'}],
        'transitions': [
          {'id': 't', 'from': ['a', 'b'], 'to': 'b'},
          {'id': 'any', 'from': '*', 'to': 'a'},
          {'id': 'ghost', 'from': ['a'], 'to': 'zzz'},
        ],
      },
    });
    expect([for (final e in lifecycleEdges(lc)) [e.id, e.from, e.to]], [['t:a', 'a', 'b']]);
  });

  group('edgePath', () {
    test('a straight forward arrow runs from the right side to the left side', () {
      final p = edgePath(Offset.zero, const Offset(268, 0), false);
      expect(p.d, 'M 172 28 H 268');
      expect(p.label, const Offset((wfNodeW + 268) / 2, wfNodeH / 2 - 8));
    });

    test('a forward arrow to another row bends twice, with its label in the middle', () {
      final p = edgePath(Offset.zero, const Offset(268, 96), false);
      expect(p.d.startsWith('M 172 28 H'), isTrue);
      expect(p.d.endsWith('H 268'), isTrue);
      expect(p.label.dy, wfNodeH / 2 + 48);
      expect(p.d, 'M 172 28 H 212 Q 220 28 220 36 V 116 Q 220 124 228 124 H 268');
    });

    test('a back arrow loops below both cards, lower for later lanes', () {
      final a = edgePath(const Offset(268, 0), Offset.zero, true);
      final b = edgePath(const Offset(268, 0), Offset.zero, true, 1);
      expect(a.label.dy, wfNodeH + 28);
      expect(b.label.dy, greaterThan(a.label.dy));
    });

    test('the path paints what the d string says', () {
      final p = edgePath(Offset.zero, const Offset(268, 96), false).toPath();
      final b = p.getBounds();
      expect(b.left, 172);
      expect(b.right, 268);
      expect(b.top, 28);
      expect(b.bottom, 124);
    });
  });
}
