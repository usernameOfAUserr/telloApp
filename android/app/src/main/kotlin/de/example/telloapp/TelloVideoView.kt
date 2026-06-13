package de.example.telloapp

import android.content.Context
import android.media.MediaCodec
import android.media.MediaFormat
import android.os.SystemClock
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
import java.nio.ByteBuffer
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
                    controller.attachSurface(holder.surface)
                }

                override fun surfaceChanged(
                    holder: android.view.SurfaceHolder,
                    format: Int,
                    width: Int,
                    height: Int,
                ) = Unit

                override fun surfaceDestroyed(holder: android.view.SurfaceHolder) {
                    controller.detachSurface(holder.surface)
                }
            },
        )
    }

    override fun getView(): View = surfaceView

    override fun dispose() {
        controller.detachSurface(surfaceView.holder.surface)
    }
}

class TelloVideoController {
    private val running = AtomicBoolean(false)
    private var socket: DatagramSocket? = null
    private var decoder: MediaCodec? = null
    private var surface: Surface? = null
    private var receiverThread: Thread? = null

    @Synchronized
    fun attachSurface(newSurface: Surface) {
        surface = newSurface
        if (running.get()) configureDecoder()
    }

    @Synchronized
    fun detachSurface(oldSurface: Surface) {
        if (surface == oldSurface) {
            releaseDecoder()
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
        releaseDecoder()
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
