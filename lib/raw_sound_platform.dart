import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

abstract class RawSoundPlayerPrototype {}

const MethodChannel _channel = MethodChannel('codevalop.com/raw_sound');

class RawSoundPlayerPlatform extends PlatformInterface {
  RawSoundPlayerPlatform() : super(token: _token);

  static final Object _token = Object();

  static RawSoundPlayerPlatform _instance = RawSoundPlayerPlatform();
  static RawSoundPlayerPlatform get instance => _instance;

  static set instance(RawSoundPlayerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  static final _players = <RawSoundPlayerPrototype, int>{};

  Future<void> initialize(
    RawSoundPlayerPrototype player, {
    int bufferSize = 4096 << 3,
    int nChannels = 1,
    int sampleRate = 16000,
    int pcmType = 0,
    bool configureAudioSession = true,
  }) async {
    final playerNo = await _channel.invokeMethod<int>('initialize', {
      'bufferSize': bufferSize,
      'nChannels': nChannels,
      'sampleRate': sampleRate,
      'pcmType': pcmType,
      'configureAudioSession': configureAudioSession,
    });
    _players[player] = playerNo!;
  }

  Future<void> release(
    RawSoundPlayerPrototype player,
  ) async {
    final playerNo = _players[player];
    await _channel.invokeMethod('release', {
      'playerNo': playerNo,
    });
  }

  Future<int> play(
    RawSoundPlayerPrototype player,
  ) async {
    final playerNo = _players[player];
    final ret = await _channel.invokeMethod<int>('play', {
      'playerNo': playerNo,
    });
    return ret!;
  }

  Future<int> stop(
    RawSoundPlayerPrototype player,
  ) async {
    final playerNo = _players[player];
    final ret = await _channel.invokeMethod<int>('stop', {
      'playerNo': playerNo,
    });
    return ret!;
  }

  Future<int> pause(
    RawSoundPlayerPrototype player,
  ) async {
    final playerNo = _players[player];
    final ret = await _channel.invokeMethod<int>('pause', {
      'playerNo': playerNo,
    });
    return ret!;
  }

  Future<int> resume(
    RawSoundPlayerPrototype player,
  ) async {
    final playerNo = _players[player];
    final ret = await _channel.invokeMethod<int>('resume', {
      'playerNo': playerNo,
    });
    return ret!;
  }

  Future<int> feed(
    RawSoundPlayerPrototype player,
    Uint8List data,
  ) async {
    final playerNo = _players[player];
    final ret = await _channel.invokeMethod<int>('feed', {
      'playerNo': playerNo,
      'data': data,
    });
    return ret!;
  }

  Future<int> setVolume(
    RawSoundPlayerPrototype player,
    double volume,
  ) async {
    final playerNo = _players[player];
    final ret = await _channel.invokeMethod<int>('setVolume', {
      'playerNo': playerNo,
      'volume': volume,
    });
    return ret!;
  }
}
