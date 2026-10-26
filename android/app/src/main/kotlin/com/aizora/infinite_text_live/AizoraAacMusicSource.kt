package com.aizora.infinite_text_live

import android.media.MediaExtractor
import android.media.MediaFormat
import java.io.File
import java.nio.ByteBuffer

/**
 * Streams AAC access units from a local M4A/MP4 file as RTMP FLV AAC audio.
 * MP3 and other formats need decoding/transcoding and are intentionally rejected.
 * This implementation does not capture device/system audio.
 */
internal class AizoraAacMusicSource(private val file: File) {
    fun stream(session: AizoraRtmpSession, active: () -> Boolean, loop: Boolean = true) {
        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(file.absolutePath)
            var track = -1
            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                if (format.getString(MediaFormat.KEY_MIME) == MediaFormat.MIMETYPE_AUDIO_AAC) {
                    track = i
                    break
                }
            }
            require(track >= 0) { "Music live supports AAC in M4A/MP4 only" }
            val format = extractor.getTrackFormat(track)
            val config = format.getByteBuffer("csd-0") ?: throw IllegalArgumentException("Missing AAC codec configuration")
            val asc = ByteArray(config.remaining())
            config.get(asc)
            require(asc.size >= 2) { "Invalid AAC configuration" }
            extractor.selectTrack(track)
            // FLV AAC sequence header: SoundFormat=10, AACPacketType=0.
            session.sendAudio(0, byteArrayOf(0xAF.toByte(), 0) + asc)
            val maxSample = 512 * 1024
            val buffer = ByteBuffer.allocate(maxSample)
            val startedNs = System.nanoTime()
            var loopOffsetUs = 0L
            var lastSampleUs = 0L
            while (active()) {
                buffer.clear()
                val size = extractor.readSampleData(buffer, 0)
                if (size < 0) {
                    if (!loop) break
                    loopOffsetUs += lastSampleUs + 23_220L
                    extractor.seekTo(0, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
                    continue
                }
                require(size <= maxSample) { "AAC packet exceeds buffer" }
                val sampleUs = extractor.sampleTime.coerceAtLeast(0L)
                lastSampleUs = sampleUs
                val timestampUs = loopOffsetUs + sampleUs
                val deadlineNs = startedNs + timestampUs * 1000L
                while (active() && System.nanoTime() < deadlineNs) {
                    Thread.sleep(minOf(25L, ((deadlineNs - System.nanoTime()) / 1_000_000L).coerceAtLeast(1L)))
                }
                if (!active()) break
                val payload = ByteArray(size)
                buffer.position(0)
                buffer.get(payload)
                session.sendAudio((timestampUs / 1000L).coerceAtMost(Int.MAX_VALUE.toLong()).toInt(),
                    byteArrayOf(0xAF.toByte(), 1) + payload)
                extractor.advance()
            }
        } finally {
            extractor.release()
        }
    }
}
