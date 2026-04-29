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

  // ── Label order must match training label_encoder.pkl (alphabetical) ───────
  // 37 classes matching classes.txt exactly
  static const List<String> romanLabels = [
    'Ain',         // 0
    'Alif',        // 1
    'Bay',         // 2
    'Daal',        // 3
    'Duaad',       // 4
    'Fay',         // 5
    'Gaaf',        // 6
    'Hay',         // 7
    'Hay2',        // 8
    'Kaaf',        // 9
    'Khay',        // 10
    'Laam',        // 11
    'Meem',        // 12
    'Noon',        // 13
    'Pay',         // 14
    'Ray',         // 15
    'Say',         // 16
    'Say2',        // 17
    'Sheen',       // 18
    'Suaad',       // 19
    'Tay',         // 20
    'Tua',         // 21
    'Wow',         // 22
    'Zay',         // 23
    'Zua',         // 24
    'Alif Hamza',  // 25
    'Bari Yay',    // 26
    'Chay',        // 27
    'Choti Yay',   // 28
    'Dal Darwaza', // 29
    'Hamza',       // 30
    'Jeem',        // 31
    'Noon Ghunna', // 32
    'Rdy',         // 33
    'Taay',        // 34
    'Yaay',        // 35
    'Zaal',        // 36
  ];

  static const List<String> urduLabels = [
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
    'ی',  // 35 Yaay  (same glyph as Choti Yay in many fonts)
    'ذ',  // 36 Zaal
  ];

  // NOTE: If model outputs 36 classes, change this to 36.
  // Check by running: interpreter.getOutputTensor(0).shape
  static const int numClasses = 37;

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

      // Log actual model shapes so you can verify
      final inputShape = _interpreter!.getInputTensor(0).shape;
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      debugPrint('✅ Model loaded. Input: $inputShape  Output: $outputShape');

      _isLoaded = true;
    } catch (e) {
      _loadError = 'Model load error: $e';
      _isLoaded = false;
      debugPrint('❌ TFLite load failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Run inference on exactly 63 normalised landmark values (21 pts × x,y,z).
  /// Returns null if model not loaded or inference fails — NO random fallback.
  DetectionResult? runInference(List<double> landmarks) {
    if (!_isLoaded || _interpreter == null) return null;
    if (landmarks.length != 63) {
      debugPrint('❌ Expected 63 landmarks, got ${landmarks.length}');
      return null;
    }
    return _runTFLite(landmarks);
  }

  DetectionResult? _runTFLite(List<double> landmarks) {
    try {
      // Determine actual output size from model
      final outputTensor = _interpreter!.getOutputTensor(0);
      final actualClasses = outputTensor.shape.last;

      final input = [landmarks]; // shape [1, 63]
      final output = List.filled(actualClasses, 0.0).reshape([1, actualClasses]);
      _interpreter!.run(input, output);

      final probs = (output[0] as List).cast<double>();
      int maxIdx = 0;
      double maxVal = probs[0];
      for (int i = 1; i < probs.length; i++) {
        if (probs[i] > maxVal) {
          maxVal = probs[i];
          maxIdx = i;
        }
      }

      debugPrint(
          '🔍 Predicted: ${maxIdx < romanLabels.length ? romanLabels[maxIdx] : maxIdx}'
          ' (${(maxVal * 100).toStringAsFixed(1)}%)');

      return _buildResult(maxIdx, maxVal, probs);
    } catch (e) {
      debugPrint('❌ TFLite inference error: $e');
      return null;
    }
  }

  DetectionResult _buildResult(int idx, double conf, List<double> probs) {
    return DetectionResult(
      classIndex: idx,
      urduLabel: idx < urduLabels.length ? urduLabels[idx] : '?',
      romanLabel: idx < romanLabels.length ? romanLabels[idx] : 'Unknown',
      confidence: conf,
      allProbabilities: probs,
    );
  }

  /// Normalise landmarks exactly as Python training code:
  ///   1. Subtract wrist (landmark 0) → translate to wrist-relative
  ///   2. Divide by max absolute value → scale to [-1, 1]
  static List<double> normalizeLandmarks(List<List<double>> raw) {
    if (raw.length != 21) {
      debugPrint('❌ normalizeLandmarks: expected 21 points, got ${raw.length}');
      return [];
    }

    final flat = raw.expand((p) => p).toList();

    // Step 1: wrist-relative
    final wx = flat[0], wy = flat[1], wz = flat[2];
    for (int i = 0; i < flat.length; i += 3) {
      flat[i] -= wx;
      flat[i + 1] -= wy;
      flat[i + 2] -= wz;
    }

    // Step 2: max-scale normalisation
    final maxVal = flat.map((v) => v.abs()).reduce(max);
    if (maxVal > 0) {
      for (int i = 0; i < flat.length; i++) {
        flat[i] /= maxVal;
      }
    }

    return flat;
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }
}

// ─── Result model ─────────────────────────────────────────────────────────────

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

  bool get isHighConfidence => confidence >= 0.70;
  bool get isMediumConfidence => confidence >= 0.50 && confidence < 0.70;
  String get confidencePercent => '${(confidence * 100).toStringAsFixed(1)}%';

  Color get confidenceColor {
    if (isHighConfidence) return const Color(0xFF00C853);
    if (isMediumConfidence) return const Color(0xFFFFD600);
    return const Color(0xFFFF1744);
  }
}
