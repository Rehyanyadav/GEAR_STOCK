import 'package:flutter/material.dart';

class AppColors {
  // Brand & Primary
  static const Color primary = Color(0xFFAC2D00);
  static const Color primaryContainer = Color(0xFFD63C05);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFFFFFBFF);
  static const Color primaryFixed = Color(0xFFFFDBD1);
  static const Color primaryFixedDim = Color(0xFFFFB5A0);
  static const Color onPrimaryFixed = Color(0xFF3B0900);

  // Secondary
  static const Color secondary = Color(0xFF5F5E5E);
  static const Color secondaryContainer = Color(0xFFE2DFDE);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onSecondaryContainer = Color(0xFF636262);

  // Surfaces & Backgrounds
  static const Color background = Color(0xFFF9F9F9);
  static const Color surface = Color(0xFFF9F9F9);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF3F3F3);
  static const Color surfaceContainer = Color(0xFFEEEEEE);
  static const Color surfaceContainerHigh = Color(0xFFE8E8E8);
  static const Color surfaceContainerHighest = Color(0xFFE2E2E2);
  static const Color surfaceDim = Color(0xFFDADADA);
  static const Color surfaceBright = Color(0xFFF9F9F9);

  // Typography & Content
  static const Color onSurface = Color(0xFF1A1C1C);
  static const Color onSurfaceVariant = Color(0xFF5B4039);
  static const Color onBackground = Color(0xFF1A1C1C);

  // Borders & Outlines
  static const Color outline = Color(0xFF8F7067);
  static const Color outlineVariant = Color(0xFFE4BEB4);

  // Status & Feedback
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);
  static const Color success = Color(0xFF059669);
  static const Color successContainer = Color(0xFFD1FAE5);
  static const Color onSuccessContainer = Color(0xFF065F46);

  // Inverse
  static const Color inverseSurface = Color(0xFF2F3131);
  static const Color inverseOnSurface = Color(0xFFF0F1F1);
}

