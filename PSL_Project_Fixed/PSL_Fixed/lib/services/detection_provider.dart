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

  // Minimum milliseconds between adding the SAME letter again
  static const int _sameLetterCooldownMs = 1500;
  // Minimum consecutive stable detections before confirming a letter
  static const int _stableFramesRequired = 4;
  // Minimum confidence to add to word
  static const double _minConfidenceToAdd = 0.65;

  DetectionResult? get lastResult => _lastResult;
  List<DetectionResult> get recentHistory => _recentHistory;
  bool get isDetecting => _isDetecting;
  bool get isCameraActive => _isCameraActive;
  String get detectedWord => _detectedWord;
  String get detectedSentence => _detectedSentence;
  int get detectionCount => _detectionCount;
  String get fullText =>
      _detectedSentence.isEmpty ? _detectedWord : '$_detectedSentence$_detectedWord';

  void setDetecting(bool value) {
    _isDetecting = value;
    notifyListeners();
  }

  void setCameraActive(bool value) {
    _isCameraActive = value;
    notifyListeners();
  }

  void updateDetection(DetectionResult result) {
    _lastResult = result;
    _detectionCount++;

    // Keep rolling history of last 15
    _recentHistory.insert(0, result);
    if (_recentHistory.length > 15) {
      _recentHistory = _recentHistory.sublist(0, 15);
    }

    // Only attempt to add a letter if confidence is high enough
    if (!result.isHighConfidence) {
      notifyListeners();
      return;
    }

    // Check for stable detection: last N frames all predict same label
    if (_recentHistory.length >= _stableFramesRequired) {
      final recent = _recentHistory.sublist(0, _stableFramesRequired);
      final allSame = recent.every((r) => r.urduLabel == result.urduLabel);

      if (allSame) {
        _tryAddLetter(result.urduLabel);
      }
    }

    notifyListeners();
  }

  void _tryAddLetter(String letter) {
    final now = DateTime.now();

    // Cooldown: don't add same letter twice within cooldown period
    if (_lastLetterAddedTime != null) {
      final elapsed = now.difference(_lastLetterAddedTime!).inMilliseconds;

      // If same letter, apply cooldown
      if (_detectedWord.isNotEmpty) {
        final lastChar = _urduLastChar(_detectedWord);
        if (lastChar == letter && elapsed < _sameLetterCooldownMs) {
          return;
        }
      } else if (elapsed < _sameLetterCooldownMs ~/ 2) {
        return; // general small cooldown even for new letters
      }
    }

    _detectedWord += letter;
    _lastLetterAddedTime = now;
    debugPrint('✅ Letter added: $letter | Word: $_detectedWord');
  }

  /// Manually add a specific letter (for future manual input feature)
  void addLetter(String letter) {
    _detectedWord += letter;
    notifyListeners();
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
      _detectedWord = _urduRemoveLast(_detectedWord);
      notifyListeners();
    } else if (_detectedSentence.isNotEmpty) {
      // Remove last word from sentence
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

  // ─── Urdu string helpers ───────────────────────────────────────────────────

  /// Remove last Urdu grapheme cluster from string
  String _urduRemoveLast(String s) {
    if (s.isEmpty) return s;
    final runes = s.runes.toList();
    if (runes.isEmpty) return '';
    return String.fromCharCodes(runes.take(runes.length - 1));
  }

  /// Get last Urdu character from string
  String _urduLastChar(String s) {
    if (s.isEmpty) return '';
    final runes = s.runes.toList();
    return String.fromCharCode(runes.last);
  }
}
