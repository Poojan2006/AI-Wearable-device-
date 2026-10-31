import 'package:flutter/material.dart';

import '../services/theme_service.dart';
import '../core/theme/app_theme.dart';

class ThemeSelectorDialog extends StatelessWidget {
  const ThemeSelectorDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const ThemeSelectorDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = ThemeService.instance.themeMode;
    final textPrimary = AppTheme.textPrimary(context);
    final textSub = AppTheme.textSub(context);

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.primary.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.palette_outlined,
              color: AppTheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            "App Visual Theme",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOption(
            context,
            mode: ThemeMode.light,
            title: "Light Theme (Default)",
            subtitle: "Clean, high readability with white cards",
            icon: Icons.light_mode_rounded,
            isSelected: current == ThemeMode.light,
          ),
          const SizedBox(height: 8),
          _buildOption(
            context,
            mode: ThemeMode.dark,
            title: "Dark Theme",
            subtitle: "Sleek industrial slate dark mode",
            icon: Icons.dark_mode_rounded,
            isSelected: current == ThemeMode.dark,
          ),
          const SizedBox(height: 8),
          _buildOption(
            context,
            mode: ThemeMode.system,
            title: "System Default",
            subtitle: "Automatically matches phone system setting",
            icon: Icons.brightness_auto_rounded,
            isSelected: current == ThemeMode.system,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            "DONE",
            style: TextStyle(color: textSub, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required ThemeMode mode,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
  }) {
    final isDark = AppTheme.isDark(context);
    final borderColor = isSelected
        ? AppTheme.primary
        : AppTheme.border(context);

    return InkWell(
      onTap: () {
        ThemeService.instance.setThemeMode(mode);
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withAlpha(isDark ? 35 : 18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primary : AppTheme.textSub(context),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppTheme.textSub(context),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppTheme.primary,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}
