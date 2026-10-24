package com.example.aizora_infinite_text_live

import java.io.Closeable
import java.net.URI
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Coordinates RTMPS handshake and RTMP command negotiation.
 * This deliberately stops unless server responses are valid. Stream-key handling
 * is caller-owned; never log or persist it. Video/audio publishing and reconnect
 * policy still require integration and device testing.
 */
internal class AizoraRtmpSession : Closeable {
    private val closed = AtomicBoolean(false)
    private var transport: AizoraRtmpsTransport? = null
    private var reader: AizoraRtmpChunkReader? = null
    private var streamId = 0

    @Synchronized
    fun open(serverUrl: String, application: String, streamKey: String) {
        check(transport == null) { "Session already opened" }
        require(streamKey.isNotBlank()) { "Stream key is required" }
        val uri = URI(serverUrl)
        require(uri.scheme.equals("rtmps", ignoreCase = true))
        val path = uri.path.trim('/').split('/', limit = 2)
        require(path.isNotEmpty() && path[0].isNotBlank()) {
            "RTMPS URL must include the application path"
        }
        val app = path[0]
        val fullTcUrl = "rtmps://${uri.host}:${if (uri.port > 0) uri.port else 443}/$app"
        val wire = AizoraRtmpsTransport()
        try {
            wire.connect(serverUrl)
            wire.handshake()
            transport = wire
            reader = AizoraRtmpChunkReader(wire.serverInput())
            val commands = AizoraPublishCommands(application.ifBlank { app }, fullTcUrl, streamKey)
            wire.writeMessage(20, 0, commands.connect())
            val connectResponse = nextCommand()
            check(connectResponse.contains("_result") || connectResponse.contains("_error")) {
                "Unexpected RTMP connect response"
            }
            check(!connectResponse.contains("_error")) { "RTMP connect rejected by server" }

            wire.writeMessage(20, 0, commands.createStream())
            val createResponse = nextCommand()
            check(createResponse.contains("_result")) { "RTMP createStream failed" }
            streamId = extractStreamId(createResponse)
            check(streamId > 0) { "Server returned no valid stream ID" }

            wire.writeMessage(20, streamId, commands.publish())
            val publishResponse = nextCommand()
            check(publishResponse.contains("NetStream.Publish.Start")) {
                "Server did not confirm publish start"
            }
        } catch (error: Exception) {
            close()
            throw error
        }
    }

    /** Send RTMP video message type 9. Input must already be FLV AVC payload. */
    @Synchronized
    fun sendVideo(timestampMs: Int, flvAvcPayload: ByteArray) {
        check(!closed.get() && streamId > 0) { "Publish session is not active" }
        require(timestampMs >= 0)
        checkNotNull(transport).writeMessage(9, streamId, flvAvcPayload, timestampMs)
    }

    private fun nextCommand(): String {
        val source = checkNotNull(reader)
        repeat(200) {
            val message = source.read()
            if (message.type == 20 || message.type == 17) {
                val text = String(message.payload, Charsets.ISO_8859_1)
                if (text.contains("_result") || text.contains("_error") ||
                    text.contains("NetStream.Publish.Start") ||
                    text.contains("NetStream.Publish.BadName")) return text
            }
            if (message.type == 4 && message.payload.isNotEmpty()) {
                // RTMP user-control events are not command replies; ignore.
            }
        }
        throw java.net.SocketTimeoutException("No RTMP command response")
    }

    /**
     * Minimal AMF0 numeric search used only as a defensive preliminary parser.
     * Production implementation should parse AMF values structurally.
     */
    private fun extractStreamId(response: String): Int {
        val match = Regex("_result.{0,80}?([0-9]+(?:\\.[0-9]+)?)").find(response)
            ?: return 0
        return match.groupValues[1].toDoubleOrNull()?.toInt() ?: 0
    }

    override fun close() {
        if (closed.compareAndSet(false, true)) {
            transport?.close()
            transport = null
            reader = null
            streamId = 0
        }
    }
}
