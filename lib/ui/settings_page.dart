import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_constants.dart';
import '../data/models/app_settings.dart';
import '../data/qr_cache_store.dart';

/// 设置页面
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

  @override
  void initState() {
    super.initState();
    final AppSettings s = widget.settings;
    _baseUrlCtrl = TextEditingController(text: s.baseUrl);
    _apiKeyCtrl = TextEditingController(text: s.apiKey);
    _modelCtrl = TextEditingController(text: s.model);
    _aiEnabled = s.aiEnabled;
    _cacheCount = widget.cacheStore.count;

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
    super.dispose();
  }

  // ---------- 保存 ----------

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

  // ---------- 清除缓存 ----------

  Future<void> _confirmClearCache() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('清除本地二维码缓存'),
        content: Text(
          '将删除本机保存的全部 $_cacheCount 条识别记录。\n\n'
          '清除后再次扫描相同二维码会重新走正则或 AI 识别，可能消耗 token。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认清除'),
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

  Future<void> _goBack() async {
    _debounce?.cancel();
    await _flush();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            decoration: const InputDecoration(
              labelText: 'API接口地址',
              hintText: AppConstants.baseUrlHint,
              prefixIcon: Icon(Icons.link),
              border: OutlineInputBorder(),
              helperText: 'codex-proxy 地址，OpenAI 兼容格式，结尾一般带 /v1',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _apiKeyCtrl,
            obscureText: _obscureKey,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'API Key',
              prefixIcon: const Icon(Icons.key),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: _obscureKey ? '显示' : '隐藏',
                icon: Icon(
                  _obscureKey ? Icons.visibility_off : Icons.visibility,
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
            decoration: const InputDecoration(
              labelText: '模型名称',
              prefixIcon: Icon(Icons.memory),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _aiEnabled,
            onChanged: _setAiEnabled,
            title: const Text('启用AI识别'),
            subtitle: const Text('关闭后完全不调用任何大模型接口，只使用本地正则匹配'),
          ),
          const Divider(height: 32),
          _sectionTitle('本地数据'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.storage),
            title: const Text('清除本地二维码缓存'),
            subtitle: Text('当前已缓存 $_cacheCount 条识别记录'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _confirmClearCache,
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '说明：AI识别仅用于本地正则无法识别的二维码，识别结果会保存在本机缓存节省token。\n'
              'iOS系统限制：本软件仅能唤起目标App，无法自动完成扫码，打开App后需要您手动点击扫码。',
              style: TextStyle(fontSize: 12.5, height: 1.6, color: Colors.white70),
            ),
          ),
          const SizedBox(height: 28),
          const Center(
            child: Text(
              'QRLinkRouter  v${AppConstants.appVersion}',
              style: TextStyle(fontSize: 12, color: Colors.white38),
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
          color: Color(0xFF3DDC84),
        ),
      ),
    );
  }
}