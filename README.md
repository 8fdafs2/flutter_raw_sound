# raw_sound
[![pub package](https://img.shields.io/badge/pub-v0.1.0-yellowgreen)](https://pub.dev/packages/raw_sound)
[![License](https://img.shields.io/badge/License-Apache%202.0-yellowgreen.svg)](https://opensource.org/licenses/Apache-2.0)

A flutter plugin for playing raw PCM audio data (16-bit integer and 32-bit float).

## Platform Support

| __Android__ (Kotlin) | __iOS__ (Swift) |
|:-------:|:---:|
| ```minSdkVersion 24``` | ```platform :ios, '14.0'``` |
|    ✔️    |  ✔️  |

## Usage

- Create an instance of the RawSoundPlayer
```dart
  final _player = RawSoundPlayer();
```
- Initialize the player instance with parameters of _bufferSize_, _nChannels_, _sampleRate_ and _pcmType_
```dart
  await _player.initialize(
    bufferSize: 4096 << 3,
    nChannels: 1,
    sampleRate: 16000,
    pcmType: RawSoundPCMType.PCMI16,
  );
```
- Start playing
```dart
  await _player.play();
```
- Feed the player instance with the raw PCM data
```dart
  while (_player.isPlaying) {
    await _player.feed(dataBlock);
  }
```
- Pause/Stop the playing
```dart
  await _player.pause();
  await _player.stop();
```
- Release the player instance
```dart
  await _player.release();
```
