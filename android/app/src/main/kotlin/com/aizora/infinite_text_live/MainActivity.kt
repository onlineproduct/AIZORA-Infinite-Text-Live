package com.aizora.infinite_text_live

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "aizora.live"
    private var publisher: AizoraLivePublisher? = null

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

                    if (publisher?.state == "connecting" || publisher?.state == "publishing_video") {
                        result.error("ALREADY_RUNNING", "Publisher is already active", null)
                        return@setMethodCallHandler
                    }
                    try {
                        publisher?.close()
                        val next = AizoraLivePublisher(serverUrl, streamKey, width.coerceIn(240, 1280), height.coerceIn(240, 1280))
                        publisher = next
                        next.start()
                        result.success(true) // Request accepted, NOT a confirmed Facebook Live.
                    } catch (error: Exception) {
                        result.error("START_FAILED", error.message ?: "Could not start publisher", null)
                    }
                }
                "submitFrame" -> {
                    val frame = call.argument<ByteArray>("png")
                    if (frame != null && publisher?.state == "publishing_video") {
                        publisher?.submitFrame(frame)
                        result.success(true)
                    } else result.success(false)
                }
                "stopLive" -> {
                    val existing = publisher
                    existing?.close()
                    result.success(existing != null)
                }
                "status" -> {
                    val current = publisher
                    result.success(mapOf(
                        "status" to (current?.state ?: "idle"),
                        "streaming" to (current?.state == "publishing_video"),
                        "error" to current?.lastError,
                        "platform" to "android",
                        "previewMatchesStream" to false
                    ))
                }
                else -> result.notImplemented()
            }
        }
    }
}
