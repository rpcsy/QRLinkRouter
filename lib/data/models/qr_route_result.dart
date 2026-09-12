/// 识别结果来源，用于区分是缓存命中、本地正则还是大模型。
enum RouteSource {
  cache, // 命中本地 Hive 缓存
  regex, // 命中内置正则库
  llm, // 大模型识别成功
  unknown, // 全部失败，走浏览器兜底
}

extension RouteSourceLabel on RouteSource {
  String get label {
    switch (this) {
      case RouteSource.cache:
        return '本地缓存';
      case RouteSource.regex:
        return '本地正则';
      case RouteSource.llm:
        return 'AI 识别';
      case RouteSource.unknown:
        return '未识别';
    }
  }
}

/// 一次二维码识别的完整结果。
class QrRouteResult {
  /// 识别出来的应用名称，未识别时为「未知」
  final String appName;

  /// 主 iOS URL Scheme，例如 douyin://；未识别时为 null 或空串
  final String? scheme;

  /// 候选备用 scheme。
  ///
  /// 有些 App 同时注册了多个 scheme（例如抖音 douyin:// 与 snssdk1128://，
  /// 小红书 xhs:// 与 xhsdiscover://）。主 scheme 唤起失败时会依次尝试这些候选，
  /// 显著提高「真的能跳过去」的概率。
  final List<String> schemeAlts;

  /// 固定 true：iOS 沙盒限制，只能唤起 App，无法自动扫码
  final bool needManualScan;

  /// 本次结果来源
  final RouteSource source;

  /// 二维码原始文本
  final String rawText;

  const QrRouteResult({
    required this.appName,
    required this.rawText,
    this.scheme,
    this.schemeAlts = const <String>[],
    this.needManualScan = true,
    this.source = RouteSource.unknown,
  });

  /// 是否有可用的 scheme
  bool get hasScheme => scheme != null && scheme!.trim().isNotEmpty;

  /// 全部候选 scheme，主 scheme 排在最前、自动去重
  List<String> get allSchemes {
    final List<String> out = <String>[];
    final String? primary = scheme?.trim();
    if (primary != null && primary.isNotEmpty) out.add(primary);
    for (final String s in schemeAlts) {
      final String v = s.trim();
      if (v.isNotEmpty && !out.contains(v)) out.add(v);
    }
    return out;
  }

  QrRouteResult copyWith({
    String? appName,
    String? scheme,
    List<String>? schemeAlts,
    bool? needManualScan,
    RouteSource? source,
    String? rawText,
  }) {
    return QrRouteResult(
      appName: appName ?? this.appName,
      scheme: scheme ?? this.scheme,
      schemeAlts: schemeAlts ?? this.schemeAlts,
      needManualScan: needManualScan ?? this.needManualScan,
      source: source ?? this.source,
      rawText: rawText ?? this.rawText,
    );
  }

  /// 写入 Hive 用（只存原始识别信息，source 由读取方决定）
  Map<String, dynamic> toCacheMap() {
    return <String, dynamic>{
      'app': appName,
      'scheme': scheme ?? '',
      // 新增字段：老缓存里没有这一项，读取时会安全降级为空列表
      'schemeAlts': schemeAlts,
      'needManualScan': needManualScan,
      'origin': source.name,
      'savedAt': DateTime.now().millisecondsSinceEpoch,
      'rawText': rawText,
    };
  }

  /// 从 Hive 读出，统一标记为 cache 来源（兼容没有 schemeAlts 的旧缓存）
  static QrRouteResult? fromCacheMap(Object? value, String rawText) {
    if (value is! Map) return null;
    final Map<String, dynamic> map = Map<String, dynamic>.from(value);
    final String app = (map['app'] ?? '').toString();
    if (app.isEmpty) return null;
    final String scheme = (map['scheme'] ?? '').toString();

    final List<String> alts = <String>[];
    final Object? rawAlts = map['schemeAlts'];
    if (rawAlts is List) {
      for (final Object? item in rawAlts) {
        final String v = (item ?? '').toString().trim();
        if (v.isNotEmpty) alts.add(v);
      }
    }

    return QrRouteResult(
      appName: app,
      scheme: scheme.isEmpty ? null : scheme,
      schemeAlts: alts,
      needManualScan: map['needManualScan'] != false,
      source: RouteSource.cache,
      rawText: rawText,
    );
  }

  @override
  String toString() =>
      'QrRouteResult(app=$appName, scheme=$scheme, alts=$schemeAlts, source=${source.name})';
}