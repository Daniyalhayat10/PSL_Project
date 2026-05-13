import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/model_service.dart';
import '../services/detection_provider.dart';

class DetectionScreen extends StatefulWidget {
  const DetectionScreen({super.key});
  @override State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {

  // Camera
  CameraController? _cam;
  List<CameraDescription> _cameras = [];
  int _camIdx = 1;
  bool _hasPermission = false;
<<<<<<< Updated upstream
  bool _streamActive  = false;
  bool _busy          = false;
  int  _frameCount    = 0;
  static const int _skip = 5;
=======
  bool _streamActive = false;
  bool _busy = false;
  int _frameCount = 0;
  static const int _skip = 10;
>>>>>>> Stashed changes

  // TTS
  FlutterTts? _tts;
  bool _ttsOn = true;
  String? _lastSpoken;

  // State
  bool   _handFound  = false;
  String _status     = 'Place your hand in the frame';
  int    _processed  = 0;

  // Animations
  late AnimationController _pulseCtrl;
  late AnimationController _letterCtrl;
  late AnimationController _glowCtrl;
  late Animation<double>   _pulseAnim;
  late Animation<double>   _letterAnim;
  late Animation<double>   _glowAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pulseCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
    _pulseAnim = Tween(begin: 1.0, end: 1.04).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _letterCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 500));
    _letterAnim = CurvedAnimation(parent: _letterCtrl,
        curve: Curves.elasticOut);

    _glowCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _glowAnim = Tween(begin: 0.3, end: 0.8).animate(
        CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

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
    _cam = null;

    // Retry up to 3 times with an increasing delay — the camera HAL sometimes
    // holds the hardware for a moment after the previous session closes.
    for (int attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        await Future.delayed(Duration(milliseconds: 400 * attempt));
      }
      _cam = CameraController(_cameras[idx], ResolutionPreset.low,
          enableAudio: false,
          imageFormatGroup: Platform.isAndroid
              ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888);
      try {
        await _cam!.initialize();
        if (mounted) { setState(() {}); await _startStream(); }
        return; // success
      } catch (e) {
        debugPrint('❌ Camera attempt ${attempt + 1}: $e');
        await _cam?.dispose();
        _cam = null;
      }
    }
    if (mounted) setState(() {}); // refresh UI to show no-camera state
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
    _process(raw);
  }

  Future<void> _process(CameraImage raw) async {
    try {
<<<<<<< Updated upstream
      final frame = _toImg(raw);
      if (frame == null) return;
      setState(() => _processed++);
=======
>>>>>>> Stashed changes
      final model = context.read<ModelService>();
      if (!model.isLoaded) return;

      DetectionResult? result;
      if (Platform.isAndroid) {
        // Pass raw YUV planes straight to the native MediaPipe landmarker —
        // no Dart-side pixel conversion needed.
        result = await model.processYuv(
          width:          raw.width,
          height:         raw.height,
          yPlane:         Uint8List.fromList(raw.planes[0].bytes),
          uPlane:         Uint8List.fromList(raw.planes[1].bytes),
          vPlane:         Uint8List.fromList(raw.planes[2].bytes),
          yStride:        raw.planes[0].bytesPerRow,
          uvStride:       raw.planes[1].bytesPerRow,
          uvPixelStride:  raw.planes[1].bytesPerPixel!,
        );
      }

      if (!mounted) return;
      setState(() => _processed++);

      // Only surface confident detections (≥ 30 %)
      final validResult = (result != null && result.confidence >= 0.30)
          ? result : null;

      if (validResult != null) {
        context.read<DetectionProvider>().updateDetection(validResult);
        if (!_handFound) _letterCtrl.forward(from: 0);
<<<<<<< Updated upstream
        setState(() { _handFound = true; _status = result.romanLabel; });
        if (_ttsOn && result.isHighConfidence &&
            result.romanLabel != _lastSpoken) {
          _lastSpoken = result.romanLabel;
          _tts?.speak(result.urduLabel);
        }
      } else {
        setState(() { _handFound = false; _status = 'Place your hand in the frame'; });
=======
        setState(() {
          _handFound = true;
          _status = '${validResult.romanLabel}  ${validResult.confidencePercent}';
        });
        if (_ttsOn && validResult.isHighConfidence &&
            validResult.romanLabel != _lastSpoken) {
          _lastSpoken = validResult.romanLabel;
          _tts?.speak(validResult.urduLabel);
        }
      } else {
        // No hand / low confidence — open the gate so next gesture can commit
        context.read<DetectionProvider>().onHandLost();
        setState(() {
          _handFound = false;
          _status = 'ہاتھ باکس میں رکھیں';
        });
>>>>>>> Stashed changes
      }
    } catch (e) { debugPrint('❌ process: $e'); }
    finally { _busy = false; }
  }

