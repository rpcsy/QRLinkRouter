import 'package:hive_flutter/hive_flutter.dart';

import '../core/app_constants.dart';
import '../core/logger.dart';
import 'models/qr_route_result.dart';

/// 二维码识别结果本地缓存（Hive）。
///
/// key   = 二维码原始文本（完全相同才算命中）
/// value = {app, scheme, needManualScan, origin, savedAt, rawText}
///
/// 缓存永久保留，直到用户在设置页手动清除。
class QrCacheStore {
  Box<dynamic>? _box;

  bool get isReady => _box != null;

  int get count => _box?.length ?? 0;

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<dynamic>(AppConstants.cacheBoxName);
    AppLog.i('Hive 缓存已打开，现有 ${_box?.length ?? 0} 条');
  }

  /// 命中缓存则返回结果，否则返回 null
  QrRouteResult? lookup(String rawText) {
    final box = _box;
    if (box == null || rawText.isEmpty) return null;
    try {
      return QrRouteResult.fromCacheMap(box.get(rawText), rawText);
    } catch (e) {
      AppLog.e('读取缓存失败', e);
      return null;
    }
  }

  Future<void> save(QrRouteResult result) async {
    final box = _box;
    if (box == null || result.rawText.isEmpty) return;
    try {
      await box.put(result.rawText, result.toCacheMap());
    } catch (e) {
      AppLog.e('写入缓存失败', e);
    }
  }

  Future<void> clear() async {
    final box = _box;
    if (box == null) return;
    try {
      await box.clear();
      AppLog.i('缓存已清空');
    } catch (e) {
      AppLog.e('清空缓存失败', e);
    }
  }
}