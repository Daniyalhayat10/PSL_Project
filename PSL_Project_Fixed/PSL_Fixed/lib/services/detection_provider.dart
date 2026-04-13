import 'package:flutter/material.dart';
import 'model_service.dart';

class DetectionProvider extends ChangeNotifier {
  DetectionResult? _lastResult;
  List<DetectionResult> _recentHistory = [];
  bool _isDetecting = false;
  bool _isCameraActive = false;
  String _detectedWord = '';
  String _detectedSentence = '';
  int _detectionCount = 0;
  DateTime? _lastDetectionTime;

  DetectionResult? get lastResult => _lastResult;
  List<DetectionResult> get recentHistory => _recentHistory;
  bool get isDetecting => _isDetecting;
  bool get isCameraActive => _isCameraActive;
  String get detectedWord => _detectedWord;
  String get detectedSentence => _detectedSentence;
  int get detectionCount => _detectionCount;

  void setDetecting(bool value) {
    _isDetecting = value;
    notifyListeners();
  }

  void setCameraActive(bool value) {
    _isCameraActive = value;
    notifyListeners();
  }

  void updateDetection(DetectionResult result) {
    final now = DateTime.now();

    // Debounce: only update if confidence high enough or 500ms passed
    if (_lastResult?.urduLabel == result.urduLabel &&
        _lastDetectionTime != null &&
        now.difference(_lastDetectionTime!).inMilliseconds < 500) {
      return;
    }

    _lastResult = result;
    _lastDetectionTime = now;
    _detectionCount++;

    // Keep rolling history of last 10
    _recentHistory.insert(0, result);
    if (_recentHistory.length > 10) {
      _recentHistory = _recentHistory.sublist(0, 10);
    }

    // Stable detection: if same letter 3 times in a row, add to word
    if (_recentHistory.length >= 3) {
      final last3 = _recentHistory.sublist(0, 3);
      if (last3.every((r) => r.urduLabel == result.urduLabel) &&
          result.isHighConfidence) {
        if (_detectedWord.isEmpty ||
            _detectedWord[_detectedWord.length - 1] != result.urduLabel[0]) {
          _detectedWord += result.urduLabel;
        }
      }
    }

    notifyListeners();
  }

  void addSpaceToWord() {
    if (_detectedWord.isNotEmpty) {
      _detectedSentence += '$_detectedWord ';
      _detectedWord = '';
      notifyListeners();
    }
  }

  void undoLastLetter() {
    if (_detectedWord.isNotEmpty) {
      // Remove last Urdu character (may be multi-byte)
      final chars = UrduChars(_detectedWord);
      _detectedWord = chars.take(chars.length - 1).toString();
      notifyListeners();
    }
  }

  void clearAll() {
    _detectedWord = '';
    _detectedSentence = '';
    _recentHistory.clear();
    _lastResult = null;
    _detectionCount = 0;
    notifyListeners();
  }

  void clearWord() {
    _detectedWord = '';
    notifyListeners();
  }
}

extension UrduStringExt on String {
  UrduChars get urduChars => UrduChars(this);
}

class UrduChars {
  final String _str;
  UrduChars(this._str);

  int get length {
    int count = 0;
    for (final _ in _str.runes) {
      count++;
    }
    return count;
  }

  UrduChars take(int n) {
    final runes = _str.runes.toList();
    final taken = runes.take(n).toList();
    return UrduChars(String.fromCharCodes(taken));
  }

  @override
  String toString() => _str;
}