<<<<<<< Updated upstream
  img.Image? _toImg(CameraImage c) {
    try { return Platform.isAndroid ? _yuv(c) : _bgra(c); }
    catch (_) { return null; }
  }

  img.Image _yuv(CameraImage c) {
    final out = img.Image(width: c.width, height: c.height);
    final yp=c.planes[0]; final up=c.planes[1]; final vp=c.planes[2];
    for (int y=0;y<c.height;y++) {
      for (int x=0;x<c.width;x++) {
        final yi=y*yp.bytesPerRow+x;
        final ui=(y~/2)*up.bytesPerRow+(x~/2)*up.bytesPerPixel!;
        final yv=yp.bytes[yi]; final u=up.bytes[ui]; final v=vp.bytes[ui];
        out.setPixelRgb(x,y,
          (yv+1.402*(v-128)).round().clamp(0,255),
          (yv-0.344136*(u-128)-0.714136*(v-128)).round().clamp(0,255),
          (yv+1.772*(u-128)).round().clamp(0,255));
      }
    }
    return out;
  }

  img.Image _bgra(CameraImage c) => img.Image.fromBytes(
      width:c.width, height:c.height,
      bytes:c.planes[0].bytes.buffer,
      format:img.Format.uint8, order:img.ChannelOrder.bgra);

=======
>>>>>>> Stashed changes
  Future<void> _switchCam() async {
    if (_cameras.length < 2) return;
    _camIdx = (_camIdx+1)%_cameras.length;
    await _startCamera(_camIdx);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
<<<<<<< Updated upstream
    if (s==AppLifecycleState.inactive) _stopStream();
    else if (s==AppLifecycleState.resumed && _cameras.isNotEmpty) _startCamera(_camIdx);
=======
    if (s == AppLifecycleState.inactive || s == AppLifecycleState.paused) {
      _stopStream();
    } else if (s == AppLifecycleState.resumed && _cameras.isNotEmpty) {
      // Small delay lets the camera HAL fully release before we reopen it.
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _startCamera(_camIdx);
      });
    }
>>>>>>> Stashed changes
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopStream(); _cam?.dispose(); _tts?.stop();
    _pulseCtrl.dispose(); _letterCtrl.dispose(); _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: Stack(children: [
        _buildCameraView(),
        _buildGuideBox(),
        _buildTopGradient(),
        _buildTopBar(),
        _buildStatusBadge(),
        Positioned(bottom:0, left:0, right:0, child: _buildBottomPanel()),
      ])),
    );
  }

  Widget _buildCameraView() {
    if (!_hasPermission) {
      return Container(
        decoration: const BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF1a1a2e), Color(0xFF16213e)])),
        child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle),
              child: const Icon(Icons.camera_alt_outlined, color: Colors.white70, size: 56)),
            const SizedBox(height: 24),
            const Text('Camera Access Required',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Enable camera to detect sign language',
                style: TextStyle(color: Colors.white54, fontSize: 14)),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _requestAndInit,
              icon: const Icon(Icons.camera),
              label: const Text('Enable Camera'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667EEA),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            ),
          ])),
      );
    }
    if (_cam == null || !_cam!.value.isInitialized) {
      return Container(color: Colors.black,
          child: const Center(child: CircularProgressIndicator(color: Color(0xFF667EEA))));
    }
    return SizedBox.expand(child: FittedBox(fit: BoxFit.cover,
      child: SizedBox(
        width: _cam!.value.previewSize!.height,
        height: _cam!.value.previewSize!.width,
        child: CameraPreview(_cam!))));
  }

  Widget _buildGuideBox() {
    return Center(child: AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, __) => ScaleTransition(
        scale: _handFound ? const AlwaysStoppedAnimation(1.0) : _pulseAnim,
        child: AnimatedBuilder(
          animation: _glowAnim,
          builder: (_, __) => Container(
            width: 250, height: 250,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: _handFound
                    ? const Color(0xFF00E676)
                    : Colors.white.withOpacity(0.75),
                width: _handFound ? 3 : 2),
              boxShadow: [BoxShadow(
                color: _handFound
                    ? const Color(0xFF00E676).withOpacity(_glowAnim.value)
                    : Colors.white.withOpacity(0.08),
                blurRadius: _handFound ? 30 : 10, spreadRadius: 2)],
            ),
            child: _handFound ? null : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.back_hand_outlined,
                    color: Colors.white.withOpacity(0.6), size: 48),
                const SizedBox(height: 10),
                Text('Place hand here',
                    style: TextStyle(color: Colors.white.withOpacity(0.6),
                        fontSize: 13, letterSpacing: 0.5)),
              ]),
          ),
        ),
      ),
    ));
  }

  Widget _buildTopGradient() {
    return Positioned(top:0, left:0, right:0,
      child: Container(height: 120,
        decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.8), Colors.transparent]))));
  }

  Widget _buildTopBar() {
    return Positioned(top: 0, left: 0, right: 0,
      child: Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _GlassButton(icon: Icons.arrow_back_ios_new,
                onTap: () => Navigator.pop(context)),
            // Title badge
            Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: const Row(children: [
                Icon(Icons.sign_language, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text('PSL Detector', style: TextStyle(color: Colors.white,
                    fontSize: 14, fontWeight: FontWeight.w600)),
              ])),
            Row(children: [
              _GlassButton(
                  icon: _ttsOn ? Icons.volume_up : Icons.volume_off,
                  onTap: () => setState(() => _ttsOn = !_ttsOn),
                  active: _ttsOn),
              const SizedBox(width: 8),
              if (_cameras.length > 1)
                _GlassButton(icon: Icons.flip_camera_ios, onTap: _switchCam),
            ]),
          ])));
  }

  Widget _buildStatusBadge() {
    return Positioned(top: 72, left: 0, right: 0,
      child: Center(child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: _handFound
              ? const Color(0xFF00C853).withOpacity(0.85)
              : Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _handFound
              ? const Color(0xFF00C853) : Colors.white24),
          boxShadow: _handFound ? [BoxShadow(
              color: const Color(0xFF00C853).withOpacity(0.4), blurRadius: 16)] : [],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(duration: const Duration(milliseconds: 300),
            width: 8, height: 8,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _handFound ? Colors.white : Colors.white54)),
          const SizedBox(width: 8),
          Text(_status, style: TextStyle(
              color: _handFound ? Colors.white : Colors.white70,
              fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      )));
  }

  Widget _buildBottomPanel() {
    return Consumer<DetectionProvider>(
      builder: (ctx, p, _) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0f0f1a),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5),
              blurRadius: 20, offset: const Offset(0, -5))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Drag handle
          Container(margin: const EdgeInsets.only(top: 12),
              width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.white24,
                  borderRadius: BorderRadius.circular(2))),
