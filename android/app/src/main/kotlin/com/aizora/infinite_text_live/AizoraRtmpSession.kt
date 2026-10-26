package com.aizora.infinite_text_live

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
            check(connectResponse.name == "_result") {
                if (connectResponse.name == "_error") "RTMP connect rejected by server"
                else "Unexpected RTMP connect response: ${connectResponse.name}"
            }

            wire.writeMessage(20, 0, commands.createStream())
            val createResponse = nextCommand()
            check(createResponse.name == "_result") { "RTMP createStream failed: ${createResponse.name}" }
            streamId = createResponse.arguments.filterIsInstance<Number>().lastOrNull()?.toInt() ?: 0
            check(streamId > 0) { "Server returned no valid stream ID" }

            wire.writeMessage(20, streamId, commands.publish())
            val publishResponse = nextCommand()
            check(AizoraAmf0Reader.findString(publishResponse.arguments, "NetStream.Publish.Start")) {
                "Server did not confirm publish start: ${publishResponse.name}"
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

    /** Send FLV AAC payload as RTMP audio message type 8. */
    @Synchronized
    fun sendAudio(timestampMs: Int, flvAacPayload: ByteArray) {
        check(!closed.get() && streamId > 0) { "Publish session is not active" }
        require(timestampMs >= 0)
        checkNotNull(transport).writeMessage(8, streamId, flvAacPayload, timestampMs)
    }

    private fun nextCommand(): AizoraAmf0Reader.Command {
        val source = checkNotNull(reader)
        repeat(200) {
            val message = source.read()
            if (message.type == 20 || message.type == 17) {
                val payload = if (message.type == 17 && message.payload.isNotEmpty() &&
                    message.payload[0].toInt() == 0) message.payload.copyOfRange(1, message.payload.size)
                    else message.payload
                val command = runCatching { AizoraAmf0Reader.command(payload) }.getOrNull()
                if (command != null && (command.name == "_result" || command.name == "_error" ||
                    AizoraAmf0Reader.findString(command.arguments, "NetStream.Publish.Start") ||
                    AizoraAmf0Reader.findString(command.arguments, "NetStream.Publish.BadName"))) return command
            }
        }
        throw java.net.SocketTimeoutException("No RTMP command response")
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
