/// Lays out a lifecycle diagram: states in columns by how many moves they are from the starting
/// state, ordered inside a column to keep arrows short. The algorithm is deterministic (no
/// randomness, ties broken by state order) and mirrors the web `layout.ts` exactly, so a lifecycle
/// looks the same on both; `test/workflow/fixtures/layout.json` is shared with the Angular specs.
library;

import 'dart:math' as math;
import 'dart:ui' show Offset, Path;

import '../form_builder/engine/js.dart';
import 'schema.dart';

const double wfNodeW = 172;
const double wfNodeH = 56;
const double wfGapX = 96;
const double wfGapY = 40;

/// An arrow between two states.
class UiWfEdge {
  const UiWfEdge({required this.id, required this.from, required this.to, this.back = false});

  /// `transitionId:fromStateId`.
  final String id;
  final String from;
  final String to;

  /// Goes against the flow (to an earlier column or the same one): drawn as a loop underneath.
  final bool back;
}

class UiWfLayout {
  const UiWfLayout({required this.positions, required this.edges, required this.width, required this.height});

  /// Top-left corner of each state's card.
  final Map<String, Offset> positions;
  final List<UiWfEdge> edges;
  final double width;
  final double height;
}

/// The arrows of a lifecycle (transitions from "any state" are drawn separately, not as edges).
List<UiWfEdge> lifecycleEdges(UiWfLifecycle lc) {
  final ids = {for (final s in lc.states) s.id};
  final out = <UiWfEdge>[];
  for (final t in lc.transitions) {
    if (t.fromAny || !ids.contains(t.to)) continue;
    for (final f in t.from) {
      if (ids.contains(f) && f != t.to) out.add(UiWfEdge(id: '${t.id}:$f', from: f, to: t.to));
    }
  }
  return out;
}

/// Transitions that leave a state and come back to it (e.g. "Ask for more documents" from Review to
/// Review): the web `lifecycleSelfLoops`. They take no part in the layout; the diagram draws each as
/// a loop over its card.
List<({String id, String state})> lifecycleSelfLoops(UiWfLifecycle lc) {
  final ids = {for (final s in lc.states) s.id};
  return [
    for (final t in lc.transitions)
      if (!t.fromAny && ids.contains(t.to) && t.from.contains(t.to)) (id: '${t.id}:${t.to}', state: t.to),
  ];
}

/// A loop over the top of a card ([at] is its top-left corner), and where its label goes (the web
/// `selfLoopPath`). [lane] stacks several loops on one card.
UiWfEdgePath selfLoopPath(Offset at, [int lane = 0]) {
  final x1 = at.dx + wfNodeW * 0.62 + lane * 8, x2 = at.dx + wfNodeW * 0.38 - lane * 8, y = at.dy;
  final top = y - 30 - lane * 12;
  return UiWfEdgePath('M ${_n(x1)} ${_n(y)} C ${_n(x1)} ${_n(top)} ${_n(x2)} ${_n(top)} ${_n(x2)} ${_n(y)}', Offset((x1 + x2) / 2, top + 4));
}

UiWfLayout autoLayout(UiWfLifecycle lc, {bool keepManual = true}) {
  final states = lc.states;
  final index = {for (var i = 0; i < states.length; i++) states[i].id: i};
  final raw = lifecycleEdges(lc);

  // 1. Break cycles with a depth-first walk from the starting state (then any unvisited state, in
  //    order): an edge to a state still on the walk's stack goes back.
  final back = <String>{};
  final color = <String, int>{};
  void visit(String id) {
    color[id] = 1;
    for (final e in raw.where((x) => x.from == id)) {
      final c = color[e.to] ?? 0;
      if (c == 1) {
        back.add(e.id);
      } else if (c == 0) {
        visit(e.to);
      }
    }
    color[id] = 2;
  }

  final initial = states.where((s) => s.category == 'initial').firstOrNull ?? states.firstOrNull;
  if (initial != null) visit(initial.id);
  for (final s in states) {
    if ((color[s.id] ?? 0) == 0) visit(s.id);
  }
  final forward = raw.where((e) => !back.contains(e.id)).toList();

  // 2. Columns: the longest forward path from a state with no forward arrows into it.
  final rank = {for (final s in states) s.id: 0};
  for (var pass = 0; pass < states.length; pass++) {
    var changed = false;
    for (final e in forward) {
      final r = (rank[e.from] ?? 0) + 1;
      if (r > (rank[e.to] ?? 0)) {
        rank[e.to] = r;
        changed = true;
      }
    }
    if (!changed) break;
  }

  // A final state no arrow leads to (reached only "from any state") goes with the other outcomes, last.
  final lastRank = rank.values.fold(0, math.max);
  for (final st in states) {
    if (st.category == 'terminal' && lastRank > 0 && !forward.any((e) => e.to == st.id || e.from == st.id)) rank[st.id] = lastRank;
  }

  // 3. Order inside columns: start in state order, then two barycentre sweeps (down then up).
  final maxRank = rank.values.fold(0, math.max);
  final columns = List.generate(maxRank + 1, (_) => <String>[]);
  for (final s in states) {
    columns[rank[s.id]!].add(s.id);
  }
  Map<String, int> pos() => {
    for (final col in columns)
      for (var i = 0; i < col.length; i++) col[i]: i,
  };
  void sweep(bool down) {
    final all = [for (var i = 0; i < columns.length; i++) i];
    final order = down ? all.skip(1) : all.reversed.skip(1);
    for (final c in order) {
      final p = pos();
      double score(String id) {
        final ns = [
          for (final e in forward)
            if (down ? e.to == id : e.from == id) p[down ? e.from : e.to]!,
        ];
        return ns.isNotEmpty ? ns.reduce((a, b) => a + b) / ns.length : p[id]!.toDouble();
      }

      final sorted = [...columns[c]]
        ..sort((a, b) {
          final d = score(a) - score(b);
          if (d != 0) return d < 0 ? -1 : 1;
          return index[a]! - index[b]!;
        });
      columns[c] = sorted;
    }
  }

  sweep(true);
  sweep(false);

  // 4. Coordinates: columns left to right, each column centred on the tallest one.
  final tallest = math.max(1, columns.fold(0, (m, c) => math.max(m, c.length)));
  final positions = <String, Offset>{};
  for (var c = 0; c < columns.length; c++) {
    final col = columns[c];
    final offset = ((tallest - col.length) * (wfNodeH + wfGapY)) / 2;
    for (var i = 0; i < col.length; i++) {
      positions[col[i]] = Offset(c * (wfNodeW + wfGapX), jsRound(offset + i * (wfNodeH + wfGapY)));
    }
  }
  final manual = lc.layout;
  if (keepManual && manual != null) {
    for (final e in manual.entries) {
      if (positions.containsKey(e.key) && e.value.length == 2) positions[e.key] = Offset(e.value[0].toDouble(), e.value[1].toDouble());
    }
  }
  final xs = positions.values;
  final width = xs.isNotEmpty ? xs.map((p) => p.dx).reduce(math.max) + wfNodeW : wfNodeW;
  final height = xs.isNotEmpty ? xs.map((p) => p.dy).reduce(math.max) + wfNodeH : wfNodeH;
  final edges = [
    for (final e in raw)
      UiWfEdge(id: e.id, from: e.from, to: e.to, back: back.contains(e.id) || (positions[e.to]?.dx ?? 0) <= (positions[e.from]?.dx ?? 0)),
  ];
  return UiWfLayout(positions: positions, edges: edges, width: width, height: height);
}

