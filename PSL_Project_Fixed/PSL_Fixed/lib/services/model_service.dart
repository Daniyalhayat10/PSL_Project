import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class ModelService extends ChangeNotifier {
  // Two models:
  // 1. hand_landmark_lite.tflite  → detects 21 hand landmarks from image
  // 2. hand_landmark_nn.tflite    → classifies sign from 63 landmark values
  Interpreter? _landmarkInterpreter;
  Interpreter? _classifierInterpreter;

  bool _isLoaded = false;
  bool _isLoading = false;
  String _loadError = '';

  bool get isLoaded => _isLoaded;
  bool get isLoading => _isLoading;
  String get loadError => _loadError;

  // ── Labels (order matches training label_encoder) ─────────────────────────
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

  // MediaPipe hand landmark model input size
  static const int _landmarkInputSize = 224;

  Future<void> loadModel() async {
    if (_isLoading || _isLoaded) return;
    _isLoading = true;
    _loadError = '';
    notifyListeners();

    try {
      final options = InterpreterOptions()..threads = 4;

      // Load classifier (your trained model)
      _classifierInterpreter = await Interpreter.fromAsset(
        'assets/models/hand_landmark_nn.tflite',
        options: options,
      );

      // Load MediaPipe hand landmark model
      // Download from: https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task
      // Or the raw TFLite: https://storage.googleapis.com/mediapipe-assets/hand_landmark_lite.tflite
      try {
        _landmarkInterpreter = await Interpreter.fromAsset(
          'assets/models/hand_landmark_lite.tflite',
          options: options,
        );
        debugPrint('✅ Hand landmark model loaded');
      } catch (e) {
        debugPrint('⚠️ hand_landmark_lite.tflite not found — will use center-crop mode');
        _landmarkInterpreter = null;
      }

      final inShape = _classifierInterpreter!.getInputTensor(0).shape;
      final outShape = _classifierInterpreter!.getOutputTensor(0).shape;
      debugPrint('✅ Classifier loaded. Input: $inShape  Output: $outShape');

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

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Process a camera frame:
  /// 1. Resize to 224×224
  /// 2. Run hand landmark model (if available) → 21 landmarks
  /// 3. Normalise landmarks
  /// 4. Run classifier → letter
  DetectionResult? processFrame(img.Image frame) {
    if (!_isLoaded || _classifierInterpreter == null) return null;

    List<double>? landmarks;

    if (_landmarkInterpreter != null) {
      landmarks = _runLandmarkModel(frame);
    }

    // If landmark model not available or failed, we cannot classify
    if (landmarks == null || landmarks.isEmpty) return null;

    return _runClassifier(landmarks);
  }

  /// Run inference directly on 63 pre-computed normalised landmarks.
  DetectionResult? runInference(List<double> landmarks) {
    if (!_isLoaded || _classifierInterpreter == null) return null;
    if (landmarks.length != 63) return null;
    return _runClassifier(landmarks);
  }

  // ── Private ────────────────────────────────────────────────────────────────

  /// Run MediaPipe hand landmark TFLite model on frame.
  /// Input:  [1, 224, 224, 3]  float32, values 0-1
  /// Output: [1, 63]           float32, normalised xyz per landmark
  List<double>? _runLandmarkModel(img.Image frame) {
    try {
      final resized = img.copyResize(
          frame, width: _landmarkInputSize, height: _landmarkInputSize);

      // Build [1, 224, 224, 3] float32 input
      final inputBuffer =
          List.generate(1, (_) =>
            List.generate(_landmarkInputSize, (y) =>
              List.generate(_landmarkInputSize, (x) {
                final pixel = resized.getPixel(x, y);
                return [
                  pixel.r / 255.0,
                  pixel.g / 255.0,
                  pixel.b / 255.0,
                ];
              })
            )
          );

      // Determine output shape from model
      final outShape = _landmarkInterpreter!.getOutputTensor(0).shape;
      final numLandmarks = outShape.last; // 63 or 21*3

      final outputBuffer =
          List.filled(numLandmarks, 0.0).reshape([1, numLandmarks]);

      _landmarkInterpreter!.run(inputBuffer, outputBuffer);

      final raw = (outputBuffer[0] as List).cast<double>();

      if (raw.length < 63) {
        debugPrint('⚠️ Landmark model output ${raw.length} values, expected 63');
        return null;
      }

      // Reshape to 21 × [x,y,z] and normalise
      final pts = List.generate(21, (i) =>
          [raw[i * 3], raw[i * 3 + 1], raw[i * 3 + 2]]);

      return normalizeLandmarks(pts);
    } catch (e) {
      debugPrint('❌ Landmark model error: $e');
      return null;
    }
  }

  DetectionResult? _runClassifier(List<double> landmarks) {
    try {
      final outTensor = _classifierInterpreter!.getOutputTensor(0);
      final numClasses = outTensor.shape.last;

      final input = [landmarks];
      final output =
          List.filled(numClasses, 0.0).reshape([1, numClasses]);

      _classifierInterpreter!.run(input, output);

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
          '🔍 ${maxIdx < romanLabels.length ? romanLabels[maxIdx] : maxIdx}'
          ' (${(maxVal * 100).toStringAsFixed(1)}%)');

      return DetectionResult(
        classIndex: maxIdx,
        urduLabel:
            maxIdx < urduLabels.length ? urduLabels[maxIdx] : '?',
        romanLabel:
            maxIdx < romanLabels.length ? romanLabels[maxIdx] : 'Unknown',
        confidence: maxVal,
        allProbabilities: probs,
      );
    } catch (e) {
      debugPrint('❌ Classifier error: $e');
      return null;
    }
  }

  // ── Normalisation (must match Python training code exactly) ───────────────

  static List<double> normalizeLandmarks(List<List<double>> raw) {
    if (raw.length != 21) return [];

    final flat = raw.expand((p) => p).toList();

    // Step 1: wrist-relative (subtract landmark 0)
    final wx = flat[0], wy = flat[1], wz = flat[2];
    for (int i = 0; i < flat.length; i += 3) {
      flat[i] -= wx;
      flat[i + 1] -= wy;
      flat[i + 2] -= wz;
    }

    // Step 2: max-abs scale to [-1, 1]
    final maxVal = flat.map((v) => v.abs()).reduce(max);
    if (maxVal > 0) {
      for (int i = 0; i < flat.length; i++) flat[i] /= maxVal;
    }

    return flat;
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

  bool get isHighConfidence => confidence >= 0.70;
  bool get isMediumConfidence => confidence >= 0.50 && confidence < 0.70;
  String get confidencePercent => '${(confidence * 100).toStringAsFixed(1)}%';

  Color get confidenceColor {
    if (isHighConfidence) return const Color(0xFF00C853);
    if (isMediumConfidence) return const Color(0xFFFFD600);
    return const Color(0xFFFF1744);
  }
}
