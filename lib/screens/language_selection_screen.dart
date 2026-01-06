import 'package:flutter/material.dart';

class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({
    super.key,
    required this.onSelected,
  });

  final ValueChanged<String> onSelected; // 'ar' | 'en' | 'ru'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اختر اللغة / Choose Language / Выберите язык'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            _LangButton(
              title: 'العربية',
              subtitle: 'واجهة من اليمين لليسار',
              onTap: () => onSelected('ar'),
            ),
            const SizedBox(height: 12),
            _LangButton(
              title: 'English',
              subtitle: 'Left-to-right UI',
              onTap: () => onSelected('en'),
            ),
            const SizedBox(height: 12),
            _LangButton(
              title: 'Русский',
              subtitle: 'Интерфейс слева направо',
              onTap: () => onSelected('ru'),
            ),
            const Spacer(),
            Text(
              'يمكنك تغيير اللغة لاحقًا من الإعدادات (يمكن إضافتها عند الطلب).',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _LangButton extends StatelessWidget {
  const _LangButton({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: theme.colorScheme.surface,
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.65),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.language_rounded),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}















