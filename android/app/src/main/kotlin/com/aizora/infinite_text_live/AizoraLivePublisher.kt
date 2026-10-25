package com.aizora.infinite_text_live

import android.graphics.Color
import android.media.MediaCodec
import java.io.Closeable
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Experimental video-only publisher. Draws a native placeholder scene, not the
 * Flutter canvas. A successful connection is not proof of Facebook playback.
 */
internal class AizoraLivePublisher(
    private val serverUrl: String,
    private val streamKey: String,
    private val width: Int,
    private val height: Int
) : Closeable {
    private val running = AtomicBoolean(false)
    @Volatile private var session: AizoraRtmpSession? = null
    @Volatile private var encoder: AizoraH264Encoder? = null
    @Volatile var state: String = "idle"
        private set
    @Volatile var lastError: String? = null
        private set
    private var worker: Thread? = null

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
                val startNs = System.nanoTime()
                var frame = 0
                while (running.get()) {
                    video.drawFrame("AIZORA TEXT LIVE", if (frame / 45 % 2 == 0) Color.rgb(18, 34, 78) else Color.rgb(53, 27, 90))
                    video.drain { bytes, ptsUs, flags ->
                        if (flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM == 0) {
                            val timestamp = (ptsUs / 1000L).coerceIn(0L, Int.MAX_VALUE.toLong()).toInt()
                            for (payload in packetizer.packetize(bytes)) {
                                if (running.get()) liveSession.sendVideo(timestamp, payload)
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
    }
}