<<<<<<< Updated upstream
=======
          const SizedBox(height: 12),
          // Current detection
          if (p.lastResult != null) _buildDetectionCard(p.lastResult!),
          const SizedBox(height: 12),
          // Word/Sentence display
          _buildTextDisplay(p),
          const SizedBox(height: 12),
          // Actions
          _buildActions(p),
          const SizedBox(height: 8),
          _buildPauseButton(p),
>>>>>>> Stashed changes
          const SizedBox(height: 16),
          // Current detection
          if (p.lastResult != null) ...[
            _buildLetterDisplay(p.lastResult!),
            const SizedBox(height: 14),
          ] else
            _buildIdlePlaceholder(),
          // Text output
          _buildTextBox(p),
          const SizedBox(height: 14),
          // Action buttons
          _buildActionRow(p),
          const SizedBox(height: 18),
        ]),
      ),
    );
  }

  Widget _buildLetterDisplay(DetectionResult r) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        // Animated Urdu letter
        ScaleTransition(scale: _letterAnim,
          child: Container(width: 80, height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: r.isHighConfidence
                      ? [const Color(0xFF00C853), const Color(0xFF00897B)]
                      : [const Color(0xFFFFAB00), const Color(0xFFFF6F00)]),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [BoxShadow(
                  color: (r.isHighConfidence
                      ? const Color(0xFF00C853) : const Color(0xFFFFAB00)).withOpacity(0.4),
                  blurRadius: 16, offset: const Offset(0, 4))]),
            child: Center(child: Text(r.urduLabel,
                style: const TextStyle(fontFamily: 'JameelNooriNastaleeq',
                    color: Colors.white, fontSize: 40),
<<<<<<< Updated upstream
                textDirection: TextDirection.rtl)))),
        const SizedBox(width: 16),
        // Info
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(r.romanLabel, style: const TextStyle(color: Colors.white,
                fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            // Confidence bar
            Row(children: [
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(value: r.confidence,
                    backgroundColor: Colors.white12,
                    color: r.confidenceColor, minHeight: 7))),
              const SizedBox(width: 8),
              Text(r.confidencePercent, style: TextStyle(color: r.confidenceColor,
                  fontSize: 12, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Container(width: 6, height: 6,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                      color: r.confidenceColor)),
              const SizedBox(width: 5),
              Text(r.isHighConfidence ? 'High confidence' : 'Medium confidence',
                  style: TextStyle(color: r.confidenceColor, fontSize: 11)),
            ]),
          ])),
        // Top 3 quick list
        Column(children: [
          for (int i = 0; i < 3 && i < r.allProbabilities.length; i++) ...[
            if (i > 0) const SizedBox(height: 4),
            _MiniLabel(
                label: i < ModelService.romanLabels.length
                    ? ModelService.romanLabels[i] : '?',
                pct: (r.allProbabilities[i] * 100).toStringAsFixed(0)),
          ],
=======
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
                        : r.isMediumConfidence
                            ? const Color(0xFFFFD600).withOpacity(0.1)
                            : const Color(0xFFFF5252).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Text(
                    r.isHighConfidence
                        ? '✓ High Confidence'
                        : r.isMediumConfidence ? '~ Medium' : '~ Low',
                    style: TextStyle(fontSize: 11,
                        color: r.isHighConfidence
                            ? const Color(0xFF00C853)
                            : r.isMediumConfidence
                                ? const Color(0xFFF9A825)
                                : const Color(0xFFFF5252),
                        fontWeight: FontWeight.w600)),
              ),
            ])),