/// An arrow's SVG path (`d`) and where its label goes.
class UiWfEdgePath {
  const UiWfEdgePath(this.d, this.label);
  final String d;
  final Offset label;

  /// The path for painting.
  Path toPath() => svgPathOf(d);
}

String _n(num v) => jsNumberToString(v);

/// An arrow between two cards with rounded right-angle bends, and where its label goes. Forward
/// arrows leave a card's right side and enter the next card's left side; arrows going back loop
/// underneath both cards. [lane] separates arrows that share the same pair of cards.
UiWfEdgePath edgePath(Offset from, Offset to, bool back, [int lane = 0]) {
  const r = 8.0;
  if (!back) {
    final x1 = from.dx + wfNodeW, y1 = from.dy + wfNodeH / 2 + lane * 10;
    final x2 = to.dx, y2 = to.dy + wfNodeH / 2 + lane * 10;
    final mx = jsRound((x1 + x2) / 2);
    if ((y2 - y1).abs() < 1) return UiWfEdgePath('M ${_n(x1)} ${_n(y1)} H ${_n(x2)}', Offset(mx, y1 - 8));
    final dir = y2 > y1 ? 1 : -1;
    final rr = math.min(r, math.min((y2 - y1).abs() / 2, (mx - x1).abs()));
    return UiWfEdgePath(
      'M ${_n(x1)} ${_n(y1)} H ${_n(mx - rr)} Q ${_n(mx)} ${_n(y1)} ${_n(mx)} ${_n(y1 + dir * rr)} V ${_n(y2 - dir * rr)} Q ${_n(mx)} ${_n(y2)} ${_n(mx + rr)} ${_n(y2)} H ${_n(x2)}',
      Offset(mx, (y1 + y2) / 2),
    );
  }
  final x1 = from.dx + wfNodeW / 2 + lane * 12, y1 = from.dy + wfNodeH;
  final x2 = to.dx + wfNodeW / 2 + lane * 12, y2 = to.dy + wfNodeH;
  // Lanes a label's height apart, so stacked arrows' labels don't overlap.
  final low = math.max(y1, y2) + 28 + lane * 22;
  final dir = x2 > x1 ? 1 : -1;
  return UiWfEdgePath(
    'M ${_n(x1)} ${_n(y1)} V ${_n(low - r)} Q ${_n(x1)} ${_n(low)} ${_n(x1 + dir * r)} ${_n(low)} H ${_n(x2 - dir * r)} Q ${_n(x2)} ${_n(low)} ${_n(x2)} ${_n(low - r)} V ${_n(y2)}',
    Offset((x1 + x2) / 2, low),
  );
}

/// A [Path] from the absolute `M`, `L`, `H`, `V`, `Q` and `C` commands [edgePath] and [selfLoopPath] write.
Path svgPathOf(String d) {
  final path = Path();
  final t = d.trim().split(RegExp(r'\s+'));
  var x = 0.0, y = 0.0;
  var i = 0;
  double next() => double.parse(t[i++]);
  while (i < t.length) {
    final c = t[i++];
    switch (c) {
      case 'M':
        x = next();
        y = next();
        path.moveTo(x, y);
      case 'L':
        x = next();
        y = next();
        path.lineTo(x, y);
      case 'H':
        x = next();
        path.lineTo(x, y);
      case 'V':
        y = next();
        path.lineTo(x, y);
      case 'Q':
        final cx = next(), cy = next();
        x = next();
        y = next();
        path.quadraticBezierTo(cx, cy, x, y);
      case 'C':
        final c1x = next(), c1y = next(), c2x = next(), c2y = next();
        x = next();
        y = next();
        path.cubicTo(c1x, c1y, c2x, c2y, x, y);
    }
  }
  return path;
}
