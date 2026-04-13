import 'package:flutter/material.dart';

/// Data model for a single hand landmark point
class HandLandmark {
  final double x;
  final double y;
  final double z;
  final int index;

  const HandLandmark({
    required this.x,
    required this.y,
    required this.z,
    required this.index,
  });
}

/// Custom painter that draws hand landmarks and connections over the camera feed
class HandLandmarkPainter extends CustomPainter {
  final List<HandLandmark> landmarks;
  final Size imageSize;
  final bool isFrontCamera;

  HandLandmarkPainter({
    required this.landmarks,
    required this.imageSize,
    this.isFrontCamera = true,
  });

  // MediaPipe hand connections
  static const List<List<int>> connections = [
    [0, 1], [1, 2], [2, 3], [3, 4],       // Thumb
    [0, 5], [5, 6], [6, 7], [7, 8],       // Index
    [0, 9], [9, 10], [10, 11], [11, 12],  // Middle
    [0, 13], [13, 14], [14, 15], [15, 16], // Ring
    [0, 17], [17, 18], [18, 19], [19, 20], // Pinky
    [5, 9], [9, 13], [13, 17],             // Palm
  ];

  static const Map<int, Color> fingerColors = {
    0: Color(0xFFFFD600), // Wrist - gold
    1: Color(0xFFFF6B35), // Thumb - orange
    2: Color(0xFFFF6B35),
    3: Color(0xFFFF6B35),
    4: Color(0xFFFF6B35),
    5: Color(0xFF00E5FF), // Index - cyan
    6: Color(0xFF00E5FF),
    7: Color(0xFF00E5FF),
    8: Color(0xFF00E5FF),
    9: Color(0xFF69FF47), // Middle - green
    10: Color(0xFF69FF47),
    11: Color(0xFF69FF47),
    12: Color(0xFF69FF47),
    13: Color(0xFFFF4081), // Ring - pink
    14: Color(0xFFFF4081),
    15: Color(0xFFFF4081),
    16: Color(0xFFFF4081),
    17: Color(0xFFAA00FF), // Pinky - purple
    18: Color(0xFFAA00FF),
    19: Color(0xFFAA00FF),
    20: Color(0xFFAA00FF),
  };

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks.isEmpty) return;

    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;

    Offset toScreen(HandLandmark lm) {
      double x = lm.x * imageSize.width * scaleX;
      double y = lm.y * imageSize.height * scaleY;
      if (isFrontCamera) x = size.width - x; // Mirror for front cam
      return Offset(x, y);
    }

    // Draw connections
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final conn in connections) {
      if (conn[0] < landmarks.length && conn[1] < landmarks.length) {
        canvas.drawLine(
          toScreen(landmarks[conn[0]]),
          toScreen(landmarks[conn[1]]),
          linePaint,
        );
      }
    }

    // Draw landmark dots
    for (final lm in landmarks) {
      final pos = toScreen(lm);
      final color = fingerColors[lm.index] ?? Colors.white;
      final isFingerTip = [4, 8, 12, 16, 20].contains(lm.index);

      // Glow effect
      final glowPaint = Paint()
        ..color = color.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(pos, isFingerTip ? 10 : 7, glowPaint);

      // Dot
      final dotPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, isFingerTip ? 6 : 4, dotPaint);

      // White border
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(pos, isFingerTip ? 6 : 4, borderPaint);
    }
  }

  @override
  bool shouldRepaint(HandLandmarkPainter oldDelegate) =>
      oldDelegate.landmarks != landmarks;
}
