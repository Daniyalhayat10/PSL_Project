import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_hand_landmark/google_mlkit_hand_landmark.dart';

import '../services/model_service.dart';
import '../services/detection_provider.dart';
import '../widgets/hand_landmark_painter.dart';

class DetectionScreen extends StatefulWidget {
  const DetectionScreen({super.key});

  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen>
    with WidgetsBindingObserver {
  // ─── Camera ───────────────────────────────────────────────────────────────
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 1; // front camera default
  bool _cameraPermissionGranted = false;
  bool _isStreamActive = false;

  // ─── ML Kit Hand Landmark ─────────────────────────────────────────────────
  HandLandmarker? _handLandmarker;
  bool _isProcessingFrame = false;
  int _frameSkip = 0;
  static const int _processEveryNFrames = 3; // process 1 in 3 frames

  // ─── TTS ──────────────────────────────────────────────────────────────────
  FlutterTts? _tts;
  bool _ttsEnabled = true;
  String? _lastSpokenLabel;

  // ─── UI state ─────────────────────────────────────────────────────────────
  bool _handDetected = false;
  List<HandLandmark> _displayLandmarks = [];
  String _statusMessage = 'ہاتھ کیمرہ کے سامنے رکھیں';

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initTTS();
    _initHandLandmarker();
    _requestPermissionAndInit();

    // Load model if not already loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final model = context.read<ModelService>();
      if (!model.isLoaded) model.loadModel();
    });
  }

  Future<void> _initTTS() async {
    _tts = FlutterTts();
    await _tts?.setLanguage('ur-PK');
    await _tts?.setSpeechRate(0.5);
    await _tts?.setVolume(1.0);
  }

  Future<void> _initHandLandmarker() async {
    final options = HandLandmarkerOptions(
      baseOptions: BaseOptions(modelAssetPath: 'assets/models/hand_landmarker.task'),
      runningMode: RunningMode.liveStream,
      numHands: 1,
      minHandDetectionConfidence: 0.5,
      minHandPresenceConfidence: 0.5,
      minTrackingConfidence: 0.5,
      resultListener: _onHandLandmarkResult,
    );
    try {
      _handLandmarker = HandLandmarker.defaultOptions();
      // Use live stream mode for real-time
      _handLandmarker = HandLandmarker(options: options);
      debugPrint('✅ HandLandmarker initialised');
    } catch (e) {
      debugPrint('❌ HandLandmarker init failed: $e');
    }
  }

  // ─── Camera setup ─────────────────────────────────────────────────────────

  Future<void> _requestPermissionAndInit() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() => _cameraPermissionGranted = status.isGranted);
    if (status.isGranted) await _initCamera();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;
    _cameraIndex = _cameras.length > 1 ? 1 : 0;
    await _startCamera(_cameraIndex);
  }

  Future<void> _startCamera(int index) async {
    await _stopStream();
    await _cameraController?.dispose();

    final camera = _cameras[index];
    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium, // medium = faster stream processing
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {});
        await _startStream();
      }
    } catch (e) {
      debugPrint('❌ Camera init error: $e');
    }
  }

  Future<void> _startStream() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isStreamActive) return;

    _isStreamActive = true;
    await _cameraController!.startImageStream(_onCameraFrame);
    if (mounted) {
      setState(() => _statusMessage = 'ہاتھ کیمرہ کے سامنے رکھیں');
    }
  }

  Future<void> _stopStream() async {
    if (!_isStreamActive) return;
    _isStreamActive = false;
    try {
      await _cameraController?.stopImageStream();
    } catch (_) {}
  }

  // ─── Real-time frame processing ───────────────────────────────────────────

  void _onCameraFrame(CameraImage image) {
    // Skip frames to avoid overloading
    _frameSkip++;
    if (_frameSkip % _processEveryNFrames != 0) return;
    if (_isProcessingFrame) return;
    if (_handLandmarker == null) return;

    _isProcessingFrame = true;
    _processFrame(image);
  }

  Future<void> _processFrame(CameraImage image) async {
    try {
      final camera = _cameras[_cameraIndex];
      final rotation = _rotationFromSensorOrientation(
          camera.sensorOrientation, camera.lensDirection);

      final inputImage = _buildInputImage(image, camera, rotation);
      if (inputImage == null) {
        _isProcessingFrame = false;
        return;
      }

      await _handLandmarker!.processImage(inputImage);
      // Result comes via _onHandLandmarkResult callback
    } catch (e) {
      debugPrint('❌ Frame process error: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  void _onHandLandmarkResult(
      HandLandmarkerResult result, InputImage inputImage, int timestamp) {
    if (!mounted) return;

    if (result.handLandmarks.isEmpty) {
      setState(() {
        _handDetected = false;
        _displayLandmarks = [];
        _statusMessage = 'ہاتھ نہیں ملا — کیمرہ کے سامنے رکھیں';
      });
      return;
    }

    // Get first hand's 21 landmarks
    final hand = result.handLandmarks.first;
    final rawLandmarks = hand.landmarks
        .map((lm) => [lm.x, lm.y, lm.z])
        .toList();

    if (rawLandmarks.length != 21) {
      _isProcessingFrame = false;
      return;
    }

    // Normalise exactly as Python training code
    final normalized = ModelService.normalizeLandmarks(rawLandmarks);
    if (normalized.isEmpty) return;

    // Run TFLite inference
    final modelService = context.read<ModelService>();
    final detResult = modelService.runInference(normalized);

    if (detResult != null && mounted) {
      context.read<DetectionProvider>().updateDetection(detResult);

      // Build display landmarks
      final displayLms = hand.landmarks
          .asMap()
          .entries
          .map((e) => HandLandmark(
                x: e.value.x,
                y: e.value.y,
                z: e.value.z,
                index: e.key,
              ))
          .toList();

      setState(() {
        _handDetected = true;
        _displayLandmarks = displayLms;
        _statusMessage = '${detResult.romanLabel} — ${detResult.confidencePercent}';
      });

      // Speak high-confidence detections (don't repeat same letter)
      if (_ttsEnabled &&
          detResult.isHighConfidence &&
          detResult.romanLabel != _lastSpokenLabel) {
        _lastSpokenLabel = detResult.romanLabel;
        _tts?.speak(detResult.urduLabel);
      }
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  InputImage? _buildInputImage(
      CameraImage image, CameraDescription camera, InputImageRotation rotation) {
    try {
      final format = Platform.isAndroid
          ? InputImageFormat.nv21
          : InputImageFormat.bgra8888;

      final plane = image.planes.first;
      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    } catch (e) {
      debugPrint('❌ InputImage build error: $e');
      return null;
    }
  }

  InputImageRotation _rotationFromSensorOrientation(
      int sensorOrientation, CameraLensDirection lensDirection) {
    var rotationCompensation = sensorOrientation;
    if (lensDirection == CameraLensDirection.front) {
      rotationCompensation = (360 - rotationCompensation) % 360;
    }
    switch (rotationCompensation) {
      case 90:  return InputImageRotation.rotation90deg;
      case 180: return InputImageRotation.rotation180deg;
      case 270: return InputImageRotation.rotation270deg;
      default:  return InputImageRotation.rotation0deg;
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _startCamera(_cameraIndex);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _stopStream();
    } else if (state == AppLifecycleState.resumed) {
      if (_cameras.isNotEmpty) _startCamera(_cameraIndex);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopStream();
    _cameraController?.dispose();
    _tts?.stop();
    _handLandmarker?.close();
    super.dispose();
  }

  // ─── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            _buildCameraView(),
            if (_displayLandmarks.isNotEmpty) _buildLandmarkOverlay(),
            _buildTopBar(),
            _buildStatusBadge(),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _buildBottomPanel(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraView() {
    if (!_cameraPermissionGranted) {
      return Container(
        color: const Color(0xFF0A0A1A),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_off, color: Colors.white38, size: 64),
              const SizedBox(height: 16),
              const Text(
                'کیمرہ اجازت درکار ہے',
                style: TextStyle(
                    fontFamily: 'JameelNooriNastaleeq',
                    color: Colors.white54,
                    fontSize: 18),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _requestPermissionAndInit,
                child: const Text('Allow Camera'),
              ),
            ],
          ),
        ),
      );
    }

    if (_cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return Container(
        color: const Color(0xFF0A0A1A),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF006400)),
        ),
      );
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _cameraController!.value.previewSize!.height,
          height: _cameraController!.value.previewSize!.width,
          child: CameraPreview(_cameraController!),
        ),
      ),
    );
  }

  Widget _buildLandmarkOverlay() {
    final size = MediaQuery.of(context).size;
    return CustomPaint(
      size: size,
      painter: HandLandmarkPainter(
        landmarks: _displayLandmarks,
        imageSize: size,
        isFrontCamera: _cameraIndex == 1,
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.7), Colors.transparent],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              _TopBarButton(
                  icon: Icons.arrow_back_ios,
                  onTap: () => Navigator.pop(context)),
              const SizedBox(width: 8),
              if (_cameras.length > 1)
                _TopBarButton(
                    icon: Icons.flip_camera_ios, onTap: _switchCamera),
            ]),
            const Text(
              'شناخت',
              style: TextStyle(
                  fontFamily: 'JameelNooriNastaleeq',
                  color: Colors.white,
                  fontSize: 20),
              textDirection: TextDirection.rtl,
            ),
            Row(children: [
              _TopBarButton(
                icon: _ttsEnabled ? Icons.volume_up : Icons.volume_off,
                onTap: () => setState(() => _ttsEnabled = !_ttsEnabled),
                active: _ttsEnabled,
              ),
              const SizedBox(width: 8),
              _TopBarButton(
                icon: Icons.delete_outline,
                onTap: () {
                  context.read<DetectionProvider>().clearAll();
                  setState(() {
                    _displayLandmarks = [];
                    _handDetected = false;
                    _statusMessage = 'ہاتھ کیمرہ کے سامنے رکھیں';
                  });
                },
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Positioned(
      top: 80, left: 16, right: 16,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: _handDetected
              ? const Color(0xFF00C853).withOpacity(0.25)
              : Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _handDetected
                ? const Color(0xFF00C853).withOpacity(0.6)
                : Colors.white24,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _handDetected ? Icons.back_hand : Icons.pan_tool_outlined,
              color: _handDetected
                  ? const Color(0xFF00C853)
                  : Colors.white38,
              size: 16,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _statusMessage,
                style: TextStyle(
                  fontFamily: 'JameelNooriNastaleeq',
                  color: _handDetected
                      ? const Color(0xFF00C853)
                      : Colors.white60,
                  fontSize: 12,
                ),
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Consumer<DetectionProvider>(
      builder: (context, provider, _) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withOpacity(0.97),
                Colors.black.withOpacity(0.75),
                Colors.transparent,
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (provider.lastResult != null)
                _buildResultCard(provider.lastResult!),
              const SizedBox(height: 8),
              _buildWordDisplay(provider),
              const SizedBox(height: 12),
              _buildActionRow(provider),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResultCard(DetectionResult result) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.romanLabel,
                    style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                        letterSpacing: 1)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: result.confidence,
                    backgroundColor: Colors.white12,
                    color: result.confidenceColor,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Confidence: ${result.confidencePercent}',
                  style: TextStyle(
                      color: result.confidenceColor, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                const Color(0xFF006400).withOpacity(0.85),
                const Color(0xFF00A300).withOpacity(0.65),
              ]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: result.confidenceColor.withOpacity(0.6),
                  width: 2),
              boxShadow: [
                BoxShadow(
                    color: result.confidenceColor.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2),
              ],
            ),
            child: Center(
              child: Text(
                result.urduLabel,
                style: const TextStyle(
                    fontFamily: 'JameelNooriNastaleeq',
                    color: Colors.white,
                    fontSize: 42),
                textDirection: TextDirection.rtl,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordDisplay(DetectionProvider provider) {
    final text = provider.fullText;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A).withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(
            'Detections: ${provider.detectionCount}',
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
          const Text(
            'شناخت شدہ',
            style: TextStyle(
                fontFamily: 'JameelNooriNastaleeq',
                color: Color(0xFFC8A951),
                fontSize: 13),
            textDirection: TextDirection.rtl,
          ),
        ]),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(10)),
          child: Text(
            text.isEmpty ? '...' : text,
            style: const TextStyle(
                fontFamily: 'JameelNooriNastaleeq',
                color: Colors.white,
                fontSize: 26),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
          ),
        ),
      ]),
    );
  }

  Widget _buildActionRow(DetectionProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _ActionButton(
            icon: Icons.space_bar,
            label: 'Space',
            onTap: provider.addSpaceToWord,
            color: const Color(0xFF1565C0),
          ),
          const SizedBox(width: 6),
          _ActionButton(
            icon: Icons.backspace_outlined,
            label: 'Undo',
            onTap: provider.undoLastLetter,
            color: const Color(0xFF6A1B9A),
          ),
          const SizedBox(width: 6),
          _ActionButton(
            icon: Icons.volume_up,
            label: 'Speak',
            onTap: () async {
              final text = provider.fullText;
              if (text.isNotEmpty) await _tts?.speak(text);
            },
            color: const Color(0xFF00695C),
          ),
          const SizedBox(width: 6),
          _ActionButton(
            icon: Icons.clear_all,
            label: 'Clear',
            onTap: () {
              provider.clearAll();
              setState(() {
                _handDetected = false;
                _displayLandmarks = [];
                _statusMessage = 'ہاتھ کیمرہ کے سامنے رکھیں';
              });
            },
            color: const Color(0xFFB71C1C),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable widgets ─────────────────────────────────────────────────────────

class _TopBarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  const _TopBarButton(
      {required this.icon, required this.onTap, this.active = true});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon,
            color: active ? Colors.white : Colors.white38, size: 20),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Column(children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(color: color, fontSize: 10)),
          ]),
        ),
      ),
    );
  }
}
