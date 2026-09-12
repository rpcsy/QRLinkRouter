import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/logger.dart';
import '../data/models/app_settings.dart';
import '../data/models/qr_route_result.dart';
import '../data/qr_cache_store.dart';
import '../services/llm_router.dart';
import '../services/regex_router.dart';
import 'settings_page.dart';
import 'widgets/result_dialog.dart';
import 'widgets/scan_frame_overlay.dart';

/// 扫码主页
class ScanPage extends StatefulWidget {
  const ScanPage({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
    required this.cacheStore,
  });

  final AppSettings settings;
  final Future<void> Function(AppSettings next) onSettingsChanged;
  final QrCacheStore cacheStore;

  @override
  State<ScanPage> createState() => _ScanPageState();
}

/// 一次识别的产出
class _ResolveOutcome {
  const _ResolveOutcome(this.result, {this.aiFailed = false});

  final QrRouteResult result;

  /// true 表示本地正则和 AI 都没识别出来（AI 还被调用过）
  final bool aiFailed;
}

class _ScanPageState extends State<ScanPage> with WidgetsBindingObserver {
  late final MobileScannerController _controller;

  bool _disposed = false;

  /// 正在处理一个二维码（弹窗期间不重复触发）
  bool _handling = false;

  /// 相机权限被拒绝
  bool _permissionDenied = false;
  bool _permissionDialogPending = false;

  /// 去重：同一段文本在冷却期内不重复处理
  String? _lastText;
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _sameCodeCooldown = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
      autoStart: true,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  // ---------- 生命周期：后台暂停相机，回前台恢复 ----------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed || _permissionDenied) return;
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_safeStart());
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        unawaited(_safeStop());
        break;
    }
  }

  Future<void> _safeStart() async {
    try {
      await _controller.start();
    } catch (e) {
      AppLog.e('相机恢复失败', e);
    }
  }

  Future<void> _safeStop() async {
    try {
      await _controller.stop();
    } catch (e) {
      AppLog.e('相机暂停失败', e);
    }
  }

  // ---------- 扫码主流程 ----------

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_disposed || _handling || _permissionDenied) return;

    final String? raw = _firstNonEmptyValue(capture);
    if (raw == null) return; // ⑤ 空 / 无效二维码：静默忽略，继续扫描

    final DateTime now = DateTime.now();
    if (raw == _lastText && now.difference(_lastAt) < _sameCodeCooldown) {
      return;
    }
    _lastText = raw;
    _lastAt = now;

    _handling = true;
    bool aiFailed = false;
    QrRouteResult result;
    try {
      final _ResolveOutcome outcome = await _resolve(raw);
      result = outcome.result;
      aiFailed = outcome.aiFailed;
    } catch (e) {
      AppLog.e('识别流程异常', e);
      result = QrRouteResult(appName: '未知', rawText: raw);
      aiFailed = true;
    }

    if (_disposed || !mounted) {
      _handling = false;
      return;
    }

    // ⑥ 弹窗居中显示，相机预览在弹窗后面继续可见
    try {
      await showQrResultDialog(
        context: context,
        result: result,
        aiFailed: aiFailed,
      );
    } catch (e) {
      AppLog.e('结果弹窗异常', e);
    } finally {
      _handling = false;
    }
  }

  /// 按固定优先级：缓存 → 本地正则 → 大模型 → 兜底
  Future<_ResolveOutcome> _resolve(String raw) async {
    // D（前置）：完全相同的二维码文本直接命中缓存，零 token
    final QrRouteResult? cached = widget.cacheStore.lookup(raw);
    if (cached != null) {
      AppLog.i('缓存命中：${cached.appName}');
      return _ResolveOutcome(cached);
    }

    // B：本地正则，不消耗 token
    final QrRouteResult? byRegex = RegexRouter.match(raw);
    if (byRegex != null) {
      AppLog.i('正则命中：${byRegex.appName}');
      await widget.cacheStore.save(byRegex);
      return _ResolveOutcome(byRegex);
    }

    // C：调用 codex-proxy（OpenAI 兼容接口）
    if (widget.settings.shouldCallLlm) {
      final QrRouteResult? byLlm =
          await LlmRouter.identify(raw, widget.settings);
      if (byLlm != null) {
        AppLog.i('AI 识别成功：${byLlm.appName}');
        await widget.cacheStore.save(byLlm);
        return _ResolveOutcome(byLlm);
      }
      // AI 失败：不写缓存，交给兜底
      return _ResolveOutcome(
        QrRouteResult(appName: '未知', rawText: raw),
        aiFailed: true,
      );
    }

    AppLog.i('AI 开关关闭或未配置，直接走浏览器兜底');
    return _ResolveOutcome(QrRouteResult(appName: '未知', rawText: raw));
  }

  String? _firstNonEmptyValue(BarcodeCapture capture) {
    for (final Barcode barcode in capture.barcodes) {
      final String? value = barcode.rawValue;
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  // ---------- 权限与错误 ----------

  Widget _buildCameraError(
    BuildContext context,
    MobileScannerException error,
    Widget? child,
  ) {
    final bool denied =
        error.errorCode == MobileScannerErrorCode.permissionDenied;
    if (denied) {
      _schedulePermissionFlow();
    }
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                denied ? Icons.no_photography_outlined : Icons.error_outline,
                size: 46,
                color: Colors.white70,
              ),
              const SizedBox(height: 14),
              Text(
                denied
                    ? '未获得相机权限，无法扫描二维码'
                    : '相机启动失败：${error.errorCode.name}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, height: 1.5),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _openSettingsPage,
                child: const Text('前往设置页'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _schedulePermissionFlow() {
    if (_permissionDialogPending || _permissionDenied) return;
    _permissionDialogPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _permissionDialogPending = false;
      if (_disposed || !mounted || _permissionDenied) return;
      _permissionDenied = true;
      await _safeStop();
      if (_disposed || !mounted) return;
      await showDialog<void>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          title: const Text('需要相机权限'),
          content: const Text(
            '需要相机权限来扫描二维码。\n'
            '请到「设置 → 隐私与安全性 → 相机」里允许本 App 使用相机，然后回到本页重新扫描。',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('知道了'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _openSettingsPage();
              },
              child: const Text('去设置'),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _openSettingsPage() async {
    await _safeStop();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext _) => SettingsPage(
          settings: widget.settings,
          onSettingsChanged: widget.onSettingsChanged,
          cacheStore: widget.cacheStore,
        ),
      ),
    );
    if (!mounted || _permissionDenied) return;
    await _safeStart();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ScanVignette(
            child: MobileScanner(
              controller: _controller,
              fit: BoxFit.cover,
              onDetect: _onDetect,
              errorBuilder: _buildCameraError,
            ),
          ),
          const IgnorePointer(
            child: ScanFrameOverlay(
              frameSize: 260,
              hint: '对准二维码进行扫描',
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 6, right: 6),
                child: Material(
                  color: Colors.black38,
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: '设置',
                    onPressed: _openSettingsPage,
                    icon: const Icon(Icons.settings, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}