package de.example.telloapp

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.sqrt

class TelloBeatDetector : EventChannel.StreamHandler {
    private val running = AtomicBoolean(false)
    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private var audioRecord: AudioRecord? = null
    private var worker: Thread? = null
    private var movingAverage = 0.0

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    fun start() {
        if (!running.compareAndSet(false, true)) return
        val minimum = AudioRecord.getMinBufferSize(
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        val bufferSize = maxOf(minimum, SAMPLE_RATE / 5)
        audioRecord = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            bufferSize,
        )
        val recorder = audioRecord
        if (recorder?.state != AudioRecord.STATE_INITIALIZED) {
            stop()
            error("Mikrofon konnte nicht initialisiert werden.")
        }
        try {
            recorder.startRecording()
        } catch (error: Exception) {
            stop()
            throw error
        }
        worker = Thread(
            { detectLoop(bufferSize) },
            "tello-beat-detector",
        ).also { it.start() }
    }

    fun stop() {
        running.set(false)
        try {
            audioRecord?.stop()
        } catch (_: IllegalStateException) {
            // Recorder may already be stopped.
        }
        audioRecord?.release()
        audioRecord = null
        worker?.interrupt()
        worker = null
        movingAverage = 0.0
    }

    private fun detectLoop(bufferSize: Int) {
        val samples = ShortArray(bufferSize)
        while (running.get()) {
            val count = audioRecord?.read(samples, 0, samples.size) ?: break
            if (count <= 0) continue
            var sum = 0.0
            for (index in 0 until count) {
                val value = samples[index].toDouble()
                sum += value * value
            }
            val rms = sqrt(sum / count) / Short.MAX_VALUE
            movingAverage = if (movingAverage == 0.0) {
                rms
            } else {
                movingAverage * 0.88 + rms * 0.12
            }
            val threshold = maxOf(MINIMUM_LEVEL, movingAverage * BEAT_FACTOR)
            if (rms > threshold) {
                val strength = (rms / threshold).coerceIn(1.0, 3.0)
                mainHandler.post { eventSink?.success(strength) }
            }
        }
    }

    private companion object {
        const val SAMPLE_RATE = 44_100
        const val MINIMUM_LEVEL = 0.025
        const val BEAT_FACTOR = 1.55
    }
}
