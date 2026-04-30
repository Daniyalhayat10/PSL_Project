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

  // ── Camera ─────────────────────────────────────────────────────────────────
  CameraController? _cam;
  List<CameraDescription> _cameras = [];
  int _camIdx = 1; // front camera by default
  bool _hasPermission = false;
  bool _streamActive = false;

  // ── Frame processing ───────────────────────────────────────────────────────
  bool _busy = false;
  int _frameCount = 0;
  // Process every 4th frame to keep UI smooth
  static const int _skipFrames = 4;

  // ── TTS ────────────────────────────────────────────────────────────────────
  FlutterTts? _tts;
  bool _ttsOn = true;
  String? _lastSpoken;

  // ── UI state ───────────────────────────────────────────────────────────────
  bool _handFound = false;
  String _status = 'ہاتھ کیمرہ کے سامنے رکھیں';
  int _processedFrames = 0; // shown in debug counter

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initTTS();
    _requestAndInit();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final m = context.read<ModelService>();
      if (!m.isLoaded && !m.isLoading) m.loadModel();
    });
  }

  Future<void> _initTTS() async {
    _tts = FlutterTts();
    await _tts?.setLanguage('ur-PK');
    await _tts?.setSpeechRate(0.5);
    await _tts?.setVolume(1.0);
  }

  // ── Camera setup ───────────────────────────────────────────────────────────

  Future<void> _requestAndInit() async {
    final s = await Permission.camera.request();
    if (!mounted) return;
    setState(() => _hasPermission = s.isGranted);
    if (s.isGranted) await _initCameras();
  }

  Future<void> _initCameras() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;
    // prefer front camera (index 1), fall back to back (index 0)
    _camIdx = _cameras.length > 1 ? 1 : 0;
    await _startCamera(_camIdx);
  }

  Future<void> _startCamera(int idx) async {
    await _stopStream();
    await _cam?.dispose();

    _cam = CameraController(
      _cameras[idx],
      ResolutionPreset.medium, // 640×480 ≈ good balance
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.yuv420
          : ImageFormatGroup.bgra8888,
    );

    try {
      await _cam!.initialize();
      if (mounted) {
        setState(() {});
        await _startStream();
      }
    } catch (e) {
      debugPrint('❌ Camera init: $e');
    }
  }

  Future<void> _startStream() async {
    if (_cam == null || !_cam!.value.isInitialized || _streamActive) return;
    _streamActive = true;
    await _cam!.startImageStream(_onFrame);
    debugPrint('✅ Camera stream started');
  }

  Future<void> _stopStream() async {
    if (!_streamActive) return;
    _streamActive = false;
    try { await _cam?.stopImageStream(); } catch (_) {}
  }

  // ── Frame processing ───────────────────────────────────────────────────────

  void _onFrame(CameraImage raw) {
    _frameCount++;
    if (_frameCount % _skipFrames != 0) return;
    if (_busy) return;
    _busy = true;
    _processFrame(raw);
  }

  Future<void> _processFrame(CameraImage raw) async {
    try {
      final frame = _toImage(raw);
      if (frame == null) return;

      setState(() => _processedFrames++);

      final model = context.read<ModelService>();
      if (!model.isLoaded) return;

      final result = model.processFrame(frame);

      if (!mounted) return;

      if (result != null) {
        context.read<DetectionProvider>().updateDetection(result);
        setState(() {
          _handFound = true;
          _status = '${result.romanLabel}  ${result.confidencePercent}';
        });
        if (_ttsOn && result.isHighConfidence &&
            result.romanLabel != _lastSpoken) {
          _lastSpoken = result.romanLabel;
          _tts?.speak(result.urduLabel);
        }
      } else {
        setState(() {
          _handFound = false;
          _status = 'ہاتھ باکس میں رکھیں';
        });
      }
    } catch (e) {
      debugPrint('❌ frame error: $e');
    } finally {
      _busy = false;
    }
  }

  // ── Image conversion ───────────────────────────────────────────────────────

  img.Image? _toImage(CameraImage c) {
    try {
      return Platform.isAndroid ? _yuv(c) : _bgra(c);
    } catch (e) {
      debugPrint('❌ convert: $e');
      return null;
    }
  }

  img.Image _yuv(CameraImage c) {
    final w = c.width, h = c.height;
    final out = img.Image(width: w, height: h);
    final yp = c.planes[0], up = c.planes[1], vp = c.planes[2];
    final yb = yp.bytes, ub = up.bytes, vb = vp.bytes;
    final uvRow = up.bytesPerRow, uvPx = up.bytesPerPixel!;
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final yi = y * yp.bytesPerRow + x;
        final ui = (y ~/ 2) * uvRow + (x ~/ 2) * uvPx;
        final yv = yb[yi], u = ub[ui], v = vb[ui];
        final r = (yv + 1.402 * (v - 128)).round().clamp(0, 255);
        final g = (yv - 0.344136 * (u - 128) - 0.714136 * (v - 128)).round().clamp(0, 255);
        final b = (yv + 1.772 * (u - 128)).round().clamp(0, 255);
        out.setPixelRgb(x, y, r, g, b);
      }
    }
    return out;
  }

  img.Image _bgra(CameraImage c) => img.Image.fromBytes(
    width: c.width, height: c.height,
    bytes: c.planes[0].bytes.buffer,
    format: img.Format.uint8,
    order: img.ChannelOrder.bgra,
  );

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    _camIdx = (_camIdx + 1) % _cameras.length;
    await _startCamera(_camIdx);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.inactive) _stopStream();
    else if (s == AppLifecycleState.resumed && _cameras.isNotEmpty) {
      _startCamera(_camIdx);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopStream();
    _cam?.dispose();
    _tts?.stop();
    super.dispose();
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(children: [
          _buildCamera(),
          _buildGuideBox(),
          _buildTopBar(),
          _buildStatusBadge(),
          Positioned(bottom: 0, left: 0, right: 0, child: _buildBottom()),
        ]),
      ),
    );
  }

  Widget _buildCamera() {
    if (!_hasPermission) {
      return Container(color: const Color(0xFF0A0A1A),
        child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off, color: Colors.white38, size: 64),
            const SizedBox(height: 16),
            const Text('کیمرہ اجازت درکار ہے',
              style: TextStyle(fontFamily: 'JameelNooriNastaleeq',
                  color: Colors.white54, fontSize: 18),
              textDirection: TextDirection.rtl),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _requestAndInit,
                child: const Text('Allow Camera')),
          ])));
    }
    if (_cam == null || !_cam!.value.isInitialized) {
      return Container(color: const Color(0xFF0A0A1A),
        child: const Center(
            child: CircularProgressIndicator(color: Color(0xFF006400))));
    }
    return SizedBox.expand(
      child: FittedBox(fit: BoxFit.cover,
        child: SizedBox(
          width: _cam!.value.previewSize!.height,
          height: _cam!.value.previewSize!.width,
          child: CameraPreview(_cam!),
        )));
  }

  /// Guide box — user should put hand here
  Widget _buildGuideBox() {
    return Center(
      child: Container(
        width: 240, height: 240,
        decoration: BoxDecoration(
          border: Border.all(
            color: _handFound ? const Color(0xFF00C853) : Colors.white38,
            width: _handFound ? 3 : 2,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: _handFound ? null : const Center(
          child: Text('ہاتھ یہاں رکھیں',
            style: TextStyle(fontFamily: 'JameelNooriNastaleeq',
                color: Colors.white38, fontSize: 14),
            textDirection: TextDirection.rtl),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(top: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.75), Colors.transparent])),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              _Btn(icon: Icons.arrow_back_ios, onTap: () => Navigator.pop(context)),
              if (_cameras.length > 1) ...[
                const SizedBox(width: 8),
                _Btn(icon: Icons.flip_camera_ios, onTap: _switchCamera),
              ],
            ]),
            const Text('شناخت',
              style: TextStyle(fontFamily: 'JameelNooriNastaleeq',
                  color: Colors.white, fontSize: 20),
              textDirection: TextDirection.rtl),
            Row(children: [
              _Btn(
                icon: _ttsOn ? Icons.volume_up : Icons.volume_off,
                onTap: () => setState(() => _ttsOn = !_ttsOn),
                active: _ttsOn,
              ),
              const SizedBox(width: 8),
              _Btn(icon: Icons.delete_outline, onTap: () {
                context.read<DetectionProvider>().clearAll();
                setState(() { _handFound = false; _status = 'ہاتھ کیمرہ کے سامنے رکھیں'; });
              }),
            ]),
          ]),
      ));
  }

  Widget _buildStatusBadge() {
    return Positioned(top: 70, left: 16, right: 16,
      child: Column(children: [
        Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _handFound
                  ? const Color(0xFF00C853).withOpacity(0.2)
                  : Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _handFound
                    ? const Color(0xFF00C853).withOpacity(0.6)
                    : Colors.white24),
            ),
            child: Text(_status,
              style: TextStyle(
                fontFamily: 'JameelNooriNastaleeq',
                color: _handFound ? const Color(0xFF00C853) : Colors.white60,
                fontSize: 13),
              textDirection: TextDirection.rtl),
          ),
        ),
        const SizedBox(height: 6),
        // Debug counter — helps confirm frames are being processed
        Text('Frames processed: $_processedFrames',
          style: const TextStyle(color: Colors.white30, fontSize: 10)),
      ]),
    );
  }

  Widget _buildBottom() {
    return Consumer<DetectionProvider>(
      builder: (ctx, p, _) => Container(
        decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.bottomCenter, end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.97),
            Colors.black.withOpacity(0.75), Colors.transparent])),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (p.lastResult != null) _buildCard(p.lastResult!),
          const SizedBox(height: 8),
          _buildWordBox(p),
          const SizedBox(height: 12),
          _buildActions(p),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  Widget _buildCard(DetectionResult r) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(r.romanLabel,
                style: const TextStyle(color: Colors.white60, fontSize: 13)),
            const SizedBox(height: 6),
            ClipRRect(borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: r.confidence,
                  backgroundColor: Colors.white12,
                  color: r.confidenceColor, minHeight: 6)),
            const SizedBox(height: 3),
            Text('Confidence: ${r.confidencePercent}',
                style: TextStyle(color: r.confidenceColor, fontSize: 11)),
          ])),
        const SizedBox(width: 16),
        Container(
          width: 90, height: 90,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              const Color(0xFF006400).withOpacity(0.85),
              const Color(0xFF00A300).withOpacity(0.6)]),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: r.confidenceColor.withOpacity(0.6), width: 2),
            boxShadow: [BoxShadow(
                color: r.confidenceColor.withOpacity(0.3), blurRadius: 20)]),
          child: Center(child: Text(r.urduLabel,
            style: const TextStyle(fontFamily: 'JameelNooriNastaleeq',
                color: Colors.white, fontSize: 44),
            textDirection: TextDirection.rtl)),
        ),
      ]),
    );
  }

  Widget _buildWordBox(DetectionProvider p) {
    final text = p.fullText;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A).withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12)),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Detections: ${p.detectionCount}',
              style: const TextStyle(color: Colors.white38, fontSize: 10)),
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
          child: Text(text.isEmpty ? '...' : text,
            style: const TextStyle(fontFamily: 'JameelNooriNastaleeq',
                color: Colors.white, fontSize: 26),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center),
        ),
      ]),
    );
  }

  Widget _buildActions(DetectionProvider p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        _Act(icon: Icons.space_bar, label: 'Space',
            onTap: p.addSpaceToWord, color: const Color(0xFF1565C0)),
        const SizedBox(width: 6),
        _Act(icon: Icons.backspace_outlined, label: 'Undo',
            onTap: p.undoLastLetter, color: const Color(0xFF6A1B9A)),
        const SizedBox(width: 6),
        _Act(icon: Icons.volume_up, label: 'Speak',
            onTap: () async {
              final t = p.fullText;
              if (t.isNotEmpty) await _tts?.speak(t);
            }, color: const Color(0xFF00695C)),
        const SizedBox(width: 6),
        _Act(icon: Icons.clear_all, label: 'Clear',
            onTap: () {
              p.clearAll();
              setState(() { _handFound = false; _status = 'ہاتھ کیمرہ کے سامنے رکھیں'; });
            }, color: const Color(0xFFB71C1C)),
      ]),
    );
  }
}

// ── Reusable small widgets ────────────────────────────────────────────────────

class _Btn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  const _Btn({required this.icon, required this.onTap, this.active = true});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Container(padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24)),
      child: Icon(icon, color: active ? Colors.white : Colors.white38, size: 20)));
}

class _Act extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  const _Act({required this.icon, required this.label,
      required this.onTap, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(onTap: onTap,
      child: Container(padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4))),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(color: color, fontSize: 10)),
        ]))));
}
