import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class ModelService extends ChangeNotifier {
  Interpreter? _classifierInterpreter;

  bool _isLoaded = false;
  bool _isLoading = false;
  String _loadError = '';

  bool get isLoaded => _isLoaded;
  bool get isLoading => _isLoading;
  String get loadError => _loadError;

  static const MethodChannel _channel = MethodChannel('psl/handlandmark');

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

      debugPrint('⏳ Loading hand_landmark_nn.tflite ...');
      _classifierInterpreter = await Interpreter.fromAsset(
        'assets/models/hand_landmark_nn.tflite', options: opts);
      debugPrint('✅ Classifier: '
          'in=${_classifierInterpreter!.getInputTensor(0).shape} '
          'out=${_classifierInterpreter!.getOutputTensor(0).shape}');

      _isLoaded = true;
    } catch (e) {
      _loadError = e.toString();
      debugPrint('❌ Load failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sends raw YUV planes to the native MediaPipe hand landmarker, then
  /// classifies the returned 63 landmark coordinates with the TFLite NN.
  Future<DetectionResult?> processYuv({
    required int width,
    required int height,
    required Uint8List yPlane,
    required Uint8List uPlane,
    required Uint8List vPlane,
    required int yStride,
    required int uvStride,
    required int uvPixelStride,
  }) async {
    if (!_isLoaded) return null;
    try {
      final dynamic raw = await _channel.invokeMethod('getLandmarks', {
        'width':         width,
        'height':        height,
        'yPlane':        yPlane,
        'uPlane':        uPlane,
        'vPlane':        vPlane,
        'yStride':       yStride,
        'uvStride':      uvStride,
        'uvPixelStride': uvPixelStride,
      });
      if (raw == null) return null;
      final landmarks = (raw as List).cast<double>();
      if (landmarks.length < 63) return null;
      return _classify(_normalize(landmarks));
    } catch (e) {
      debugPrint('❌ processYuv: $e');
      return null;
    }
  }

  List<double> _normalize(List<double> flat) {
    final r = List<double>.from(flat);
    final wx = r[0], wy = r[1], wz = r[2];
    for (int i = 0; i < r.length; i += 3) {
      r[i] -= wx; r[i + 1] -= wy; r[i + 2] -= wz;
    }
    double mx = 0;
    for (final v in r) { if (v.abs() > mx) mx = v.abs(); }
    if (mx > 0) { for (int i = 0; i < r.length; i++) r[i] /= mx; }
    return r;
  }

  // ── Classify ───────────────────────────────────────────────────────────────
  DetectionResult? _classify(List<double> lm) {
    try {
      final outShape = _classifierInterpreter!.getOutputTensor(0).shape;
      final n = outShape.last;
      final input  = [lm];
      final output = List.filled(n, 0.0).reshape([1, n]);
      _classifierInterpreter!.run(input, output);

      final probs = (output[0] as List).cast<double>();
      int best = 0; double bv = probs[0];
      for (int i = 1; i < probs.length; i++) {
        if (probs[i] > bv) { bv = probs[i]; best = i; }
      }
      debugPrint('🔍 ${best < romanLabels.length ? romanLabels[best] : best}'
          '  (${(bv * 100).toStringAsFixed(1)}%)');

      return DetectionResult(
        classIndex:       best,
        urduLabel:        best < urduLabels.length  ? urduLabels[best]  : '?',
        romanLabel:       best < romanLabels.length ? romanLabels[best] : '?',
        confidence:       bv,
        allProbabilities: probs,
      );
    } catch(e) { debugPrint('❌ Classify: $e'); return null; }
  }

  @override
  void dispose() {
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
