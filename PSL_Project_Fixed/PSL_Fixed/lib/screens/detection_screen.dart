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
    with WidgetsBindingObserver, TickerProviderStateMixin {

  CameraController? _cam;
  List<CameraDescription> _cameras = [];
  int _camIdx = 1;
  bool _hasPermission = false;
  bool _streamActive = false;
  bool _busy = false;
  int _frameCount = 0;
  static const int _skip = 4;

  FlutterTts? _tts;
  bool _ttsOn = true;
  String? _lastSpoken;

  bool _handFound = false;
  String _status = 'ہاتھ باکس میں رکھیں';
  int _processed = 0;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;
  late AnimationController _letterCtrl;
  late Animation<double> _letterAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pulseCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _pulse = Tween(begin: 0.95, end: 1.05).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _letterCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 400));
    _letterAnim = CurvedAnimation(parent: _letterCtrl, curve: Curves.elasticOut);

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
  }

  Future<void> _requestAndInit() async {
    final s = await Permission.camera.request();
    if (!mounted) return;
    setState(() => _hasPermission = s.isGranted);
    if (s.isGranted) await _initCameras();
  }

  Future<void> _initCameras() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;
    _camIdx = _cameras.length > 1 ? 1 : 0;
    await _startCamera(_camIdx);
  }

  Future<void> _startCamera(int idx) async {
    await _stopStream();
    await _cam?.dispose();
    _cam = CameraController(_cameras[idx], ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888);
    try {
      await _cam!.initialize();
      if (mounted) { setState(() {}); await _startStream(); }
    } catch (e) { debugPrint('❌ Camera: $e'); }
  }

  Future<void> _startStream() async {
    if (_cam == null || !_cam!.value.isInitialized || _streamActive) return;
    _streamActive = true;
    await _cam!.startImageStream(_onFrame);
  }

  Future<void> _stopStream() async {
    if (!_streamActive) return;
    _streamActive = false;
    try { await _cam?.stopImageStream(); } catch (_) {}
  }

  void _onFrame(CameraImage raw) {
    _frameCount++;
    if (_frameCount % _skip != 0 || _busy) return;
    _busy = true;
    _processFrame(raw);
  }

  Future<void> _processFrame(CameraImage raw) async {
    try {
      final frame = _toImage(raw);
      if (frame == null) return;
      setState(() => _processed++);
      final model = context.read<ModelService>();
      if (!model.isLoaded) return;
      final result = model.processFrame(frame);
      if (!mounted) return;
      if (result != null) {
        context.read<DetectionProvider>().updateDetection(result);
        if (!_handFound) _letterCtrl.forward(from: 0);
        setState(() {
          _handFound = true;
          _status = '${result.romanLabel}  ${result.confidencePercent}';
        });
        if (_ttsOn && result.isHighConfidence && result.romanLabel != _lastSpoken) {
          _lastSpoken = result.romanLabel;
          _tts?.speak(result.urduLabel);
        }
      } else {
        setState(() {
          _handFound = false;
          _status = 'ہاتھ باکس میں رکھیں';
        });
      }
    } catch (e) { debugPrint('❌ frame: $e'); }
    finally { _busy = false; }
  }

  img.Image? _toImage(CameraImage c) {
    try { return Platform.isAndroid ? _yuv(c) : _bgra(c); }
    catch (e) { return null; }
  }

  img.Image _yuv(CameraImage c) {
    final out = img.Image(width: c.width, height: c.height);
    final yp = c.planes[0], up = c.planes[1], vp = c.planes[2];
    for (int y = 0; y < c.height; y++) {
      for (int x = 0; x < c.width; x++) {
        final yi = y * yp.bytesPerRow + x;
        final ui = (y ~/ 2) * up.bytesPerRow + (x ~/ 2) * up.bytesPerPixel!;
        final yv = yp.bytes[yi], u = up.bytes[ui], v = vp.bytes[ui];
        out.setPixelRgb(x, y,
          (yv + 1.402*(v-128)).round().clamp(0,255),
          (yv - 0.344136*(u-128) - 0.714136*(v-128)).round().clamp(0,255),
          (yv + 1.772*(u-128)).round().clamp(0,255));
      }
    }
    return out;
  }

  img.Image _bgra(CameraImage c) => img.Image.fromBytes(
      width: c.width, height: c.height,
      bytes: c.planes[0].bytes.buffer,
      format: img.Format.uint8, order: img.ChannelOrder.bgra);

  Future<void> _switchCam() async {
    if (_cameras.length < 2) return;
    _camIdx = (_camIdx + 1) % _cameras.length;
    await _startCamera(_camIdx);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.inactive) _stopStream();
    else if (s == AppLifecycleState.resumed && _cameras.isNotEmpty) _startCamera(_camIdx);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopStream(); _cam?.dispose();
    _tts?.stop();
    _pulseCtrl.dispose(); _letterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: SafeArea(
        child: Stack(children: [
          _buildCamera(),
          _buildAnimatedGuideBox(),
          _buildTopBar(),
          _buildStatusChip(),
          Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomSheet()),
        ]),
      ),
    );
  }

  Widget _buildCamera() {
    if (!_hasPermission) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          ),
        ),
        child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off, color: Colors.white70, size: 72),
            const SizedBox(height: 20),
            const Text('Camera permission required',
                style: TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _requestAndInit,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Allow Camera'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF667EEA),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14)),
            ),
          ])),
      );
    }
    if (_cam == null || !_cam!.value.isInitialized) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          ),
        ),
        child: const Center(
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)),
      );
    }
    return SizedBox.expand(
      child: FittedBox(fit: BoxFit.cover,
        child: SizedBox(
          width: _cam!.value.previewSize!.height,
          height: _cam!.value.previewSize!.width,
          child: CameraPreview(_cam!),
        )),
    );
  }

  Widget _buildAnimatedGuideBox() {
    return Center(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, __) => Transform.scale(
          scale: _handFound ? 1.0 : _pulse.value,
          child: Container(
            width: 230, height: 230,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _handFound
                    ? const Color(0xFF00E676)
                    : Colors.white.withOpacity(0.85),
                width: _handFound ? 3.5 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _handFound
                      ? const Color(0xFF00E676).withOpacity(0.4)
                      : Colors.white.withOpacity(0.2),
                  blurRadius: 20, spreadRadius: 2,
                ),
              ],
            ),
            child: _handFound
                ? null
                : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.back_hand_outlined,
                        color: Colors.white70, size: 44),
                    const SizedBox(height: 8),
                    const Text('ہاتھ یہاں رکھیں',
                        style: TextStyle(
                            fontFamily: 'JameelNooriNastaleeq',
                            color: Colors.white70, fontSize: 15),
                        textDirection: TextDirection.rtl),
                  ]),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(top: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.65), Colors.transparent],
          ),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              _GlassBtn(icon: Icons.arrow_back_ios_new,
                  onTap: () => Navigator.pop(context)),
              if (_cameras.length > 1) ...[
                const SizedBox(width: 8),
                _GlassBtn(icon: Icons.flip_camera_ios, onTap: _switchCam),
              ],
            ]),
            // Title
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(20)),
              child: const Text('PSL شناخت',
                style: TextStyle(fontFamily: 'JameelNooriNastaleeq',
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                textDirection: TextDirection.rtl),
            ),
            Row(children: [
              _GlassBtn(
                  icon: _ttsOn ? Icons.volume_up : Icons.volume_off,
                  onTap: () => setState(() => _ttsOn = !_ttsOn),
                  active: _ttsOn),
              const SizedBox(width: 8),
              _GlassBtn(icon: Icons.delete_sweep, onTap: () {
                context.read<DetectionProvider>().clearAll();
                setState(() { _handFound = false; _status = 'ہاتھ باکس میں رکھیں'; });
              }),
            ]),
          ]),
      ));
  }

  Widget _buildStatusChip() {
    return Positioned(top: 76, left: 0, right: 0,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: _handFound
                ? const Color(0xFF00E676).withOpacity(0.9)
                : Colors.black.withOpacity(0.55),
            borderRadius: BorderRadius.circular(30),
            boxShadow: _handFound ? [
              BoxShadow(color: const Color(0xFF00E676).withOpacity(0.4),
                  blurRadius: 12),
            ] : [],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(_handFound ? Icons.check_circle : Icons.pan_tool_outlined,
                color: _handFound ? Colors.white : Colors.white60, size: 16),
            const SizedBox(width: 8),
            Text(_status,
                style: TextStyle(
                    fontFamily: 'JameelNooriNastaleeq',
                    color: _handFound ? Colors.white : Colors.white70,
                    fontSize: 13, fontWeight: FontWeight.w600),
                textDirection: TextDirection.rtl),
          ]),
        ),
      ));
  }

  Widget _buildBottomSheet() {
    return Consumer<DetectionProvider>(
      builder: (ctx, p, _) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15),
              blurRadius: 20, offset: const Offset(0, -5))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle
          Container(margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          // Current detection
          if (p.lastResult != null) _buildDetectionCard(p.lastResult!),
          const SizedBox(height: 12),
          // Word/Sentence display
          _buildTextDisplay(p),
          const SizedBox(height: 12),
          // Actions
          _buildActions(p),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  Widget _buildDetectionCard(DetectionResult r) {
    return ScaleTransition(
      scale: _letterAnim,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: r.isHighConfidence
                ? [const Color(0xFF00C853).withOpacity(0.1), const Color(0xFF69F0AE).withOpacity(0.05)]
                : [const Color(0xFFFFD600).withOpacity(0.1), const Color(0xFFFFEE58).withOpacity(0.05)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: r.confidenceColor.withOpacity(0.4), width: 1.5),
        ),
        child: Row(children: [
          // Big Urdu letter
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF667EEA), const Color(0xFF764BA2)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(
                  color: const Color(0xFF667EEA).withOpacity(0.4),
                  blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Center(child: Text(r.urduLabel,
                style: const TextStyle(
                    fontFamily: 'JameelNooriNastaleeq',
                    color: Colors.white, fontSize: 40),
                textDirection: TextDirection.rtl)),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.romanLabel,
                  style: const TextStyle(fontSize: 18,
                      fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                      value: r.confidence,
                      backgroundColor: Colors.grey[200],
                      color: r.confidenceColor, minHeight: 8),
                )),
                const SizedBox(width: 8),
                Text(r.confidencePercent,
                    style: TextStyle(color: r.confidenceColor,
                        fontWeight: FontWeight.bold, fontSize: 13)),
              ]),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                    color: r.isHighConfidence
                        ? const Color(0xFF00C853).withOpacity(0.1)
                        : const Color(0xFFFFD600).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Text(
                    r.isHighConfidence ? '✓ High Confidence' : '~ Medium',
                    style: TextStyle(fontSize: 11,
                        color: r.isHighConfidence
                            ? const Color(0xFF00C853)
                            : const Color(0xFFF9A825),
                        fontWeight: FontWeight.w600)),
              ),
            ])),
        ]),
      ),
    );
  }

  Widget _buildTextDisplay(DetectionProvider p) {
    final text = p.fullText;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E7FF), width: 1.5),
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
                color: const Color(0xFF667EEA).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Text('${p.detectionCount} detections',
                style: const TextStyle(color: Color(0xFF667EEA),
                    fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          const Text('شناخت شدہ متن',
              style: TextStyle(fontFamily: 'JameelNooriNastaleeq',
                  color: Color(0xFF764BA2), fontSize: 13,
                  fontWeight: FontWeight.bold),
              textDirection: TextDirection.rtl),
        ]),
        const SizedBox(height: 10),
        Container(
          width: double.infinity, padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE0E7FF))),
          child: Text(text.isEmpty ? '...' : text,
              style: const TextStyle(fontFamily: 'JameelNooriNastaleeq',
                  color: Color(0xFF1A1A2E), fontSize: 28),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center),
        ),
      ]),
    );
  }

  Widget _buildActions(DetectionProvider p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        _ActionChip(label: 'Space', icon: Icons.space_bar,
            color: const Color(0xFF667EEA), onTap: p.addSpaceToWord),
        const SizedBox(width: 8),
        _ActionChip(label: 'Undo', icon: Icons.backspace_outlined,
            color: const Color(0xFF764BA2), onTap: p.undoLastLetter),
        const SizedBox(width: 8),
        _ActionChip(label: 'Speak', icon: Icons.record_voice_over,
            color: const Color(0xFF00BCD4), onTap: () async {
          final t = p.fullText;
          if (t.isNotEmpty) await _tts?.speak(t);
        }),
        const SizedBox(width: 8),
        _ActionChip(label: 'Clear', icon: Icons.clear_all,
            color: const Color(0xFFE91E63), onTap: () {
          p.clearAll();
          setState(() { _handFound = false; _status = 'ہاتھ باکس میں رکھیں'; });
        }),
      ]),
    );
  }
}

// ── Small widgets ─────────────────────────────────────────────────────────────

class _GlassBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  const _GlassBtn({required this.icon, required this.onTap, this.active = true});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.4)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1),
              blurRadius: 8)]),
      child: Icon(icon, color: active ? Colors.white : Colors.white54, size: 20)));
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionChip({required this.label, required this.icon,
      required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [color.withOpacity(0.15), color.withOpacity(0.05)]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(color: color, fontSize: 10,
              fontWeight: FontWeight.w700)),
        ]),
      )));
}
