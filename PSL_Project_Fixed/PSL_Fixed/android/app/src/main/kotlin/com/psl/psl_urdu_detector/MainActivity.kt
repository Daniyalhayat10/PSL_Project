package com.psl.psl_urdu_detector

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {

    private val CHANNEL = "psl/handlandmark"
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var landmarkerHelper: HandLandmarkerHelper? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getLandmarks" -> {
                        val yBytes        = call.argument<ByteArray>("yPlane")       ?: run { result.success(null); return@setMethodCallHandler }
                        val uBytes        = call.argument<ByteArray>("uPlane")       ?: run { result.success(null); return@setMethodCallHandler }
                        val vBytes        = call.argument<ByteArray>("vPlane")       ?: run { result.success(null); return@setMethodCallHandler }
                        val width         = call.argument<Int>("width")              ?: run { result.success(null); return@setMethodCallHandler }
                        val height        = call.argument<Int>("height")             ?: run { result.success(null); return@setMethodCallHandler }
                        val yStride       = call.argument<Int>("yStride")            ?: run { result.success(null); return@setMethodCallHandler }
                        val uvStride      = call.argument<Int>("uvStride")           ?: run { result.success(null); return@setMethodCallHandler }
                        val uvPixelStride = call.argument<Int>("uvPixelStride")      ?: run { result.success(null); return@setMethodCallHandler }

                        executor.submit {
                            try {
                                if (landmarkerHelper == null) {
                                    landmarkerHelper = HandLandmarkerHelper(applicationContext)
                                    landmarkerHelper!!.initialize()
                                }
                                val landmarks = landmarkerHelper!!.getLandmarks(
                                    yBytes, uBytes, vBytes,
                                    width, height,
                                    yStride, uvStride, uvPixelStride
                                )
                                mainHandler.post {
                                    if (landmarks != null) {
                                        result.success(landmarks.map { it.toDouble() })
                                    } else {
                                        result.success(null)
                                    }
                                }
                            } catch (e: Exception) {
                                mainHandler.post {
                                    result.error("LANDMARK_ERROR", e.message, null)
                                }
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        landmarkerHelper?.close()
        executor.shutdown()
        super.onDestroy()
    }
}
