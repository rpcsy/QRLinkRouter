import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/qr_route_result.dart';
import '../../services/link_opener.dart';

/// 弹出识别结果弹窗（居中，不遮挡整屏，弹窗后面相机预览仍可见）
Future<void> showQrResultDialog({
  required BuildContext context,
  required QrRouteResult result,
  bool aiFailed = false,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext ctx) =>
        QrResultDialog(result: result, aiFailed: aiFailed),
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

    // 唤起失败：设备未安装目标 App → 提示后浏览器兜底
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

    return AlertDialog(
      title: Row(
        children: <Widget>[
          Icon(
            isUnknown ? Icons.help_outline : Icons.check_circle_outline,
            color: isUnknown ? Colors.orangeAccent : const Color(0xFF3DDC84),
          ),
          const SizedBox(width: 8),
          Text(isUnknown ? '未识别' : '识别成功'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '识别平台：${r.appName}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Text(
              r.rawText,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.white60),
            ),
            const SizedBox(height: 12),
            const Text(
              '【iOS系统限制，唤起App后，请在对应软件内手动点击扫码按钮】',
              style: TextStyle(fontSize: 12, color: Colors.orangeAccent),
            ),
            if (widget.aiFailed) ...<Widget>[
              const SizedBox(height: 8),
              const Text(
                'AI识别失败，将使用浏览器打开原始链接',
                style: TextStyle(fontSize: 12, color: Colors.redAccent),
              ),
            ],
            if (_status != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                _status!,
                style: const TextStyle(fontSize: 13, color: Color(0xFF3DDC84)),
              ),
            ],
          ],
        ),
      ),
      actionsOverflowButtonSpacing: 8,
      actions: <Widget>[
        if (hasScheme)
          FilledButton.icon(
            onPressed: _busy ? null : _openTargetApp,
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('打开对应App'),
          )
        else if (LinkOpener.isHttpUrl(r.rawText))
          FilledButton.icon(
            onPressed: _busy ? null : _openInBrowser,
            icon: const Icon(Icons.public, size: 18),
            label: const Text('用浏览器打开'),
          ),
        OutlinedButton.icon(
          onPressed: _busy ? null : _copyRawText,
          icon: const Icon(Icons.copy, size: 18),
          label: const Text('复制二维码原文'),
        ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}