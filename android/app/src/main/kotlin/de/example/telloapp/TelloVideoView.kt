package de.example.telloapp

import android.content.Context
import android.graphics.Bitmap
import android.media.MediaCodec
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.Build
import android.os.Environment
import android.os.SystemClock
import android.provider.MediaStore
import android.view.PixelCopy
import android.view.Surface
import android.view.SurfaceView
import android.view.View
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetSocketAddress
import java.net.SocketException
import java.io.File
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.atomic.AtomicBoolean

class TelloVideoViewFactory(
    private val controller: TelloVideoController,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return TelloVideoPlatformView(context, controller)
    }
}

private class TelloVideoPlatformView(
    context: Context,
    private val controller: TelloVideoController,
) : PlatformView {
    private val surfaceView = SurfaceView(context)

    init {
        surfaceView.holder.addCallback(
            object : android.view.SurfaceHolder.Callback {
                override fun surfaceCreated(holder: android.view.SurfaceHolder) {
                    controller.attachSurface(surfaceView)
                }

                override fun surfaceChanged(
                    holder: android.view.SurfaceHolder,
                    format: Int,
                    width: Int,
                    height: Int,
                ) = Unit

                override fun surfaceDestroyed(holder: android.view.SurfaceHolder) {
                    controller.detachSurface(surfaceView)
                }
            },
        )
    }

    override fun getView(): View = surfaceView

    override fun dispose() {
        controller.detachSurface(surfaceView)
    }
}

class TelloVideoController(private val context: Context) {
    private val running = AtomicBoolean(false)
    private var socket: DatagramSocket? = null
    private var decoder: MediaCodec? = null
    private var surface: Surface? = null
    private var surfaceView: SurfaceView? = null
    private var receiverThread: Thread? = null
    private var recordingRequested = false
    private var muxer: MediaMuxer? = null
    private var muxerTrack = -1
    private var recordingFile: File? = null
    private var recordingStartedAtUs = 0L
    private var recordedSamples = 0
    private var sequenceParameterSet: ByteArray? = null
    private var pictureParameterSet: ByteArray? = null

    @Synchronized
    fun attachSurface(view: SurfaceView) {
        surfaceView = view
        surface = view.holder.surface
        if (running.get()) configureDecoder()
    }

    @Synchronized
    fun detachSurface(view: SurfaceView) {
        if (surfaceView == view) {
            releaseDecoder()
            surfaceView = null
            surface = null
        }
    }

    @Synchronized
    fun start() {
        if (!running.compareAndSet(false, true)) return
        configureDecoder()
        receiverThread = Thread(::receiveLoop, "tello-h264-receiver").also {
            it.start()
        }
    }

    @Synchronized
    fun stop() {
        running.set(false)
        socket?.close()
        socket = null
        receiverThread?.interrupt()
        receiverThread = null
        if (recordingRequested) stopRecording()
        releaseDecoder()
    }

    fun capturePhoto(onSuccess: (String) -> Unit, onError: (String) -> Unit) {
        val view = surfaceView
        if (view == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            onError("Fotoaufnahme benötigt Android 7 oder neuer.")
            return
        }
        val bitmap = Bitmap.createBitmap(
            view.width.coerceAtLeast(1),
            view.height.coerceAtLeast(1),
            Bitmap.Config.ARGB_8888,
        )
        PixelCopy.request(
            view,
            bitmap,
            { result ->
                if (result != PixelCopy.SUCCESS) {
                    bitmap.recycle()
                    onError("PixelCopy-Fehler $result")
                    return@request
                }
                try {
                    onSuccess(savePhoto(bitmap))
                } catch (error: Exception) {
                    onError(error.message ?: "Foto konnte nicht gespeichert werden.")
                } finally {
                    bitmap.recycle()
                }
            },
            view.handler,
        )
    }

    @Synchronized
    fun startRecording() {
        if (recordingRequested) return
        recordingRequested = true
        recordedSamples = 0
        recordingFile = File.createTempFile("tello_", ".mp4", context.cacheDir)
        startMuxerIfReady()
    }

