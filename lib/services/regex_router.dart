import '../data/models/qr_route_result.dart';

/// 一条平台规则
class _PlatformRule {
  const _PlatformRule(this.appName, this.scheme, this.patterns);

  final String appName;
  final String scheme;
  final List<RegExp> patterns;
}

/// 内置正则库：完全本地离线执行，不消耗任何 token。
///
/// 命中后直接返回 scheme，跳过 LLM 调用。
///
/// 修改点2：原有规则全部保留，并追加大量校园类 + 日常通用 App 规则。
/// 注意：列表顺序即匹配优先级，**特例必须排在通用规则前面**，例如：
///   - 企业微信(work.weixin.qq.com) 必须排在 微信(weixin.qq.com) 之前
///   - QQ音乐(y.qq.com)           必须排在 QQ(qq.com) 之前
/// 否则会被通用规则抢先命中。
class RegexRouter {
  RegexRouter._();

  /// 所有规则，越靠前优先级越高
  static final List<_PlatformRule> _rules = <_PlatformRule>[
    // ================= 修改点2：校园类 App（新增） =================
    // 企业微信：必须排在「微信」之前
    _PlatformRule('企业微信', 'workweixin://', <RegExp>[
      RegExp(r'^https?://work\.weixin\.qq\.com/', caseSensitive: false),
      RegExp(r'^https?://[^/]*\.work\.weixin\.qq\.com/', caseSensitive: false),
    ]),
    _PlatformRule('学习通', 'chaoxing://', <RegExp>[
      RegExp(r'^https?://[^/]*chaoxing\.com/', caseSensitive: false),
      RegExp(r'^chaoxing://', caseSensitive: false),
    ]),
    _PlatformRule('趣知校园', 'qzxy://', <RegExp>[
      RegExp(r'^https?://qzxy\.[^/]*\.com/', caseSensitive: false),
      RegExp(r'^qzxy://', caseSensitive: false),
    ]),
    _PlatformRule('胖乖生活', 'pangguai://', <RegExp>[
      RegExp(r'^https?://[^/]*pangguai\.com/', caseSensitive: false),
      RegExp(r'^pangguai://', caseSensitive: false),
    ]),
    _PlatformRule('智慧校园', 'zhxy://', <RegExp>[
      RegExp(r'^https?://zhxy\.[^/]*\.edu\.cn/', caseSensitive: false),
      RegExp(r'^zhxy://', caseSensitive: false),
    ]),
    _PlatformRule('校园一点通', 'xiaoyuanydt://', <RegExp>[
      RegExp(r'^https?://ydt\.[^/]*\.edu\.cn/', caseSensitive: false),
      RegExp(r'^xiaoyuanydt://', caseSensitive: false),
    ]),

    // ================= 原有规则（全部保留） =================
    _PlatformRule('微信', 'weixin://', <RegExp>[
      RegExp(r'^weixin://', caseSensitive: false),
      RegExp(r'^https?://mp\.weixin\.qq\.com/', caseSensitive: false),
      RegExp(r'^https?://(www\.)?weixin\.qq\.com/', caseSensitive: false),
    ]),
    _PlatformRule('抖音', 'douyin://', <RegExp>[
      RegExp(r'^https?://v\.douyin\.com/', caseSensitive: false),
      RegExp(r'^https?://(www\.)?douyin\.com/', caseSensitive: false),
      RegExp(r'^https?://(www\.)?iesdouyin\.com/', caseSensitive: false),
      RegExp(r'^douyin://', caseSensitive: false),
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
      RegExp(r'^https?://[^/]*taobao\.com/', caseSensitive: false),
    ]),
    _PlatformRule('哔哩哔哩', 'bilibili://', <RegExp>[
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

    // ================= 修改点2：日常通用 App（新增） =================
    // QQ音乐：必须排在 QQ 之前
    _PlatformRule('QQ音乐', 'qqmusic://', <RegExp>[
      RegExp(r'^https?://y\.qq\.com/', caseSensitive: false),
      RegExp(r'^https?://[^/]*y\.qq\.com/', caseSensitive: false),
      RegExp(r'^qqmusic://', caseSensitive: false),
    ]),
    _PlatformRule('QQ', 'mqq://', <RegExp>[
      RegExp(r'^https?://(www\.)?qq\.com/', caseSensitive: false),
      RegExp(r'^https?://m\.qq\.com/', caseSensitive: false),
      RegExp(r'^mqq://', caseSensitive: false),
    ]),
    _PlatformRule('钉钉', 'dingtalk://', <RegExp>[
      RegExp(r'^https?://[^/]*dingtalk\.com/', caseSensitive: false),
      RegExp(r'^dingtalk://', caseSensitive: false),
    ]),
    _PlatformRule('飞书', 'lark://', <RegExp>[
      RegExp(r'^https?://[^/]*feishu\.cn/', caseSensitive: false),
      RegExp(r'^https?://[^/]*larksuite\.com/', caseSensitive: false),
      RegExp(r'^lark://', caseSensitive: false),
    ]),
    _PlatformRule('美团', 'meituan://', <RegExp>[
      RegExp(r'^https?://[^/]*meituan\.com/', caseSensitive: false),
      RegExp(r'^https?://[^/]*meituan\.net/', caseSensitive: false),
      RegExp(r'^meituan://', caseSensitive: false),
    ]),
    // 按需求规格：大众点评单独用 dianping://
    _PlatformRule('大众点评', 'dianping://', <RegExp>[
      RegExp(r'^https?://[^/]*dianping\.com/', caseSensitive: false),
      RegExp(r'^dianping://', caseSensitive: false),
    ]),
    _PlatformRule('饿了么', 'eleme://', <RegExp>[
      RegExp(r'^https?://[^/]*ele\.me/', caseSensitive: false),
      RegExp(r'^eleme://', caseSensitive: false),
    ]),
    _PlatformRule('京东', 'jd://', <RegExp>[
      RegExp(r'^https?://[^/]*jd\.com/', caseSensitive: false),
      RegExp(r'^https?://3\.cn/', caseSensitive: false),
      RegExp(r'^openapp\.jd\.com', caseSensitive: false),
    ]),
    _PlatformRule('快手', 'kwai://', <RegExp>[
      RegExp(r'^https?://v\.kuaishou\.com/', caseSensitive: false),
      RegExp(r'^https?://[^/]*kuaishou\.com/', caseSensitive: false),
      RegExp(r'^kwai://', caseSensitive: false),
    ]),
    _PlatformRule('网易云音乐', 'orpheus://', <RegExp>[
      RegExp(r'^https?://music\.163\.com/', caseSensitive: false),
      RegExp(r'^https?://[^/]*\.music\.163\.com/', caseSensitive: false),
      RegExp(r'^orpheus://', caseSensitive: false),
    ]),
    _PlatformRule('高德地图', 'iosamap://', <RegExp>[
      RegExp(r'^https?://[^/]*amap\.com/', caseSensitive: false),
      RegExp(r'^iosamap://', caseSensitive: false),
    ]),
    _PlatformRule('百度地图', 'baidumap://', <RegExp>[
      RegExp(r'^https?://map\.baidu\.com/', caseSensitive: false),
      RegExp(r'^https?://[^/]*map\.baidu\.com/', caseSensitive: false),
      RegExp(r'^baidumap://', caseSensitive: false),
    ]),
    _PlatformRule('携程', 'ctrip://', <RegExp>[
      RegExp(r'^https?://[^/]*ctrip\.com/', caseSensitive: false),
      RegExp(r'^https?://[^/]*trip\.com/', caseSensitive: false),
      RegExp(r'^ctrip://', caseSensitive: false),
    ]),
    _PlatformRule('滴滴出行', 'diditaxi://', <RegExp>[
      RegExp(r'^https?://[^/]*didiglobal\.com/', caseSensitive: false),
      RegExp(r'^https?://[^/]*didichuxing\.com/', caseSensitive: false),
      RegExp(r'^diditaxi://', caseSensitive: false),
    ]),
    _PlatformRule('微博', 'weibo://', <RegExp>[
      RegExp(r'^https?://[^/]*weibo\.com/', caseSensitive: false),
      RegExp(r'^https?://[^/]*weibo\.cn/', caseSensitive: false),
      RegExp(r'^sinaweibo://', caseSensitive: false),
    ]),
    _PlatformRule('知乎', 'zhihu://', <RegExp>[
      RegExp(r'^https?://[^/]*zhihu\.com/', caseSensitive: false),
      RegExp(r'^https?://[^/]*zhihu\.cn/', caseSensitive: false),
      RegExp(r'^zhihu://', caseSensitive: false),
    ]),
    _PlatformRule('酷狗音乐', 'kugou://', <RegExp>[
      RegExp(r'^https?://[^/]*kugou\.com/', caseSensitive: false),
      RegExp(r'^kugou://', caseSensitive: false),
    ]),
    _PlatformRule('招商银行', 'cmbmobilebank://', <RegExp>[
      RegExp(r'^https?://[^/]*cmbchina\.com/', caseSensitive: false),
      RegExp(r'^cmbmobilebank://', caseSensitive: false),
    ]),
    _PlatformRule('交通银行', 'bankcomm://', <RegExp>[
      RegExp(r'^https?://[^/]*bankcomm\.com/', caseSensitive: false),
      RegExp(r'^bankcomm://', caseSensitive: false),
    ]),
    _PlatformRule('建行生活', 'ccblife://', <RegExp>[
      RegExp(r'^https?://[^/]*ccbhome\.cn/', caseSensitive: false),
      RegExp(r'^ccblife://', caseSensitive: false),
    ]),
    _PlatformRule('云闪付', 'uppay://', <RegExp>[
      RegExp(r'^https?://[^/]*yunshanfu\.cn/', caseSensitive: false),
      RegExp(r'^uppay://', caseSensitive: false),
    ]),
  ];

  /// 全部支持的平台名（用于设置页/文档展示）
  static List<String> get supportedApps =>
      _rules.map((_PlatformRule r) => r.appName).toList(growable: false);

  /// 规则条数
  static int get ruleCount => _rules.length;

  /// 命中返回结果（source = regex），未命中返回 null
  static QrRouteResult? match(String rawText) {
    final String text = rawText.trim();
    if (text.isEmpty) return null;

    for (final _PlatformRule rule in _rules) {
      for (final RegExp pattern in rule.patterns) {
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