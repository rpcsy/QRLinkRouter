import 'package:url_launcher/url_launcher.dart';

import '../core/logger.dart';

/// 通过 url_launcher（iOS: UIApplication.openURL）唤起其他 App 或用 Safari 打开链接。
class LinkOpener {
  LinkOpener._();

  /// 用 URL Scheme 唤起目标 App。
  ///
  /// 返回 false 表示设备未安装该 App 或系统拒绝唤起。
  static Future<bool> openScheme(String scheme) async {
    final text = scheme.trim();
    if (text.isEmpty) return false;
    try {
      final Uri uri = Uri.parse(text);
      if (!await canLaunchUrl(uri)) {
        AppLog.i('canLaunchUrl = false: $text');
        return false;
      }
      final bool ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      AppLog.i('launchUrl($text) = $ok');
      return ok;
    } catch (e) {
      AppLog.e('唤起失败: $text', e);
      return false;
    }
  }

  /// 用系统浏览器打开原始链接（仅 http/https 有效）
  static Future<bool> openInBrowser(String rawText) async {
    final text = rawText.trim();
    if (!isHttpUrl(text)) return false;
    try {
      final Uri uri = Uri.parse(text);
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      AppLog.e('浏览器打开失败: $text', e);
      return false;
    }
  }

  /// 判断文本是否为 http/https 链接
  static bool isHttpUrl(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) return false;
    final Uri? uri = Uri.tryParse(text);
    if (uri == null) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }
}