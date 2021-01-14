# raw_sound
[![pub package](https://img.shields.io/badge/pub-0.2.0--nullsafety.0-yellowgreen)](https://pub.dev/packages/raw_sound)
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
    // Buffer size of the underlying audio track (Android only)
    bufferSize: 4096 << 3,
    // Number of channels, either 1 or 2
    nChannels: 1,
    // Sample rate for playback in Hz
    sampleRate: 16000,
    // PCM format type, either PCMI16 (16-bit integer) or PCMF32 (32-bit float)
    pcmType: RawSoundPCMType.PCMI16,
  );
```
- Start the playback
```dart
  await _player.play();
```
- Feed the player instance with the raw PCM data
```dart
  // Demonstrate how to continuously feed the player until the playback is paused/stopped
  while (_player.isPlaying) {
    await _player.feed(dataBlock);
  }
```
- Pause the playback
```dart
  // Pause immediately and keep queued buffers
  await _player.pause();
```
- Stop the playback
```dart
  // Stop immediately and drop queued buffers
  await _player.stop();
```
- Release the player instance
```dart
  // Remember to release any initialized player instances
  await _player.release();
```
