import 'package:flutter/widgets.dart';

/// Parses SVG path data into a [Path]: absolute and relative `M L H V C S Q T Z`, implicit
/// repeats (extra pairs after `M` are line-tos), exponents (`1e-05`) and numbers run together
/// (`.5-.3`, `1.5.5`). Arcs (`A`) are not supported and throw a [FormatException]. Used to draw brand
/// logos from their official SVG files without an SVG dependency.
Path uiParseSvgPath(String d, {PathFillType fillType = PathFillType.nonZero}) {
  final path = Path()..fillType = fillType;
  final tokens = RegExp(r'[A-Za-z]|[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?').allMatches(d).map((m) => m.group(0)!).toList();
  var i = 0;
  String? cmd;
  var x = 0.0, y = 0.0; // current point
  var sx = 0.0, sy = 0.0; // subpath start
  double? cx, cy; // last cubic control point (for S)
  double? qx, qy; // last quadratic control point (for T)

  bool isCmd(String s) => RegExp(r'^[A-Za-z]$').hasMatch(s);
  double n() {
    if (i >= tokens.length || isCmd(tokens[i])) throw FormatException('Missing number for $cmd in path data');
    return double.parse(tokens[i++]);
  }

  while (i < tokens.length) {
    if (isCmd(tokens[i])) {
      cmd = tokens[i++];
    } else if (cmd == null) {
      throw const FormatException('Path data must start with a command');
    }
    final c = cmd;
    final rel = c == c.toLowerCase();
    final ox = rel ? x : 0.0, oy = rel ? y : 0.0;
    var keepC = false, keepQ = false;
    switch (c.toUpperCase()) {
      case 'M':
        x = ox + n();
        y = oy + n();
        path.moveTo(x, y);
        sx = x;
        sy = y;
        // Further pairs are line-tos of the same kind.
        cmd = rel ? 'l' : 'L';
      case 'L':
        x = ox + n();
        y = oy + n();
        path.lineTo(x, y);
      case 'H':
        x = ox + n();
        path.lineTo(x, y);
      case 'V':
        y = oy + n();
        path.lineTo(x, y);
      case 'C':
        final x1 = ox + n(), y1 = oy + n(), x2 = ox + n(), y2 = oy + n();
        x = ox + n();
        y = oy + n();
        path.cubicTo(x1, y1, x2, y2, x, y);
        cx = x2;
        cy = y2;
        keepC = true;
      case 'S':
        // The first control point mirrors the previous cubic's second one (or is the current point).
        final x1 = cx != null ? 2 * x - cx : x, y1 = cy != null ? 2 * y - cy : y;
        final x2 = ox + n(), y2 = oy + n();
        x = ox + n();
        y = oy + n();
        path.cubicTo(x1, y1, x2, y2, x, y);
        cx = x2;
        cy = y2;
        keepC = true;
      case 'Q':
        final x1 = ox + n(), y1 = oy + n();
        x = ox + n();
        y = oy + n();
        path.quadraticBezierTo(x1, y1, x, y);
        qx = x1;
        qy = y1;
        keepQ = true;
      case 'T':
        final x1 = qx != null ? 2 * x - qx : x, y1 = qy != null ? 2 * y - qy : y;
        x = ox + n();
        y = oy + n();
        path.quadraticBezierTo(x1, y1, x, y);
        qx = x1;
        qy = y1;
        keepQ = true;
      case 'Z':
        path.close();
        x = sx;
        y = sy;
        if (i < tokens.length && !isCmd(tokens[i])) throw const FormatException('Numbers after Z in path data');
      default:
        throw FormatException('Unsupported SVG path command $c');
    }
    if (!keepC) cx = cy = null;
    if (!keepQ) qx = qy = null;
  }
  return path;
}
