import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

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
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 1;
  FlutterTts? _tts;
  bool _ttsEnabled = true;
  bool _cameraPermissionGranted = false;
  bool _isCapturing = false;
  bool _handDetected = false;
  List<HandLandmark> _landmarks = [];
  String _statusMessage = 'ہاتھ کیمرہ کے سامنے رکھیں اور تصویر لیں';
  PoseDetector? _poseDetector;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initTTS();
    _requestPermissionAndInit();
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(mode: PoseDetectionMode.single),
    );
  }

  Future<void> _initTTS() async {
    _tts = FlutterTts();
    await _tts?.setLanguage('ur-PK');
    await _tts?.setSpeechRate(0.5);
    await _tts?.setVolume(1.0);
  }

  Future<void> _requestPermissionAndInit() async {
    final status = await Permission.camera.request();
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
    final camera = _cameras[index];
    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await _cameraController!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  /// Main flow: capture photo → ML Kit landmarks → TFLite predict
  Future<void> _captureAndPredict() async {
    if (_isCapturing) return;
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    setState(() {
      _isCapturing = true;
      _handDetected = false;
      _landmarks = [];
      _statusMessage = 'تصویر لی جا رہی ہے...';
    });

    try {
      // Step 1: Capture photo
      final XFile photo = await _cameraController!.takePicture();

      setState(() => _statusMessage = 'ہاتھ کی پہچان ہو رہی ہے...');

      // Step 2: ML Kit pose detection on the photo
      final inputImage = InputImage.fromFilePath(photo.path);
      final poses = await _poseDetector!.processImage(inputImage);

      if (poses.isEmpty) {
        setState(() {
          _statusMessage = 'ہاتھ نہیں ملا — دوبارہ کوشش کریں';
          _isCapturing = false;
        });
        File(photo.path).delete().catchError((_) {});
        return;
      }

      // Step 3: Extract 21 hand landmark points from pose
      final pose = poses.first;
      final rawLandmarks = _extractHandLandmarks(pose);

      if (rawLandmarks.isEmpty) {
        setState(() {
          _statusMessage = 'ہاتھ واضح نہیں — سیدھا کیمرہ کے سامنے رکھیں';
          _isCapturing = false;
        });
        File(photo.path).delete().catchError((_) {});
        return;
      }

      // Step 4: Normalize exactly as in Python training code
      final normalized = ModelService.normalizeLandmarks(rawLandmarks);

      // Step 5: TFLite inference
      final modelService = context.read<ModelService>();
      final result = modelService.runInference(normalized);

      if (result != null && mounted) {
        context.read<DetectionProvider>().updateDetection(result);
        setState(() {
          _handDetected = true;
          _landmarks = _buildDisplayLandmarks(pose);
          _statusMessage =
              '${result.romanLabel} — ${result.confidencePercent}';
        });
        if (_ttsEnabled && result.isHighConfidence) {
          await _tts?.speak(result.urduLabel);
        }
      }

      File(photo.path).delete().catchError((_) {});
    } catch (e) {
      debugPrint('Capture error: $e');
      setState(() => _statusMessage = 'خطا — دوبارہ کوشش کریں');
    }

    setState(() => _isCapturing = false);
  }

  /// Extract 21 hand landmark positions from ML Kit pose result.
  /// Uses wrist + finger keypoints; interpolates the 4 joints of each finger.
  List<List<double>> _extractHandLandmarks(Pose pose) {
    final rw = pose.landmarks[PoseLandmarkType.rightWrist];
    final lw = pose.landmarks[PoseLandmarkType.leftWrist];
    final ri = pose.landmarks[PoseLandmarkType.rightIndex];
    final li = pose.landmarks[PoseLandmarkType.leftIndex];
    final rp = pose.landmarks[PoseLandmarkType.rightPinky];
    final lp = pose.landmarks[PoseLandmarkType.leftPinky];
    final rt = pose.landmarks[PoseLandmarkType.rightThumb];
    final lt = pose.landmarks[PoseLandmarkType.leftThumb];

    // Pick the more visible hand
    final wrist = (rw?.likelihood ?? 0) >= (lw?.likelihood ?? 0) ? rw : lw;
    final indexTip = (ri?.likelihood ?? 0) >= (li?.likelihood ?? 0) ? ri : li;
    final pinkyTip = (rp?.likelihood ?? 0) >= (lp?.likelihood ?? 0) ? rp : lp;
    final thumbTip = (rt?.likelihood ?? 0) >= (lt?.likelihood ?? 0) ? rt : lt;

    if (wrist == null || (wrist.likelihood) < 0.5) return [];

    final wx = wrist.x, wy = wrist.y, wz = wrist.z;
    final ix = indexTip?.x ?? wx, iy = indexTip?.y ?? (wy - 0.10), iz = indexTip?.z ?? wz;
    final px = pinkyTip?.x ?? wx, py = pinkyTip?.y ?? (wy - 0.10), pz = pinkyTip?.z ?? wz;
    final tx = thumbTip?.x ?? wx, ty = thumbTip?.y ?? (wy - 0.05), tz = thumbTip?.z ?? wz;

    // Middle and ring estimated by interpolation
    final mx = (ix + px) / 2, my = (iy + py) / 2, mz = (iz + pz) / 2;
    final rx = (mx + px) / 2, ry = (my + py) / 2, rz = (mz + pz) / 2;

    List<double> interp(double ax, double ay, double az,
            double bx, double by, double bz, double t) =>
        [ax + (bx - ax) * t, ay + (by - ay) * t, az + (bz - az) * t];

    final pts = <List<double>>[];
    pts.add([wx, wy, wz]); // 0 wrist
    for (int i = 1; i <= 4; i++) pts.add(interp(wx, wy, wz, tx, ty, tz, i / 4)); // thumb
    for (int i = 1; i <= 4; i++) pts.add(interp(wx, wy, wz, ix, iy, iz, i / 4)); // index
    for (int i = 1; i <= 4; i++) pts.add(interp(wx, wy, wz, mx, my, mz, i / 4)); // middle
    for (int i = 1; i <= 4; i++) pts.add(interp(wx, wy, wz, rx, ry, rz, i / 4)); // ring
    for (int i = 1; i <= 4; i++) pts.add(interp(wx, wy, wz, px, py, pz, i / 4)); // pinky
    return pts;
  }

  List<HandLandmark> _buildDisplayLandmarks(Pose pose) {
    return _extractHandLandmarks(pose)
        .asMap()
        .entries
        .map((e) => HandLandmark(
              x: e.value[0],
              y: e.value[1],
              z: e.value[2],
              index: e.key,
            ))
        .toList();
  }

  void _switchCamera() async {
    if (_cameras.length < 2) return;
    await _cameraController?.dispose();
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _startCamera(_cameraIndex);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      if (_cameras.isNotEmpty) _startCamera(_cameraIndex);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _tts?.stop();
    _poseDetector?.close();
    super.dispose();
  }

  // ─── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            _buildCameraView(),
            if (_landmarks.isNotEmpty) _buildLandmarkOverlay(),
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
              const Icon(Icons.camera_off, color: Colors.white38, size: 64),
              const SizedBox(height: 16),
              const Text('کیمرہ اجازت درکار ہے',
                style: TextStyle(fontFamily: 'JameelNooriNastaleeq',
                    color: Colors.white54, fontSize: 18),
                textDirection: TextDirection.rtl),
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

    if (_cameraController == null || !_cameraController!.value.isInitialized) {
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
        landmarks: _landmarks,
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
                _TopBarButton(icon: Icons.flip_camera_ios, onTap: _switchCamera),
            ]),
            const Text('شناخت',
              style: TextStyle(fontFamily: 'JameelNooriNastaleeq',
                  color: Colors.white, fontSize: 20),
              textDirection: TextDirection.rtl),
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
                    _landmarks = [];
                    _handDetected = false;
                    _statusMessage = 'ہاتھ کیمرہ کے سامنے رکھیں اور تصویر لیں';
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
            if (_isCapturing)
              const SizedBox(width: 14, height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF00C853)))
            else
              Icon(
                _handDetected ? Icons.back_hand : Icons.pan_tool_outlined,
                color: _handDetected ? const Color(0xFF00C853) : Colors.white38,
                size: 16,
              ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(_statusMessage,
                style: TextStyle(
                  fontFamily: 'JameelNooriNastaleeq',
                  color: _handDetected ? const Color(0xFF00C853) : Colors.white60,
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
              _buildCaptureRow(provider),
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
                    style: const TextStyle(color: Colors.white60,
                        fontSize: 13, letterSpacing: 1)),
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
                Text('Confidence: ${result.confidencePercent}',
                    style: TextStyle(color: result.confidenceColor, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 90, height: 90,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                const Color(0xFF006400).withOpacity(0.85),
                const Color(0xFF00A300).withOpacity(0.65),
              ]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: result.confidenceColor.withOpacity(0.6), width: 2),
              boxShadow: [
                BoxShadow(color: result.confidenceColor.withOpacity(0.3),
                    blurRadius: 20, spreadRadius: 2),
              ],
            ),
            child: Center(
              child: Text(result.urduLabel,
                style: const TextStyle(fontFamily: 'JameelNooriNastaleeq',
                    color: Colors.white, fontSize: 42),
                textDirection: TextDirection.rtl),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordDisplay(DetectionProvider provider) {
    final text = '${provider.detectedSentence}${provider.detectedWord}';
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
          Text('Word: $text',
              style: const TextStyle(color: Colors.white54, fontSize: 10)),
          const Text('شناخت شدہ',
              style: TextStyle(fontFamily: 'JameelNooriNastaleeq',
                  color: Color(0xFFC8A951), fontSize: 13),
              textDirection: TextDirection.rtl),
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
            style: const TextStyle(fontFamily: 'JameelNooriNastaleeq',
                color: Colors.white, fontSize: 26),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
          ),
        ),
      ]),
    );
  }

  Widget _buildCaptureRow(DetectionProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _ActionButton(icon: Icons.space_bar, label: 'Space',
              onTap: provider.addSpaceToWord, color: const Color(0xFF1565C0)),
          const SizedBox(width: 6),
          _ActionButton(icon: Icons.backspace_outlined, label: 'Undo',
              onTap: provider.undoLastLetter, color: const Color(0xFF6A1B9A)),
          const SizedBox(width: 6),
          _ActionButton(icon: Icons.volume_up, label: 'Speak',
              onTap: () async {
                final text =
                    '${provider.detectedSentence}${provider.detectedWord}';
                if (text.isNotEmpty) await _tts?.speak(text);
              },
              color: const Color(0xFF00695C)),
          const SizedBox(width: 12),

          // Camera capture button (big green circle)
          GestureDetector(
            onTap: _isCapturing ? null : _captureAndPredict,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 70, height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: _isCapturing
                      ? [Colors.grey.shade700, Colors.grey.shade600]
                      : [const Color(0xFF006400), const Color(0xFF00C853)],
                ),
                boxShadow: _isCapturing ? [] : [
                  BoxShadow(color: const Color(0xFF006400).withOpacity(0.6),
                      blurRadius: 20, spreadRadius: 3),
                ],
              ),
              child: _isCapturing
                  ? const Center(
                      child: SizedBox(width: 28, height: 28,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 3)))
                  : const Icon(Icons.camera_alt, color: Colors.white, size: 32),
            ),
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
  const _ActionButton(
      {required this.icon,
      required this.label,
      required this.onTap,
      required this.color});

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
