import 'package:flutter/material.dart';
import 'package:my_app/core/constants/app_colors.dart';

class DoctorLogo extends StatelessWidget {
  const DoctorLogo({super.key, this.size = 100, this.color = kBrandColor});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _StethoscopeCrossPainter(color: color),
      ),
    );
  }
}

class _StethoscopeCrossPainter extends CustomPainter {
  _StethoscopeCrossPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.045
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Stethoscope loop (circle) around center-left area.
    final loopCenter = Offset(w * 0.40, h * 0.40);
    final loopRadius = w * 0.30;
    canvas.drawCircle(loopCenter, loopRadius, strokePaint);

    // Tubing from the loop down to the earpiece-style end (bottom right).
    final path = Path()
      ..moveTo(loopCenter.dx - loopRadius * 0.05, loopCenter.dy + loopRadius)
      ..cubicTo(
        w * 0.30, h * 0.80,
        w * 0.55, h * 0.92,
        w * 0.80, h * 0.85,
      )
      ..cubicTo(
        w * 0.95, h * 0.80,
        w * 0.95, h * 0.65,
        w * 0.85, h * 0.62,
      );
    canvas.drawPath(path, strokePaint);

    // Chest-piece circle at the end of the tube.
    canvas.drawCircle(Offset(w * 0.85, h * 0.62), w * 0.045, fillPaint);
    canvas.drawCircle(
      Offset(w * 0.85, h * 0.62),
      w * 0.045,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.02,
    );

    // Medical cross centered inside the loop.
    final crossSize = loopRadius * 0.85;
    final crossThickness = crossSize * 0.34;
    final rrect1 = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: loopCenter,
        width: crossThickness,
        height: crossSize,
      ),
      Radius.circular(crossThickness * 0.25),
    );
    final rrect2 = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: loopCenter,
        width: crossSize,
        height: crossThickness,
      ),
      Radius.circular(crossThickness * 0.25),
    );
    canvas.drawRRect(rrect1, fillPaint);
    canvas.drawRRect(rrect2, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _StethoscopeCrossPainter oldDelegate) =>
      oldDelegate.color != color;
}