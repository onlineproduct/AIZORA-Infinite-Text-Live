package com.aizora.infinite_text_live

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "aizora.live"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "startLive" -> {
                    val serverUrl = call.argument<String>("serverUrl") ?: ""
                    val streamKey = call.argument<String>("streamKey") ?: ""
                    val width = call.argument<Int>("width") ?: 1280
                    val height = call.argument<Int>("height") ?: 720

                    if (serverUrl.isBlank() || streamKey.isBlank()) {
                        result.error("INVALID_ARGUMENT", "serverUrl and streamKey are required", null)
                        return@setMethodCallHandler
                    }

                    android.util.Log.w("AIZORA_LIVE", "RTMPS publisher is not implemented yet; refusing to report a false live start.")
                    result.error("PUBLISHER_NOT_IMPLEMENTED", "RTMPS publishing is not implemented yet. No Facebook Live stream was started.", null)
                }
                "stopLive" -> {
                    result.success(false)
                    android.util.Log.i("AIZORA_LIVE", "No active publisher exists; stop acknowledged without claiming a stream stopped.")
                }
                "status" -> {
                    result.success(mapOf(
                        "status" to "publisher_not_implemented",
                        "streaming" to false,
                        "platform" to "android",
                    ))
                }
                else -> result.notImplemented()
            }
        }
    }
}
