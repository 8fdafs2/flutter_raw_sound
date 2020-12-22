import 'dart:async';
import 'dart:typed_data';
import 'package:synchronized/synchronized.dart';

import 'package:raw_sound/raw_sound_platform.dart';

enum RawSoundPCMType {
  PCMI16,
  PCMF32,
}

enum PlayState {
  stopped,
  playing,
  paused,
}

class RawSoundPlayer implements RawSoundPlayerPrototype {
  final _lock = Lock();

  bool _isInited = false;
  bool get isInited => _isInited;

  PlayState _playState = PlayState.stopped;
  PlayState get playState => _playState;
  bool get isPlaying => _playState == PlayState.playing;
  bool get isPaused => _playState == PlayState.paused;
  bool get isStopped => _playState == PlayState.stopped;

  Future<void> initialize({
    int bufferSize = 4096,
    int nChannels = 1,
    int sampleRate = 16000,
    RawSoundPCMType pcmType = RawSoundPCMType.PCMI16,
  }) async {
    print('RS:---> initialize');

    await _lock.synchronized(() async {
      _ensureIsNotOpen();

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

  Future<void> release() async {
    print('RS:---> release');

    await _lock.synchronized(() async {
      _ensureIsOpen();

      await _stop();

      await RawSoundPlayerPlatform.instance.release(
        this,
      );
      _playState = PlayState.stopped;
      _isInited = false;
    });

    print('RS:<--- release');
  }

  Future<void> play() async {
    print('RS:---> play');

    await _lock.synchronized(() async {
      _ensureIsOpen();

      await _stop();

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

  Future<void> stop() async {
    print('RS:---> stop');

    await _lock.synchronized(() async {
      _ensureIsOpen();

      try {
        await _stop();
      } on Exception catch (e) {
        print(e);
      }
    });

    print('RS:<--- stop');
  }

  Future<void> pause() async {
    print('RS:---> pause');

    await _lock.synchronized(() async {
      _ensureIsOpen();

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

  Future<void> resume() async {
    print('RS:---> resume');

    await _lock.synchronized(() async {
      _ensureIsOpen();

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

  Future<void> feed(Uint8List data) async {
    // print('RS:---> feed');

    await _lock.synchronized(() async {
      _ensureIsOpen();

      var state = await RawSoundPlayerPlatform.instance.feed(
        this,
        data,
      );
      _playState = PlayState.values[state];
    });

    // print('RS:<--- feed');
  }

  Future<void> setVolume(double volume) async {
    print('RS:---> setVolume');

    await _lock.synchronized(() async {
      _ensureIsOpen();

      var state = await RawSoundPlayerPlatform.instance.setVolume(
        this,
        volume,
      );
      _playState = PlayState.values[state];
    });

    print('RS:---> setVolume');
  }

  // ---------------------------------------------------------------------------

  void _ensureIsOpen() {
    if (!_isInited) {
      throw Exception('Audio session is not open');
    }
  }

  void _ensureIsNotOpen() {
    if (_isInited) {
      throw Exception('Audio session is open');
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
