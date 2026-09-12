import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 半透明取景框 + 四角定位标记。
class ScanFrameOverlay extends StatelessWidget {
  const ScanFrameOverlay({super.key, this.frameSize = 260, this.hint});

  /// 取景框边长
  final double frameSize;

  /// 取景框下方提示文字
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SizedBox.expand(
          child: CustomPaint(
            painter: _ScanFramePainter(frameSize: frameSize, hint: hint),
          ),
        );
      },
    );
  }
}

class _ScanFramePainter extends CustomPainter {
  _ScanFramePainter({required this.frameSize, this.hint});

  final double frameSize;

  /// 取景框下方提示文字
  final String? hint;

  static const double _radius = 16;
  static const double _cornerLength = 34;
  static const double _cornerWidth = 4.5;
  static const Color _cornerColor = Color(0xFF3DDC84);

  @override
  void paint(Canvas canvas, Size size) {
    final Rect frame = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 - 30),
      width: frameSize,
      height: frameSize,
    );

    // 1) 遮罩：整屏半透明黑，中间挖空
    final Path scrim = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(frame, const Radius.circular(_radius)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(scrim, Paint()..color = const Color(0x99000000));

    // 2) 取景框描边
    canvas.drawRRect(
      RRect.fromRectAndRadius(frame, const Radius.circular(_radius)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0x66FFFFFF),
    );

    // 3) 四角定位标记
    final Paint cornerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _cornerWidth
      ..strokeCap = StrokeCap.round
      ..color = _cornerColor;

    final double len = math.min(_cornerLength, frameSize / 3);
    final Path corners = Path()
      // 左上
      ..moveTo(frame.left, frame.top + len)
      ..lineTo(frame.left, frame.top + _radius)
      ..quadraticBezierTo(
          frame.left, frame.top, frame.left + _radius, frame.top)
      ..lineTo(frame.left + len, frame.top)
      // 右上
      ..moveTo(frame.right - len, frame.top)
      ..lineTo(frame.right - _radius, frame.top)
      ..quadraticBezierTo(
          frame.right, frame.top, frame.right, frame.top + _radius)
      ..lineTo(frame.right, frame.top + len)
      // 右下
      ..moveTo(frame.right, frame.bottom - len)
      ..lineTo(frame.right, frame.bottom - _radius)
      ..quadraticBezierTo(
          frame.right, frame.bottom, frame.right - _radius, frame.bottom)
      ..lineTo(frame.right - len, frame.bottom)
      // 左下
      ..moveTo(frame.left + len, frame.bottom)
      ..lineTo(frame.left + _radius, frame.bottom)
      ..quadraticBezierTo(
          frame.left, frame.bottom, frame.left, frame.bottom - _radius)
      ..lineTo(frame.left, frame.bottom - len);

    canvas.drawPath(corners, cornerPaint);

    // 4) 取景框下方提示文字（保留系统字体，不使用任何私有 API）
    final String? text = hint;
    if (text != null && text.isNotEmpty) {
      final TextPainter painter = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
            shadows: <Shadow>[
              Shadow(color: Color(0xAA000000), blurRadius: 6),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width - 48);

      painter.paint(
        canvas,
        Offset(
          (size.width - painter.width) / 2,
          frame.bottom + 22,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScanFramePainter oldDelegate) {
    return oldDelegate.frameSize != frameSize || oldDelegate.hint != hint;
  }
}

/// 顶部/底部轻微渐隐，让取景框更聚焦（纯绘制，无外部依赖）
class ScanVignette extends StatelessWidget {
  const ScanVignette({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        child,
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0x99000000),
                  Color(0x00000000),
                  Color(0x00000000),
                  Color(0x99000000),
                ],
                stops: <double>[0.0, 0.18, 0.72, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

