import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_constants.dart';
import '../core/app_theme.dart';
import '../data/models/app_settings.dart';
import '../data/qr_cache_store.dart';
import '../services/link_opener.dart';
import '../services/regex_router.dart';
import 'widgets/pressable_scale.dart';

/// 设置页面
///
/// 修改点5：整体适配新的深色主题（#121212 背景 / #1E1E1E 卡片 / #2979FF 主色），
/// 输入框、开关、说明块、按钮统一样式，并加入按压缩放反馈。
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
    required this.cacheStore,
  });

  final AppSettings settings;
  final Future<void> Function(AppSettings next) onSettingsChanged;
  final QrCacheStore cacheStore;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _baseUrlCtrl;
  late final TextEditingController _apiKeyCtrl;
  late final TextEditingController _modelCtrl;
  late bool _aiEnabled;
  bool _obscureKey = true;
  Timer? _debounce;
  int _cacheCount = 0;

  // ---- 跳转测试（排障用）----
  late final TextEditingController _probeCtrl;
  String? _probeResult;
  bool _probing = false;

  @override
  void initState() {
    super.initState();
    final AppSettings s = widget.settings;
    _baseUrlCtrl = TextEditingController(text: s.baseUrl);
    _apiKeyCtrl = TextEditingController(text: s.apiKey);
    _modelCtrl = TextEditingController(text: s.model);
    _aiEnabled = s.aiEnabled;
    _cacheCount = widget.cacheStore.count;
    _probeCtrl = TextEditingController(text: 'weixin://');

    _baseUrlCtrl.addListener(_onFieldChanged);
    _apiKeyCtrl.addListener(_onFieldChanged);
    _modelCtrl.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _baseUrlCtrl.removeListener(_onFieldChanged);
    _apiKeyCtrl.removeListener(_onFieldChanged);
    _modelCtrl.removeListener(_onFieldChanged);
    unawaited(_flush());
    _baseUrlCtrl.dispose();
    _apiKeyCtrl.dispose();
    _modelCtrl.dispose();
    _probeCtrl.dispose();
    super.dispose();
  }

  // ---------- 保存（原有逻辑不变） ----------

  void _onFieldChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(_flush());
    });
  }

  Future<void> _flush() async {
    final String model = _modelCtrl.text.trim();
    final AppSettings next = AppSettings(
      baseUrl: _baseUrlCtrl.text.trim(),
      apiKey: _apiKeyCtrl.text.trim(),
      model: model.isEmpty ? AppConstants.defaultModel : model,
      aiEnabled: _aiEnabled,
    );
    await widget.onSettingsChanged(next);
  }

  Future<void> _setAiEnabled(bool value) async {
    setState(() => _aiEnabled = value);
    await _flush();
  }

  // ---------- 清除缓存（原有逻辑不变） ----------

  Future<void> _confirmClearCache() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('清除本地二维码缓存'),
        content: Text(
          '将删除本机保存的全部 $_cacheCount 条识别记录。\n\n'
          '清除后再次扫描相同二维码会重新走正则或 AI 识别，可能消耗 token。',
          style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          PressableScale(
            child: FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('确认清除'),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await widget.cacheStore.clear();
    if (!mounted) return;
    setState(() => _cacheCount = widget.cacheStore.count);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('本地缓存已清空')),
    );
  }

  /// 跳转测试：直接调用 launchUrl，把真实返回值显示出来。
  /// 用来判断"跳不动"到底出在 scheme 不对、App 没装、还是被系统拦了。
  Future<void> _runProbe() async {
    final String scheme = _probeCtrl.text.trim();
    if (scheme.isEmpty) {
      setState(() => _probeResult = '请输入一个 scheme，例如 weixin://');
      return;
    }
    setState(() {
      _probing = true;
      _probeResult = '正在尝试 $scheme …';
    });
    final OpenResult r = await LinkOpener.openScheme(scheme);
    if (!mounted) return;
    setState(() {
      _probing = false;
      _probeResult = r.ok
          ? '唤起成功：$scheme\n（${r.detail}）'
          : '唤起失败：$scheme\n${r.detail}\n\n若 canOpenURL=false 且 App 确实已安装，请检查 Info.plist 白名单。';
    });
  }

  Future<void> _goBack() async {
    _debounce?.cancel();
    await _flush();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  /// 统一输入框样式（修改点5）
  InputDecoration _decoration({
    required String label,
    required IconData icon,
    String? hint,
    String? helper,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      helperStyle: const TextStyle(color: AppColors.textFaint, fontSize: 11.5),
      prefixIcon: Icon(icon, color: AppColors.textSecondary),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.inputFill,
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      hintStyle: const TextStyle(color: AppColors.textFaint),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          tooltip: '返回扫码主页',
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          _sectionTitle('接口配置'),
          TextField(
            controller: _baseUrlCtrl,
            keyboardType: TextInputType.url,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: _decoration(
              label: 'API接口地址',
              icon: Icons.link,
              hint: AppConstants.baseUrlHint,
              helper: 'codex-proxy 地址，OpenAI 兼容格式，结尾一般带 /v1',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _apiKeyCtrl,
            obscureText: _obscureKey,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: _decoration(
              label: 'API Key',
              icon: Icons.key,
              suffix: IconButton(
                tooltip: _obscureKey ? '显示' : '隐藏',
                icon: Icon(
                  _obscureKey ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => setState(() => _obscureKey = !_obscureKey),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _modelCtrl,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: _decoration(
              label: '模型名称',
              icon: Icons.memory,
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _aiEnabled,
            onChanged: _setAiEnabled,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.primary,
            title: const Text(
              '启用AI识别',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            subtitle: const Text(
              '关闭后完全不调用任何大模型接口，只使用本地正则匹配',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
            ),
          ),
          const Divider(height: 32, color: AppColors.divider),
          _sectionTitle('本地数据'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.storage, color: AppColors.textSecondary),
            title: const Text(
              '清除本地二维码缓存',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            subtitle: Text(
              '当前已缓存 $_cacheCount 条识别记录',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
            ),
            trailing: const Icon(Icons.chevron_right, color: AppColors.textFaint),
            onTap: _confirmClearCache,
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.infoBlock,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: const Text(
              '说明：AI识别仅用于本地正则无法识别的二维码，识别结果会保存在本机缓存节省token。\n'
              'iOS系统限制：本软件仅能唤起目标App，无法自动完成扫码，打开App后需要您手动点击扫码。',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.6,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.infoBlock,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Text(
              '本地已内置 ${RegexRouter.ruleCount} 条平台识别规则，命中即离线跳转，不消耗 token。',
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.6,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _sectionTitle('跳转测试（排障用）'),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _probeCtrl,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: _decoration(
                    label: '测试 scheme',
                    icon: Icons.bug_report,
                    helper: '例如 weixin:// 、alipays:// 、taobao://' ,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              PressableScale(
                child: FilledButton(
                  onPressed: _probing ? null : _runProbe,
                  child: const Text('测试'),
                ),
              ),
            ],
          ),
          if (_probeResult != null) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.infoBlock,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Text(
                _probeResult!,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 28),
          const Center(
            child: Text(
              'QRLinkRouter  v${AppConstants.appVersion}',
              style: TextStyle(fontSize: 12, color: AppColors.textFaint),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
