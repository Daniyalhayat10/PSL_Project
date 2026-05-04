import 'dart:math';
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class ModelService extends ChangeNotifier {
  Interpreter? _palmDetector;
  Interpreter? _landmarkInterpreter;
  Interpreter? _classifierInterpreter;

  bool _isLoaded = false;
  bool _isLoading = false;
  String _loadError = '';

  bool get isLoaded => _isLoaded;
  bool get isLoading => _isLoading;
  String get loadError => _loadError;

  // Palm detector input size
  static const int _palmInputSize = 192;
  // Hand landmark input size
  static const int _landmarkInputSize = 224;
  // Minimum palm score to attempt landmark extraction
  static const double _palmScoreThreshold = 0.5;
  // Minimum hand presence score from landmark model
  static const double _handPresenceThreshold = 0.4;

  // ── Labels matching classes.txt exactly ────────────────────────────────────
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

  // ── Load all three models ──────────────────────────────────────────────────

  Future<void> loadModel() async {
    if (_isLoading || _isLoaded) return;
    _isLoading = true;
    _loadError = '';
    notifyListeners();

    try {
      final opts = InterpreterOptions()..threads = 2;

      // 1. Palm detector — finds hand in full frame
      _palmDetector = await Interpreter.fromAsset(
        'assets/models/palm_detection_lite.tflite',
        options: opts,
      );
      debugPrint('✅ Palm detector loaded');
      _logTensorShapes(_palmDetector!, 'Palm detector');

      // 2. Hand landmark model — 21 keypoints from cropped hand
      _landmarkInterpreter = await Interpreter.fromAsset(
        'assets/models/hand_landmark_lite.tflite',
        options: opts,
      );
      debugPrint('✅ Hand landmark model loaded');
      _logTensorShapes(_landmarkInterpreter!, 'Hand landmark');

      // 3. Your trained letter classifier
      _classifierInterpreter = await Interpreter.fromAsset(
        'assets/models/hand_landmark_nn.tflite',
        options: opts,
      );
      debugPrint('✅ Classifier loaded');
      _logTensorShapes(_classifierInterpreter!, 'Classifier');

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

  void _logTensorShapes(Interpreter interp, String name) {
    try {
      final inShape = interp.getInputTensor(0).shape;
      final numOut = interp.getOutputTensors().length;
      debugPrint('  $name in: $inShape  outputs: $numOut');
      for (int i = 0; i < numOut; i++) {
        debugPrint('    out[$i]: ${interp.getOutputTensor(i).shape}');
      }
    } catch (_) {}
  }

  // ── Main pipeline ─────────────────────────────────────────────────────────

  DetectionResult? processFrame(img.Image frame) {
    if (!_isLoaded) return null;

    // STAGE 1: Detect palm in full frame
    final palmCrop = _detectAndCropPalm(frame);
    if (palmCrop == null) {
      debugPrint('🖐 No palm detected');
      return null;
    }

    // STAGE 2: Extract 21 hand landmarks from cropped region
    final landmarks = _runLandmarkModel(palmCrop);
    if (landmarks == null) {
      debugPrint('🖐 Landmark extraction failed');
      return null;
    }

    // STAGE 3: Normalise landmarks (same as Python training)
    final normalised = _normalizeLandmarks(landmarks);
    if (normalised.isEmpty) return null;

    // STAGE 4: Classify letter
    return _runClassifier(normalised);
  }

  // ── STAGE 1: Palm detection ───────────────────────────────────────────────

  /// MediaPipe palm_detection_lite.tflite
  ///   Input : [1, 192, 192, 3]   float32  0–1
  ///   Output0: [1, 2016, 18]     regressors (bbox + keypoints)
  ///   Output1: [1, 2016, 1]      scores
  img.Image? _detectAndCropPalm(img.Image frame) {
    try {
      final resized = img.copyResize(frame,
          width: _palmInputSize, height: _palmInputSize);

      final input = List.generate(1, (_) =>
        List.generate(_palmInputSize, (y) =>
          List.generate(_palmInputSize, (x) {
            final p = resized.getPixel(x, y);
            return [p.r / 255.0, p.g / 255.0, p.b / 255.0];
          })
        )
      );

      // Get actual output shapes from model
      final numOut = _palmDetector!.getOutputTensors().length;
      final out0Shape = _palmDetector!.getOutputTensor(0).shape;
      final out0Size = out0Shape.reduce((a, b) => a * b);

      final outputs = <int, Object>{
        0: List.filled(out0Size, 0.0).reshape(out0Shape),
      };
      if (numOut > 1) {
        final out1Shape = _palmDetector!.getOutputTensor(1).shape;
        final out1Size = out1Shape.reduce((a, b) => a * b);
        outputs[1] = List.filled(out1Size, 0.0).reshape(out1Shape);
      }

      _palmDetector!.runForMultipleInputs([input], outputs);

      // Find best detection
      // Scores tensor — find max score and its index
      if (numOut < 2) {
        // Only one output — assume full frame is hand (fallback)
        return _centerCropSquare(frame);
      }

      final scoresRaw = _flattenToDouble(outputs[1]!);
      final regsRaw   = _flattenToDouble(outputs[0]!);

      double bestScore = -1;
      int bestIdx = 0;
      for (int i = 0; i < scoresRaw.length; i++) {
        // Apply sigmoid
        final score = 1.0 / (1.0 + exp(-scoresRaw[i]));
        if (score > bestScore) {
          bestScore = score;
          bestIdx = i;
        }
      }

      debugPrint('🖐 Best palm score: ${bestScore.toStringAsFixed(3)}');

      if (bestScore < _palmScoreThreshold) {
        return null; // no palm found
      }

      // Each detection has 18 values: [cx, cy, w, h, kp0x, kp0y, ...]
      // Coordinates are in [0,1] relative to 192×192 input
      final detSize = regsRaw.length ~/ scoresRaw.length;
      final base = bestIdx * detSize;

      if (base + 3 >= regsRaw.length) {
        // Fallback to centre crop
        return _centerCropSquare(frame);
      }

      double cx = regsRaw[base];
      double cy = regsRaw[base + 1];
      double bw = regsRaw[base + 2];
      double bh = regsRaw[base + 3];

      // Anchor-decode: MediaPipe anchors are pre-defined grid centres
      // Simple approximation: treat cx,cy as normalised centre of 192×192
      // Map back to original frame coordinates
      final scaleX = frame.width  / _palmInputSize.toDouble();
      final scaleY = frame.height / _palmInputSize.toDouble();

      // Add 30% padding around detected hand
      const pad = 0.35;
      bw = bw * (1 + pad * 2);
      bh = bh * (1 + pad * 2);

      int x1 = ((cx - bw / 2) * scaleX).round().clamp(0, frame.width);
      int y1 = ((cy - bh / 2) * scaleY).round().clamp(0, frame.height);
      int x2 = ((cx + bw / 2) * scaleX).round().clamp(0, frame.width);
      int y2 = ((cy + bh / 2) * scaleY).round().clamp(0, frame.height);

      final cropW = (x2 - x1).clamp(10, frame.width);
      final cropH = (y2 - y1).clamp(10, frame.height);

      if (cropW < 10 || cropH < 10) return _centerCropSquare(frame);

      final cropped = img.copyCrop(frame,
          x: x1, y: y1, width: cropW, height: cropH);

      return img.copyResize(cropped,
          width: _landmarkInputSize, height: _landmarkInputSize);
    } catch (e) {
      debugPrint('❌ Palm detection error: $e — using centre crop');
      // Fallback: use centre crop (works when hand fills the guide box)
      return img.copyResize(
        _centerCropSquare(frame),
        width: _landmarkInputSize,
        height: _landmarkInputSize,
      );
    }
  }

  // ── STAGE 2: Hand landmark model ─────────────────────────────────────────

  /// Input : [1, 224, 224, 3]  float32  0–1
  /// Output0: [1, 63]          landmarks (21 × xyz)
  /// Output1: [1, 1]           hand presence score
  List<List<double>>? _runLandmarkModel(img.Image img224) {
    try {
      final input = List.generate(1, (_) =>
        List.generate(_landmarkInputSize, (y) =>
          List.generate(_landmarkInputSize, (x) {
            final p = img224.getPixel(x, y);
            return [p.r / 255.0, p.g / 255.0, p.b / 255.0];
          })
        )
      );

      final numOut  = _landmarkInterpreter!.getOutputTensors().length;
      final out0Sh  = _landmarkInterpreter!.getOutputTensor(0).shape;
      final out0Sz  = out0Sh.reduce((a, b) => a * b);

      final outputs = <int, Object>{
        0: List.filled(out0Sz, 0.0).reshape(out0Sh),
      };
      if (numOut > 1) {
        outputs[1] = List.filled(1, 0.0).reshape([1, 1]);
      }
      if (numOut > 2) {
        outputs[2] = List.filled(1, 0.0).reshape([1, 1]);
      }

      _landmarkInterpreter!.runForMultipleInputs([input], outputs);

      // Check hand presence
      if (numOut > 1) {
        final flag = _flattenToDouble(outputs[1]!).first;
        debugPrint('🖐 Hand flag: ${flag.toStringAsFixed(3)}');
        if (flag < _handPresenceThreshold) return null;
      }

      final flat = _flattenToDouble(outputs[0]!);
      if (flat.length < 63) return null;

      // Reshape flat [63] → [[x,y,z] × 21]
      return List.generate(21, (i) =>
          [flat[i * 3], flat[i * 3 + 1], flat[i * 3 + 2]]);
    } catch (e) {
      debugPrint('❌ Landmark model error: $e');
      return null;
    }
  }

  // ── STAGE 3: Normalise ────────────────────────────────────────────────────

  List<double> _normalizeLandmarks(List<List<double>> raw) {
    if (raw.length != 21) return [];
    final flat = raw.expand((p) => p).toList();

    // Wrist-relative
    final wx = flat[0], wy = flat[1], wz = flat[2];
    for (int i = 0; i < flat.length; i += 3) {
      flat[i] -= wx; flat[i+1] -= wy; flat[i+2] -= wz;
    }

    // Max-abs scale → [-1, 1]
    final maxVal = flat.map((v) => v.abs()).reduce(max);
    if (maxVal > 0) {
      for (int i = 0; i < flat.length; i++) flat[i] /= maxVal;
    }
    return flat;
  }

  // ── STAGE 4: Classifier ───────────────────────────────────────────────────

  DetectionResult? _runClassifier(List<double> landmarks) {
    try {
      final outShape   = _classifierInterpreter!.getOutputTensor(0).shape;
      final numClasses = outShape.last;
      final input  = [landmarks];
      final output = List.filled(numClasses, 0.0).reshape([1, numClasses]);

      _classifierInterpreter!.run(input, output);

      final probs = (output[0] as List).cast<double>();
      int bestIdx = 0; double bestVal = probs[0];
      for (int i = 1; i < probs.length; i++) {
        if (probs[i] > bestVal) { bestVal = probs[i]; bestIdx = i; }
      }

      debugPrint('🔍 ${bestIdx < romanLabels.length ? romanLabels[bestIdx] : bestIdx}'
          '  (${(bestVal*100).toStringAsFixed(1)}%)');

      return DetectionResult(
        classIndex:       bestIdx,
        urduLabel:        bestIdx < urduLabels.length  ? urduLabels[bestIdx]  : '?',
        romanLabel:       bestIdx < romanLabels.length ? romanLabels[bestIdx] : 'Unknown',
        confidence:       bestVal,
        allProbabilities: probs,
      );
    } catch (e) {
      debugPrint('❌ Classifier error: $e');
      return null;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  img.Image _centerCropSquare(img.Image src) {
    final size = min(src.width, src.height);
    final x = (src.width  - size) ~/ 2;
    final y = (src.height - size) ~/ 2;
    return img.copyCrop(src, x: x, y: y, width: size, height: size);
  }

  List<double> _flattenToDouble(Object obj) {
    if (obj is List) return obj.expand((e) => _flattenToDouble(e)).toList();
    if (obj is double) return [obj];
    if (obj is num) return [obj.toDouble()];
    return [];
  }

  @override
  void dispose() {
    _palmDetector?.close();
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

  bool get isHighConfidence   => confidence >= 0.65;
  bool get isMediumConfidence => confidence >= 0.45 && confidence < 0.65;
  String get confidencePercent => '${(confidence * 100).toStringAsFixed(1)}%';

  Color get confidenceColor {
    if (isHighConfidence)   return const Color(0xFF00C853);
    if (isMediumConfidence) return const Color(0xFFFFD600);
    return const Color(0xFFFF1744);
  }
}