    @Synchronized
    fun stopRecording(): String {
        recordingRequested = false
        muxer?.let {
            try {
                if (muxerTrack >= 0 && recordedSamples > 0) it.stop()
            } finally {
                it.release()
            }
        }
        muxer = null
        muxerTrack = -1
        val file = recordingFile
        recordingFile = null
        if (file == null ||
            !file.exists() ||
            file.length() == 0L ||
            recordedSamples == 0
        ) {
            file?.delete()
            return "Keine Videodaten empfangen"
        }
        return publishVideo(file)
    }

    @Synchronized
    private fun configureDecoder() {
        val outputSurface = surface ?: return
        releaseDecoder()
        decoder = MediaCodec.createDecoderByType(MediaFormat.MIMETYPE_VIDEO_AVC).apply {
            val format = MediaFormat.createVideoFormat(
                MediaFormat.MIMETYPE_VIDEO_AVC,
                VIDEO_WIDTH,
                VIDEO_HEIGHT,
            )
            format.setInteger(
                MediaFormat.KEY_MAX_INPUT_SIZE,
                MAX_ACCESS_UNIT_SIZE,
            )
            configure(format, outputSurface, null, 0)
            start()
        }
    }

    private fun receiveLoop() {
        val packetBuffer = ByteArray(UDP_PACKET_SIZE)
        val accessUnit = ByteBuffer.allocate(MAX_ACCESS_UNIT_SIZE)
        try {
            socket = DatagramSocket(null).apply {
                reuseAddress = true
                bind(InetSocketAddress(VIDEO_PORT))
                soTimeout = 1000
            }
            while (running.get()) {
                try {
                    val packet = DatagramPacket(packetBuffer, packetBuffer.size)
                    socket?.receive(packet)
                    if (accessUnit.remaining() < packet.length) accessUnit.clear()
                    accessUnit.put(packet.data, packet.offset, packet.length)
                    if (packet.length < UDP_PACKET_SIZE) {
                        val frame = ByteArray(accessUnit.position())
                        accessUnit.flip()
                        accessUnit.get(frame)
                        accessUnit.clear()
                        inspectCodecData(frame)
                        writeRecordingSample(frame)
                        queueAccessUnit(frame)
                    }
                } catch (_: java.net.SocketTimeoutException) {
                    // Re-check running periodically.
                }
            }
        } catch (_: SocketException) {
            // Closing the socket is the normal shutdown mechanism.
        } finally {
            socket?.close()
            socket = null
        }
    }

    @Synchronized
    private fun inspectCodecData(frame: ByteArray) {
        for ((type, nal) in splitNalUnits(frame)) {
            when (type) {
                7 -> sequenceParameterSet = nal
                8 -> pictureParameterSet = nal
            }
        }
        startMuxerIfReady()
    }

    @Synchronized
    private fun startMuxerIfReady() {
        if (!recordingRequested || muxer != null) return
        val sps = sequenceParameterSet ?: return
        val pps = pictureParameterSet ?: return
        val file = recordingFile ?: return
        val mediaFormat = MediaFormat.createVideoFormat(
            MediaFormat.MIMETYPE_VIDEO_AVC,
            VIDEO_WIDTH,
            VIDEO_HEIGHT,
        ).apply {
            setByteBuffer("csd-0", ByteBuffer.wrap(sps))
            setByteBuffer("csd-1", ByteBuffer.wrap(pps))
            setInteger(MediaFormat.KEY_FRAME_RATE, 30)
        }
        muxer = MediaMuxer(
            file.absolutePath,
            MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4,
        ).also {
            muxerTrack = it.addTrack(mediaFormat)
            it.start()
            recordingStartedAtUs = SystemClock.elapsedRealtimeNanos() / 1000
        }
    }

    @Synchronized
    private fun writeRecordingSample(frame: ByteArray) {
        val activeMuxer = muxer ?: return
        if (!recordingRequested || muxerTrack < 0) return
        val isKeyFrame = splitNalUnits(frame).any { it.first == 5 }
        val info = MediaCodec.BufferInfo().apply {
            offset = 0
            size = frame.size
            presentationTimeUs =
                SystemClock.elapsedRealtimeNanos() / 1000 - recordingStartedAtUs
            flags = if (isKeyFrame) MediaCodec.BUFFER_FLAG_KEY_FRAME else 0
        }
        activeMuxer.writeSampleData(muxerTrack, ByteBuffer.wrap(frame), info)
        recordedSamples++
    }

