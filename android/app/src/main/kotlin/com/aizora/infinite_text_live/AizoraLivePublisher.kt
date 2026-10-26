package com.aizora.infinite_text_live

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.media.MediaCodec
import java.io.Closeable
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Experimental RTMPS publisher. Encodes captured Flutter canvas frames when available.
 * A successful RTMP publish response does not confirm Facebook playback.
 */
internal class AizoraLivePublisher(
    private val serverUrl: String,
    private val streamKey: String,
    private val width: Int,
    private val height: Int,
    private val musicFile: File? = null
) : Closeable {
    private val running = AtomicBoolean(false)
    @Volatile private var session: AizoraRtmpSession? = null
    @Volatile private var encoder: AizoraH264Encoder? = null
    @Volatile var state: String = "idle"
        private set
    @Volatile var lastError: String? = null
        private set
    @Volatile var sentVideoPackets: Long = 0
        private set
    @Volatile var capturedCanvasFrames: Long = 0
        private set
    private var worker: Thread? = null
    private var audioWorker: Thread? = null
    @Volatile private var latestFrame: Bitmap? = null

    fun submitFrame(png: ByteArray) {
        if (!running.get() || png.size > 3_000_000) return
        val decoded = BitmapFactory.decodeByteArray(png, 0, png.size) ?: return
        latestFrame = decoded
        capturedCanvasFrames++
    }

    @Synchronized fun start() {
        check(worker == null) { "Publisher already started" }
        running.set(true)
        state = "connecting"
        worker = Thread({
            try {
                val liveSession = AizoraRtmpSession()
                session = liveSession
                liveSession.open(serverUrl, "", streamKey)
                if (!running.get()) return@Thread
                val video = AizoraH264Encoder(width, height, 15)
                encoder = video
                val packetizer = AizoraAvcFlvPacketizer()
                state = "publishing_video"
                if (musicFile != null) {
                    audioWorker = Thread({
                        try {
                            AizoraAacMusicSource(musicFile).stream(liveSession, { running.get() })
                        } catch (error: Exception) {
                            lastError = "Music publishing: " + (error.message ?: error.javaClass.simpleName)
                        }
                    }, "AizoraAacMusic").apply { isDaemon = true; start() }
                }
                val startNs = System.nanoTime()
                var frame = 0
                while (running.get()) {
                    val image = latestFrame
                    if (image != null && !image.isRecycled) video.drawBitmapFrame(image)
                    else video.drawFrame("Waiting for canvas", Color.rgb(18, 34, 78))
                    video.drain { bytes, ptsUs, flags ->
                        if (flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM == 0) {
                            val timestamp = (ptsUs / 1000L).coerceIn(0L, Int.MAX_VALUE.toLong()).toInt()
                            for (payload in packetizer.packetize(bytes)) {
                                if (running.get()) {
                                    liveSession.sendVideo(timestamp, payload)
                                    sentVideoPackets++
                                }
                            }
                        }
                    }
                    frame++
                    val nextNs = startNs + frame * (1_000_000_000L / 15L)
                    val delayMs = ((nextNs - System.nanoTime()) / 1_000_000L).coerceAtLeast(0L)
                    if (delayMs > 0) Thread.sleep(delayMs.coerceAtMost(100L))
                }
            } catch (e: Exception) {
                lastError = e.message ?: e.javaClass.simpleName
                state = "failed"
            } finally {
                running.set(false)
                try { encoder?.close() } catch (_: Exception) {}
                encoder = null
                latestFrame = null
                audioWorker?.interrupt()
                audioWorker = null
                try { session?.close() } catch (_: Exception) {}
                session = null
                if (state != "failed") state = "stopped"
            }
        }, "AizoraRtmpsPublisher").apply { isDaemon = true; start() }
    }

    override fun close() {
        running.set(false)
        try { session?.close() } catch (_: Exception) {}
        worker?.interrupt()
        audioWorker?.interrupt()
    }
}
