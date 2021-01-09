package com.codevalop.raw_sound

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import androidx.annotation.Nullable
import io.flutter.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result


/** RawSoundPlugin */
class RawSoundPlugin : FlutterPlugin, MethodCallHandler {
    companion object {
        const val TAG = "RawSoundPlugin"
    }

    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel

    private lateinit var androidContext: Context

    private var players: MutableList<RawSoundPlayer> = mutableListOf()

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "codevalop.com/raw_sound")
        channel.setMethodCallHandler(this)
        androidContext = flutterPluginBinding.applicationContext
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        var playerNo: Int = -1

        if (call.method != "initialize") {
            playerNo = call.argument<Int>("playerNo")!!
            if (playerNo < 0 || playerNo > players.size) {
                result.error("Invalid Args", "Invalid playerNo: $playerNo", "")
                Log.e(TAG, "Invalid playerNo: $playerNo")
                return
            }
            // Log.d(TAG, "${call.method} w/ playerNo: $playerNo")
        }

        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            "initialize" -> {
                val bufferSize = call.argument<Int>("bufferSize")!!
                val sampleRate = call.argument<Int>("sampleRate")!!
                val nChannels = call.argument<Int>("nChannels")!!
                val pcmType = PCMType.values().getOrNull(call.argument<Int>("pcmType")!!)!!
                initialize(bufferSize, sampleRate, nChannels, pcmType, result)
            }
            "release" -> {
                release(playerNo, result)
            }
            "play" -> {
                play(playerNo, result)
            }
            "stop" -> {
                stop(playerNo, result)
            }
            "pause" -> {
                pause(playerNo, result)
            }
            "resume" -> {
                resume(playerNo, result)
            }
            "feed" -> {
                val data = call.argument<ByteArray>("data")!!
                feed(playerNo, data, result)
            }
            "setVolume" -> {
                val volume = call.argument<Float>("volume")!!
                setVolume(playerNo, volume, result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    private fun sendResultError(@NonNull errorCode: String, @Nullable errorMessage: String,
                                @Nullable errorDetails: Any?, @NonNull result: Result) {
        Handler(Looper.getMainLooper()).post {
            result.error(errorCode, errorMessage, errorDetails)
        }
    }

    private fun sendResultInt(@NonNull playState: Int, @NonNull result: Result) {
        Handler(Looper.getMainLooper()).post {
            result.success(playState)
        }
    }

    private fun initialize(@NonNull bufferSize: Int, @NonNull sampleRate: Int,
                           @NonNull nChannels: Int, @NonNull pcmType: PCMType,
                           @NonNull result: Result) {
        val player = RawSoundPlayer(androidContext, bufferSize, sampleRate, nChannels, pcmType)
        players.add(player)
        sendResultInt(players.lastIndex, result)
    }

    private fun release(@NonNull playerNo: Int, @NonNull result: Result) {
        val player = players[playerNo]
        if (player.release()) {
            players.removeAt(playerNo)
            sendResultInt(playerNo, result)
        } else {
            sendResultError("Error", "Failed to release player",
                    null, result)
        }
    }

    private fun play(@NonNull playerNo: Int, @NonNull result: Result) {
        val player = players[playerNo]
        if (player.play()) {
            sendResultInt(player.getPlayState(), result)
        } else {
            sendResultError("Error", "Failed to play player",
                    null, result)
        }
    }

    private fun stop(@NonNull playerNo: Int, @NonNull result: Result) {
        val player = players[playerNo]
        if (player.stop()) {
            sendResultInt(player.getPlayState(), result)
        } else {
            sendResultError("Error", "Failed to stop player",
                    null, result)
        }
    }

    private fun resume(@NonNull playerNo: Int, @NonNull result: Result) {
        val player = players[playerNo]
        if (player.resume()) {
            sendResultInt(player.getPlayState(), result)
        } else {
            sendResultError("Error", "Failed to resume player",
                    null, result)
        }
    }

    private fun pause(@NonNull playerNo: Int, @NonNull result: Result) {
        val player = players[playerNo]
        if (player.pause()) {
            sendResultInt(player.getPlayState(), result)
        } else {
            sendResultError("Error", "Failed to pause player",
                    null, result)
        }
    }

    private fun feed(@NonNull playerNo: Int, @NonNull data: ByteArray, @NonNull result: Result) {
        val player = players[playerNo]
        player.feed(
                data
        ) { r: Boolean ->
            if (r) {
                sendResultInt(player.getPlayState(), result)
            } else {
                sendResultError("Error", "Failed to feed player",
                        null, result)
            }
        }
    }

    private fun setVolume(@NonNull playerNo: Int, @NonNull volume: Float, @NonNull result: Result) {
        val player = players[playerNo]
        if (player.setVolume(volume)) {
            sendResultInt(player.getPlayState(), result)
        } else {
            sendResultError("Error", "Failed to setVolume player",
                    null, result)
        }
    }
}
