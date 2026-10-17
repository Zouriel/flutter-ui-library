import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Flutter twin of the web library's style-contract spec: components read tokens only.
void main() {
  final files = Directory('lib/src').listSync(recursive: true).whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart')).toList();

  test('no hard-coded colours outside the generated tokens', () {
    final bad = <String>[];
    final allowed = RegExp(r'Color\(0x00000000\)'); // fully transparent
    for (final f in files) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final l = lines[i];
        if (RegExp(r'Color\(0x[0-9a-fA-F]{8}\)').hasMatch(l.replaceAll(allowed, '')) || RegExp(r'Colors\.\w+').hasMatch(l)) {
          bad.add('${f.path}:${i + 1}: ${l.trim()}');
        }
      }
    }
    expect(bad, isEmpty, reason: 'Use theme tokens (context.ui) instead of literal colours.');
  });

  test('no emoji or text glyphs used as icons', () {
    final glyphs = RegExp('[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{2190}-\u{21FF}\u{25A0}-\u{25FF}\u{2713}\u{2715}]', unicode: true);
    final bad = <String>[];
    for (final f in files) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final l = lines[i];
        if (l.trimLeft().startsWith('//')) continue;
        if (glyphs.hasMatch(l)) bad.add('${f.path}:${i + 1}: ${l.trim()}');
      }
    }
    expect(bad, isEmpty, reason: 'Use hugeicons or a drawn shape.');
  });

  test('no Material or Cupertino imports in the library', () {
    final bad = files.where((f) => RegExp(r'package:flutter/(material|cupertino)\.dart|package:material_ui').hasMatch(f.readAsStringSync())).map((f) => f.path);
    expect(bad, isEmpty);
  });
}
