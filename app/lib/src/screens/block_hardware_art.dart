import 'package:material_ui/material_ui.dart';

import '../models/effect_block.dart';

class BlockHardwareArt extends StatelessWidget {
  const BlockHardwareArt({
    required this.family,
    required this.accent,
    required this.enabled,
    super.key,
  });

  final EffectFamily family;
  final Color accent;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 36,
      child: CustomPaint(
        painter: _BlockHardwarePainter(
          family: family,
          accent: accent,
          enabled: enabled,
        ),
      ),
    );
  }
}

class _BlockHardwarePainter extends CustomPainter {
  const _BlockHardwarePainter({
    required this.family,
    required this.accent,
    required this.enabled,
  });

  final EffectFamily family;
  final Color accent;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    if (family == EffectFamily.amplifier) {
      _paintAmplifier(canvas, size);
    } else if (family == EffectFamily.cabinet) {
      _paintCabinet(canvas, size);
    } else {
      _paintPedal(canvas, size);
    }
  }

  void _paintPedal(Canvas canvas, Size size) {
    final body = Rect.fromLTWH(
      size.width * 0.12, size.height * 0.07,
      size.width * 0.76, size.height * 0.86,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(6)),
      Paint()..color = const Color(0xFF11161D),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(6)),
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    final plate = Rect.fromLTWH(body.left + 4, body.top + 3, body.width - 8, 5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(plate, const Radius.circular(2)),
      Paint()..color = Color.lerp(accent, const Color(0xFF11161D), 0.35)!,
    );
    for (final fraction in const [0.30, 0.50, 0.70]) {
      _drawKnob(
        canvas,
        Offset(body.left + body.width * fraction, body.top + 13),
        3.4,
      );
    }
    canvas.drawCircle(
      Offset(body.right - 7, body.top + 8),
      2,
      Paint()..color = enabled ? const Color(0xFF72F0A8) : const Color(0xFF555D68),
    );
    final footswitch = Offset(body.center.dx, body.bottom - 7);
    canvas.drawCircle(footswitch, 4.8, Paint()..color = const Color(0xFF070A0E));
    canvas.drawCircle(
      footswitch,
      3.4,
      Paint()
        ..color = const Color(0xFF9AA4B2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawCircle(footswitch, 1.7, Paint()..color = const Color(0xFF313943));
  }

  void _paintAmplifier(Canvas canvas, Size size) {
    final body = Rect.fromLTWH(
      size.width * 0.12, size.height * 0.18,
      size.width * 0.76, size.height * 0.78,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(4)),
      Paint()..color = const Color(0xFF242A31),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(4)),
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
    final handle = Rect.fromLTWH(
      size.width * 0.39, size.height * 0.03,
      size.width * 0.22, size.height * 0.17,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(handle, const Radius.circular(3)),
      Paint()..color = const Color(0xFF0B0E12),
    );
    final panel = Rect.fromLTWH(body.left + 4, body.top + 3, body.width - 8, 6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(panel, const Radius.circular(2)),
      Paint()..color = const Color(0xFF0D1116),
    );
    for (final fraction in const [0.28, 0.50, 0.72]) {
      _drawKnob(
        canvas,
        Offset(panel.left + panel.width * fraction, panel.center.dy),
        2.4,
      );
    }
    final grille = Rect.fromLTWH(
      body.left + 4, panel.bottom + 2,
      body.width - 8, body.bottom - panel.bottom - 7,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(grille, const Radius.circular(2)),
      Paint()..color = const Color(0xFF151A20),
    );
    for (var line = 1; line < 7; line++) {
      final y = grille.top + grille.height * line / 7;
      canvas.drawLine(
        Offset(grille.left + 2, y),
        Offset(grille.right - 2, y),
        Paint()
          ..color = const Color(0xFF38424D)
          ..strokeWidth = 0.55,
      );
    }
    canvas.drawCircle(
      grille.center,
      size.height * 0.12,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
  }

  void _paintCabinet(Canvas canvas, Size size) {
    final body = Rect.fromLTWH(
      size.width * 0.20, size.height * 0.04,
      size.width * 0.60, size.height * 0.92,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(3)),
      Paint()..color = const Color(0xFF1A1F26),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(3)),
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
    for (final x in const [0.38, 0.62]) {
      for (final y in const [0.32, 0.68]) {
        final center = Offset(
          body.left + body.width * x,
          body.top + body.height * y,
        );
        canvas.drawCircle(
          center, 5.3,
          Paint()
            ..color = const Color(0xFF303943)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
        canvas.drawCircle(center, 3.7, Paint()..color = const Color(0xFF11161D));
        canvas.drawCircle(center, 1.1, Paint()..color = accent);
      }
    }
  }

  void _drawKnob(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF05080C));
    canvas.drawCircle(
      center,
      radius * 0.67,
      Paint()..color = const Color(0xFF8E99A5),
    );
    canvas.drawLine(
      center,
      Offset(center.dx, center.dy - radius * 0.55),
      Paint()
        ..color = accent
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _BlockHardwarePainter oldDelegate) =>
      oldDelegate.family != family ||
      oldDelegate.accent != accent ||
      oldDelegate.enabled != enabled;
}
