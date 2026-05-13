import 'package:flutter/material.dart';
import 'model_service.dart';

class DetectionProvider extends ChangeNotifier {
  DetectionResult? _lastResult;
  bool _isDetecting = false;
  bool _isCameraActive = false;
  String _detectedWord = '';
  String _detectedSentence = '';
  int _detectionCount = 0;

  // Live consecutive-frame counter
  int _consecutiveCount = 0;
  String? _lastSeenRoman;
  DateTime? _lastLetterAddedTime;

  // Pause flag — user can halt auto-commit without stopping the camera
  bool _detectionPaused = false;
  bool get detectionPaused => _detectionPaused;

  void toggleDetectionPause() {
    _detectionPaused = !_detectionPaused;
    if (!_detectionPaused) {
      // Apply cooldown on resume so the hand shown during pause isn't committed immediately
      _lastLetterAddedTime = DateTime.now();
      _consecutiveCount = 0;
      _lastSeenRoman = null;
    }
    notifyListeners();
  }

  // How many consecutive high-confidence frames at the same sign before commit
  static const int _stableFramesRequired = 3;

  // After committing, ignore ALL results for this long (prevents instant re-adds)
  static const int _cooldownMs = 1500;

  DetectionResult? get lastResult       => _lastResult;
  bool get isDetecting                  => _isDetecting;
  bool get isCameraActive               => _isCameraActive;
  String get detectedWord               => _detectedWord;
  String get detectedSentence           => _detectedSentence;
  int get detectionCount                => _detectionCount;
  String get fullText =>
      _detectedSentence.isEmpty ? _detectedWord : '$_detectedSentence$_detectedWord';

  void setDetecting(bool v)    { _isDetecting = v;   notifyListeners(); }
  void setCameraActive(bool v) { _isCameraActive = v; notifyListeners(); }

  /// Called when no hand is visible — resets the consecutive counter.
  void onHandLost() {
    if (_consecutiveCount != 0 || _lastSeenRoman != null) {
      _consecutiveCount = 0;
      _lastSeenRoman = null;
      notifyListeners();
    }
  }

  void updateDetection(DetectionResult result) {
    _lastResult = result;
    _detectionCount++;

    // When paused, still update lastResult for the UI card but skip auto-commit
    if (_detectionPaused) { notifyListeners(); return; }

    // ── Cooldown guard ────────────────────────────────────────────────────────
    // After a letter is committed, ignore everything for _cooldownMs.
    final inCooldown = _lastLetterAddedTime != null &&
        DateTime.now().difference(_lastLetterAddedTime!).inMilliseconds < _cooldownMs;
    if (inCooldown) {
      notifyListeners();
      return;
    }

    // ── Consecutive-frame stability ───────────────────────────────────────────
    if (result.romanLabel == _lastSeenRoman) {
      _consecutiveCount++;
    } else {
      _consecutiveCount = 1;
      _lastSeenRoman = result.romanLabel;
    }

    // ── Commit ────────────────────────────────────────────────────────────────
    if (result.isHighConfidence && _consecutiveCount >= _stableFramesRequired) {
      _commitLetter(result.urduLabel);
    }

    notifyListeners();
  }

  void _commitLetter(String urduLetter) {
    _detectedWord += urduLetter;
    _lastLetterAddedTime = DateTime.now();
    _consecutiveCount = 0;   // require fresh stability for next letter
    _lastSeenRoman = null;
    debugPrint('✅ Added: $urduLetter  Word: $_detectedWord');
  }

  void addSpaceToWord() {
    if (_detectedWord.isNotEmpty) {
      _detectedSentence += '$_detectedWord ';
      _detectedWord = '';
      // Keep cooldown running so detection doesn't immediately add to the new word
      _lastLetterAddedTime = DateTime.now();
      _consecutiveCount = 0;
      _lastSeenRoman = null;
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
    _lastResult = null;
    _detectionCount = 0;
    _consecutiveCount = 0;
    _lastSeenRoman = null;
    _lastLetterAddedTime = null;
    notifyListeners();
  }

  void clearWord() {
    _detectedWord = '';
    _consecutiveCount = 0;
    _lastSeenRoman = null;
    _lastLetterAddedTime = null;
    notifyListeners();
  }
}
