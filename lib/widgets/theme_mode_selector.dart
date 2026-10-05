import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme_mode_provider.dart';

class ThemeModeSelector extends ConsumerWidget {
  const ThemeModeSelector({super.key});

  static const _labels = {
    ThemeMode.system: 'System',
    ThemeMode.light: 'Light',
    ThemeMode.dark: 'Dark',
  };

  static const _icons = {
    ThemeMode.system: Icons.brightness_auto_outlined,
    ThemeMode.light: Icons.light_mode_outlined,
    ThemeMode.dark: Icons.dark_mode_outlined,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final colorScheme = Theme.of(context).colorScheme;
    return PopupMenuButton<ThemeMode>(
      key: const ValueKey('theme-mode-selector'),
      tooltip: 'Choose app appearance',
      initialValue: themeMode,
      onSelected: (mode) => ref.read(themeModeProvider.notifier).state = mode,
      itemBuilder: (context) => ThemeMode.values
          .map(
            (mode) => PopupMenuItem<ThemeMode>(
              value: mode,
              child: Row(
                children: [
                  Icon(_icons[mode], size: 20),
                  const SizedBox(width: 12),
                  Text(_labels[mode]!),
                  if (mode == themeMode) ...[
                    const Spacer(),
                    Icon(
                      Icons.check,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                  ],
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest.withAlpha(220),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colorScheme.outlineVariant.withAlpha(110)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icons[themeMode], size: 18, color: colorScheme.primary),
            const SizedBox(width: 7),
            Text(
              _labels[themeMode]!,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(width: 3),
            Icon(
              Icons.expand_more,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
