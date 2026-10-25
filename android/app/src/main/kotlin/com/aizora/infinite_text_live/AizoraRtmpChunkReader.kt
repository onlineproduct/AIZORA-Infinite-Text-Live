package com.aizora.infinite_text_live

import java.io.EOFException
import java.io.InputStream

/**
 * Incoming RTMP chunk reader with per-chunk-stream state.
 * Supports fmt 0/1/2/3, extended timestamps and Set Chunk Size.
 * No stream should be published before _result/onStatus is validated.
 */
internal class AizoraRtmpChunkReader(private val input: InputStream) {
    data class Message(val type: Int, val streamId: Int, val timestamp: Long, val payload: ByteArray)
    private data class State(
        var timestamp: Long = 0,
        var delta: Long = 0,
        var length: Int = 0,
        var type: Int = 0,
        var streamId: Int = 0,
        var extended: Boolean = false,
        var data: java.io.ByteArrayOutputStream = java.io.ByteArrayOutputStream()
    )

    private val states = mutableMapOf<Int, State>()
    private var chunkSize = 128

    private fun byte(): Int {
        val value = input.read()
        if (value < 0) throw EOFException("RTMP server closed connection")
        return value
    }

    private fun u24(): Int = (byte() shl 16) or (byte() shl 8) or byte()
    private fun u32(): Long = ((byte().toLong() shl 24) or
        (byte().toLong() shl 16) or (byte().toLong() shl 8) or byte().toLong()) and 0xffffffffL

    private fun streamId(): Int {
        val b0 = byte()
        val b1 = byte()
        val b2 = byte()
        val b3 = byte()
        return b0 or (b1 shl 8) or (b2 shl 16) or (b3 shl 24)
    }

    fun read(): Message {
        while (true) {
            val basic = byte()
            val fmt = basic ushr 6
            var csid = basic and 63
            if (csid == 0) csid = 64 + byte()
            else if (csid == 1) csid = 64 + byte() + (byte() shl 8)
            val state = states.getOrPut(csid) { State() }
            val starting = state.data.size() == 0
            when (fmt) {
                0 -> {
                    val timestamp = u24()
                    state.length = u24()
                    state.type = byte()
                    state.streamId = streamId()
                    state.extended = timestamp == 0xffffff
                    state.timestamp = if (state.extended) u32() else timestamp.toLong()
                    state.delta = 0
                    state.data.reset()
                }
                1 -> {
                    val delta = u24()
                    state.length = u24()
                    state.type = byte()
                    state.extended = delta == 0xffffff
                    state.delta = if (state.extended) u32() else delta.toLong()
                    state.timestamp += state.delta
                    state.data.reset()
                }
                2 -> {
                    val delta = u24()
                    state.extended = delta == 0xffffff
                    state.delta = if (state.extended) u32() else delta.toLong()
                    state.timestamp += state.delta
                    state.data.reset()
                }
                3 -> {
                    if (starting) state.timestamp += state.delta
                    if (state.extended) u32() // extended timestamp is repeated on continuations
                }
            }
            require(state.length in 0..16_777_215) { "Invalid RTMP message length" }
            val remaining = state.length - state.data.size()
            require(remaining >= 0) { "RTMP message overflow" }
            val bytes = ByteArray(minOf(chunkSize, remaining))
            var read = 0
            while (read < bytes.size) {
                val n = input.read(bytes, read, bytes.size - read)
                if (n < 0) throw EOFException("RTMP message truncated")
                if (n == 0) continue
                read += n
            }
            state.data.write(bytes)
            if (state.data.size() == state.length) {
                val message = Message(state.type, state.streamId, state.timestamp, state.data.toByteArray())
                state.data.reset()
                if (message.type == 1 && message.payload.size >= 4) {
                    val p = message.payload
                    val value = ((p[0].toInt() and 127) shl 24) or
                        ((p[1].toInt() and 255) shl 16) or
                        ((p[2].toInt() and 255) shl 8) or (p[3].toInt() and 255)
                    require(value in 1..1_048_576) { "Unsupported RTMP chunk size" }
                    chunkSize = value
                }
                return message
            }
        }
    }
}
