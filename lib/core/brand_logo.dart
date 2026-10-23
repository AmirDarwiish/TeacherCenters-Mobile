import 'package:flutter/material.dart';
import 'brand.dart';

class SentrakLogo extends StatelessWidget {
  const SentrakLogo({
    super.key,
    this.size = 40,
    this.wordmark = true,
    this.inverse = false,
  });
  final double size;
  final bool wordmark, inverse;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'سنترك',
    image: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: Size.square(size),
          painter: SentrakLogoPainter(inverse: inverse),
        ),
        if (wordmark) ...[
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'سنترك',
              style: TextStyle(
                fontFamily: 'Alexandria',
                fontWeight: FontWeight.w700,
                fontSize: 24,
                height: 1.25,
                color: inverse ? BrandColors.white : context.brand.ink,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class SentrakLogoPainter extends CustomPainter {
  const SentrakLogoPainter({this.inverse = false});
  final bool inverse;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 40, size.height / 40);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 40, 40),
        const Radius.circular(12),
      ),
      Paint()..color = inverse ? BrandColors.white : BrandColors.logoBlue,
    );
    final arc = Path()
      ..moveTo(27.5, 12.5)
      ..arcToPoint(
        const Offset(30.5, 20),
        radius: const Radius.circular(10.5),
        largeArc: true,
        clockwise: false,
      );
    canvas.drawPath(
      arc,
      Paint()
        ..color = inverse ? BrandColors.logoBlue : BrandColors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      const Offset(20, 20),
      4,
      Paint()..color = BrandColors.logoCyan,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SentrakLogoPainter oldDelegate) =>
      inverse != oldDelegate.inverse;
}
