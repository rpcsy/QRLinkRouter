import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/app_constants.dart';
import '../core/app_theme.dart';
import '../core/logger.dart';
import '../data/models/app_settings.dart';
import '../data/models/qr_route_result.dart';
import '../data/qr_cache_store.dart';
import '../services/llm_router.dart';
import '../services/regex_router.dart';
import 'settings_page.dart';
import 'widgets/app_page_route.dart';
import 'widgets/pressable_scale.dart';
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

  // ===================== 修改点1：扫码防抖锁 =====================
  /// 识别到二维码后置 true（同时暂停扫描器），弹窗关闭后置 false 并恢复扫码。
  /// 这个锁是「扫一次之后不能扫第二次」BUG 的核心修复点之一。
  bool _isProcessing = false;

  /// 用户主动暂停（进入设置页、退到后台）时置 true，
  /// 避免相机看门狗把这些场景下"正常的停止"误判成异常并强行拉起相机。
  bool _userPaused = false;

  // ===================== 修改点1：相机看门狗 =====================
  Timer? _watchdog;

  /// 相机权限被拒绝
  bool _permissionDenied = false;
  bool _permissionDialogPending = false;

  /// 同一个二维码文本的抑制窗口。
  /// 弹窗关闭、相机重启后，同一个二维码在 2 秒内不再重复弹窗（防止死循环），
  /// 但**换一个二维码可以立刻识别**，这正是原先缺失的能力。
  static const Duration _sameTextSuppress = Duration(seconds: 2);

  String? _lastText;
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 修改点1：把 detectionSpeed 从 noDuplicates 改成 normal。
    // noDuplicates 会让插件在整段会话里对同一个码值不再回调，
    // 关掉弹窗后就再也扫不动了；改为 normal 后由我们自己的
    // _isProcessing 锁 + 定时停止/重启扫描器来控制重复识别。
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
      autoStart: true,
    );

    _startWatchdog();
  }

  @override
  void dispose() {
    _disposed = true;
    _watchdog?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  // ================= 修改点1-4：相机异常自动重启（看门狗） =================

  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer.periodic(AppConstants.cameraWatchdogInterval, (Timer _) {
      unawaited(_checkCameraAlive());
    });
  }

  /// 相机意外停止（被系统回收、被其他 App 抢占、插件异常）时自动重启预览
  Future<void> _checkCameraAlive() async {
    if (_disposed || !mounted) return;
    if (_permissionDenied || _isProcessing || _userPaused) return;
    try {
      if (!_controller.value.isRunning) {
        AppLog.i('看门狗：相机未运行，自动重启预览');
        await _safeStart();
      }
    } catch (e) {
      AppLog.e('看门狗检查失败', e);
    }
  }

  // ================= 修改点1-3：生命周期（退后台暂停 / 回前台恢复） =================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed || _permissionDenied) return;
    switch (state) {
      case AppLifecycleState.resumed:
        // 回到前台：只有在没有弹窗、不在设置页时才恢复
        if (!_isProcessing && !_userPaused) {
          unawaited(_safeStart());
        }
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
    if (_disposed) return;
    try {
      await _controller.start();
    } catch (e) {
      AppLog.e('相机恢复失败', e);
    }
  }

  Future<void> _safeStop() async {
    if (_disposed) return;
    try {
      await _controller.stop();
    } catch (e) {
      AppLog.e('相机暂停失败', e);
    }
  }

  // ===================== 扫码主流程 =====================

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_disposed || _isProcessing || _permissionDenied || _userPaused) return;

    final String? raw = _firstNonEmptyValue(capture);
    if (raw == null) return; // 空 / 无效二维码：静默忽略，继续扫描

    // 同一个文本在抑制窗口内不重复处理
    final DateTime now = DateTime.now();
    if (raw == _lastText && now.difference(_lastAt) < _sameTextSuppress) {
      return;
    }

    // ===================== 修改点1：核心修复开始 =====================
    // 1) 上锁，防止弹窗期间被重复触发
    _isProcessing = true;
    // 2) 立刻暂停扫描器，避免相机持续回调
    await _safeStop();

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
      _isProcessing = false;
      return;
    }

    try {
      // 3) 弹窗期间相机保持暂停，关掉弹窗后再恢复
      await showQrResultDialog(
        context: context,
        result: result,
        aiFailed: aiFailed,
      );
    } catch (e) {
      AppLog.e('结果弹窗异常', e);
    } finally {
      // 4) 解锁 + 重启扫描器 → 允许继续扫描下一个二维码
      _isProcessing = false;
      _lastText = raw;
      _lastAt = DateTime.now();
      if (!_disposed && !_permissionDenied && !_userPaused) {
        await _safeStart();
      }
    }
    // ===================== 修改点1：核心修复结束 =====================
  }

  /// 按固定优先级：缓存 → 本地正则 → 大模型 → 兜底（原有逻辑不变）
  Future<_ResolveOutcome> _resolve(String raw) async {
    // 缓存优先：完全相同的二维码文本直接命中，零 token
    final QrRouteResult? cached = widget.cacheStore.lookup(raw);
    if (cached != null) {
      AppLog.i('缓存命中：${cached.appName}');
      return _ResolveOutcome(cached);
    }

    // 本地正则，不消耗 token
    final QrRouteResult? byRegex = RegexRouter.match(raw);
    if (byRegex != null) {
      AppLog.i('正则命中：${byRegex.appName}');
      await widget.cacheStore.save(byRegex);
      return _ResolveOutcome(byRegex);
    }

    // 调 codex-proxy（OpenAI 兼容接口）
    if (widget.settings.shouldCallLlm) {
      final QrRouteResult? byLlm =
          await LlmRouter.identify(raw, widget.settings);
      if (byLlm != null) {
        AppLog.i('AI 识别成功：${byLlm.appName}');
        await widget.cacheStore.save(byLlm);
        return _ResolveOutcome(byLlm);
      }
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

  // ===================== 权限与错误 =====================

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
      color: AppColors.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                denied ? Icons.no_photography_outlined : Icons.error_outline,
                size: 46,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 14),
              Text(
                denied
                    ? '未获得相机权限，无法扫描二维码'
                    : '相机启动失败：${error.errorCode.name}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              PressableScale(
                child: FilledButton(
                  onPressed: _openSettingsPage,
                  child: const Text('前往设置页'),
                ),
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
            PressableScale(
              child: FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _openSettingsPage();
                },
                child: const Text('去设置'),
              ),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _openSettingsPage() async {
    // 进设置页时主动暂停相机，并让看门狗别把它拉起来
    _userPaused = true;
    await _safeStop();
    if (!mounted) return;
    // 修改点5（过渡动画）：使用滑动 + 淡入的自定义路由
    await Navigator.of(context).push(
      SlideFadeRoute<void>(
        page: SettingsPage(
          settings: widget.settings,
          onSettingsChanged: widget.onSettingsChanged,
          cacheStore: widget.cacheStore,
        ),
      ),
    );
    if (!mounted) return;
    _userPaused = false;
    if (_permissionDenied) return;
    await _safeStart();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
                child: PressableScale(
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
          ),
        ],
      ),
    );
  }
}