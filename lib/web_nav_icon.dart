import 'package:material_ui/material_ui.dart';

/// The approved web navigation's 24-unit outline drawings, not platform glyphs.
class WebNavIcon extends StatelessWidget {
  const WebNavIcon(this.index, {super.key});
  final int index;
  @override
  Widget build(BuildContext context) => CustomPaint(
      size: const Size(23, 23),
      painter: _WebNavPainter(
          index, IconTheme.of(context).color ?? const Color(0xFF8B7B88)));
}

class _WebNavPainter extends CustomPainter {
  const _WebNavPainter(this.index, this.color);
  final int index;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final p = Path();
    switch (index) {
      case 0:
        p.moveTo(3, 11);
        p.lineTo(12, 3);
        p.lineTo(21, 11);
        p.moveTo(5, 10);
        p.lineTo(5, 21);
        p.lineTo(10, 21);
        p.lineTo(10, 14);
        p.lineTo(14, 14);
        p.lineTo(14, 21);
        p.lineTo(19, 21);
        p.lineTo(19, 10);
      case 1:
        p.moveTo(8, 3);
        p.lineTo(2, 7);
        p.lineTo(5, 12);
        p.lineTo(8, 10);
        p.lineTo(8, 21);
        p.lineTo(16, 21);
        p.lineTo(16, 10);
        p.lineTo(19, 12);
        p.lineTo(22, 7);
        p.lineTo(16, 3);
        p.arcToPoint(const Offset(8, 3), radius: const Radius.circular(4));
        p.close();
      case 2:
        p.moveTo(12, 2);
        p.lineTo(15, 9);
        p.lineTo(22, 12);
        p.lineTo(15, 15);
        p.lineTo(12, 22);
        p.lineTo(9, 15);
        p.lineTo(2, 12);
        p.lineTo(9, 9);
        p.close();
      case 3:
        p.moveTo(10, 2);
        p.lineTo(14, 2);
        p.lineTo(14, 6);
        p.lineTo(18, 9);
        p.lineTo(16, 14);
        p.lineTo(20, 20);
        p.lineTo(4, 20);
        p.lineTo(8, 14);
        p.lineTo(6, 9);
        p.lineTo(10, 6);
        p.close();
        p.moveTo(8, 14);
        p.lineTo(16, 14);
        p.moveTo(12, 20);
        p.lineTo(12, 23);
        p.moveTo(8, 23);
        p.lineTo(16, 23);
      default:
        canvas.drawCircle(const Offset(12, 7), 4, pen);
        p.moveTo(4, 22);
        p.lineTo(4, 19);
        p.arcToPoint(const Offset(20, 19), radius: const Radius.circular(8));
        p.lineTo(20, 22);
    }
    canvas.drawPath(p, pen);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WebNavPainter oldDelegate) =>
      oldDelegate.index != index || oldDelegate.color != color;
}
