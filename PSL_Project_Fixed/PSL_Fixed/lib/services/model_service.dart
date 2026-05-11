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

  static const int _inputSize = 224;

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

  Future<void> loadModel() async {
    if (_isLoading || _isLoaded) return;
    _isLoading = true;
    _loadError = '';
    notifyListeners();

    try {
      final opts = InterpreterOptions()..threads = 2;

      _landmarkInterpreter = await Interpreter.fromAsset(
        'assets/models/hand_landmark_lite.tflite', options: opts);

      _classifierInterpreter = await Interpreter.fromAsset(
        'assets/models/hand_landmark_nn.tflite', options: opts);

      final numOut = _landmarkInterpreter!.getOutputTensors().length;
      debugPrint('✅ Landmark model: $numOut outputs');
      for (int i = 0; i < numOut; i++) {
        debugPrint('   out[$i]: ${_landmarkInterpreter!.getOutputTensor(i).shape}');
      }
      debugPrint('✅ Classifier: '
          'in=${_classifierInterpreter!.getInputTensor(0).shape} '
          'out=${_classifierInterpreter!.getOutputTensor(0).shape}');

      _isLoaded = true;
    } catch (e) {
      _loadError = e.toString();
      _isLoaded = false;
      debugPrint('❌ Load failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  DetectionResult? processFrame(img.Image frame) {
    if (!_isLoaded) return null;
    final cropped = _centerCropAndResize(frame);
    final landmarks = _extractLandmarks(cropped);
    if (landmarks == null) return null;
    return _classify(landmarks);
  }

  List<double>? _extractLandmarks(img.Image img224) {
    try {
      final input = List.generate(1, (_) =>
        List.generate(_inputSize, (y) =>
          List.generate(_inputSize, (x) {
            final p = img224.getPixel(x, y);
            return [p.r / 255.0, p.g / 255.0, p.b / 255.0];
          })
        )
      );

      // Allocate all 4 outputs
      // out[0]=raw px coords [1,63], out[1]=hand flag [1,1],
      // out[2]=handedness [1,1],     out[3]=world coords [1,63]
      final outputs = <int, Object>{
        0: List.filled(63, 0.0).reshape([1, 63]),
        1: List.filled(1,  0.0).reshape([1, 1]),
        2: List.filled(1,  0.0).reshape([1, 1]),
        3: List.filled(63, 0.0).reshape([1, 63]),
      };

      _landmarkInterpreter!.runForMultipleInputs([input], outputs);

      // Read hand presence score
      final flag = ((outputs[1] as List)[0] as List)[0] as double;
      debugPrint('🖐 Hand flag: ${flag.toStringAsFixed(4)}');

      // Use very low threshold — model may score low even with a real hand
      // because it expects pre-cropped aligned hand, not full frame
      if (flag < 0.01) return null;

      // Use output[0]: raw pixel coordinates (0–224 range)
      // Normalise: wrist-relative then max-abs scale → matches training
      final raw = _flatten(outputs[0]!);
      if (raw.length < 63) return null;

      return _normalize(raw.sublist(0, 63));
    } catch (e) {
      debugPrint('❌ Landmark error: $e');
      return null;
    }
  }

  List<double> _normalize(List<double> flat) {
    final r = List<double>.from(flat);
    // Wrist-relative
    final wx = r[0], wy = r[1], wz = r[2];
    for (int i = 0; i < r.length; i += 3) {
      r[i] -= wx; r[i+1] -= wy; r[i+2] -= wz;
    }
    // Max-abs scale
    double mx = 0;
    for (final v in r) { if (v.abs() > mx) mx = v.abs(); }
    if (mx > 0) { for (int i = 0; i < r.length; i++) r[i] /= mx; }
    return r;
  }

  DetectionResult? _classify(List<double> landmarks) {
    try {
      final outShape = _classifierInterpreter!.getOutputTensor(0).shape;
      final n = outShape.last;
      final input  = [landmarks];
      final output = List.filled(n, 0.0).reshape([1, n]);
      _classifierInterpreter!.run(input, output);

      final probs = (output[0] as List).cast<double>();
      int best = 0; double bv = probs[0];
      for (int i = 1; i < probs.length; i++) {
        if (probs[i] > bv) { bv = probs[i]; best = i; }
      }
      debugPrint('🔍 ${best < romanLabels.length ? romanLabels[best] : best}'
          '  (${(bv*100).toStringAsFixed(1)}%)');

      return DetectionResult(
        classIndex: best,
        urduLabel:  best < urduLabels.length  ? urduLabels[best]  : '?',
        romanLabel: best < romanLabels.length ? romanLabels[best] : '?',
        confidence: bv,
        allProbabilities: probs,
      );
    } catch (e) {
      debugPrint('❌ Classify error: $e');
      return null;
    }
  }

  img.Image _centerCropAndResize(img.Image src) {
    final size = min(src.width, src.height);
    final x = (src.width  - size) ~/ 2;
    final y = (src.height - size) ~/ 2;
    final crop = img.copyCrop(src, x: x, y: y, width: size, height: size);
    return img.copyResize(crop, width: _inputSize, height: _inputSize);
  }

  List<double> _flatten(Object obj) {
    if (obj is List) return obj.expand((e) => _flatten(e)).toList();
    if (obj is double) return [obj];
    if (obj is num) return [obj.toDouble()];
    return [];
  }

  @override
  void dispose() {
    _landmarkInterpreter?.close();
    _classifierInterpreter?.close();
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

  bool get isHighConfidence   => confidence >= 0.60;
  bool get isMediumConfidence => confidence >= 0.35 && confidence < 0.60;
  String get confidencePercent => '${(confidence * 100).toStringAsFixed(1)}%';

  Color get confidenceColor {
    if (isHighConfidence)   return const Color(0xFF00C853);
    if (isMediumConfidence) return const Color(0xFFFFD600);
    return const Color(0xFFFF5252);
  }
}
