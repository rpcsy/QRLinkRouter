import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_constants.dart';
import 'models/app_settings.dart';

/// 设置项持久化（shared_preferences）
class SettingsStore {
  static const String _kBaseUrl = 'settings.baseUrl';
  static const String _kApiKey = 'settings.apiKey';
  static const String _kModel = 'settings.model';
  static const String _kAiEnabled = 'settings.aiEnabled';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _ensure() async {
    final cached = _prefs;
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    return prefs;
  }

  Future<AppSettings> load() async {
    final prefs = await _ensure();
    return AppSettings(
      baseUrl: prefs.getString(_kBaseUrl) ?? '',
      apiKey: prefs.getString(_kApiKey) ?? '',
      model: prefs.getString(_kModel) ?? AppConstants.defaultModel,
      aiEnabled: prefs.getBool(_kAiEnabled) ?? true,
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await _ensure();
    await prefs.setString(_kBaseUrl, settings.baseUrl.trim());
    await prefs.setString(_kApiKey, settings.apiKey.trim());
    await prefs.setString(_kModel, settings.model.trim());
    await prefs.setBool(_kAiEnabled, settings.aiEnabled);
  }
}