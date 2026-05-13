package com.psl.psl_urdu_detector

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker.HandLandmarkerOptions

class HandLandmarkerHelper(private val context: Context) {

    private var handLandmarker: HandLandmarker? = null

    fun initialize() {
        val baseOptions = BaseOptions.builder()
            .setModelAssetPath("flutter_assets/assets/models/hand_landmarker.task")
            .build()

        val options = HandLandmarkerOptions.builder()
            .setBaseOptions(baseOptions)
            .setNumHands(1)
            .setMinHandDetectionConfidence(0.3f)
            .setMinHandPresenceConfidence(0.3f)
            .setMinTrackingConfidence(0.3f)
            .setRunningMode(RunningMode.IMAGE)
            .build()

        handLandmarker = HandLandmarker.createFromOptions(context, options)
    }

    fun getLandmarks(
        yBytes: ByteArray,
        uBytes: ByteArray,
        vBytes: ByteArray,
        width: Int,
        height: Int,
        yStride: Int,
        uvStride: Int,
        uvPixelStride: Int
    ): FloatArray? {
        val bitmap = yuvToBitmap(yBytes, uBytes, vBytes, width, height, yStride, uvStride, uvPixelStride)
        val mpImage = BitmapImageBuilder(bitmap).build()

        val result = try {
            handLandmarker?.detect(mpImage)
        } catch (e: Exception) {
            android.util.Log.e("HandLandmarkerHelper", "detect() failed: ${e.message}")
            null
        } ?: return null

        if (result.landmarks().isEmpty()) return null

        val landmarks = result.landmarks()[0]
        if (landmarks.size < 21) return null

        val flat = FloatArray(63)
        for (i in 0 until 21) {
            val lm = landmarks[i]
            flat[i * 3]     = lm.x()
            flat[i * 3 + 1] = lm.y()
            flat[i * 3 + 2] = lm.z()
        }
        return flat
    }

    private fun yuvToBitmap(
        yBytes: ByteArray,
        uBytes: ByteArray,
        vBytes: ByteArray,
        width: Int,
        height: Int,
        yStride: Int,
        uvStride: Int,
        uvPixelStride: Int
    ): Bitmap {
        val pixels = IntArray(width * height)
        for (row in 0 until height) {
            for (col in 0 until width) {
                val yi = row * yStride + col
                val ui = (row shr 1) * uvStride + (col shr 1) * uvPixelStride
                val yv = yBytes[yi].toInt() and 0xFF
                val u  = uBytes[ui].toInt() and 0xFF
                val v  = vBytes[ui].toInt() and 0xFF
                val r = (yv + 1.402   * (v - 128)).toInt().coerceIn(0, 255)
                val g = (yv - 0.34414 * (u - 128) - 0.71414 * (v - 128)).toInt().coerceIn(0, 255)
                val b = (yv + 1.772   * (u - 128)).toInt().coerceIn(0, 255)
                pixels[row * width + col] = Color.rgb(r, g, b)
            }
        }
        val bmp = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        bmp.setPixels(pixels, 0, width, 0, 0, width, height)
        return bmp
    }

    fun close() {
        handLandmarker?.close()
        handLandmarker = null
    }
}
