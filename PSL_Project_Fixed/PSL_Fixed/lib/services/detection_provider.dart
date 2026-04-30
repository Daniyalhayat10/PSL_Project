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
  DateTime? _lastLetterAddedTime;

  static const int _sameLetterCooldownMs = 1800;
  static const int _stableFramesRequired = 5;

  DetectionResult? get lastResult => _lastResult;
  List<DetectionResult> get recentHistory => List.unmodifiable(_recentHistory);
  bool get isDetecting => _isDetecting;
  bool get isCameraActive => _isCameraActive;
  String get detectedWord => _detectedWord;
  String get detectedSentence => _detectedSentence;
  int get detectionCount => _detectionCount;
  String get fullText =>
      _detectedSentence.isEmpty ? _detectedWord : '$_detectedSentence$_detectedWord';

  void setDetecting(bool v) { _isDetecting = v; notifyListeners(); }
  void setCameraActive(bool v) { _isCameraActive = v; notifyListeners(); }

  void updateDetection(DetectionResult result) {
    _lastResult = result;
    _detectionCount++;

    _recentHistory.insert(0, result);
    if (_recentHistory.length > 20) {
      _recentHistory = _recentHistory.sublist(0, 20);
    }

    // Only add letter if confidence is high enough
    if (!result.isHighConfidence) { notifyListeners(); return; }

    // Require N stable consecutive frames with same label
    if (_recentHistory.length >= _stableFramesRequired) {
      final recent = _recentHistory.sublist(0, _stableFramesRequired);
      final allSame = recent.every((r) => r.urduLabel == result.urduLabel);
      if (allSame) _tryAddLetter(result.urduLabel);
    }

    notifyListeners();
  }

  void _tryAddLetter(String letter) {
    final now = DateTime.now();
    if (_lastLetterAddedTime != null) {
      final elapsed = now.difference(_lastLetterAddedTime!).inMilliseconds;
      if (elapsed < _sameLetterCooldownMs) return;
    }
    _detectedWord += letter;
    _lastLetterAddedTime = now;
    debugPrint('✅ Added: $letter  Word: $_detectedWord');
  }

  void addSpaceToWord() {
    if (_detectedWord.isNotEmpty) {
      _detectedSentence += '$_detectedWord ';
      _detectedWord = '';
      _lastLetterAddedTime = null;
      notifyListeners();
    }
  }

  void undoLastLetter() {
    if (_detectedWord.isNotEmpty) {
      final runes = _detectedWord.runes.toList();
      _detectedWord = String.fromCharCodes(runes.take(runes.length - 1));
      notifyListeners();
    } else if (_detectedSentence.isNotEmpty) {
      final trimmed = _detectedSentence.trimRight();
      final lastSpace = trimmed.lastIndexOf(' ');
      if (lastSpace >= 0) {
        _detectedWord = trimmed.substring(lastSpace + 1);
        _detectedSentence = trimmed.substring(0, lastSpace + 1);
      } else {
        _detectedWord = trimmed;
        _detectedSentence = '';
      }
      notifyListeners();
    }
  }

  void clearAll() {
    _detectedWord = '';
    _detectedSentence = '';
    _recentHistory.clear();
    _lastResult = null;
    _detectionCount = 0;
    _lastLetterAddedTime = null;
    notifyListeners();
  }

  void clearWord() {
    _detectedWord = '';
    _lastLetterAddedTime = null;
    notifyListeners();
  }
}
