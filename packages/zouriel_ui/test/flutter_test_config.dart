import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the bundled fonts under the names package fonts get at runtime
/// (`packages/zouriel_ui/<Family>`), so golden images show real text instead of test boxes.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final families = {
    'Roboto': 'Roboto',
    'JetBrains Mono': 'JetBrainsMono',
    'Space Grotesk': 'SpaceGrotesk',
    'Bricolage Grotesque': 'BricolageGrotesque',
  };
  for (final e in families.entries) {
    final loader = FontLoader('packages/zouriel_ui/${e.key}');
    for (final f in Directory('fonts').listSync().whereType<File>()) {
      final name = f.uri.pathSegments.last;
      if (name.startsWith('${e.value}-') && name.endsWith('.ttf')) {
        loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
      }
    }
    await loader.load();
  }
  await testMain();
}
