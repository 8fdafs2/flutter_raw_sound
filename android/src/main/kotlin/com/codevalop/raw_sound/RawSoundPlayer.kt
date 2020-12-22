package com.codevalop.raw_sound

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import androidx.annotation.NonNull
import io.flutter.Log
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withPermit
import java.nio.ByteBuffer

enum class PlayState {
    Stopped,
    Playing,
    Paused,
}

enum class PCMType {
    PCMI16,
    PCMF32,
}

/** RawSoundPlayer */
class RawSoundPlayer(@NonNull androidContext: Context, @NonNull bufferSize: Int,
                     @NonNull sampleRate: Int, @NonNull nChannels: Int, @NonNull pcmType: PCMType) {
    companion object {
        const val TAG = "RawSoundPlayer"
    }

    private val audioTrack: AudioTrack
    private val semBufferAdded = Semaphore(Int.MAX_VALUE, Int.MAX_VALUE)
    private val semBufferUsed = Semaphore(Int.MAX_VALUE, Int.MAX_VALUE)
    private val buffers: MutableList<ByteBuffer> = mutableListOf()
    private val buffersCacheSize = 4
    private val semAddBufferIdled = Semaphore(1, 0)
    private val semUseBufferIdled = Semaphore(1, 0)
    private val lckBuffers = Mutex()
    private val pcmType: PCMType

    init {
        require(nChannels == 1 || nChannels == 2) { "Only support one or two channels" }
        val audioManager = androidContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val sessionId = audioManager.generateAudioSessionId()
        this.pcmType = pcmType
        val attributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build()
        val encoding = when (pcmType) {
            PCMType.PCMI16 -> AudioFormat.ENCODING_PCM_16BIT
            PCMType.PCMF32 -> AudioFormat.ENCODING_PCM_FLOAT
        }
        val format = AudioFormat.Builder()
                .setEncoding(encoding)
                .setSampleRate(sampleRate)
                .setChannelMask(if (nChannels == 1) AudioFormat.CHANNEL_OUT_MONO else AudioFormat.CHANNEL_OUT_STEREO)
                .build()
        Log.i(TAG, "Create audio track w/ bufferSize: $bufferSize, sampleRate: ${format.getSampleRate()}, encoding: ${format.getEncoding()}, nChannels: ${format.getChannelCount()}")
        audioTrack = AudioTrack(attributes, format, bufferSize, AudioTrack.MODE_STREAM, sessionId)
        Log.i(TAG, "sessionId: ${audioTrack.getAudioSessionId()}, bufferCapacityInFrames: ${audioTrack.getBufferCapacityInFrames()}, bufferSizeInFrames: ${audioTrack.getBufferSizeInFrames()}")
    }

    fun release(): Boolean {
        runBlocking {
            clearBuffers()
        }
        audioTrack.release()
        return true
    }

    fun getPlayState(): Int {
        return when (audioTrack.playState) {
            AudioTrack.PLAYSTATE_PAUSED -> PlayState.Paused.ordinal
            AudioTrack.PLAYSTATE_PLAYING -> PlayState.Playing.ordinal
            else -> PlayState.Stopped.ordinal
        }
    }

    fun play(): Boolean {
        try {
            audioTrack.play()
        } catch (t: Throwable) {
            Log.e(TAG, "Trying to play an uninitialized audio track")
            return false
        }

        GlobalScope.launch(Dispatchers.IO) {
            Log.d(TAG, "--> queUseBuffer")
            semUseBufferIdled.withPermit {
                while (audioTrack.playState == AudioTrack.PLAYSTATE_PLAYING) {
                    withTimeoutOrNull(1000 * 1) {
                        semBufferAdded.acquire()
                    } ?: continue
                    val buffer = popBuffer() ?: continue
                    // Log.d(TAG, "bufferSize: ${buffer.remaining()}")
                    while (buffer.remaining() > 0) {
                        val bytes = audioTrack.write(buffer, buffer.remaining(), AudioTrack.WRITE_BLOCKING)
                        if (bytes < 0) {
                            Log.e(TAG, "Failed to write into audio track buffer: $bytes")
                            break
                        } else {
                            Log.w(TAG, "Write zero bytes into audio track buffer")
                            break
                        }
                    }
                    semBufferUsed.release()
                }
            }
            Log.d(TAG, "<-- queUseBuffer")
        }

        return true
    }

    fun stop(): Boolean {
        val r = try {
            audioTrack.pause()
            audioTrack.flush()
            audioTrack.stop()
            true
        } catch (t: Throwable) {
            Log.e(TAG, "Trying to stop an uninitialized audio track")
            false
        }
        runBlocking {
            clearBuffers()
        }
        return r
    }

    fun pause(): Boolean {
        val r = try {
            audioTrack.pause()
            true
        } catch (t: Throwable) {
            Log.e(TAG, "Trying to pause an uninitialized audio track")
            false
        }
        runBlocking {
            clearBuffers()
        }
        return r
    }

    fun resume(): Boolean {
        return try {
            audioTrack.play()
            true
        } catch (t: Throwable) {
            Log.e(TAG, "Trying to resume an uninitialized audio track")
            false
        }
    }

    fun feed(@NonNull data: ByteArray, onDone: (r: Boolean) -> Unit) {
        if (audioTrack.playState != AudioTrack.PLAYSTATE_PLAYING) {
            Log.e(TAG, "Player is not playing")
            onDone(true)
            return
        }

        GlobalScope.launch(Dispatchers.Default) {
            // Log.d(TAG, "--> queAddBuffer")
            semAddBufferIdled.withPermit {
                addBuffer(ByteBuffer.wrap(data))
                semBufferAdded.release()
                if (getBuffersCount() >= buffersCacheSize) {
                    while (audioTrack.playState == AudioTrack.PLAYSTATE_PLAYING) {
                        withTimeoutOrNull(1000 * 1) {
                            semBufferUsed.acquire()
                        } ?: continue
                        if (getBuffersCount() < buffersCacheSize) {
                            break
                        }
                    }
                }
                onDone(true)
            }
            // Log.d(TAG, "<-- queAddBuffer")
        }
        // Log.d(TAG, "underrun count: ${audioTrack.underrunCount}")
    }

    fun setVolume(@NonNull volume: Float): Boolean {
        val r = audioTrack.setVolume(volume)
        if (r == AudioTrack.SUCCESS) {
            return true
        }
        Log.e(TAG, "Failed to setVolume of audio track: $r")
        return false
    }

    // ---------------------------------------------------------------------------------------------

    private suspend fun clearBuffers() {
        lckBuffers.withLock {
            buffers.clear()
        }
    }

    private suspend fun getBuffersCount(): Int {
        lckBuffers.withLock {
            return buffers.size
        }
    }

    private suspend fun addBuffer(buffer: ByteBuffer) {
        lckBuffers.withLock {
            buffers.add(0, buffer)
        }
    }

    private suspend fun popBuffer(): ByteBuffer? {
        lckBuffers.withLock {
            val size = buffers.size
            return if (size == 0) null else buffers.removeAt(size - 1)
        }
    }
}

