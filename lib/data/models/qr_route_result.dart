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

  /// iOS URL Scheme，例如 douyin://；未识别时为 null 或空串
  final String? scheme;

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
    this.needManualScan = true,
    this.source = RouteSource.unknown,
  });

  /// 是否有可用的 scheme
  bool get hasScheme => scheme != null && scheme!.trim().isNotEmpty;

  QrRouteResult copyWith({
    String? appName,
    String? scheme,
    bool? needManualScan,
    RouteSource? source,
    String? rawText,
  }) {
    return QrRouteResult(
      appName: appName ?? this.appName,
      scheme: scheme ?? this.scheme,
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
      'needManualScan': needManualScan,
      'origin': source.name,
      'savedAt': DateTime.now().millisecondsSinceEpoch,
      'rawText': rawText,
    };
  }

  /// 从 Hive 读出，统一标记为 cache 来源
  static QrRouteResult? fromCacheMap(Object? value, String rawText) {
    if (value is! Map) return null;
    final map = Map<String, dynamic>.from(value);
    final app = (map['app'] ?? '').toString();
    if (app.isEmpty) return null;
    final scheme = (map['scheme'] ?? '').toString();
    return QrRouteResult(
      appName: app,
      scheme: scheme.isEmpty ? null : scheme,
      needManualScan: map['needManualScan'] != false,
      source: RouteSource.cache,
      rawText: rawText,
    );
  }

  @override
  String toString() =>
      'QrRouteResult(app=$appName, scheme=$scheme, source=${source.name})';
}