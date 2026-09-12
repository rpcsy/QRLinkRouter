import 'dart:convert';

import 'package:dio/dio.dart';

import '../core/app_constants.dart';
import '../core/logger.dart';
import '../data/models/app_settings.dart';
import '../data/models/qr_route_result.dart';

/// 调用 codex-proxy（OpenAI 兼容 /chat/completions）做二维码归属识别。
///
/// 失败一律返回 null，由上层走兜底逻辑，绝不抛出到 UI。
class LlmRouter {
  LlmRouter._();

  /// URL Scheme 合法性：必须是 scheme:// 形式（公开标准，防止模型瞎编）
  static final RegExp _schemePattern =
      RegExp(r'^[a-zA-Z][a-zA-Z0-9+.\-]*://');

  static Dio _buildDio() {
    return Dio(
      BaseOptions(
        connectTimeout: AppConstants.requestTimeout,
        sendTimeout: AppConstants.requestTimeout,
        receiveTimeout: AppConstants.requestTimeout,
        responseType: ResponseType.json,
        headers: const <String, dynamic>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
  }

  /// 把用户填的 baseUrl 拼成 chat/completions 端点，容忍结尾多余的 /
  static String endpointOf(String baseUrl) {
    var base = baseUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return '$base/chat/completions';
  }

  /// 识别二维码文本；成功返回结果，任何失败返回 null
  static Future<QrRouteResult?> identify(
    String rawText,
    AppSettings settings,
  ) async {
    if (!settings.shouldCallLlm) {
      AppLog.i('跳过 AI：开关关闭或未配置 API');
      return null;
    }
    if (rawText.trim().isEmpty) return null;

    final dio = _buildDio();
    try {
      final Response<dynamic> response = await dio.post<dynamic>(
        endpointOf(settings.baseUrl),
        data: <String, dynamic>{
          'model': settings.model,
          'messages': <Map<String, String>>[
            <String, String>{
              'role': 'user',
              'content': AppConstants.buildPrompt(rawText),
            },
          ],
          'temperature': 0,
          'stream': false,
        },
        options: Options(
          headers: <String, dynamic>{
            'Authorization': 'Bearer ${settings.apiKey}',
          },
        ),
      );

      final String? content = _extractContent(response.data);
      if (content == null || content.trim().isEmpty) {
        AppLog.e('AI 返回内容为空');
        return null;
      }

      final Map<String, dynamic>? json = _decodeJsonObject(content);
      if (json == null) {
        AppLog.e('AI 返回不是合法 JSON: $content');
        return null;
      }

      final String app = (json['app'] ?? '').toString().trim();
      String scheme = (json['scheme'] ?? '').toString().trim();
      if (scheme.toLowerCase() == 'null') scheme = '';
      if (app.isEmpty) {
        AppLog.e('AI 返回缺少 app 字段');
        return null;
      }

      // scheme 必须是公开标准的 scheme:// 形式，否则视为未识别
      final bool schemeValid =
          scheme.isNotEmpty && _schemePattern.hasMatch(scheme);

      return QrRouteResult(
        appName: app,
        scheme: schemeValid ? scheme : null,
        needManualScan: true,
        source: RouteSource.llm,
        rawText: rawText,
      );
    } on DioException catch (e) {
      AppLog.e('AI 请求失败(${e.type.name})', e.message);
      return null;
    } catch (e) {
      AppLog.e('AI 请求未知异常', e);
      return null;
    } finally {
      dio.close(force: true);
    }
  }

  /// 兼容多种返回结构：chat.completions / completions / responses
  static String? _extractContent(Object? data) {
    if (data == null) return null;
    if (data is String) return data;
    if (data is! Map) return null;
    final Map<dynamic, dynamic> map = data;

    final Object? choices = map['choices'];
    if (choices is List && choices.isNotEmpty) {
      final Object? first = choices.first;
      if (first is Map) {
        final Object? message = first['message'];
        if (message is Map) {
          final Object? content = message['content'];
          if (content is String) return content;
          // 少数代理会把 content 拆成数组
          if (content is List) {
            final buffer = StringBuffer();
            for (final Object? part in content) {
              if (part is Map && part['text'] is String) {
                buffer.write(part['text'] as String);
              } else if (part is String) {
                buffer.write(part);
              }
            }
            if (buffer.isNotEmpty) return buffer.toString();
          }
        }
        final Object? text = first['text'];
        if (text is String) return text;
      }
    }

    final Object? outputText = map['output_text'];
    if (outputText is String) return outputText;

    return null;
  }

  /// 从模型输出里抠出 JSON 对象（容忍 markdown 代码块和前后废话）
  static Map<String, dynamic>? _decodeJsonObject(String content) {
    var text = content.trim();
    if (text.startsWith('```')) {
      text = text.replaceAll(RegExp(r'^```[a-zA-Z]*\s*'), '');
      text = text.replaceAll(RegExp(r'\s*```$'), '');
      text = text.trim();
    }

    final int start = text.indexOf('{');
    final int end = text.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    final String candidate = text.substring(start, end + 1);

    try {
      final Object? decoded = jsonDecode(candidate);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return null;
    } catch (e) {
      AppLog.e('JSON 解析失败', e);
      return null;
    }
  }
}