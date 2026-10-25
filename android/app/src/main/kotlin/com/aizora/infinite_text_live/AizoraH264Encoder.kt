package com.aizora.infinite_text_live

import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.view.Surface

/**
 * Off-screen H.264 video encoder. Does not capture the Activity/screen.
 * Caller owns timing and must drain the encoder and publish the output bytes.
 * This class deliberately does NOT claim an RTMPS connection.
 */
class AizoraH264Encoder(
    private val width: Int = 720,
    private val height: Int = 1280,
    private val frameRate: Int = 15
) : AutoCloseable {
    private val codec: MediaCodec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
    private val surface: Surface
    private val background = Paint(Paint.ANTI_ALIAS_FLAG)
    private val lettering = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        textAlign = Paint.Align.CENTER
        textSize = 48f
        setShadowLayer(4f, 2f, 2f, Color.BLACK)
    }
    private var closed = false

    init {
        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_BIT_RATE, 1_500_000)
            setInteger(MediaFormat.KEY_FRAME_RATE, frameRate)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 2)
        }
        codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        surface = codec.createInputSurface()
        codec.start()
    }

    /** Draws a complete scene to the encoder input, even if the screen is off. */
    fun drawFrame(text: String, backgroundColor: Int) {
        check(!closed) { "Encoder already closed" }
        val canvas: Canvas = surface.lockCanvas(null)
        try {
            canvas.drawColor(backgroundColor)
            val bounds = Rect()
            val safeText = text.take(200)
            lettering.getTextBounds(safeText, 0, safeText.length, bounds)
            canvas.drawText(safeText, width / 2f, height / 2f - bounds.exactCenterY(), lettering)
        } finally {
            surface.unlockCanvasAndPost(canvas)
        }
    }

    /**
     * Encoded output callback receives H.264 NAL data and presentation time.
     * MediaCodec BUFFER_FLAG_CODEC_CONFIG carries SPS/PPS for the RTMP publisher.
     */
    fun drain(onPacket: (data: ByteArray, presentationTimeUs: Long, flags: Int) -> Unit) {
        check(!closed) { "Encoder already closed" }
        val info = MediaCodec.BufferInfo()
        while (true) {
            val index = codec.dequeueOutputBuffer(info, 0)
            if (index == MediaCodec.INFO_TRY_AGAIN_LATER) return
            if (index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) continue
            if (index < 0) continue
            try {
                val buffer = codec.getOutputBuffer(index)
                if (buffer != null && info.size > 0) {
                    buffer.position(info.offset)
                    buffer.limit(info.offset + info.size)
                    val data = ByteArray(info.size)
                    buffer.get(data)
                    onPacket(data, info.presentationTimeUs, info.flags)
                }
            } finally {
                codec.releaseOutputBuffer(index, false)
            }
        }
    }

    override fun close() {
        if (closed) return
        closed = true
        try { codec.stop() } finally {
            surface.release()
            codec.release()
        }
    }
}
