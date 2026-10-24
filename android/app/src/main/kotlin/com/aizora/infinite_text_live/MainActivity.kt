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

                    result.success(true)
                    android.util.Log.i("AIZORA_LIVE", "startLive requested: serverUrl=$serverUrl width=$width height=$height streamKeyLength=${streamKey.length}")
                }
                "stopLive" -> {
                    result.success(true)
                    android.util.Log.i("AIZORA_LIVE", "stopLive requested")
                }
                "status" -> {
                    result.success(mapOf(
                        "status" to "bridge_ready",
                        "streaming" to false,
                        "platform" to "android",
                    ))
                }
                else -> result.notImplemented()
            }
        }
    }
}
