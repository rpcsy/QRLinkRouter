import '../../core/app_constants.dart';

/// 用户设置项
class AppSettings {
  /// codex-proxy 地址，例如 https://xxx.vps-domain.com/v1
  final String baseUrl;

  /// API Key
  final String apiKey;

  /// 模型名称
  final String model;

  /// AI 识别总开关；关闭后完全不调用任何 LLM 接口
  final bool aiEnabled;

  const AppSettings({
    this.baseUrl = '',
    this.apiKey = '',
    this.model = AppConstants.defaultModel,
    this.aiEnabled = true,
  });

  bool get isApiConfigured =>
      baseUrl.trim().isNotEmpty && apiKey.trim().isNotEmpty;

  /// 是否应该调用大模型：开关打开 + 地址和 key 都填了
  bool get shouldCallLlm => aiEnabled && isApiConfigured;

  AppSettings copyWith({
    String? baseUrl,
    String? apiKey,
    String? model,
    bool? aiEnabled,
  }) {
    return AppSettings(
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: (model ?? this.model).trim().isEmpty
          ? AppConstants.defaultModel
          : (model ?? this.model).trim(),
      aiEnabled: aiEnabled ?? this.aiEnabled,
    );
  }
}