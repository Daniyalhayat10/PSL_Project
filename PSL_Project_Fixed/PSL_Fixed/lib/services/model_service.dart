import 'dart:math';
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class ModelService extends ChangeNotifier {
  Interpreter? _palmInterpreter;
  Interpreter? _landmarkInterpreter;
  Interpreter? _classifierInterpreter;

  bool _isLoaded = false;
  bool _isLoading = false;
  String _loadError = '';

  bool get isLoaded => _isLoaded;
  bool get isLoading => _isLoading;
  String get loadError => _loadError;

  static const int _palmInputSize     = 192;
  static const int _landmarkInputSize = 224;
  static const double _palmThreshold  = 0.05; // very permissive
  static const double _handThreshold  = 0.01; // basically always try

  // Pre-computed MediaPipe palm-detection anchors (strides [8,16,16,16], 2/cell)
  late final List<List<double>> _anchors = _buildAnchors();

  // ── Labels ─────────────────────────────────────────────────────────────────
  static const List<String> romanLabels = [
    'Ain','Alif','Bay','Daal','Duaad','Fay','Gaaf','Hay','Hay2',
    'Kaaf','Khay','Laam','Meem','Noon','Pay','Ray','Say','Say2',
    'Sheen','Suaad','Tay','Tua','Wow','Zay','Zua',
    'alif hamza','bari yaay','chay','choti yaay','dal drwaza',
    'hamza','jeem',"noon ghun'na",'rdy','taay','yaay','zaal',
  ];
  static const List<String> urduLabels = [
    'ع','ا','ب','د','ض','ف','گ','ح','ہ',
    'ک','خ','ل','م','ن','پ','ر','ث','س',
    'ش','ص','ت','ط','و','ز','ظ',
    'أ','ے','چ','ی','ڈ',
    'ء','ج','ں','ڑ','ٹ','ی','ذ',
  ];

  // ── Load ───────────────────────────────────────────────────────────────────
  Future<void> loadModel() async {
    if (_isLoading || _isLoaded) return;
    _isLoading = true; _loadError = '';
    notifyListeners();
    try {
      final opts = InterpreterOptions()..threads = 2;
      _palmInterpreter = await Interpreter.fromAsset(
          'assets/models/palm_detection_lite.tflite', options: opts);
      _landmarkInterpreter = await Interpreter.fromAsset(
          'assets/models/hand_landmark_lite.tflite', options: opts);
      _classifierInterpreter = await Interpreter.fromAsset(
          'assets/models/hand_landmark_nn.tflite', options: opts);
      debugPrint('✅ All 3 models loaded. Anchors: ${_anchors.length}');
      _isLoaded = true;
    } catch (e) {
      _loadError = e.toString();
      debugPrint('❌ Load failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Main pipeline ──────────────────────────────────────────────────────────
  DetectionResult? processFrame(img.Image frame) {
    if (!_isLoaded) return null;

    // Stage 1: palm detection → get hand crop
    final crop = _detectAndCrop(frame);
    if (crop == null) return null;

    // Stage 2: hand landmark extraction
    final lm = _extractLandmarks(crop);
    if (lm == null) return null;

    // Stage 3: normalise (match Python training)
    final norm = _normaliseLandmarks(lm);
    if (norm.isEmpty) return null;

    // Stage 4: classify
    return _classify(norm);
  }

  // ── Stage 1: Palm detection ────────────────────────────────────────────────
  img.Image? _detectAndCrop(img.Image frame) {
    try {
      // Resize frame to 192×192 for palm detector
      final palm192 = img.copyResize(
          _squareCrop(frame), width: _palmInputSize, height: _palmInputSize);

      final input = _buildInput(palm192, _palmInputSize);

      final regShape  = _palmInterpreter!.getOutputTensor(0).shape; // [1,2016,18]
      final scShape   = _palmInterpreter!.getOutputTensor(1).shape; // [1,2016,1]
      final regSz = regShape.reduce((a,b)=>a*b);
      final scSz  = scShape .reduce((a,b)=>a*b);

      final outputs = <int,Object>{
        0: List.filled(regSz, 0.0).reshape(regShape),
        1: List.filled(scSz,  0.0).reshape(scShape),
      };
      _palmInterpreter!.runForMultipleInputs([input], outputs);

      final regs   = _flatten(outputs[0]!); // 2016 * 18
      final scores = _flatten(outputs[1]!); // 2016

      // Find best detection
      double bestScore = -1e9;
      int    bestIdx   = 0;
      for (int i = 0; i < scores.length; i++) {
        final s = 1.0 / (1.0 + exp(-scores[i])); // sigmoid
        if (s > bestScore) { bestScore = s; bestIdx = i; }
      }
      debugPrint('🖐 Palm score: ${bestScore.toStringAsFixed(4)} idx=$bestIdx');

      // Decode bounding box using anchor
      final anchor = _anchors[bestIdx];
      final reg    = regs.sublist(bestIdx * 18, bestIdx * 18 + 4);

      // Decoded box in normalised [0,1] of 192-space
      final cx = anchor[0] + reg[0] / _palmInputSize;
      final cy = anchor[1] + reg[1] / _palmInputSize;
      final bw = (reg[2].abs() / _palmInputSize).clamp(0.05, 1.0);
      final bh = (reg[3].abs() / _palmInputSize).clamp(0.05, 1.0);

      // Add 45% padding
      const pad = 0.45;
      final x1 = ((cx - bw * (0.5 + pad)) * frame.width ).round().clamp(0, frame.width);
      final y1 = ((cy - bh * (0.5 + pad)) * frame.height).round().clamp(0, frame.height);
      final x2 = ((cx + bw * (0.5 + pad)) * frame.width ).round().clamp(0, frame.width);
      final y2 = ((cy + bh * (0.5 + pad)) * frame.height).round().clamp(0, frame.height);
      final cw = (x2 - x1).clamp(30, frame.width);
      final ch = (y2 - y1).clamp(30, frame.height);

      debugPrint('🖐 Crop: x=$x1 y=$y1 w=$cw h=$ch (palm score=${bestScore.toStringAsFixed(3)})');

      // Use detection crop if score reasonable, else centre crop
      img.Image cropped;
      if (bestScore > _palmThreshold && cw > 30 && ch > 30) {
        cropped = img.copyCrop(frame, x: x1, y: y1, width: cw, height: ch);
      } else {
        cropped = _squareCrop(frame); // fallback
      }

      return img.copyResize(cropped,
          width: _landmarkInputSize, height: _landmarkInputSize);
    } catch (e) {
      debugPrint('❌ Palm detect: $e');
      return img.copyResize(_squareCrop(frame),
          width: _landmarkInputSize, height: _landmarkInputSize);
    }
  }

  // ── Stage 2: Hand landmark model ───────────────────────────────────────────
  List<List<double>>? _extractLandmarks(img.Image img224) {
    try {
      final input = _buildInput(img224, _landmarkInputSize);
      final outputs = <int,Object>{
        0: List.filled(63, 0.0).reshape([1,63]),  // raw pixel coords
        1: List.filled(1,  0.0).reshape([1,1]),   // hand flag
        2: List.filled(1,  0.0).reshape([1,1]),   // handedness
        3: List.filled(63, 0.0).reshape([1,63]),  // normalised (world)
      };
      _landmarkInterpreter!.runForMultipleInputs([input], outputs);

      final flag = ((outputs[1] as List)[0] as List)[0] as double;
      debugPrint('🖐 Hand flag: ${flag.toStringAsFixed(4)}');
      if (flag < _handThreshold) return null;

      // Use output[0] — raw pixel coords (0–224), divide by 224 → [0,1]
      final raw = _flatten(outputs[0]!);
      if (raw.length < 63) return null;

      return List.generate(21, (i) => [
        raw[i*3]   / _landmarkInputSize,
        raw[i*3+1] / _landmarkInputSize,
        raw[i*3+2] / _landmarkInputSize,
      ]);
    } catch (e) {
      debugPrint('❌ Landmark: $e');
      return null;
    }
  }

  // ── Stage 3: Normalise (must match Python training) ────────────────────────
  List<double> _normaliseLandmarks(List<List<double>> pts) {
    final flat = pts.expand((p)=>p).toList();
    // Wrist-relative
    final wx=flat[0], wy=flat[1], wz=flat[2];
    for (int i=0;i<flat.length;i+=3) { flat[i]-=wx; flat[i+1]-=wy; flat[i+2]-=wz; }
    // Max-abs scale
    double mx=0; for (final v in flat) { if(v.abs()>mx) mx=v.abs(); }
    if (mx>0) { for (int i=0;i<flat.length;i++) flat[i]/=mx; }
    return flat;
  }

  // ── Stage 4: Classify ──────────────────────────────────────────────────────
  DetectionResult? _classify(List<double> lm) {
    try {
      final n = _classifierInterpreter!.getOutputTensor(0).shape.last;
      final out = List.filled(n,0.0).reshape([1,n]);
      _classifierInterpreter!.run([lm], out);
      final probs = (out[0] as List).cast<double>();
      int best=0; double bv=probs[0];
      for (int i=1;i<probs.length;i++) { if(probs[i]>bv){bv=probs[i];best=i;} }
      debugPrint('🔍 ${best<romanLabels.length?romanLabels[best]:best}  (${(bv*100).toStringAsFixed(1)}%)');
      return DetectionResult(
        classIndex: best,
        urduLabel:  best<urduLabels.length  ? urduLabels[best]  : '?',
        romanLabel: best<romanLabels.length ? romanLabels[best] : '?',
        confidence: bv, allProbabilities: probs,
      );
    } catch(e) { debugPrint('❌ Classify: $e'); return null; }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  List<List<List<List<double>>>> _buildInput(img.Image src, int size) {
    return List.generate(1, (_) =>
      List.generate(size, (y) =>
        List.generate(size, (x) {
          final p = src.getPixel(x, y);
          // [0,1] normalisation — MediaPipe standard
          return [p.r/255.0, p.g/255.0, p.b/255.0];
        })
      )
    );
  }

  img.Image _squareCrop(img.Image src) {
    final s = min(src.width, src.height);
    return img.copyCrop(src,
        x:(src.width-s)~/2, y:(src.height-s)~/2, width:s, height:s);
  }

  List<double> _flatten(Object o) {
    if (o is List) return o.expand((e)=>_flatten(e)).toList();
    if (o is double) return [o];
    if (o is num) return [o.toDouble()];
    return [];
  }

  /// Generate MediaPipe palm-detection anchors once at startup
  List<List<double>> _buildAnchors() {
    final anchors = <List<double>>[];
    const strides = [8, 16, 16, 16];
    const size    = 192.0;
    for (final stride in strides) {
      final rows = (size / stride).ceil();
      final cols = (size / stride).ceil();
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          final cx = (c + 0.5) / cols;
          final cy = (r + 0.5) / rows;
          anchors.add([cx, cy]);  // 2 anchors per cell
          anchors.add([cx, cy]);
        }
      }
    }
    return anchors;
  }

  @override
  void dispose() {
    _palmInterpreter?.close();
    _landmarkInterpreter?.close();
    _classifierInterpreter?.close();
    super.dispose();
  }
}

// ─── Result ───────────────────────────────────────────────────────────────────
class DetectionResult {
  final int classIndex;
  final String urduLabel;
  final String romanLabel;
  final double confidence;
  final List<double> allProbabilities;

  const DetectionResult({
    required this.classIndex, required this.urduLabel,
    required this.romanLabel, required this.confidence,
    required this.allProbabilities,
  });

  bool get isHighConfidence   => confidence >= 0.60;
  bool get isMediumConfidence => confidence >= 0.35 && confidence < 0.60;
  String get confidencePercent => '${(confidence*100).toStringAsFixed(1)}%';

  Color get confidenceColor {
    if (isHighConfidence)   return const Color(0xFF00C853);
    if (isMediumConfidence) return const Color(0xFFFFAB00);
    return const Color(0xFFFF5252);
  }
}
