import AVFoundation
import UIKit
import os

public enum PlayState: Int {
  case Stopped
  case Playing
  case Paused
}

public enum PCMType: Int {
  case PCMI16
  case PCMF32
}

class RawSoundPlayer {

  private let audioEngine = AVAudioEngine()
  private let playerNode = AVAudioPlayerNode()

  private let inputFormat: AVAudioFormat
  private let outputFormat: AVAudioFormat

  private var isPaused = false

  private var buffers = [AVAudioPCMBuffer]()
  private let buffersCacheSize = 4

  // mutex to protect mainly write operations on buffers
  private let lckBuffers = NSLock()
  // signal of a buffer is added
  private let semBufferAdded = DispatchSemaphore(value: 0)
  // signal of a buffer is used
  private let semBufferUsed = DispatchSemaphore(value: 0)
  private let queAddBuffer = DispatchQueue(label: "queAddBuffer")
  private let queUseBuffer = DispatchQueue(label: "queUseBuffer")
  // signal of execution of async code finished in queAddBuffer
  private let queAddBufferIdled = DispatchSemaphore(value: 1)
  // signal of execution of async code finished in queUseBuffer
  private let queUseBufferIdled = DispatchSemaphore(value: 1)

  private let pcmType: PCMType

  init?(bufferSize: Int, sampleRate: Int, nChannels: Int, pcmType: PCMType) {
    precondition(
      nChannels == 1 || nChannels == 2,
      "Only support one or two channels")

    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(.playback, mode: .default)
    } catch {
      return nil
    }

    // init?(commonFormat: AVAudioCommonFormat, sampleRate: Double, channels: AVAudioChannelCount, interleaved: Bool)
    // Initializes a newly allocated audio format instance

    self.pcmType = pcmType

    let inputCommonFormat: AVAudioCommonFormat
    switch pcmType {
    case .PCMI16:
      inputCommonFormat = .pcmFormatInt16
    case .PCMF32:
      inputCommonFormat = .pcmFormatFloat32
    }

