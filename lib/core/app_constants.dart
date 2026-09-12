/// 全局常量。所有写死的配置集中在这里，方便改。
class AppConstants {
  AppConstants._();

  /// 设置页底部展示的版本号（与 pubspec.yaml 的 version 保持一致）
  static const String appVersion = '1.1.0+2';

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

  /// 两次识别之间的最小间隔（防止同一个二维码被连续重复触发）
  static const Duration rescanCooldown = Duration(milliseconds: 800);

  /// 相机看门狗检查间隔：相机意外停止时自动重启预览
  static const Duration cameraWatchdogInterval = Duration(seconds: 5);

  /// 大模型固定 Prompt（写死，不做任何修改）。
  ///
  /// 修改点3：换成「智能识别、不限定 App 清单」的新 Prompt。
  ///
  /// 使用 raw 字符串，避免 Dart 对 { } 做插值。
  /// 请求时把 {{qrContent}} 替换成二维码原文。
  static const String llmPromptTemplate = r'''
任务：分析输入的二维码原始文本，智能识别二维码归属的手机App，输出对应的iOS可用URL Scheme。
规则：
1. 解析网页链接、短链接、登录二维码、校园平台链接、支付链接，自动识别所属App。包含校园类App：趣知校园、胖乖生活、学习通、钉钉、飞书、企业微信、智慧校园；日常生活全部主流App。**不局限固定清单，尽可能识别市面上全部App链接**。
2. 只输出纯JSON文本，禁止任何多余解释、markdown、注释，只能输出JSON。
3. needManualScan含义：iOS沙盒限制，第三方App无法替目标App自动扫码，唤起App后用户必须手动点击目标App扫码按钮，此字段固定true。
JSON字段定义：
app：字符串，识别出的App名称；识别不出填"未知"
scheme：字符串，iOS URL Scheme；找不到有效scheme填空字符串""
needManualScan：布尔值，固定true
示例1：{"app":"QQ","scheme":"mqq://","needManualScan":true}
示例2：{"app":"趣知校园","scheme":"qzxy://","needManualScan":true}
示例3：{"app":"胖乖生活","scheme":"pangguai://","needManualScan":true}
示例4：{"app":"未知","scheme":"","needManualScan":true}
输入二维码文本：{{qrContent}}
''';

  /// 拼接完整 Prompt
  static String buildPrompt(String qrRawText) {
    return llmPromptTemplate.replaceAll('{{qrContent}}', qrRawText);
  }
}