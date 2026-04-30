import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image/image.dart' as img;

import '../services/model_service.dart';
import '../services/detection_provider.dart';

class DetectionScreen extends StatefulWidget {
  const DetectionScreen({super.key});

  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen>
    with WidgetsBindingObserver {
  // Camera
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 1;
  bool _cameraPermissionGranted = false;
  bool _isStreamActive = false;

  // Frame processing
  bool _isProcessingFrame = false;
  int _frameCounter = 0;
  static const int _processEveryNFrames = 5;

  // TTS
  FlutterTts? _tts;
  bool _ttsEnabled = true;
  String? _lastSpokenLabel;

  // UI
  bool _handDetected = false;
  String _statusMessage = 'ہاتھ کیمرہ کے سامنے رکھیں';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initTTS();
    _requestPermissionAndInit();
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

  // ── Camera ──────────────────────────────────────────────────────────────────

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

    _cameraController = CameraController(
      _cameras[index],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.yuv420
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
  }

  Future<void> _stopStream() async {
    if (!_isStreamActive) return;
    _isStreamActive = false;
    try { await _cameraController?.stopImageStream(); } catch (_) {}
  }

  // ── Frame processing ────────────────────────────────────────────────────────

  void _onCameraFrame(CameraImage cameraImage) {
    _frameCounter++;
    if (_frameCounter % _processEveryNFrames != 0) return;
    if (_isProcessingFrame) return;
    _isProcessingFrame = true;
    _processFrameAsync(cameraImage);
  }

  Future<void> _processFrameAsync(CameraImage cameraImage) async {
    try {
      final imgFrame = _convertCameraImage(cameraImage);
      if (imgFrame == null) return;

      final modelService = context.read<ModelService>();
      final result = modelService.processFrame(imgFrame);

      if (!mounted) return;

      if (result != null) {
        context.read<DetectionProvider>().updateDetection(result);
        setState(() {
          _handDetected = true;
          _statusMessage =
              '${result.romanLabel}  ${result.confidencePercent}';
        });

        if (_ttsEnabled &&
            result.isHighConfidence &&
            result.romanLabel != _lastSpokenLabel) {
          _lastSpokenLabel = result.romanLabel;
          _tts?.speak(result.urduLabel);
        }
      } else {
        setState(() {
          _handDetected = false;
          _statusMessage = 'ہاتھ نہیں ملا — کیمرہ کے سامنے رکھیں';
        });
      }
    } catch (e) {
      debugPrint('❌ processFrame error: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  /// Convert CameraImage (YUV420 or BGRA) to img.Image
  img.Image? _convertCameraImage(CameraImage camImage) {
    try {
      if (Platform.isAndroid) {
        return _yuv420ToImage(camImage);
      } else {
        return _bgra8888ToImage(camImage);
      }
    } catch (e) {
      debugPrint('❌ Image convert error: $e');
      return null;
    }
  }

  img.Image _yuv420ToImage(CameraImage camImage) {
    final int width = camImage.width;
    final int height = camImage.height;
    final image = img.Image(width: width, height: height);

    final yPlane = camImage.planes[0];
    final uPlane = camImage.planes[1];
    final vPlane = camImage.planes[2];

    final yBytes = yPlane.bytes;
    final uBytes = uPlane.bytes;
    final vBytes = vPlane.bytes;

    final int uvRowStride = uPlane.bytesPerRow;
    final int uvPixelStride = uPlane.bytesPerPixel!;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int yIdx = y * yPlane.bytesPerRow + x;
        final int uvIdx =
            (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;

        final int yVal = yBytes[yIdx];
        final int uVal = uBytes[uvIdx];
        final int vVal = vBytes[uvIdx];

        int r = (yVal + 1.402 * (vVal - 128)).round().clamp(0, 255);
        int g = (yVal - 0.344136 * (uVal - 128) - 0.714136 * (vVal - 128))
            .round()
            .clamp(0, 255);
        int b = (yVal + 1.772 * (uVal - 128)).round().clamp(0, 255);

        image.setPixelRgb(x, y, r, g, b);
      }
    }
    return image;
  }

  img.Image _bgra8888ToImage(CameraImage camImage) {
    return img.Image.fromBytes(
      width: camImage.width,
      height: camImage.height,
      bytes: camImage.planes[0].bytes.buffer,
      format: img.Format.uint8,
      order: img.ChannelOrder.bgra,
    );
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
    super.dispose();
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(children: [
          _buildCameraView(),
          _buildGuideBox(),
          _buildTopBar(),
          _buildStatusBadge(),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _buildBottomPanel(),
          ),
        ]),
      ),
    );
  }

