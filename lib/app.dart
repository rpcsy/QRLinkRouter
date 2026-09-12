import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'data/models/app_settings.dart';
import 'data/qr_cache_store.dart';
import 'data/settings_store.dart';
import 'ui/scan_page.dart';

/// 应用根节点：持有全局设置，向下传递给扫码页和设置页。
class QRLinkRouterApp extends StatefulWidget {
  const QRLinkRouterApp({
    super.key,
    required this.settingsStore,
    required this.cacheStore,
    required this.initialSettings,
  });

  final SettingsStore settingsStore;
  final QrCacheStore cacheStore;
  final AppSettings initialSettings;

  @override
  State<QRLinkRouterApp> createState() => _QRLinkRouterAppState();
}

class _QRLinkRouterAppState extends State<QRLinkRouterApp> {
  late AppSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
  }

  Future<void> _updateSettings(AppSettings next) async {
    setState(() => _settings = next);
    await widget.settingsStore.save(next);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QRLinkRouter',
      debugShowCheckedModeBanner: false,
      // 修改点5：统一使用新的深色主题
      theme: AppTheme.dark(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      home: ScanPage(
        settings: _settings,
        onSettingsChanged: _updateSettings,
        cacheStore: widget.cacheStore,
      ),
    );
  }
}