>>>>>>> Stashed changes
        ]),
      ]));
  }

  Widget _buildIdlePlaceholder() {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(height: 80, padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.waving_hand, color: Colors.white24, size: 28),
          const SizedBox(width: 12),
          Column(mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Waiting for gesture...',
                style: TextStyle(color: Colors.white54, fontSize: 14)),
            Text('Frames: $_processed',
                style: const TextStyle(color: Colors.white30, fontSize: 10)),
          ]),
        ])));
  }

  Widget _buildTextBox(DetectionProvider p) {
    final text = p.fullText;
    return Container(margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1))),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${p.detectionCount} detections',
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
          const Text('Detected Text',
              style: TextStyle(color: Colors.white54, fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 8),
        Container(width: double.infinity, padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12)),
          child: Text(text.isEmpty ? '— — —' : text,
              style: const TextStyle(fontFamily: 'JameelNooriNastaleeq',
                  color: Colors.white, fontSize: 26, height: 1.4),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center)),
      ]));
  }

  Widget _buildActionRow(DetectionProvider p) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        _ActionBtn(icon: Icons.space_bar, label: 'Space',
            color: const Color(0xFF667EEA),
            onTap: p.addSpaceToWord),
        const SizedBox(width: 8),
        _ActionBtn(icon: Icons.backspace_outlined, label: 'Undo',
            color: const Color(0xFF9C27B0),
            onTap: p.undoLastLetter),
        const SizedBox(width: 8),
        _ActionBtn(icon: Icons.record_voice_over, label: 'Speak',
            color: const Color(0xFF00BCD4),
            onTap: () async {
              final t = p.fullText;
              if (t.isNotEmpty) await _tts?.speak(t);
            }),
        const SizedBox(width: 8),
        _ActionBtn(icon: Icons.clear_all, label: 'Clear',
            color: const Color(0xFFE91E63),
            onTap: () {
              p.clearAll();
              setState(() { _handFound=false; _status='Place your hand in the frame'; });
            }),
      ]));
  }
  Widget _buildPauseButton(DetectionProvider p) {
    final paused = p.detectionPaused;
    final color = paused ? const Color(0xFF00C853) : const Color(0xFFFF9800);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: p.toggleDetectionPause,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(paused ? Icons.play_arrow : Icons.pause, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              paused ? 'Resume AI Detection' : 'Pause AI Detection',
              style: TextStyle(color: color, fontSize: 12,
                  fontWeight: FontWeight.w700),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Small widgets ──────────────────────────────────────────────────────────────

class _GlassButton extends StatelessWidget {
  final IconData icon; final VoidCallback onTap; final bool active;
  const _GlassButton({required this.icon, required this.onTap, this.active=true});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Container(padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8)]),
      child: Icon(icon, color: active ? Colors.white : Colors.white38, size: 20)));
}

class _ActionBtn extends StatelessWidget {
  final IconData icon; final String label;
  final Color color; final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label,
      required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(onTap: onTap,
      child: Container(padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.18),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.35))),
        child: Column(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 10,
              fontWeight: FontWeight.w700)),
        ]))));
}

class _MiniLabel extends StatelessWidget {
  final String label, pct;
  const _MiniLabel({required this.label, required this.pct});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8)),
    child: Text('$label $pct%',
        style: const TextStyle(color: Colors.white54, fontSize: 9)));
}
