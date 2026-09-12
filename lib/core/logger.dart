import 'package:flutter/foundation.dart';

/// 极简日志，release 下只在 debug 模式输出，避免刷屏。
class AppLog {
  AppLog._();

  static void i(String message) {
    if (kDebugMode) {
      debugPrint('[QRLinkRouter] $message');
    }
  }

  static void e(String message, [Object? error]) {
    if (kDebugMode) {
      debugPrint('[QRLinkRouter][ERROR] $message ${error ?? ''}');
    }
  }
}