    private fun splitNalUnits(frame: ByteArray): List<Pair<Int, ByteArray>> {
        val starts = mutableListOf<Int>()
        var index = 0
        while (index < frame.size - 3) {
            val threeByteStart = frame[index] == 0.toByte() &&
                frame[index + 1] == 0.toByte() &&
                frame[index + 2] == 1.toByte()
            val fourByteStart = index < frame.size - 4 &&
                frame[index] == 0.toByte() &&
                frame[index + 1] == 0.toByte() &&
                frame[index + 2] == 0.toByte() &&
                frame[index + 3] == 1.toByte()
            if (threeByteStart || fourByteStart) starts += index
            index += if (fourByteStart) 4 else if (threeByteStart) 3 else 1
        }
        return starts.mapIndexedNotNull { position, start ->
            val prefix = if (frame[start + 2] == 1.toByte()) 3 else 4
            val end = starts.getOrNull(position + 1) ?: frame.size
            if (start + prefix >= end) return@mapIndexedNotNull null
            val nal = frame.copyOfRange(start, end)
            val type = frame[start + prefix].toInt() and 0x1f
            type to nal
        }
    }

    private fun savePhoto(bitmap: Bitmap): String {
        val name = "TELLO_${timestamp()}.jpg"
        val values = android.content.ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, name)
            put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/Tello")
            }
        }
        val uri = context.contentResolver.insert(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            values,
        ) ?: error("Galerieeintrag konnte nicht erstellt werden.")
        context.contentResolver.openOutputStream(uri)?.use {
            bitmap.compress(Bitmap.CompressFormat.JPEG, 95, it)
        } ?: error("Galeriedatei konnte nicht geöffnet werden.")
        return uri.toString()
    }

    private fun publishVideo(file: File): String {
        val values = android.content.ContentValues().apply {
            put(MediaStore.Video.Media.DISPLAY_NAME, "TELLO_${timestamp()}.mp4")
            put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Video.Media.RELATIVE_PATH, Environment.DIRECTORY_MOVIES + "/Tello")
            }
        }
        val uri = context.contentResolver.insert(
            MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
            values,
        ) ?: error("Videoeintrag konnte nicht erstellt werden.")
        context.contentResolver.openOutputStream(uri)?.use { output ->
            FileInputStream(file).use { input -> input.copyTo(output) }
        } ?: error("Videodatei konnte nicht geöffnet werden.")
        file.delete()
        return uri.toString()
    }

    private fun timestamp(): String =
        SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())

    @Synchronized
    private fun queueAccessUnit(frame: ByteArray) {
        val codec = decoder ?: return
        try {
            val inputIndex = codec.dequeueInputBuffer(0)
            if (inputIndex >= 0) {
                val inputBuffer = codec.getInputBuffer(inputIndex)
                if (inputBuffer == null || inputBuffer.capacity() < frame.size) {
                    codec.queueInputBuffer(inputIndex, 0, 0, 0, 0)
                    return
                }
                inputBuffer.apply {
                    clear()
                    put(frame)
                }
                codec.queueInputBuffer(
                    inputIndex,
                    0,
                    frame.size,
                    SystemClock.elapsedRealtimeNanos() / 1000,
                    0,
                )
            }

            val info = MediaCodec.BufferInfo()
            var outputIndex = codec.dequeueOutputBuffer(info, 0)
            while (outputIndex >= 0) {
                codec.releaseOutputBuffer(outputIndex, true)
                outputIndex = codec.dequeueOutputBuffer(info, 0)
            }
        } catch (_: IllegalStateException) {
            // Surface recreation may race with an incoming UDP frame.
        }
    }

    @Synchronized
    private fun releaseDecoder() {
        decoder?.let {
            try {
                it.stop()
            } catch (_: IllegalStateException) {
                // Decoder may not have reached the started state.
            }
            it.release()
        }
        decoder = null
    }

    private companion object {
        const val VIDEO_PORT = 11111
        const val VIDEO_WIDTH = 960
        const val VIDEO_HEIGHT = 720
        const val UDP_PACKET_SIZE = 1460
        const val MAX_ACCESS_UNIT_SIZE = 1024 * 1024
    }
}
