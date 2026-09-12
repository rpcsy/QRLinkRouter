import 'package:flutter/material.dart';

import 'app.dart';
import 'core/logger.dart';
import 'data/models/app_settings.dart';
import 'data/qr_cache_store.dart';
import 'data/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final SettingsStore settingsStore = SettingsStore();
  final QrCacheStore cacheStore = QrCacheStore();

  AppSettings settings = const AppSettings();
  try {
    settings = await settingsStore.load();
  } catch (e) {
    AppLog.e('读取设置失败', e);
  }

  try {
    await cacheStore.init();
  } catch (e) {
    AppLog.e('初始化 Hive 缓存失败', e);
  }

  runApp(
    QRLinkRouterApp(
      settingsStore: settingsStore,
      cacheStore: cacheStore,
      initialSettings: settings,
    ),
  );
}