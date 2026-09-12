import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../data/models/qr_route_result.dart';
import '../../services/link_opener.dart';
import 'pressable_scale.dart';

/// 修改点5（过渡动画1）：弹窗改为「缩放 + 淡入」弹出、「淡出 + 缩小」关闭。
///
/// 使用 showGeneralDialog 才能自定义过渡动画；
/// barrierColor 让背景的相机画面轻微变暗，配合毛玻璃形成层次感。
Future<void> showQrResultDialog({
  required BuildContext context,
  required QrRouteResult result,
  bool aiFailed = false,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: '二维码识别结果',
    barrierColor: AppColors.barrier,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (BuildContext ctx, Animation<double> a1, Animation<double> a2) {
      return QrResultDialog(result: result, aiFailed: aiFailed);
    },
    transitionBuilder: (BuildContext ctx, Animation<double> animation,
        Animation<double> secondaryAnimation, Widget child) {
      // 缩放用带回弹的曲线，淡入用平滑曲线，分开处理避免透明度溢出
      final Animation<double> scaleCurve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeIn,
      );
      final Animation<double> fadeCurve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(
        opacity: fadeCurve,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.88, end: 1.0).animate(scaleCurve),
          child: child,
        ),
      );
    },
  );
}

class QrResultDialog extends StatefulWidget {
  const QrResultDialog({
    super.key,
    required this.result,
    this.aiFailed = false,
  });

  final QrRouteResult result;
  final bool aiFailed;

  @override
  State<QrResultDialog> createState() => _QrResultDialogState();
}

class _QrResultDialogState extends State<QrResultDialog> {
  String? _status;
  bool _busy = false;

  Future<void> _openTargetApp() async {
    final String? scheme = widget.result.scheme;
    if (scheme == null || scheme.trim().isEmpty) {
      await _openInBrowser();
      return;
    }

    setState(() {
      _busy = true;
      _status = null;
    });

    final bool ok = await LinkOpener.openScheme(scheme);
    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop();
      return;
    }

    // 唤起失败：设备未安装目标 App → 提示后浏览器兜底（原有逻辑不变）
    setState(() => _status = '未检测到该App，即将在浏览器打开链接');
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    await _openInBrowser();
  }

  Future<void> _openInBrowser() async {
    if (LinkOpener.isHttpUrl(widget.result.rawText)) {
      setState(() => _status = '正在用浏览器打开原始链接…');
      final bool opened = await LinkOpener.openInBrowser(widget.result.rawText);
      if (!mounted) return;
      if (opened) {
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        _busy = false;
        _status = '浏览器打开失败，请检查二维码链接是否有效';
      });
      return;
    }

    setState(() {
      _busy = false;
      _status = '二维码内容不是网址，无法用浏览器打开，请复制原文后手动处理';
    });
  }

  Future<void> _copyRawText() async {
    await Clipboard.setData(ClipboardData(text: widget.result.rawText));
    if (!mounted) return;
    setState(() => _status = '复制完成');
  }

  @override
  Widget build(BuildContext context) {
    final QrRouteResult r = widget.result;
    final bool hasScheme = r.hasScheme;
    final bool isUnknown = r.source == RouteSource.unknown;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 26),
      child: ClipRRect(
        // 修改点5：圆角加大到 24
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          // 修改点5：毛玻璃模糊背景
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.glassCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.glassBorder),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: AppColors.dialogShadow,
                  blurRadius: 28,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // ---- 标题 ----
                Row(
                  children: <Widget>[
                    Icon(
                      isUnknown ? Icons.help_outline : Icons.check_circle_outline,
                      color: isUnknown
                          ? const Color(0xFFFFB300)
                          : AppColors.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isUnknown ? '未识别' : '识别成功',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ---- 识别平台 ----
                Text(
                  '识别平台：${r.appName}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  r.rawText,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),

                // ---- 手动扫码提示 ----
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.infoBlock,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '【iOS系统限制，唤起App后，请在对应软件内手动点击扫码按钮】',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: Color(0xFFFFB300),
                    ),
                  ),
                ),

                // ---- AI 失败提示（兜底，逻辑不变）----
                if (widget.aiFailed) ...<Widget>[
                  const SizedBox(height: 8),
                  const Text(
                    'AI识别失败，将使用浏览器打开原始链接',
                    style: TextStyle(fontSize: 12, color: Color(0xFFE57373)),
                  ),
                ],

                // ---- 状态提示 ----
                if (_status != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    _status!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // ---- 主按钮：按压缩放反馈（修改点5-过渡动画3）----
                if (hasScheme)
                  SizedBox(
                    width: double.infinity,
                    child: PressableScale(
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _openTargetApp,
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text('打开对应App'),
                      ),
                    ),
                  )
                else if (LinkOpener.isHttpUrl(r.rawText))
                  SizedBox(
                    width: double.infinity,
                    child: PressableScale(
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _openInBrowser,
                        icon: const Icon(Icons.public, size: 18),
                        label: const Text('用浏览器打开'),
                      ),
                    ),
                  ),

                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: PressableScale(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _copyRawText,
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text('复制二维码原文'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    PressableScale(
                      child: TextButton(
                        onPressed:
                            _busy ? null : () => Navigator.of(context).pop(),
                        child: const Text('关闭'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}