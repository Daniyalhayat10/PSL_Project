import 'package:flutter/material.dart';

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

class HandLandmarkPainter extends CustomPainter {
  final List<HandLandmark> landmarks;
  final Size imageSize;
  final bool isFrontCamera;

  const HandLandmarkPainter({
    required this.landmarks,
    required this.imageSize,
    this.isFrontCamera = true,
  });

  // Hand skeleton connections (MediaPipe standard)
  static const List<List<int>> connections = [
    // Thumb
    [0, 1], [1, 2], [2, 3], [3, 4],
    // Index
    [0, 5], [5, 6], [6, 7], [7, 8],
    // Middle
    [0, 9], [9, 10], [10, 11], [11, 12],
    // Ring
    [0, 13], [13, 14], [14, 15], [15, 16],
    // Pinky
    [0, 17], [17, 18], [18, 19], [19, 20],
    // Palm
    [5, 9], [9, 13], [13, 17],
  ];

  // Fingertip indices for special highlighting
  static const List<int> fingertips = [4, 8, 12, 16, 20];
  // Knuckle indices
  static const List<int> knuckles = [3, 7, 11, 15, 19];

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks.isEmpty) return;

    final linePaint = Paint()
      ..color = const Color(0xFF00FF88).withOpacity(0.85)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = const Color(0xFF00FF88)
      ..style = PaintingStyle.fill;

    final tipPaint = Paint()
      ..color = const Color(0xFFFFD600)
      ..style = PaintingStyle.fill;

    final wristPaint = Paint()
      ..color = const Color(0xFF00BFFF)
      ..style = PaintingStyle.fill;

    // Map normalised [0,1] coordinates → canvas pixels
    Offset toOffset(HandLandmark lm) {
      double x = lm.x;
      // Mirror X for front camera
      if (isFrontCamera) x = 1.0 - x;
      return Offset(x * size.width, lm.y * size.height);
    }

    final offsets = {for (final lm in landmarks) lm.index: toOffset(lm)};

    // Draw skeleton lines
    for (final conn in connections) {
      final a = offsets[conn[0]];
      final b = offsets[conn[1]];
      if (a != null && b != null) {
        canvas.drawLine(a, b, linePaint);
      }
    }

    // Draw landmark dots
    for (final lm in landmarks) {
      final offset = offsets[lm.index];
      if (offset == null) continue;

      if (lm.index == 0) {
        // Wrist — blue larger dot
        canvas.drawCircle(offset, 7, wristPaint);
        canvas.drawCircle(offset, 7,
            Paint()
              ..color = Colors.white.withOpacity(0.5)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5);
      } else if (fingertips.contains(lm.index)) {
        // Fingertips — yellow
        canvas.drawCircle(offset, 6, tipPaint);
        canvas.drawCircle(offset, 6,
            Paint()
              ..color = Colors.white.withOpacity(0.6)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2);
      } else {
        // Regular joints — green
        canvas.drawCircle(offset, 4, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(HandLandmarkPainter oldDelegate) =>
      oldDelegate.landmarks != landmarks ||
      oldDelegate.isFrontCamera != isFrontCamera;
}
