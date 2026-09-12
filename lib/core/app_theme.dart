import 'package:flutter/material.dart';

/// 修改点5：统一主题配色（深色风格，适配 iPhone 扫码场景）
///
/// 主色        #2979FF  柔和蓝
/// 背景色      #121212  深色背景
/// 卡片/弹窗   #1E1E1E
/// 主文字      #FFFFFF
/// 次要文字    #AAAAAA
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF2979FF);
  static const Color primaryPressed = Color(0xFF1565C0); // 主按钮按下变暗
  static const Color background = Color(0xFF121212);
  static const Color card = Color(0xFF1E1E1E);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFAAAAAA);
  static const Color divider = Color(0xFF2A2A2A);
  static const Color fieldFill = Color(0xFF1A1A1A);

  /// 弹窗遮罩：比默认更暗一点，让相机画面轻微变暗（修改点5）
  static const Color barrier = Color(0xB3000000);

  // ---- 修改点5：毛玻璃弹窗用色（alpha 直接写在常量里，不依赖 withOpacity/withValues）----
  /// 弹窗玻璃背景（约 92% 不透明）
  static const Color glassCard = Color(0xEB1E1E1E);
  /// 弹窗描边（8% 白）
  static const Color glassBorder = Color(0x14FFFFFF);
  /// 弹窗阴影
  static const Color dialogShadow = Color(0x99000000);
  /// 输入框填充
  static const Color inputFill = Color(0xFF1A1A1A);
  /// 说明块背景
  static const Color infoBlock = Color(0xFF1E1E1E);
  /// 弱化文字
  static const Color textFaint = Color(0xFF777777);
}

class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.primary,
      surface: AppColors.card,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.divider),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? Colors.white
              : AppColors.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : const Color(0xFF3A3A3A),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.card,
        contentTextStyle: TextStyle(color: AppColors.textPrimary),
        behavior: SnackBarBehavior.floating,
      ),
      listTileTheme: const ListTileThemeData(
        textColor: AppColors.textPrimary,
        iconColor: AppColors.textSecondary,
      ),
    );
  }
}