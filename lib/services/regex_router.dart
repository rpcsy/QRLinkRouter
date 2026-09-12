import '../data/models/qr_route_result.dart';

/// 一条平台规则
class _PlatformRule {
  final String appName;
  final String scheme;
  final List<RegExp> patterns;

  const _PlatformRule(this.appName, this.scheme, this.patterns);
}

/// 内置正则库：完全本地执行，不消耗任何 token。
///
/// 命中后直接返回 scheme，跳过 LLM 调用。
class RegexRouter {
  RegexRouter._();

  static final List<_PlatformRule> _rules = <_PlatformRule>[
    _PlatformRule('抖音', 'douyin://', <RegExp>[
      RegExp(r'^https?://v\.douyin\.com/', caseSensitive: false),
      RegExp(r'^https?://(www\.)?douyin\.com/', caseSensitive: false),
      RegExp(r'^https?://(www\.)?iesdouyin\.com/', caseSensitive: false),
      RegExp(r'^douyin://', caseSensitive: false),
    ]),
    _PlatformRule('微信', 'weixin://', <RegExp>[
      RegExp(r'^weixin://', caseSensitive: false),
      RegExp(r'^https?://mp\.weixin\.qq\.com/', caseSensitive: false),
      RegExp(r'^https?://(www\.)?weixin\.qq\.com/', caseSensitive: false),
    ]),
    _PlatformRule('支付宝', 'alipays://', <RegExp>[
      RegExp(r'^https?://qr\.alipay\.com/', caseSensitive: false),
      RegExp(r'^https?://(www\.)?alipay\.com/', caseSensitive: false),
      RegExp(r'^alipays://', caseSensitive: false),
      RegExp(r'^alipay://', caseSensitive: false),
    ]),
    _PlatformRule('淘宝', 'taobao://', <RegExp>[
      RegExp(r'^https?://m\.tb\.cn/', caseSensitive: false),
      RegExp(r'^https?://e\.tb\.cn/', caseSensitive: false),
      RegExp(r'^https?://(www\.)?tb\.cn/', caseSensitive: false),
      RegExp(r'^https?://item\.taobao\.com/', caseSensitive: false),
      RegExp(r'^https?://(www\.)?taobao\.com/', caseSensitive: false),
    ]),
    _PlatformRule('B站', 'bilibili://', <RegExp>[
      RegExp(r'^https?://b23\.tv/', caseSensitive: false),
      RegExp(r'^https?://(www\.)?bilibili\.com/', caseSensitive: false),
      RegExp(r'^bilibili://', caseSensitive: false),
    ]),
    _PlatformRule('小红书', 'xhs://', <RegExp>[
      RegExp(r'^https?://xhslink\.com/', caseSensitive: false),
      RegExp(r'^https?://(www\.)?xiaohongshu\.com/', caseSensitive: false),
      RegExp(r'^xhs://', caseSensitive: false),
    ]),
    _PlatformRule('拼多多', 'pinduoduo://', <RegExp>[
      RegExp(r'^https?://mobile\.yangkeduo\.com/', caseSensitive: false),
      RegExp(r'^https?://(www\.)?yangkeduo\.com/', caseSensitive: false),
      RegExp(r'^pinduoduo://', caseSensitive: false),
    ]),
  ];

  /// 全部支持的平台名（用于设置页/文档展示）
  static List<String> get supportedApps =>
      _rules.map((r) => r.appName).toList(growable: false);

  /// 命中返回结果（source = regex），未命中返回 null
  static QrRouteResult? match(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) return null;

    for (final rule in _rules) {
      for (final pattern in rule.patterns) {
        if (pattern.hasMatch(text)) {
          return QrRouteResult(
            appName: rule.appName,
            scheme: rule.scheme,
            rawText: text,
            source: RouteSource.regex,
          );
        }
      }
    }
    return null;
  }
}