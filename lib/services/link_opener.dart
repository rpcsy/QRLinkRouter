import 'package:url_launcher/url_launcher.dart';

import '../core/logger.dart';

/// 一次唤起尝试的结果（带诊断信息，方便排查「点了没反应」）
class OpenResult {
  const OpenResult({required this.ok, this.used, this.detail = ''});

  final bool ok;

  /// 成功时实际生效的 scheme
  final String? used;

  /// 诊断文本，失败时展示给用户
  final String detail;
}

/// 通过 url_launcher（iOS: UIApplication.openURL）唤起其他 App 或用 Safari 打开链接。
class LinkOpener {
  LinkOpener._();

  /// 【本次修复的核心】不再用 canLaunchUrl 做前置拦截。
  ///
  /// url_launcher_ios 的原生实现是：
  ///   canLaunchUrl -> UIApplication.shared.canOpenURL(url)
  ///   launchUrl    -> UIApplication.shared.open(url, options: ...)
  ///
  /// canOpenURL 受 LSApplicationQueriesSchemes 白名单影响，行为并不稳定，
  /// 一旦误报 false，老代码就直接 return，根本不会走到真正的打开动作，
  /// 表现出来就是「装了 App 也跳不过去」。
  /// 而 open 不需要白名单，所以这里改为**直接调用 launchUrl**，失败再回退。
  static Future<OpenResult> openScheme(String scheme) async {
    final String text = scheme.trim();
    if (text.isEmpty) {
      return const OpenResult(ok: false, detail: 'scheme 为空');
    }
    try {
      final Uri uri = Uri.parse(text);
      final bool ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (ok) {
        return OpenResult(ok: true, used: text, detail: 'launchUrl=true');
      }
      // 失败后再取一次 canOpenURL，仅用于诊断展示
      bool can = false;
      try {
        can = await canLaunchUrl(uri);
      } catch (_) {
        can = false;
      }
      return OpenResult(ok: false, detail: 'launchUrl=false, canOpenURL=$can');
    } catch (e) {
      AppLog.e('唤起异常: $text', e);
      return OpenResult(ok: false, detail: '异常: $e');
    }
  }

  /// 依次尝试多个候选 scheme，返回第一个成功的
  static Future<OpenResult> openSchemes(List<String> schemes) async {
    final List<String> candidates = <String>[];
    for (final String s in schemes) {
      final String v = s.trim();
      if (v.isNotEmpty && !candidates.contains(v)) candidates.add(v);
    }
    if (candidates.isEmpty) {
      return const OpenResult(ok: false, detail: '没有可用的 scheme');
    }

    final List<String> tried = <String>[];
    String lastDetail = '';
    for (final String c in candidates) {
      final OpenResult r = await openScheme(c);
      if (r.ok) {
        return OpenResult(
          ok: true,
          used: c,
          detail: '已用 $c 唤起${candidates.length > 1 ? '（第 ${tried.length + 1} 个候选）' : ''}',
        );
      }
      tried.add(c);
      lastDetail = r.detail;
    }
    return OpenResult(
      ok: false,
      detail: '候选 ${tried.join(' / ')} 均失败；$lastDetail',
    );
  }

  /// 用系统浏览器打开原始链接（仅 http/https 有效）
  ///
  /// 注意：如果目标 App 注册了该域名的 Universal Link，
  /// iOS 会先把链接交给 App 而不是 Safari，这也是一条可用的跳转路径。
  static Future<bool> openInBrowser(String rawText) async {
    final String text = rawText.trim();
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
    final String text = rawText.trim();
    if (text.isEmpty) return false;
    final Uri? uri = Uri.tryParse(text);
    if (uri == null) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }
}