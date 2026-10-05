import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearstock/theme/app_theme.dart';

void main() {
  test('light and dark themes keep readable, distinct surfaces', () {
    final light = AppTheme.lightTheme;
    final dark = AppTheme.darkTheme;

    expect(light.brightness, Brightness.light);
    expect(light.colorScheme.primary, AppColors.primary);
    expect(dark.brightness, Brightness.dark);
    expect(dark.colorScheme.surface, const Color(0xFF121110));
    expect(dark.colorScheme.onSurface, const Color(0xFFF3EFED));
    expect(
      dark.extension<AppStatusColors>()!.successContainer,
      const Color(0xFF064E3B),
    );
  });
}
