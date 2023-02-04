import Flutter
import UIKit
import os

public class RawSoundPlugin: NSObject, FlutterPlugin {

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "codevalop.com/raw_sound", binaryMessenger: registrar.messenger())
    let instance = RawSoundPlugin(channel: channel)
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  private let channel: FlutterMethodChannel
  private var players = [RawSoundPlayer]()

  init(channel: FlutterMethodChannel) {
    self.channel = channel
    super.init()
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args: [String: AnyObject] = call.arguments as! [String: AnyObject]

    var playerNo = -1
    if call.method != "initialize" {
      playerNo = args["playerNo"] as! Int

      if playerNo < 0 || playerNo > players.count - 1 {
        result(
          FlutterError(code: "Invalid Args", message: "Invalid playerNo: $playerNo", details: nil))
        return
      }
    }

    switch call.method {
    case "getPlatformVersion":
      result("iOS \(UIDevice.current.systemVersion)")
    case "initialize":
      let bufferSize = args["bufferSize"] as! Int
      let sampleRate = args["sampleRate"] as! Int
      let nChannels = args["nChannels"] as! Int
      let pcmType: PCMType = PCMType(rawValue: args["pcmType"] as! Int)!
      let configureAudioSession = args["configureAudioSession"] as! Bool
      initialize(
        bufferSize: bufferSize, sampleRate: sampleRate,
        nChannels: nChannels, pcmType: pcmType, configureAudioSession: configureAudioSession,
        result: result,
        )
    case "release":
      release(playerNo: playerNo, result: result)
    case "play":
      play(playerNo: playerNo, result: result)
    case "stop":
      stop(playerNo: playerNo, result: result)
    case "pause":
      pause(playerNo: playerNo, result: result)
    case "resume":
      resume(playerNo: playerNo, result: result)
    case "feed":
      let _data = args["data"] as! FlutterStandardTypedData
      let data: [UInt8] = [UInt8](_data.data)
      feed(playerNo: playerNo, data: data, result: result)
    case "setVolume":
      let volume = args["volume"] as! Float
      setVolume(playerNo: playerNo, volume: volume, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func sendResultError(
    _ code: String, message: String?, details: Any?,
    result: @escaping FlutterResult
  ) {
    DispatchQueue.main.async {
      result(FlutterError(code: code, message: message, details: details))
    }
  }

  private func sendResultInt(_ playState: Int, result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      result(playState)
    }
  }

  private func initialize(
    bufferSize: Int, sampleRate: Int, nChannels: Int, pcmType: PCMType, configureAudioSession: Bool,
    result: @escaping FlutterResult
  ) {
    guard
      let player = RawSoundPlayer(
        bufferSize: bufferSize, sampleRate: sampleRate,
        nChannels: nChannels, pcmType: pcmType,
        configureAudioSession: configureAudioSession)
    else {
      sendResultError(
        "Error", message: "Failed to initalize", details: nil, result: result)
      return
    }
    players.append(player)
    sendResultInt(players.count - 1, result: result)
  }

  private func release(playerNo: Int, result: @escaping FlutterResult) {
    let player = players[playerNo]
    if player.release() {
      players.remove(at: playerNo)
      sendResultInt(playerNo, result: result)
    } else {
      sendResultError(
        "Error", message: "Failed to release", details: nil, result: result)
    }
  }

  private func play(playerNo: Int, result: @escaping FlutterResult) {
    let player = players[playerNo]
    if player.play() {
      sendResultInt(player.getPlayState(), result: result)
    } else {
      sendResultError(
        "Error", message: "Failed to play", details: nil, result: result)
    }
  }

  private func stop(playerNo: Int, result: @escaping FlutterResult) {
    let player = players[playerNo]
    if player.stop() {
      sendResultInt(player.getPlayState(), result: result)
    } else {
      sendResultError(
        "Error", message: "Failed to stop", details: nil, result: result)
    }
  }

  private func resume(playerNo: Int, result: @escaping FlutterResult) {
    let player = players[playerNo]
    if player.resume() {
      sendResultInt(player.getPlayState(), result: result)
    } else {
      sendResultError(
        "Error", message: "Failed to resume", details: nil, result: result)
    }
  }

  private func pause(playerNo: Int, result: @escaping FlutterResult) {
    let player = players[playerNo]
    if player.pause() {
      sendResultInt(player.getPlayState(), result: result)
    } else {
      sendResultError(
        "Error", message: "Failed to pause", details: nil, result: result)
    }
  }

  private func feed(playerNo: Int, data: [UInt8], result: @escaping FlutterResult) {
    let player = players[playerNo]
    player.feed(
      data: data,
      onDone: { r in
        if r {
          self.sendResultInt(player.getPlayState(), result: result)
        } else {
          self.sendResultError(
            "Error", message: "Failed to feed", details: nil, result: result)
        }
      }
    )
  }

  private func setVolume(playerNo: Int, volume: Float, result: @escaping FlutterResult) {
    let player = players[playerNo]
    if player.setVolume(volume) {
      sendResultInt(player.getPlayState(), result: result)
    } else {
      sendResultError(
        "Error", message: "Failed to setVolume", details: nil, result: result)
    }
  }
}