    inputFormat = AVAudioFormat(
      commonFormat: inputCommonFormat,
      sampleRate: Double(sampleRate),
      channels: AVAudioChannelCount(nChannels), interleaved: true)!
    outputFormat = AVAudioFormat(
      commonFormat: .pcmFormatFloat32,
      sampleRate: Double(sampleRate),
      channels: AVAudioChannelCount(nChannels), interleaved: true)!
    audioEngine.attach(playerNode)
    audioEngine.connect(
      playerNode, to: audioEngine.outputNode, format: outputFormat)
    audioEngine.prepare()
    buffers.reserveCapacity(buffersCacheSize)
  }

  func release() -> Bool {
    audioEngine.stop()
    audioEngine.reset()
    clearBuffers()
    return true
  }

  func getPlayState() -> Int {
    if playerNode.isPlaying {
      return PlayState.Playing.rawValue
    }
    if isPaused {
      return PlayState.Paused.rawValue
    }
    return PlayState.Stopped.rawValue
  }

  func play() -> Bool {
    if !audioEngine.isRunning {

      do {
        try audioEngine.start()
      } catch {
        return false
      }
    }

    playerNode.play()
    isPaused = false

    queUseBuffer.async {
      self.queUseBufferIdled.wait()
      defer {
        self.queUseBufferIdled.signal()
      }

      let n = self.buffersCacheSize - self.getBuffersCount()
      if n > 0 {
        for _ in 1...n {
          self.semBufferUsed.signal()
        }
      }

      while self.playerNode.isPlaying {
        guard self.semBufferAdded.wait(timeout: .now() + .seconds(1)) == .success else {
          continue
        }
        guard let buffer = self.popBuffer() else {
          continue
        }
        self.playerNode.scheduleBuffer(
          buffer,
          completionCallbackType: .dataConsumed,
          completionHandler: { _ in
            self.semBufferUsed.signal()
          }
        )
      }
    }

    return true
  }

  func stop() -> Bool {
    defer {
      clearBuffers()
      resetSemBufferUsed()
      resetSemBufferAdded()
    }
    guard audioEngine.isRunning else {
      return true
    }
    if playerNode.isPlaying {
      playerNode.stop()
      isPaused = false
    }
    return true
  }

  func pause() -> Bool {
    guard audioEngine.isRunning else {
      return false
    }
    if playerNode.isPlaying {
      playerNode.pause()
      isPaused = true
    }
    return true
  }

  func resume() -> Bool {
    guard audioEngine.isRunning else {
      return false
    }
    if !playerNode.isPlaying {
      playerNode.play()
      isPaused = false
    }
    return true
  }

  func feed(data: [UInt8], onDone: @escaping (_ r: Bool) -> Void) {
    guard audioEngine.isRunning else {
      onDone(false)
      return
    }
    guard playerNode.isPlaying else {
      onDone(true)
      return
    }

    queAddBuffer.async {
      self.queAddBufferIdled.wait()
      defer {
        self.queAddBufferIdled.signal()
      }
      let buffer = self.dataToBuffer(data)
      self.addBuffer(buffer)
      self.semBufferAdded.signal()
      while self.playerNode.isPlaying {
        guard self.semBufferUsed.wait(timeout: .now() + .seconds(1)) == .success else {
          continue
        }
        if self.getBuffersCount() < self.buffersCacheSize {
          break
        }
      }
      onDone(true)
    }
  }

  func setVolume(_ volume: Float) -> Bool {
    guard audioEngine.isRunning else {
      return false
    }
    playerNode.volume = volume
    audioEngine.reset()
    return true
  }

  // ---------------------------------------------------------------------------

  private func clearBuffers() {
    lckBuffers.lock()
    defer { lckBuffers.unlock() }
    buffers.removeAll()
  }

  private func getBuffersCount() -> Int {
    lckBuffers.lock()
    defer { lckBuffers.unlock() }
    let buffers_count = buffers.count
    return buffers_count
  }

  private func addBuffer(_ buffer: AVAudioPCMBuffer) {
    self.lckBuffers.lock()
    defer { lckBuffers.unlock() }
    self.buffers.insert(buffer, at: 0)
  }

  private func popBuffer() -> AVAudioPCMBuffer? {
    lckBuffers.lock()
    defer { lckBuffers.unlock() }
    let buffer = buffers.popLast()
    return buffer
  }

  private func dataToBuffer(_ data: [UInt8]) -> AVAudioPCMBuffer {
    let byteCount = data.count
    let frameLength =
      UInt32(byteCount) / inputFormat.streamDescription.pointee.mBytesPerFrame
    let audioBuffer = AVAudioPCMBuffer(
      pcmFormat: inputFormat,
      frameCapacity: frameLength)!

    data.withUnsafeBytes {
      audioBuffer.audioBufferList.pointee.mBuffers.mData!.copyMemory(
        from: $0.baseAddress!, byteCount: byteCount)
    }

    audioBuffer.frameLength = frameLength

    if pcmType == .PCMF32 {
      return audioBuffer
    }

    // let iData = audioBuffer.int16ChannelData![0]

    let audioConverter = AVAudioConverter(from: inputFormat, to: outputFormat)!
    let ratio = Double(outputFormat.sampleRate) / Double(inputFormat.sampleRate)
    let convertedAudioBuffer = AVAudioPCMBuffer(
      pcmFormat: outputFormat,
      frameCapacity: AVAudioFrameCount(Double(audioBuffer.frameCapacity) * ratio))!

    var error: NSError? = nil
    let r: AVAudioConverterOutputStatus = audioConverter.convert(
      to: convertedAudioBuffer, error: &error,
      withInputFrom: { inNumPackets, outStatus in
        outStatus.pointee = .haveData
        return audioBuffer
      })

    return convertedAudioBuffer
  }

  private func resetSemBufferUsed() {
    while semBufferUsed.wait(timeout: .now()) == .success {
      //
    }
  }

  private func resetSemBufferAdded() {
    while semBufferAdded.wait(timeout: .now()) == .success {
      //
    }
  }

}
