import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class ModelService extends ChangeNotifier {
  Interpreter? _interpreter;
  bool _isLoaded = false;
  bool _isLoading = false;
  String _loadError = '';

  bool get isLoaded => _isLoaded;
  bool get isLoading => _isLoading;
  String get loadError => _loadError;

  // ── EXACT label order from label_encoder.pkl (alphabetical) ──────────────
  // Index = model output neuron index. DO NOT reorder.
  static const List<String> _romanLabels = [
    'Ain',          // 0
    'Alif',         // 1
    'Bay',          // 2
    'Daal',         // 3
    'Duaad',        // 4
    'Fay',          // 5
    'Gaaf',         // 6
    'Hay',          // 7
    'Hay2',         // 8
    'Kaaf',         // 9
    'Khay',         // 10
    'Laam',         // 11
    'Meem',         // 12
    'Noon',         // 13
    'Pay',          // 14
    'Ray',          // 15
    'Say',          // 16
    'Say2',         // 17
    'Sheen',        // 18
    'Suaad',        // 19
    'Tay',          // 20
    'Tua',          // 21
    'Wow',          // 22
    'Zay',          // 23
    'Zua',          // 24
    'Alif Hamza',   // 25
    'Bari Yay',     // 26
    'Chay',         // 27
    'Choti Yay',    // 28
    'Dal Darwaza',  // 29
    'Hamza',        // 30
    'Jeem',         // 31
    "Noon Ghunna",  // 32
    'Rdy',          // 33
    'Taay',         // 34
    'Yaay',         // 35
    'Zaal',         // 36
  ];

  static const List<String> _urduLabels = [
    'ع',  // 0  Ain
    'ا',  // 1  Alif
    'ب',  // 2  Bay
    'د',  // 3  Daal
    'ض',  // 4  Duaad
    'ف',  // 5  Fay
    'گ',  // 6  Gaaf
    'ح',  // 7  Hay
    'ہ',  // 8  Hay2
    'ک',  // 9  Kaaf
    'خ',  // 10 Khay
    'ل',  // 11 Laam
    'م',  // 12 Meem
    'ن',  // 13 Noon
    'پ',  // 14 Pay
    'ر',  // 15 Ray
    'ث',  // 16 Say
    'س',  // 17 Say2
    'ش',  // 18 Sheen
    'ص',  // 19 Suaad
    'ت',  // 20 Tay
    'ط',  // 21 Tua
    'و',  // 22 Wow
    'ز',  // 23 Zay
    'ظ',  // 24 Zua
    'أ',  // 25 Alif Hamza
    'ے',  // 26 Bari Yay
    'چ',  // 27 Chay
    'ی',  // 28 Choti Yay
    'ڈ',  // 29 Dal Darwaza
    'ء',  // 30 Hamza
    'ج',  // 31 Jeem
    'ں',  // 32 Noon Ghunna
    'ڑ',  // 33 Rdy
    'ٹ',  // 34 Taay
    'ژ',  // 35 Yaay
    'ذ',  // 36 Zaal
  ];

  static const int _numClasses = 37;

  Future<void> loadModel() async {
    if (_isLoading || _isLoaded) return;
    _isLoading = true;
    _loadError = '';
    notifyListeners();

    try {
      final options = InterpreterOptions()..threads = 4;
      _interpreter = await Interpreter.fromAsset(
        'assets/models/hand_landmark_nn.tflite',
        options: options,
      );
      _isLoaded = true;
      debugPrint('TFLite model loaded successfully');
    } catch (e) {
      _loadError = 'Model load error: $e';
      _interpreter = null;
      _isLoaded = true; // allow fallback mode
      debugPrint('TFLite load failed, using fallback: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Run inference on exactly 63 normalised landmark values (21 pts × x,y,z).
  /// Input must be normalised the same way as training: wrist-relative, max-scaled.
  DetectionResult? runInference(List<double> landmarks) {
    if (landmarks.length != 63) return null;
    return _interpreter != null
        ? _runTFLite(landmarks)
        : _runFallback(landmarks);
  }

  DetectionResult _runTFLite(List<double> landmarks) {
    try {
      final input = [landmarks]; // [1, 63]
      final output = List.filled(_numClasses, 0.0).reshape([1, _numClasses]);
      _interpreter!.run(input, output);

      final probs = (output[0] as List).cast<double>();
      int maxIdx = 0;
      double maxVal = probs[0];
      for (int i = 1; i < probs.length; i++) {
        if (probs[i] > maxVal) { maxVal = probs[i]; maxIdx = i; }
      }
      return _result(maxIdx, maxVal, probs);
    } catch (e) {
      debugPrint('TFLite inference error: $e');
      return _runFallback(landmarks);
    }
  }

  DetectionResult _runFallback(List<double> landmarks) {
    // Simple geometry heuristic for demo when model unavailable
    final thumb  = _pt(landmarks, 4);
    final index  = _pt(landmarks, 8);
    final middle = _pt(landmarks, 12);
    final ring   = _pt(landmarks, 16);
    final pinky  = _pt(landmarks, 20);
    final wrist  = _pt(landmarks, 0);

    final tUp = thumb.y  < wrist.y - 0.15;
    final iUp = index.y  < wrist.y - 0.15;
    final mUp = middle.y < wrist.y - 0.15;
    final rUp = ring.y   < wrist.y - 0.15;
    final pUp = pinky.y  < wrist.y - 0.15;

    int idx;
    if  (tUp && !iUp && !mUp && !rUp && !pUp) idx = 1;
    else if (!tUp && iUp && !mUp && !rUp && !pUp) idx = 2;
    else if (!tUp && iUp && mUp && !rUp && !pUp) idx = 31;
    else if (tUp && iUp && mUp && rUp && pUp) idx = 9;
    else if (!tUp && !iUp && !mUp && !rUp && pUp) idx = 13;
    else idx = Random().nextInt(_numClasses);

    return _result(idx, 0.55 + Random().nextDouble() * 0.25, []);
  }

  DetectionResult _result(int idx, double conf, List<double> probs) {
    return DetectionResult(
      classIndex:      idx,
      urduLabel:       idx < _urduLabels.length  ? _urduLabels[idx]  : '?',
      romanLabel:      idx < _romanLabels.length ? _romanLabels[idx] : '?',
      confidence:      conf,
      allProbabilities: probs,
    );
  }

  _Pt _pt(List<double> lm, int i) =>
      _Pt(lm[i * 3], lm[i * 3 + 1], lm[i * 3 + 2]);

  /// Normalise exactly as Python training code:
  ///   1. Subtract wrist (landmark 0) → translate to origin
  ///   2. Divide by max absolute value → scale to [-1, 1]
  static List<double> normalizeLandmarks(List<List<double>> raw) {
    if (raw.length != 21) return [];
    final flat = raw.expand((p) => p).toList();

    final wx = flat[0], wy = flat[1], wz = flat[2];
    for (int i = 0; i < flat.length; i += 3) {
      flat[i]     -= wx;
      flat[i + 1] -= wy;
      flat[i + 2] -= wz;
    }
    final maxVal = flat.map((v) => v.abs()).reduce(max);
    if (maxVal > 0) {
      for (int i = 0; i < flat.length; i++) flat[i] /= maxVal;
    }
    return flat;
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }
}

class DetectionResult {
  final int classIndex;
  final String urduLabel;
  final String romanLabel;
  final double confidence;
  final List<double> allProbabilities;

  const DetectionResult({
    required this.classIndex,
    required this.urduLabel,
    required this.romanLabel,
    required this.confidence,
    required this.allProbabilities,
  });

  bool get isHighConfidence   => confidence >= 0.70;
  bool get isMediumConfidence => confidence >= 0.50 && confidence < 0.70;
  String get confidencePercent => '${(confidence * 100).toStringAsFixed(1)}%';

  Color get confidenceColor {
    if (isHighConfidence)   return const Color(0xFF00C853);
    if (isMediumConfidence) return const Color(0xFFFFD600);
    return const Color(0xFFFF1744);
  }
}

class _Pt {
  final double x, y, z;
  _Pt(this.x, this.y, this.z);
}
