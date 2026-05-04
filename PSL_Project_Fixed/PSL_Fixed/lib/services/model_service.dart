import 'dart:math';
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

/// Hand landmark model tensor layout (verified by inspection):
///   Input  [0]: [1, 224, 224, 3]  float32  values 0–1
///   Output [0]: Identity   [1, 63]  raw pixel coords (0–224 range)  ← DO NOT USE
///   Output [1]: Identity_1 [1,  1]  hand presence score (0–1)
///   Output [2]: Identity_2 [1,  1]  handedness (left/right)
///   Output [3]: Identity_3 [1, 63]  NORMALISED landmarks ← USE THIS
class ModelService extends ChangeNotifier {
  Interpreter? _landmarkInterpreter;
  Interpreter? _classifierInterpreter;

  bool _isLoaded = false;
  bool _isLoading = false;
  String _loadError = '';

  bool get isLoaded => _isLoaded;
  bool get isLoading => _isLoading;
  String get loadError => _loadError;

  static const int _inputSize = 224;

  // Lowered threshold — blank image gives 0.003, real hand should be >> 0.05
  static const double _handPresenceThreshold = 0.05;

  // ── Labels — exact order from classes.txt ──────────────────────────────────
  static const List<String> romanLabels = [
    'Ain', 'Alif', 'Bay', 'Daal', 'Duaad', 'Fay', 'Gaaf', 'Hay', 'Hay2',
    'Kaaf', 'Khay', 'Laam', 'Meem', 'Noon', 'Pay', 'Ray', 'Say', 'Say2',
    'Sheen', 'Suaad', 'Tay', 'Tua', 'Wow', 'Zay', 'Zua',
    'alif hamza', 'bari yaay', 'chay', 'choti yaay', 'dal drwaza',
    'hamza', 'jeem', "noon ghun'na", 'rdy', 'taay', 'yaay', 'zaal',
  ];

