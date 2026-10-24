package com.example.aizora_infinite_text_live

import java.io.ByteArrayOutputStream
import java.io.Closeable
import java.io.InputStream
import java.io.OutputStream
import java.net.URI
import java.security.SecureRandom
import javax.net.ssl.SSLSocket
import javax.net.ssl.SSLSocketFactory

/**
 * Low-level RTMPS transport. This is a transport foundation, NOT a completed
 * RTMP publish session. RTMP command negotiation and H264 FLV packetization
 * must be implemented before Facebook Live can receive video.
 */
class AizoraRtmpsTransport : Closeable {
    private var socket: SSLSocket? = null
    private var input: InputStream? = null
    private var output: OutputStream? = null

    /** Only RTMPS is accepted; never send a private stream key over plain RTMP. */
    fun connect(serverUrl: String, timeoutMs: Int = 10000) {
        check(socket == null) { "Already connected" }
        val uri = URI(serverUrl)
        require(uri.scheme.equals("rtmps", ignoreCase = true)) { "RTMPS required" }
        val host = requireNotNull(uri.host) { "Missing RTMPS host" }
        val port = if (uri.port > 0) uri.port else 443
        val tls = (SSLSocketFactory.getDefault() as SSLSocketFactory)
            .createSocket() as SSLSocket
        try {
            tls.soTimeout = timeoutMs
            tls.connect(java.net.InetSocketAddress(host, port), timeoutMs)
            tls.startHandshake() // TLS certificate and hostname validation
            socket = tls
            input = tls.inputStream
            output = tls.outputStream
        } catch (error: Exception) {
            tls.close()
            throw error
        }
    }

    internal fun serverInput(): InputStream = checkNotNull(input) { "Not connected" }

    /** Perform the RTMP C0/C1 -> S0/S1/S2 -> C2 handshake over TLS. */
    fun handshake() {
        val source = checkNotNull(input) { "Not connected" }
        val sink = checkNotNull(output) { "Not connected" }
        val c1 = ByteArray(1536)
        SecureRandom().nextBytes(c1)
        // RTMP version 3, timestamp 0, zero-filled second four bytes.
        for (i in 0 until 8) c1[i] = 0
        sink.write(byteArrayOf(3))
        sink.write(c1)
        sink.flush()

        val server = ByteArray(3073)
        var offset = 0
        while (offset < server.size) {
            val n = source.read(server, offset, server.size - offset)
            if (n < 0) throw java.io.EOFException("RTMP handshake closed")
            offset += n
        }
        require(server[0].toInt() == 3) { "Unsupported RTMP version" }
        // C2 echoes the server's S1, not its S2.
        sink.write(server, 1, 1536)
        sink.flush()
    }

    /** Write an RTMP chunk message (format 0, chunk stream 3). */
    fun writeMessage(messageType: Int, messageStreamId: Int, payload: ByteArray, timestampMs: Int = 0) {
        val sink = checkNotNull(output) { "Not connected" }
        require(messageType in 1..255 && messageStreamId >= 0 && timestampMs >= 0)
        require(payload.size <= 0xFFFFFF)
        val header = ByteArrayOutputStream()
        header.write(0x03) // fmt=0, chunk stream ID=3
        val extended = timestampMs >= 0xFFFFFF
        write24(header, if (extended) 0xFFFFFF else timestampMs)
        write24(header, payload.size)
        header.write(messageType)
        // Message stream ID is little-endian.
        repeat(4) { header.write((messageStreamId ushr (8 * it)) and 0xff) }
        if (extended) write32(header, timestampMs)
        sink.write(header.toByteArray())
        // Default RTMP outgoing chunk size is 128 bytes until negotiated.
        var offset = 0
        while (offset < payload.size) {
            val size = minOf(128, payload.size - offset)
            sink.write(payload, offset, size)
            offset += size
            if (offset < payload.size) {
                sink.write(0xC3) // fmt=3 continuation, chunk stream ID=3
                if (extended) write32(sink, timestampMs)
            }
        }
        sink.flush()
    }

    private fun write24(out: OutputStream, value: Int) {
        out.write((value ushr 16) and 0xff)
        out.write((value ushr 8) and 0xff)
        out.write(value and 0xff)
    }

    private fun write32(out: OutputStream, value: Int) {
        out.write((value ushr 24) and 0xff)
        out.write((value ushr 16) and 0xff)
        out.write((value ushr 8) and 0xff)
        out.write(value and 0xff)
    }

    override fun close() {
        socket?.close()
        socket = null
        input = null
        output = null
    }
}
