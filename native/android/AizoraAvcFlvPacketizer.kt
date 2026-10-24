package com.example.aizora_infinite_text_live

import java.io.ByteArrayOutputStream

/**
 * Converts Annex-B H264 access units to RTMP/FLV AVC video messages.
 * The caller must send configuration (SPS/PPS) before video frames.
 */
internal class AizoraAvcFlvPacketizer {
    private var sps: ByteArray? = null
    private var pps: ByteArray? = null

    private fun nalUnits(data: ByteArray): List<ByteArray> {
        val markers = mutableListOf<Pair<Int, Int>>()
        var i = 0
        while (i + 3 < data.size) {
            val markerLength = when {
                data[i] == 0.toByte() && data[i + 1] == 0.toByte() &&
                    data[i + 2] == 1.toByte() -> 3
                i + 3 < data.size && data[i] == 0.toByte() &&
                    data[i + 1] == 0.toByte() && data[i + 2] == 0.toByte() &&
                    data[i + 3] == 1.toByte() -> 4
                else -> 0
            }
            if (markerLength > 0) {
                markers.add(i to markerLength)
                i += markerLength
            } else i++
        }
        if (markers.isEmpty()) return if (data.isEmpty()) emptyList() else listOf(data)
        return markers.mapIndexedNotNull { index, (start, length) ->
            val end = if (index + 1 < markers.size) markers[index + 1].first else data.size
            if (start + length < end) data.copyOfRange(start + length, end) else null
        }
    }

    private fun ByteArrayOutputStream.u16(value: Int) {
        write((value ushr 8) and 255)
        write(value and 255)
    }

    private fun ByteArrayOutputStream.u32(value: Int) {
        write((value ushr 24) and 255)
        write((value ushr 16) and 255)
        write((value ushr 8) and 255)
        write(value and 255)
    }

    /**
     * Returns zero or more RTMP message type 9 payloads. Video timestamps
     * are supplied separately to RTMP writeMessage in milliseconds.
     */
    fun packetize(encoded: ByteArray): List<ByteArray> {
        val nals = nalUnits(encoded)
        val frames = mutableListOf<ByteArray>()
        val video = mutableListOf<ByteArray>()
        var keyframe = false
        var configChanged = false
        for (nal in nals) {
            if (nal.isEmpty()) continue
            when (nal[0].toInt() and 31) {
                7 -> { sps = nal; configChanged = true }
                8 -> { pps = nal; configChanged = true }
                5 -> { keyframe = true; video.add(nal) }
                1 -> video.add(nal)
            }
        }
        val currentSps = sps
        val currentPps = pps
        if (configChanged && currentSps != null && currentPps != null && currentSps.size >= 4) {
            frames.add(ByteArrayOutputStream().apply {
                write(0x17) // keyframe, AVC
                write(0x00) // AVC sequence header
                write(byteArrayOf(0, 0, 0)) // composition offset
                write(1) // AVCDecoderConfigurationRecord version
                write(currentSps[1].toInt() and 255)
                write(currentSps[2].toInt() and 255)
                write(currentSps[3].toInt() and 255)
                write(0xFF) // four-byte NAL length
                write(0xE1) // one SPS
                u16(currentSps.size)
                write(currentSps)
                write(1) // one PPS
                u16(currentPps.size)
                write(currentPps)
            }.toByteArray())
        }
        if (video.isNotEmpty() && currentSps != null && currentPps != null) {
            frames.add(ByteArrayOutputStream().apply {
                write(if (keyframe) 0x17 else 0x27)
                write(0x01) // AVC NALU
                write(byteArrayOf(0, 0, 0)) // composition offset
                for (nal in video) {
                    u32(nal.size)
                    write(nal)
                }
            }.toByteArray())
        }
        return frames
    }
}