  static const List<String> urduLabels = [
    'ع', 'ا', 'ب', 'د', 'ض', 'ف', 'گ', 'ح', 'ہ',
    'ک', 'خ', 'ل', 'م', 'ن', 'پ', 'ر', 'ث', 'س',
    'ش', 'ص', 'ت', 'ط', 'و', 'ز', 'ظ',
    'أ', 'ے', 'چ', 'ی', 'ڈ',
    'ء', 'ج', 'ں', 'ڑ', 'ٹ', 'ی', 'ذ',
  ];

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> loadModel() async {
    if (_isLoading || _isLoaded) return;
    _isLoading = true;
    _loadError = '';
    notifyListeners();

    try {
      final opts = InterpreterOptions()..threads = 2;

      _landmarkInterpreter = await Interpreter.fromAsset(
        'assets/models/hand_landmark_lite.tflite',
        options: opts,
      );

      _classifierInterpreter = await Interpreter.fromAsset(
        'assets/models/hand_landmark_nn.tflite',
        options: opts,
      );

      // Log verified tensor layout
      final numOut = _landmarkInterpreter!.getOutputTensors().length;
      debugPrint('✅ Landmark model loaded. Output count: $numOut');
      for (int i = 0; i < numOut; i++) {
        debugPrint(
            '   out[$i]: ${_landmarkInterpreter!.getOutputTensor(i).shape}');
      }
      debugPrint('✅ Classifier loaded. '
          'in=${_classifierInterpreter!.getInputTensor(0).shape} '
          'out=${_classifierInterpreter!.getOutputTensor(0).shape}');

      _isLoaded = true;
    } catch (e) {
      _loadError = e.toString();
      _isLoaded = false;
      debugPrint('❌ Model load failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Main entry ─────────────────────────────────────────────────────────────

  DetectionResult? processFrame(img.Image frame) {
    if (!_isLoaded) return null;

    // Crop largest central square and resize to 224×224
    final cropped = _centerCropAndResize(frame);

    // Stage 1: extract landmarks from hand image
    final landmarkResult = _runLandmarkModel(cropped);
    if (landmarkResult == null) return null;

    // Stage 2: classify letter from landmarks
    return _runClassifier(landmarkResult);
  }

  // ── Landmark model ─────────────────────────────────────────────────────────

  List<double>? _runLandmarkModel(img.Image img224) {
    try {
      // Build [1, 224, 224, 3] float32 input — values in [0, 1]
      final input = List.generate(
        1,
        (_) => List.generate(
          _inputSize,
          (y) => List.generate(
            _inputSize,
            (x) {
              final p = img224.getPixel(x, y);
              return [p.r / 255.0, p.g / 255.0, p.b / 255.0];
            },
          ),
        ),
      );

      // Allocate all 4 outputs with correct shapes
      // [1,63]  [1,1]  [1,1]  [1,63]
      final outputs = <int, Object>{
        0: List.filled(63, 0.0).reshape([1, 63]),   // raw pixel coords
        1: List.filled(1,  0.0).reshape([1, 1]),    // hand presence
        2: List.filled(1,  0.0).reshape([1, 1]),    // handedness
        3: List.filled(63, 0.0).reshape([1, 63]),   // normalised landmarks ✅
      };

      _landmarkInterpreter!.runForMultipleInputs([input], outputs);

      // Read hand presence score from output[1]
      final handScore = ((outputs[1] as List)[0] as List)[0] as double;
      debugPrint('🖐 Hand presence: ${handScore.toStringAsFixed(4)}');

      if (handScore < _handPresenceThreshold) {
        return null; // no hand detected
      }

      // Read NORMALISED landmarks from output[3] — already in correct scale
      final normLandmarks = _flattenToDouble(outputs[3]!);
      if (normLandmarks.length < 63) {
        debugPrint('⚠️ norm landmarks too short: ${normLandmarks.length}');
        return null;
      }

      // Apply same normalisation as Python training code
      // (wrist-relative + max-scale) on the normalised coords
      return _normalizeLandmarks(normLandmarks.sublist(0, 63));
    } catch (e) {
      debugPrint('❌ Landmark model error: $e');
      return null;
    }
  }

  // ── Normalise (matches Python training exactly) ────────────────────────────

  List<double> _normalizeLandmarks(List<double> flat) {
    if (flat.length < 63) return [];

    final result = List<double>.from(flat);

    // Step 1: wrist-relative (subtract landmark 0 = wrist)
    final wx = result[0], wy = result[1], wz = result[2];
    for (int i = 0; i < result.length; i += 3) {
      result[i]     -= wx;
      result[i + 1] -= wy;
      result[i + 2] -= wz;
    }

    // Step 2: max-abs scale → [-1, 1]
    double maxVal = 0;
    for (final v in result) {
      if (v.abs() > maxVal) maxVal = v.abs();
    }
    if (maxVal > 0) {
      for (int i = 0; i < result.length; i++) result[i] /= maxVal;
    }

    return result;
  }

  // ── Classifier ─────────────────────────────────────────────────────────────

  DetectionResult? _runClassifier(List<double> landmarks) {
    try {
      final outShape   = _classifierInterpreter!.getOutputTensor(0).shape;
      final numClasses = outShape.last;

      final input  = [landmarks];
      final output = List.filled(numClasses, 0.0).reshape([1, numClasses]);

      _classifierInterpreter!.run(input, output);

      final probs  = (output[0] as List).cast<double>();
      int bestIdx  = 0;
      double bestV = probs[0];
      for (int i = 1; i < probs.length; i++) {
        if (probs[i] > bestV) { bestV = probs[i]; bestIdx = i; }
      }

      debugPrint('🔍 ${bestIdx < romanLabels.length ? romanLabels[bestIdx] : bestIdx}'
          '  (${(bestV * 100).toStringAsFixed(1)}%)');

      return DetectionResult(
        classIndex:       bestIdx,
        urduLabel:        bestIdx < urduLabels.length  ? urduLabels[bestIdx]  : '?',
        romanLabel:       bestIdx < romanLabels.length ? romanLabels[bestIdx] : 'Unknown',
        confidence:       bestV,
        allProbabilities: probs,
      );
    } catch (e) {
      debugPrint('❌ Classifier error: $e');
      return null;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  img.Image _centerCropAndResize(img.Image src) {
    final size = min(src.width, src.height);
    final x    = (src.width  - size) ~/ 2;
    final y    = (src.height - size) ~/ 2;
    final crop = img.copyCrop(src, x: x, y: y, width: size, height: size);
    return img.copyResize(crop,
        width: _inputSize, height: _inputSize,
        interpolation: img.Interpolation.linear);
  }

  List<double> _flattenToDouble(Object obj) {
    if (obj is List) {
      return obj.expand((e) => _flattenToDouble(e)).toList();
    }
    if (obj is double) return [obj];
    if (obj is num)    return [obj.toDouble()];
    return [];
  }

  @override
  void dispose() {
    _landmarkInterpreter?.close();
    _classifierInterpreter?.close();
    super.dispose();
  }
}

// ─── DetectionResult ──────────────────────────────────────────────────────────

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

  bool get isHighConfidence   => confidence >= 0.60;
  bool get isMediumConfidence => confidence >= 0.40 && confidence < 0.60;
  String get confidencePercent => '${(confidence * 100).toStringAsFixed(1)}%';

  Color get confidenceColor {
    if (isHighConfidence)   return const Color(0xFF00C853);
    if (isMediumConfidence) return const Color(0xFFFFD600);
    return const Color(0xFFFF1744);
  }
}
