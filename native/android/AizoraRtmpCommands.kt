package com.example.aizora_infinite_text_live

import java.io.ByteArrayOutputStream

/**
 * RTMP AMF0 command encoding. Command responses and stream IDs must be
 * negotiated with the server before any H264 video can be published.
 */
internal object AizoraAmf0 {
    fun string(value: String): ByteArray {
        val bytes = value.toByteArray(Charsets.UTF_8)
        require(bytes.size <= 65535)
        return ByteArrayOutputStream().apply {
            write(0x02)
            write((bytes.size ushr 8) and 255)
            write(bytes.size and 255)
            write(bytes)
        }.toByteArray()
    }

    fun number(value: Double): ByteArray {
        val bits = java.lang.Double.doubleToRawLongBits(value)
        return ByteArrayOutputStream().apply {
            write(0x00)
            for (shift in 56 downTo 0 step 8) {
                write(((bits ushr shift) and 255L).toInt())
            }
        }.toByteArray()
    }

    fun nullValue(): ByteArray = byteArrayOf(0x05)

    fun objectValue(properties: Map<String, ByteArray>): ByteArray {
        return ByteArrayOutputStream().apply {
            write(0x03)
            for ((name, value) in properties) {
                val bytes = name.toByteArray(Charsets.UTF_8)
                require(bytes.size <= 65535)
                write((bytes.size ushr 8) and 255)
                write(bytes.size and 255)
                write(bytes)
                write(value)
            }
            write(byteArrayOf(0x00, 0x00, 0x09))
        }.toByteArray()
    }

    fun command(name: String, transactionId: Double, vararg args: ByteArray): ByteArray =
        ByteArrayOutputStream().apply {
            write(string(name))
            write(number(transactionId))
            args.forEach(::write)
        }.toByteArray()
}

/**
 * Generates RTMP connect, createStream and publish requests.
 * These must be sent in order, waiting for each server response.
 * This class alone does not start a Facebook Live broadcast.
 */
internal class AizoraPublishCommands(
    private val application: String,
    private val tcUrl: String,
    private val streamName: String
) {
    fun connect(): ByteArray = AizoraAmf0.command(
        "connect", 1.0,
        AizoraAmf0.objectValue(
            mapOf(
                "app" to AizoraAmf0.string(application),
                "type" to AizoraAmf0.string("nonprivate"),
                "tcUrl" to AizoraAmf0.string(tcUrl),
                "flashVer" to AizoraAmf0.string("FMLE/3.0"),
                "fpad" to byteArrayOf(0x01, 0x00),
                "capabilities" to AizoraAmf0.number(15.0),
                "audioCodecs" to AizoraAmf0.number(0.0),
                "videoCodecs" to AizoraAmf0.number(7.0),
                "videoFunction" to AizoraAmf0.number(1.0)
            )
        )
    )

    fun createStream(): ByteArray =
        AizoraAmf0.command("createStream", 2.0, AizoraAmf0.nullValue())

    fun publish(): ByteArray = AizoraAmf0.command(
        "publish", 0.0,
        AizoraAmf0.nullValue(),
        AizoraAmf0.string(streamName),
        AizoraAmf0.string("live")
    )
}
