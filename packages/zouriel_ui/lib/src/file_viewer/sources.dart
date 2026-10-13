import 'dart:io' show File;

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

/// How the viewers read a `src` string, the same way everywhere:
/// `http(s)://…` is fetched, `file://…` (or an absolute path) is a local file, anything else is an
/// asset key (`assets/notes.txt`, or `packages/<pkg>/…`).
abstract final class UiFileSources {
  static bool isNetwork(String src) => src.startsWith('http://') || src.startsWith('https://');
  static bool isFile(String src) => src.startsWith('file://') || src.startsWith('/');

  /// The file name at the end of [src], without a query string.
  static String nameOf(String src) {
    final path = src.split('?').first.split('#').first;
    final slash = path.lastIndexOf('/');
    return slash < 0 ? path : path.substring(slash + 1);
  }

  /// The lower-case extension of [name] (or ''), the web `ext()`.
  static String extensionOf(String name) {
    final n = nameOf(name);
    final dot = n.lastIndexOf('.');
    return dot < 0 ? '' : n.substring(dot + 1).toLowerCase();
  }

  /// Loads a text file. Throws with a readable message (`HTTP 404`) when it can't.
  static Future<String> loadText(String src) async {
    if (isNetwork(src)) {
      final r = await http.get(Uri.parse(src));
      if (r.statusCode < 200 || r.statusCode >= 300) throw Exception('HTTP ${r.statusCode}');
      return r.body;
    }
    if (isFile(src)) return File(src.startsWith('file://') ? Uri.parse(src).toFilePath() : src).readAsString();
    return rootBundle.loadString(src);
  }

  /// A video_player controller for [src] (audio or video).
  static VideoPlayerController playerFor(String src) {
    if (isNetwork(src)) return VideoPlayerController.networkUrl(Uri.parse(src));
    if (src.startsWith('content://')) return VideoPlayerController.contentUri(Uri.parse(src));
    if (isFile(src)) return VideoPlayerController.file(File(src.startsWith('file://') ? Uri.parse(src).toFilePath() : src));
    return VideoPlayerController.asset(src);
  }
}

/// `m:ss`, or `h:mm:ss` past an hour.
String uiFormatMediaTime(Duration d) {
  if (d.isNegative) return '0:00';
  final total = d.inSeconds;
  final h = total ~/ 3600, m = (total % 3600) ~/ 60, s = total % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
}
