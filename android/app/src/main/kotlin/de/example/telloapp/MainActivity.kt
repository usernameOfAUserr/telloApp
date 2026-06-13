package de.example.telloapp

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformViewRegistry
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    private lateinit var videoController: TelloVideoController

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        videoController = TelloVideoController(applicationContext)
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
    }

    override fun onDestroy() {
        if (::videoController.isInitialized) videoController.stop()
        super.onDestroy()
    }
}
