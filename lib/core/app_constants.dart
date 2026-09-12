/// 全局常量。所有写死的配置集中在这里，方便改。
class AppConstants {
  AppConstants._();

  /// 设置页底部展示的版本号（与 pubspec.yaml 的 version 保持一致）
  static const String appVersion = '1.0.0+1';

  /// 默认模型名称
  static const String defaultModel = 'deepseek-v4-flash';

  /// 默认 API 地址占位示例
  static const String baseUrlHint = 'https://xxx.vps-domain.com/v1';

  /// 网络超时（需求：10 秒）
  static const Duration requestTimeout = Duration(seconds: 10);

  /// Hive 缓存 box 名称
  static const String cacheBoxName = 'qr_cache_v1';

  /// 相机权限说明文案（需与 Info.plist 的 NSCameraUsageDescription 一致）
  static const String cameraPermissionText = '需要相机权限来扫描二维码';

  /// 是否允许识别结果里的 http/https 链接用浏览器兜底打开
  static const bool allowBrowserFallback = true;

  /// 大模型固定 Prompt（写死，不做任何修改）。
  ///
  /// 使用 raw 字符串，避免 Dart 对 { } 做插值。
  /// 请求时把 {{qrContent}} 替换成二维码原文。
  static const String llmPromptTemplate = r'''
任务：分析输入的二维码原始文本，识别该二维码归属的手机App，输出对应的iOS可用URL Scheme。
规则：
1. 优先解析短链接、跳转链接，识别平台。
2. 只输出纯JSON文本，禁止任何多余解释、说明、markdown、换行注释，不能输出任何JSON以外文字。
3. 支持识别平台列表：微信、支付宝、抖音、小红书、B站、淘宝、拼多多。
4. needManualScan字段含义：iOS系统沙盒限制，第三方App无法自动替目标App执行扫码动作，只能唤起App，唤起后用户必须手动点击目标App内扫码按钮，该字段固定为true。
5. 返回JSON字段定义：
   app：字符串，识别出来的应用名称；
   scheme：字符串，iOS可调用的URL Scheme；
   needManualScan：布尔值，固定true；
6. 无法判断归属平台时，app 返回 "未知"，scheme 返回空字符串 ""。禁止编造不存在的scheme。
示例返回：{"app":"抖音","scheme":"douyin://","needManualScan":true}
输入二维码文本：{{qrContent}}
''';

  /// 拼接完整 Prompt
  static String buildPrompt(String qrRawText) {
    return llmPromptTemplate.replaceAll('{{qrContent}}', qrRawText);
  }
}