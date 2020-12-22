import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:raw_sound/raw_sound_player.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static int bufferSize = 4096 << 4;
  static int nChannels = 1;
  static int sampleRate = 16000;
  static double freq = 440.0;
  static double period = 1.0 / freq;
  static double volume = 0.5;

  final _playerPCMI16 = RawSoundPlayer();
  final _playerPCMF32 = RawSoundPlayer();
  bool _playerPCMI16Inited = false;
  bool _playerPCMF32Inited = false;

  @override
  void initState() {
    super.initState();
    _playerPCMI16
        .initialize(
      bufferSize: bufferSize,
      nChannels: nChannels,
      sampleRate: sampleRate,
      pcmType: RawSoundPCMType.PCMI16,
    )
        .then((value) {
      setState(() {
        _playerPCMI16Inited = true;
      });
    });
    _playerPCMF32
        .initialize(
      bufferSize: bufferSize,
      nChannels: nChannels,
      sampleRate: sampleRate,
      pcmType: RawSoundPCMType.PCMF32,
    )
        .then((value) {
      setState(() {
        _playerPCMF32Inited = true;
      });
    });
  }

  @override
  void dispose() {
    _playerPCMI16.release();
    _playerPCMF32.release();
    super.dispose();
  }

  Future<void> _playPCMI16() async {
    if (_playerPCMI16.isPlaying) {
      return;
    }
    await _playerPCMI16.play();
    setState(() {
      //
    });
    final dataBlock = _genPCMI16DataBlock(nPeriods: 20);
    while (_playerPCMI16.isPlaying) {
      await _playerPCMI16.feed(dataBlock);
    }
  }

  Future<void> _pausePCMI16() async {
    await _playerPCMI16.pause();
    setState(() {
      //
    });
  }

  Future<void> _playPCMF32() async {
    if (_playerPCMF32.isPlaying) {
      return;
    }
    await _playerPCMF32.play();
    setState(() {
      //
    });
    final dataBlock = _genPCMF32DataBlock(nPeriods: 20);
    while (_playerPCMF32.isPlaying) {
      await _playerPCMF32.feed(dataBlock);
    }
  }

  Future<void> _pausePCMF32() async {
    await _playerPCMF32.pause();
    setState(() {
      //
    });
  }

  Uint8List _genPCMI16DataBlock({int nPeriods = 1}) {
    final nFramesPerPeriod = (period * sampleRate).toInt();
    debugPrint('nFrames / period: $nFramesPerPeriod');
    final step = math.pi * 2 / nFramesPerPeriod;
    final dataBlockPerPeriod = ByteData(nFramesPerPeriod << 1);
    for (int i = 0; i < nFramesPerPeriod; i++) {
      final value = (math.sin(step * i) * volume * 32767).toInt();
      dataBlockPerPeriod.setInt16(i << 1, value, Endian.host);
    }
    final dataBlock = <int>[];
    for (int i = 0; i < nPeriods; i++) {
      dataBlock.addAll(dataBlockPerPeriod.buffer.asUint8List());
    }
    debugPrint('dataBlock nBytes: ${dataBlock.length}');
    return Uint8List.fromList(dataBlock);
  }

  Uint8List _genPCMF32DataBlock({int nPeriods = 1}) {
    final nFramesPerPeriod = (period * sampleRate).toInt();
    debugPrint('nFrames / period: $nFramesPerPeriod');
    final step = math.pi * 2 / nFramesPerPeriod;
    final dataBlockPerPeriod = ByteData(nFramesPerPeriod << 2);
    for (int i = 0; i < nFramesPerPeriod; i++) {
      final value = math.sin(step * i) * volume;
      dataBlockPerPeriod.setFloat32(i << 2, value, Endian.host);
    }
    final dataBlock = <int>[];
    for (int i = 0; i < nPeriods; i++) {
      dataBlock.addAll(dataBlockPerPeriod.buffer.asUint8List());
    }
    debugPrint('dataBlock nBytes: ${dataBlock.length}');
    return Uint8List.fromList(dataBlock);
  }

  Widget build(BuildContext context) {
    debugPrint('PlayerPCMI16 is inited? $_playerPCMI16Inited');
    debugPrint('PlayerPCMF32 is inited? $_playerPCMF32Inited');

    if (!_playerPCMI16Inited || !_playerPCMF32Inited) {
      return Container();
    }

    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.grey,
      ),
      home: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text('Raw Sound Plugin Example App'),
        ),
        body: Column(
          children: [
            Card(
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(_playerPCMI16.isPlaying
                        ? Icons.stop
                        : Icons.play_arrow),
                    onPressed: () {
                      _playerPCMI16.isPlaying ? _pausePCMI16() : _playPCMI16();
                    },
                  ),
                  Text('Test PCMI16 (16-bit Integer)'),
                ],
              ),
            ),
            Card(
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(_playerPCMF32.isPlaying
                        ? Icons.stop
                        : Icons.play_arrow),
                    onPressed: () {
                      _playerPCMF32.isPlaying ? _pausePCMF32() : _playPCMF32();
                    },
                  ),
                  Text('Test PCMF32 (32-bit Float)'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
