package de.example.telloapp

import android.Manifest
import android.content.pm.PackageManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformViewRegistry
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    private lateinit var videoController: TelloVideoController
    private lateinit var beatDetector: TelloBeatDetector
    private var pendingAudioResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        videoController = TelloVideoController(applicationContext)
        beatDetector = TelloBeatDetector()
        val registry: PlatformViewRegistry = flutterEngine.platformViewsController.registry
        registry.registerViewFactory(
            "de.example.telloapp/video-view",
            TelloVideoViewFactory(videoController),
        )

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "de.example.telloapp/video",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    videoController.start()
                    result.success(null)
                }
                "stop" -> {
                    videoController.stop()
                    result.success(null)
                }
                "capturePhoto" -> videoController.capturePhoto(
                    onSuccess = result::success,
                    onError = { result.error("capture_failed", it, null) },
                )
                "startRecording" -> {
                    videoController.startRecording()
                    result.success("Aufnahme gestartet")
                }
                "stopRecording" -> {
                    try {
                        result.success(videoController.stopRecording())
                    } catch (error: Exception) {
                        result.error("recording_failed", error.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "de.example.telloapp/beats",
        ).setStreamHandler(beatDetector)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "de.example.telloapp/audio",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> startBeatDetection(result)
                "stop" -> {
                    beatDetector.stop()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startBeatDetection(result: MethodChannel.Result) {
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            try {
                beatDetector.start()
                result.success(null)
            } catch (error: Exception) {
                result.error("audio_start_failed", error.message, null)
            }
            return
        }
        pendingAudioResult = result
        requestPermissions(
            arrayOf(Manifest.permission.RECORD_AUDIO),
            AUDIO_PERMISSION_REQUEST,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != AUDIO_PERMISSION_REQUEST) return
        val result = pendingAudioResult
        pendingAudioResult = null
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            try {
                beatDetector.start()
                result?.success(null)
            } catch (error: Exception) {
                result?.error("audio_start_failed", error.message, null)
            }
        } else {
            result?.error(
                "microphone_denied",
                "Mikrofonzugriff wurde nicht erlaubt.",
                null,
            )
        }
    }

    override fun onDestroy() {
        if (::videoController.isInitialized) videoController.stop()
        if (::beatDetector.isInitialized) beatDetector.stop()
        super.onDestroy()
    }

    private companion object {
        const val AUDIO_PERMISSION_REQUEST = 4201
    }
}
