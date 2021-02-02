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
    int bufferSize,
    int nChannels,
    int sampleRate,
    int pcmType,
  }) async {
    final playerNo = await _channel.invokeMethod<int>('initialize', {
      'bufferSize': bufferSize,
      'nChannels': nChannels,
      'sampleRate': sampleRate,
      'pcmType': pcmType,
    });
    _players[player] = playerNo;
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
  ) {
    final playerNo = _players[player];
    return _channel.invokeMethod('play', {
      'playerNo': playerNo,
    });
  }

  Future<int> stop(
    RawSoundPlayerPrototype player,
  ) {
    final playerNo = _players[player];
    return _channel.invokeMethod('stop', {
      'playerNo': playerNo,
    });
  }

  Future<int> pause(
    RawSoundPlayerPrototype player,
  ) {
    final playerNo = _players[player];
    return _channel.invokeMethod('pause', {
      'playerNo': playerNo,
    });
  }

  Future<int> resume(
    RawSoundPlayerPrototype player,
  ) {
    final playerNo = _players[player];
    return _channel.invokeMethod('resume', {
      'playerNo': playerNo,
    });
  }

  Future<int> feed(
    RawSoundPlayerPrototype player,
    Uint8List data,
  ) {
    final playerNo = _players[player];
    return _channel.invokeMethod('feed', {
      'playerNo': playerNo,
      'data': data,
    });
  }

  Future<int> setVolume(
    RawSoundPlayerPrototype player,
    double volume,
  ) {
    final playerNo = _players[player];
    return _channel.invokeMethod('setVolume', {
      'playerNo': playerNo,
      'volume': volume,
    });
  }
}
