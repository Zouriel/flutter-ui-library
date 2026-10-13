import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// A video_player platform that "plays" instantly in tests: every source initialises to [duration]
/// at [size], and the calls the players make are recorded in [calls].
class FakeVideoPlatform extends VideoPlayerPlatform {
  FakeVideoPlatform({this.duration = const Duration(minutes: 2, seconds: 5), this.size = const Size(1280, 720), this.fail = false});

  final Duration duration;
  final Size size;
  final bool fail;
  final List<String> calls = [];
  final Map<int, StreamController<VideoEvent>> _streams = {};
  final Map<int, Duration> positions = {};
  final Map<int, bool> playing = {};
  final Map<int, double> volume = {};
  final Map<int, double> speed = {};
  int _next = 1;

  static FakeVideoPlatform install({Duration? duration, bool fail = false}) {
    final f = FakeVideoPlatform(duration: duration ?? const Duration(minutes: 2, seconds: 5), fail: fail);
    VideoPlayerPlatform.instance = f;
    return f;
  }

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async => _create();

  @override
  Future<int?> create(DataSource dataSource) async => _create();

  int _create() {
    final id = _next++;
    calls.add('create $id');
    final c = StreamController<VideoEvent>();
    _streams[id] = c;
    positions[id] = Duration.zero;
    if (fail) {
      scheduleMicrotask(() => c.addError(PlatformException(code: 'error', message: 'Source error'), StackTrace.empty));
    } else {
      scheduleMicrotask(() => c.add(VideoEvent(eventType: VideoEventType.initialized, duration: duration, size: size)));
    }
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _streams[playerId]!.stream;

  @override
  Future<void> dispose(int playerId) async {
    calls.add('dispose $playerId');
    await _streams.remove(playerId)?.close();
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> play(int playerId) async {
    calls.add('play $playerId');
    playing[playerId] = true;
    _streams[playerId]?.add(VideoEvent(eventType: VideoEventType.isPlayingStateUpdate, isPlaying: true));
  }

  @override
  Future<void> pause(int playerId) async {
    calls.add('pause $playerId');
    playing[playerId] = false;
    _streams[playerId]?.add(VideoEvent(eventType: VideoEventType.isPlayingStateUpdate, isPlaying: false));
  }

  @override
  Future<void> setVolume(int playerId, double v) async => volume[playerId] = v;

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    calls.add('seek $playerId ${position.inSeconds}');
    positions[playerId] = position;
  }

  @override
  Future<void> setPlaybackSpeed(int playerId, double s) async => speed[playerId] = s;

  @override
  Future<Duration> getPosition(int playerId) async => positions[playerId] ?? Duration.zero;

  @override
  Widget buildViewWithOptions(VideoViewOptions options) => const SizedBox.expand(key: ValueKey('fake-video'));

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
}