  /// Green guide box so user knows where to hold their hand
  Widget _buildGuideBox() {
    return Center(
      child: Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          border: Border.all(
            color: _handDetected
                ? const Color(0xFF00C853)
                : Colors.white38,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: _handDetected
            ? null
            : const Center(
                child: Text(
                  'ہاتھ یہاں رکھیں',
                  style: TextStyle(
                    fontFamily: 'JameelNooriNastaleeq',
                    color: Colors.white38,
                    fontSize: 14,
                  ),
                  textDirection: TextDirection.rtl,
                ),
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
              _TopBarBtn(icon: Icons.arrow_back_ios,
                  onTap: () => Navigator.pop(context)),
              if (_cameras.length > 1) ...[
                const SizedBox(width: 8),
                _TopBarBtn(icon: Icons.flip_camera_ios, onTap: _switchCamera),
              ],
            ]),
            const Text('شناخت',
                style: TextStyle(
                    fontFamily: 'JameelNooriNastaleeq',
                    color: Colors.white,
                    fontSize: 20),
                textDirection: TextDirection.rtl),
            Row(children: [
              _TopBarBtn(
                icon: _ttsEnabled ? Icons.volume_up : Icons.volume_off,
                onTap: () => setState(() => _ttsEnabled = !_ttsEnabled),
                active: _ttsEnabled,
              ),
              const SizedBox(width: 8),
              _TopBarBtn(
                icon: Icons.delete_outline,
                onTap: () {
                  context.read<DetectionProvider>().clearAll();
                  setState(() {
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
      top: 70, left: 16, right: 16,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _handDetected
                ? const Color(0xFF00C853).withOpacity(0.2)
                : Colors.black.withOpacity(0.55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _handDetected
                  ? const Color(0xFF00C853).withOpacity(0.6)
                  : Colors.white24,
            ),
          ),
          child: Text(
            _statusMessage,
            style: TextStyle(
              fontFamily: 'JameelNooriNastaleeq',
              color: _handDetected
                  ? const Color(0xFF00C853)
                  : Colors.white60,
              fontSize: 13,
            ),
            textDirection: TextDirection.rtl,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Consumer<DetectionProvider>(
      builder: (context, provider, _) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.97),
              Colors.black.withOpacity(0.7),
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
      ),
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
                        color: Colors.white60, fontSize: 13, letterSpacing: 1)),
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
                  style: TextStyle(color: result.confidenceColor, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                const Color(0xFF006400).withOpacity(0.85),
                const Color(0xFF00A300).withOpacity(0.6),
              ]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: result.confidenceColor.withOpacity(0.6), width: 2),
              boxShadow: [
                BoxShadow(
                    color: result.confidenceColor.withOpacity(0.3),
                    blurRadius: 20)
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
          Text('Frames: ${provider.detectionCount}',
              style: const TextStyle(color: Colors.white38, fontSize: 10)),
          const Text('شناخت شدہ',
              style: TextStyle(
                  fontFamily: 'JameelNooriNastaleeq',
                  color: Color(0xFFC8A951),
                  fontSize: 13),
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
      child: Row(children: [
        _ActionBtn(
            icon: Icons.space_bar, label: 'Space',
            onTap: provider.addSpaceToWord,
            color: const Color(0xFF1565C0)),
        const SizedBox(width: 6),
        _ActionBtn(
            icon: Icons.backspace_outlined, label: 'Undo',
            onTap: provider.undoLastLetter,
            color: const Color(0xFF6A1B9A)),
        const SizedBox(width: 6),
        _ActionBtn(
            icon: Icons.volume_up, label: 'Speak',
            onTap: () async {
              final t = provider.fullText;
              if (t.isNotEmpty) await _tts?.speak(t);
            },
            color: const Color(0xFF00695C)),
        const SizedBox(width: 6),
        _ActionBtn(
            icon: Icons.clear_all, label: 'Clear',
            onTap: () {
              provider.clearAll();
              setState(() {
                _handDetected = false;
                _statusMessage = 'ہاتھ کیمرہ کے سامنے رکھیں';
              });
            },
            color: const Color(0xFFB71C1C)),
      ]),
    );
  }
}

// ── Small reusable widgets ────────────────────────────────────────────────────

class _TopBarBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  const _TopBarBtn({required this.icon, required this.onTap, this.active = true});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: Icon(icon, color: active ? Colors.white : Colors.white38, size: 20),
        ),
      );
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  const _ActionBtn({required this.icon, required this.label,
      required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
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
