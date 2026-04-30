import 'dart:math';
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class ModelService extends ChangeNotifier {
  Interpreter? _landmarkInterpreter;
  Interpreter? _classifierInterpreter;

  bool _isLoaded = false;
  bool _isLoading = false;
  String _loadError = '';

  bool get isLoaded => _isLoaded;
  bool get isLoading => _isLoading;
  String get loadError => _loadError;

  // ── Labels — must match classes.txt order exactly ──────────────────────────
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

  static const int _inputSize = 224;
  // Minimum hand-presence confidence from MediaPipe model
  static const double _handPresenceThreshold = 0.5;

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> loadModel() async {
    if (_isLoading || _isLoaded) return;
    _isLoading = true;
    _loadError = '';
    notifyListeners();

    try {
      final opts = InterpreterOptions()..threads = 2;

      // 1. Load the hand landmark model (MediaPipe hand_landmark_lite.tflite)
      _landmarkInterpreter = await Interpreter.fromAsset(
        'assets/models/hand_landmark_lite.tflite',
        options: opts,
      );

      // 2. Load your trained letter classifier
      _classifierInterpreter = await Interpreter.fromAsset(
        'assets/models/hand_landmark_nn.tflite',
        options: opts,
      );

      // Log shapes so we can verify
      final lmIn  = _landmarkInterpreter!.getInputTensor(0).shape;
      final lmOut0 = _landmarkInterpreter!.getOutputTensor(0).shape;
      final lmOut1 = _landmarkInterpreter!.getOutputTensor(1).shape;
      debugPrint('✅ Landmark model — input: $lmIn  out0: $lmOut0  out1: $lmOut1');

      final clIn  = _classifierInterpreter!.getInputTensor(0).shape;
      final clOut = _classifierInterpreter!.getOutputTensor(0).shape;
      debugPrint('✅ Classifier model — input: $clIn  output: $clOut');

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

  // ── Main entry — called every N frames ────────────────────────────────────

  /// Returns null if no hand detected or confidence too low.
  DetectionResult? processFrame(img.Image frame) {
    if (!_isLoaded) return null;
    if (_landmarkInterpreter == null || _classifierInterpreter == null) return null;

    // Step 1: crop centre square (where user's hand should be)
    final cropped = _centerCropSquare(frame);

    // Step 2: resize to 224×224
    final resized = img.copyResize(cropped,
        width: _inputSize, height: _inputSize,
        interpolation: img.Interpolation.linear);

    // Step 3: run MediaPipe landmark model
    final landmarkResult = _runLandmarkModel(resized);
    if (landmarkResult == null) return null;

    // Step 4: normalise landmarks exactly as Python training code
    final normalised = _normalizeLandmarks(landmarkResult);
    if (normalised.isEmpty) return null;

    // Step 5: run your trained classifier
    return _runClassifier(normalised);
  }

  // ── Step 3: MediaPipe landmark model ──────────────────────────────────────

  /// MediaPipe hand_landmark_lite.tflite:
  ///   Input  : [1, 224, 224, 3]  float32  values 0–1
  ///   Output0: [1, 63]           float32  21 landmarks × (x,y,z)
  ///   Output1: [1, 1]            float32  hand presence score 0–1
  ///   Output2: [1, 1]  (optional) handedness
  List<List<double>>? _runLandmarkModel(img.Image img224) {
    try {
      // Build input tensor [1, 224, 224, 3]
      final input = List.generate(1, (_) =>
        List.generate(_inputSize, (y) =>
          List.generate(_inputSize, (x) {
            final p = img224.getPixel(x, y);
            return [p.r / 255.0, p.g / 255.0, p.b / 255.0];
          })
        )
      );

      // Prepare outputs — MediaPipe has at least 2 output tensors
      // Output 0: landmarks [1, 63]
      // Output 1: hand flag [1, 1]
      final numOutputs = _landmarkInterpreter!.getOutputTensors().length;
      debugPrint('Landmark model output tensor count: $numOutputs');

      final out0Shape = _landmarkInterpreter!.getOutputTensor(0).shape;
      final landmarkCount = out0Shape.reduce((a, b) => a * b); // total elements

      // Use runForMultipleOutputs to get all tensors
      final outputs = <int, Object>{
        0: List.filled(landmarkCount, 0.0).reshape(out0Shape),
        1: List.filled(1, 0.0).reshape([1, 1]),
      };
      if (numOutputs > 2) {
        outputs[2] = List.filled(1, 0.0).reshape([1, 1]);
      }

      _landmarkInterpreter!.runForMultipleInputs([input], outputs);

      // Check hand presence score
      final handFlag = ((outputs[1] as List)[0] as List)[0] as double;
      debugPrint('Hand presence score: ${handFlag.toStringAsFixed(3)}');

      if (handFlag < _handPresenceThreshold) {
        return null; // no hand detected
      }

      // Extract landmark flat list
      final flatLandmarks = _flattenOutput(outputs[0]!);
      if (flatLandmarks.length < 63) {
        debugPrint('⚠️ Not enough landmark values: ${flatLandmarks.length}');
        return null;
      }

      // Reshape to 21 × [x, y, z]
      final pts = List.generate(21, (i) => [
        flatLandmarks[i * 3].toDouble(),
        flatLandmarks[i * 3 + 1].toDouble(),
        flatLandmarks[i * 3 + 2].toDouble(),
      ]);

      return pts;
    } catch (e) {
      debugPrint('❌ Landmark model error: $e');
      return null;
    }
  }

  /// Recursively flatten nested List into flat double list
  List<num> _flattenOutput(Object obj) {
    if (obj is List) {
      return obj.expand((e) => _flattenOutput(e)).toList();
    }
    return [obj as num];
  }

  // ── Step 4: Normalise landmarks (must match Python training) ───────────────

  List<double> _normalizeLandmarks(List<List<double>> raw) {
    if (raw.length != 21) return [];

    final flat = raw.expand((p) => p).toList();

    // Wrist-relative: subtract landmark 0 (wrist)
    final wx = flat[0], wy = flat[1], wz = flat[2];
    for (int i = 0; i < flat.length; i += 3) {
      flat[i]     -= wx;
      flat[i + 1] -= wy;
      flat[i + 2] -= wz;
    }

    // Scale: divide by max absolute value → range [-1, 1]
    final maxVal = flat.map((v) => v.abs()).reduce(max);
    if (maxVal > 0) {
      for (int i = 0; i < flat.length; i++) flat[i] /= maxVal;
    }

    return flat;
  }

  // ── Step 5: Run your trained classifier ───────────────────────────────────

  DetectionResult? _runClassifier(List<double> landmarks) {
    try {
      final outShape = _classifierInterpreter!.getOutputTensor(0).shape;
      final numClasses = outShape.last;

      final input  = [landmarks]; // [1, 63]
      final output = List.filled(numClasses, 0.0).reshape([1, numClasses]);

      _classifierInterpreter!.run(input, output);

      final probs = (output[0] as List).cast<double>();
      int bestIdx = 0;
      double bestVal = probs[0];
      for (int i = 1; i < probs.length; i++) {
        if (probs[i] > bestVal) { bestVal = probs[i]; bestIdx = i; }
      }

      debugPrint('🔍 ${bestIdx < romanLabels.length ? romanLabels[bestIdx] : bestIdx}'
          '  (${(bestVal * 100).toStringAsFixed(1)}%)');

      return DetectionResult(
        classIndex:      bestIdx,
        urduLabel:       bestIdx < urduLabels.length  ? urduLabels[bestIdx]  : '?',
        romanLabel:      bestIdx < romanLabels.length ? romanLabels[bestIdx] : 'Unknown',
        confidence:      bestVal,
        allProbabilities: probs,
      );
    } catch (e) {
      debugPrint('❌ Classifier error: $e');
      return null;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Crop the largest central square from the image.
  img.Image _centerCropSquare(img.Image src) {
    final size = min(src.width, src.height);
    final x = (src.width  - size) ~/ 2;
    final y = (src.height - size) ~/ 2;
    return img.copyCrop(src, x: x, y: y, width: size, height: size);
  }

  @override
  void dispose() {
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
    required this.classIndex,
    required this.urduLabel,
    required this.romanLabel,
    required this.confidence,
    required this.allProbabilities,
  });

  bool get isHighConfidence   => confidence >= 0.70;
  bool get isMediumConfidence => confidence >= 0.45 && confidence < 0.70;
  String get confidencePercent => '${(confidence * 100).toStringAsFixed(1)}%';

  Color get confidenceColor {
    if (isHighConfidence)   return const Color(0xFF00C853);
    if (isMediumConfidence) return const Color(0xFFFFD600);
    return const Color(0xFFFF1744);
  }
}
