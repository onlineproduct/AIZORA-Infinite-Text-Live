package com.example.aizora_infinite_text_live

import java.io.ByteArrayInputStream
import java.io.DataInputStream

/** Small bounded AMF0 reader for RTMP command replies. */
internal object AizoraAmf0Reader {
    data class Command(val name: String, val transactionId: Double, val arguments: List<Any?>)

    fun command(payload: ByteArray): Command {
        val input = DataInputStream(ByteArrayInputStream(payload))
        val name = readValue(input) as? String ?: error("RTMP command name is missing")
        val transaction = readValue(input) as? Double ?: error("RTMP transaction ID is missing")
        val args = mutableListOf<Any?>()
        while (input.available() > 0) args += readValue(input)
        return Command(name, transaction, args)
    }

    private fun readValue(input: DataInputStream, depth: Int = 0): Any? {
        require(depth < 16) { "AMF nesting too deep" }
        val marker = input.readUnsignedByte()
        fun readString(): String {
            val size = input.readUnsignedShort()
            require(size <= input.available()) { "Truncated AMF string" }
            val bytes = ByteArray(size)
            input.readFully(bytes)
            return String(bytes, Charsets.UTF_8)
        }
        return when (marker) {
            0 -> input.readDouble()
            1 -> input.readUnsignedByte() != 0
            2 -> readString()
            3, 8 -> {
                if (marker == 8) input.readInt()
                val map = linkedMapOf<String, Any?>()
                while (input.available() >= 3) {
                    val size = input.readUnsignedShort()
                    if (size == 0) {
                        if (input.readUnsignedByte() == 9) break
                        error("Invalid AMF object terminator")
                    }
                    require(size <= input.available()) { "Truncated AMF property" }
                    val bytes = ByteArray(size)
                    input.readFully(bytes)
                    val key = String(bytes, Charsets.UTF_8)
                    map[key] = readValue(input, depth + 1)
                }
                map
            }
            5, 6 -> null
            10 -> {
                val count = input.readInt()
                require(count in 0..10000) { "Invalid AMF array length" }
                List(count) { readValue(input, depth + 1) }
            }
            11 -> {
                val millis = input.readDouble()
                input.readShort()
                millis
            }
            12 -> {
                val size = input.readInt()
                require(size in 0..input.available()) { "Invalid AMF long string" }
                val bytes = ByteArray(size)
                input.readFully(bytes)
                String(bytes, Charsets.UTF_8)
            }
            else -> error("Unsupported AMF0 marker: $marker")
        }
    }

    fun findString(value: Any?, target: String): Boolean = when (value) {
        is String -> value == target
        is Map<*, *> -> value.values.any { findString(it, target) }
        is Iterable<*> -> value.any { findString(it, target) }
        else -> false
    }
}