class AppTheme {
  static ThemeData get lightTheme => _buildTheme(Brightness.light);

  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: isDark ? const Color(0xFFFF8A67) : AppColors.primary,
          brightness: brightness,
        ).copyWith(
          primary: isDark ? const Color(0xFFFF8A67) : AppColors.primary,
          onPrimary: isDark ? const Color(0xFF481300) : AppColors.onPrimary,
          primaryContainer: isDark
              ? const Color(0xFF7A2A10)
              : AppColors.primaryContainer,
          onPrimaryContainer: isDark
              ? const Color(0xFFFFE8E0)
              : AppColors.onPrimaryContainer,
          primaryFixed: isDark
              ? const Color(0xFFFFDAD0)
              : AppColors.primaryFixed,
          primaryFixedDim: isDark
              ? const Color(0xFFFFB5A0)
              : AppColors.primaryFixedDim,
          onPrimaryFixed: isDark
              ? const Color(0xFF3B0900)
              : AppColors.onPrimaryFixed,
          secondary: isDark ? const Color(0xFFD0C1BC) : AppColors.secondary,
          onSecondary: AppColors.onSecondary,
          secondaryContainer: isDark
              ? const Color(0xFF52433F)
              : AppColors.secondaryContainer,
          onSecondaryContainer: isDark
              ? const Color(0xFFEADBD6)
              : AppColors.onSecondaryContainer,
          error: isDark ? const Color(0xFFFFB4AB) : AppColors.error,
          onError: isDark ? const Color(0xFF690005) : AppColors.onPrimary,
          errorContainer: isDark
              ? const Color(0xFF93000A)
              : AppColors.errorContainer,
          onErrorContainer: isDark
              ? const Color(0xFFFFDAD6)
              : AppColors.onErrorContainer,
          surface: isDark ? const Color(0xFF121110) : AppColors.surface,
          onSurface: isDark ? const Color(0xFFF3EFED) : AppColors.onSurface,
          onSurfaceVariant: isDark
              ? const Color(0xFFD7C2B9)
              : AppColors.onSurfaceVariant,
          surfaceContainerLowest: isDark
              ? const Color(0xFF0D0C0B)
              : AppColors.surfaceContainerLowest,
          surfaceContainerLow: isDark
              ? const Color(0xFF1A1817)
              : AppColors.surfaceContainerLow,
          surfaceContainer: isDark
              ? const Color(0xFF211F1E)
              : AppColors.surfaceContainer,
          surfaceContainerHigh: isDark
              ? const Color(0xFF2B2827)
              : AppColors.surfaceContainerHigh,
          surfaceContainerHighest: isDark
              ? const Color(0xFF353130)
              : AppColors.surfaceContainerHighest,
          surfaceDim: isDark ? const Color(0xFF121110) : AppColors.surfaceDim,
          surfaceBright: isDark
              ? const Color(0xFF3A3634)
              : AppColors.surfaceBright,
          outline: isDark ? const Color(0xFFA88F86) : AppColors.outline,
          outlineVariant: isDark
              ? const Color(0xFF59443D)
              : AppColors.outlineVariant,
          inverseSurface: isDark
              ? const Color(0xFFEAE0DC)
              : AppColors.inverseSurface,
          onInverseSurface: isDark
              ? const Color(0xFF322F2D)
              : AppColors.inverseOnSurface,
          inversePrimary: isDark
              ? const Color(0xFFB93B15)
              : AppColors.primaryContainer,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: colorScheme.surface,
      colorScheme: colorScheme,
      extensions: [
        AppStatusColors(
          success: isDark ? const Color(0xFF6EE7B7) : AppColors.success,
          successContainer: isDark
              ? const Color(0xFF064E3B)
              : AppColors.successContainer,
          onSuccessContainer: isDark
              ? const Color(0xFFA7F3D0)
              : AppColors.onSuccessContainer,
        ),
      ],
      fontFamily: 'Inter',
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colorScheme.surfaceContainerHigh.withAlpha(128),
            width: 1,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          animationDuration: const Duration(milliseconds: 320),
          backgroundColor: WidgetStatePropertyAll(colorScheme.primary),
          foregroundColor: WidgetStatePropertyAll(colorScheme.onPrimary),
          elevation: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return 0;
            if (states.contains(WidgetState.pressed)) return 1;
            if (states.contains(WidgetState.hovered)) return 8;
            return 2;
          }),
          shadowColor: WidgetStateProperty.resolveWith((states) {
            final opacity = states.contains(WidgetState.hovered) ? 120 : 55;
            return colorScheme.primary.withAlpha(opacity);
          }),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
          shape: WidgetStateProperty.resolveWith((states) {
            final hovered = states.contains(WidgetState.hovered);
            final pressed = states.contains(WidgetState.pressed);
            final radius = pressed ? 10.0 : (hovered ? 22.0 : 12.0);
            return RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
              side: BorderSide(
                color: hovered
                    ? colorScheme.primaryFixed.withAlpha(135)
                    : Colors.transparent,
                width: hovered ? 1.2 : 0,
              ),
            );
          }),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          animationDuration: const Duration(milliseconds: 320),
          foregroundColor: WidgetStatePropertyAll(colorScheme.primary),
          side: WidgetStateProperty.resolveWith((states) {
            final hovered = states.contains(WidgetState.hovered);
            return BorderSide(
              color: hovered
                  ? colorScheme.primary.withAlpha(190)
                  : colorScheme.outlineVariant,
              width: hovered ? 1.8 : 1,
            );
          }),
          shape: WidgetStateProperty.resolveWith((states) {
            final hovered = states.contains(WidgetState.hovered);
            final pressed = states.contains(WidgetState.pressed);
            return RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                pressed ? 10 : (hovered ? 22 : 12),
              ),
            );
          }),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        hintStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
    );
  }
}

class AppStatusColors extends ThemeExtension<AppStatusColors> {
  const AppStatusColors({
    required this.success,
    required this.successContainer,
    required this.onSuccessContainer,
  });

  final Color success;
  final Color successContainer;
  final Color onSuccessContainer;

  static AppStatusColors of(BuildContext context) =>
      Theme.of(context).extension<AppStatusColors>()!;

  @override
  AppStatusColors copyWith({
    Color? success,
    Color? successContainer,
    Color? onSuccessContainer,
  }) {
    return AppStatusColors(
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
    );
  }

  @override
  AppStatusColors lerp(covariant AppStatusColors? other, double t) {
    if (other == null) return this;
    return AppStatusColors(
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      onSuccessContainer: Color.lerp(
        onSuccessContainer,
        other.onSuccessContainer,
        t,
      )!,
    );
  }
}
