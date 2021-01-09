import 'dart:async';
import 'dart:typed_data';
import 'package:synchronized/synchronized.dart';

import 'package:raw_sound/raw_sound_platform.dart';

/// Raw PCM format type
enum RawSoundPCMType {
  /// PCM format: Integer 16-bit, native endianness
  PCMI16,

  /// PCM format: Float 32-bit, native endianness
  PCMF32,
}

/// Play state
enum PlayState {
  /// Playback is stopped
  ///
  /// After initialized, the player will be set initially as stopped
  stopped,

  /// Playback is ongoing
  playing,

  /// Playback is paused
  paused,
}

/// A player for playing the raw PCM audio data
class RawSoundPlayer implements RawSoundPlayerPrototype {
  final _lock = Lock();

  bool _isInited = false;

  /// True if the player is already initialized by initialize()
  bool get isInited => _isInited;

  PlayState _playState = PlayState.stopped;

  /// The play state of the player
  PlayState get playState => _playState;

  /// True if the playback is ongoing
  ///
  /// Shortcut for ```player.playState == PlayState.playing```
  bool get isPlaying => _playState == PlayState.playing;

  /// True if the playback is paused
  ///
  /// Shortcut for ```player.playState == PlayState.paused```
  bool get isPaused => _playState == PlayState.paused;

  /// True if the playback is stopped
  ///
  /// Shortcut for ```player.playState == PlayState.stopped```
  bool get isStopped => _playState == PlayState.stopped;

  /// Initializes the player
  ///
  /// Throws an [Exception] if the player is already initialized
  ///
  /// The [bufferSize] is only valid for Android to set up the buffer size of the underlying AudioTrack
  ///
  /// The [nChannels] should either be 1 or 2 to indicate the number of channels
  ///
  /// The [sampleRate] is the sample rate for output
  ///
  /// The [pcmType] determines the raw PCM format
  Future<void> initialize({
    int bufferSize = 4096,
    int nChannels = 1,
    int sampleRate = 16000,
    RawSoundPCMType pcmType = RawSoundPCMType.PCMI16,
  }) async {
    print('RS:---> initialize');

    await _lock.synchronized(() async {
      _ensureUninited();

      await RawSoundPlayerPlatform.instance.initialize(
        this,
        bufferSize: bufferSize,
        nChannels: nChannels,
        sampleRate: sampleRate,
        pcmType: pcmType.index,
      );
      _playState = PlayState.stopped;
      _isInited = true;
    });

    print('RS:<--- initialize');
  }

  /// Releases the player
  ///
  /// Throws an [Exception] if the player is not initialized
  ///
  /// Before the releasing the playback will be stopped
  Future<void> release() async {
    print('RS:---> release');

    await _lock.synchronized(() async {
      _ensureInited();

      await _stop();

      await RawSoundPlayerPlatform.instance.release(
        this,
      );
      _playState = PlayState.stopped;
      _isInited = false;
    });

    print('RS:<--- release');
  }

  /// Starts the playback
  ///
  /// Throws an [Exception] if the player is not initialized
  ///
  /// Throws an [Exception] if the playback is not started
  Future<void> play() async {
    print('RS:---> play');

    await _lock.synchronized(() async {
      _ensureInited();

      var state = await RawSoundPlayerPlatform.instance.play(
        this,
      );
      _playState = PlayState.values[state];
      if (_playState != PlayState.playing) {
        throw Exception('Player is not playing');
      }
    });

    print('RS:<--- play');
  }

  /// Stops the playback
  ///
  /// Throws an [Exception] if the player is not initialized
  ///
  /// Throws an [Exception] if the playback is not stopped
  ///
  /// Stops the playback will drop the queued buffers
  Future<void> stop() async {
    print('RS:---> stop');

    await _lock.synchronized(() async {
      _ensureInited();

      await _stop();
    });

    print('RS:<--- stop');
  }

  /// Pauses the playback
  ///
  /// Throws an [Exception] if the player is not initialized
  ///
  /// Throws an [Exception] if the playback is not paused
  ///
  /// Pauses the playback will not drop the queued buffers
  Future<void> pause() async {
    print('RS:---> pause');

    await _lock.synchronized(() async {
      _ensureInited();

      var state = await RawSoundPlayerPlatform.instance.pause(
        this,
      );
      _playState = PlayState.values[state];
      if (_playState != PlayState.paused) {
        throw Exception('Player is not paused');
      }
    });

    print('RS:<--- pause');
  }

  /// Resumes the playback that being paused
  ///
  /// Throws an [Exception] if the player is not initialized
  ///
  /// Throws an [Exception] if the playback is not resumed
  Future<void> resume() async {
    print('RS:---> resume');

    await _lock.synchronized(() async {
      _ensureInited();

      var state = await RawSoundPlayerPlatform.instance.resume(
        this,
      );
      _playState = PlayState.values[state];
      if (_playState != PlayState.playing) {
        throw Exception('Player is not resumed');
      }
    });

    print('RS:<--- resume');
  }

  /// Feeds the player with raw PCM [data] block
  ///
  /// Throws an [Exception] if the player is not initialized
  ///
  /// The format of [data] must comply with the [pcmType] used to initialize the player.
  /// And the size of [data] should not be too small to cause underrun
  Future<void> feed(Uint8List data) async {
    // print('RS:---> feed');

    await _lock.synchronized(() async {
      _ensureInited();

      var state = await RawSoundPlayerPlatform.instance.feed(
        this,
        data,
      );
      _playState = PlayState.values[state];
    });

    // print('RS:<--- feed');
  }

  /// Sets the [volume]
  ///
  /// Throws an [Exception] if the player is not initialized
  ///
  /// The [volume] should be in range of [0.0, 1.0]
  Future<void> setVolume(double volume) async {
    print('RS:---> setVolume');

    await _lock.synchronized(() async {
      _ensureInited();

      var state = await RawSoundPlayerPlatform.instance.setVolume(
        this,
        volume,
      );
      _playState = PlayState.values[state];
    });

    print('RS:---> setVolume');
  }

  // ---------------------------------------------------------------------------

  void _ensureInited() {
    if (!_isInited) {
      throw Exception('Player is not initialized');
    }
  }

  void _ensureUninited() {
    if (_isInited) {
      throw Exception('Player is already initialized');
    }
  }

  Future<void> _stop() async {
    print('RS:---> _stop');

    var state = await RawSoundPlayerPlatform.instance.stop(
      this,
    );
    _playState = PlayState.values[state];
    if (_playState == PlayState.playing) {
      throw Exception('Player is not stopped');
    }

    print('RS:<--- _stop');
  }
}
