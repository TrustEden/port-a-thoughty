import 'package:flutter/material.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    this.subtitle =
        'Capture first, clean later. Porta-Thoughty keeps your brain clear.',
  });

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withValues(alpha: 0.7),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14014F8E),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: Image.asset('assets/mascot.png', fit: BoxFit.cover),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Port-A-Thoughty',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                  fontSize: (theme.textTheme.bodyMedium?.fontSize ?? 14) - 2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
