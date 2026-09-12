import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

/// 修改点5：取景框改为有状态组件，加入「缓慢呼吸」动画引导用户对准二维码。
///
/// - 边角使用主题主色 #2979FF 高亮
/// - 呼吸时主色描边的亮度/粗细轻微起伏（周期 1.8 秒，来回往复）
/// - 全屏半透明蒙版，仅取景框内部透明
class ScanFrameOverlay extends StatefulWidget {
  const ScanFrameOverlay({super.key, this.frameSize = 260, this.hint});

  /// 取景框边长
  final double frameSize;

  /// 取景框下方提示文字
  final String? hint;

  @override
  State<ScanFrameOverlay> createState() => _ScanFrameOverlayState();
}

class _ScanFrameOverlayState extends State<ScanFrameOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath;

  @override
  void initState() {
    super.initState();
    // 修改点5：呼吸动画，1.8 秒一个来回，无限循环
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: AnimatedBuilder(
        animation: _breath,
        builder: (BuildContext context, Widget? child) {
          return CustomPaint(
            painter: _ScanFramePainter(
              frameSize: widget.frameSize,
              hint: widget.hint,
              // 0 → 1 往复，映射成柔和的正弦曲线，避免生硬的线性呼吸
              breath: Curves.easeInOut.transform(_breath.value),
            ),
          );
        },
      ),
    );
  }
}

class _ScanFramePainter extends CustomPainter {
  _ScanFramePainter({
    required this.frameSize,
    required this.breath,
    this.hint,
  });

  final double frameSize;

  /// 呼吸进度 0..1
  final double breath;

  /// 取景框下方提示文字
  final String? hint;

  static const double _radius = 20;
  static const double _cornerLength = 34;
  static const double _cornerWidth = 4.5;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect frame = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 - 30),
      width: frameSize,
      height: frameSize,
    );

    // 1) 蒙版：整屏半透明黑，中间挖空（仅取景框区域透明）
    final Path scrim = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(frame, const Radius.circular(_radius)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(scrim, Paint()..color = const Color(0x99000000));

    // 2) 取景框描边（主色，随呼吸微微变亮）
    canvas.drawRRect(
      RRect.fromRectAndRadius(frame, const Radius.circular(_radius)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0x33FFFFFF),
    );

    // 3) 四角定位标记：主题主色高亮 + 呼吸发光
    final Color cornerColor = Color.lerp(
      AppColors.primary,
      const Color(0xFF7FB0FF),
      breath,
    )!;
    final Paint cornerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _cornerWidth + breath * 0.8
      ..strokeCap = StrokeCap.round
      ..color = cornerColor;

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

    // 4) 取景框下方提示文字
    final String? text = hint;
    if (text != null && text.isNotEmpty) {
      final TextPainter painter = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            color: AppColors.textPrimary,
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
        Offset((size.width - painter.width) / 2, frame.bottom + 22),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScanFramePainter oldDelegate) {
    return oldDelegate.frameSize != frameSize ||
        oldDelegate.hint != hint ||
        oldDelegate.breath != breath;
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