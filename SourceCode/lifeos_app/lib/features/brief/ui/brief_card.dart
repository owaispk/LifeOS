// Brief display card (PBI-039a).
import 'package:flutter/material.dart';

import '../../../core/l10n.dart';

class BriefCard extends StatelessWidget {
  const BriefCard({
    super.key,
    required this.text,
    required this.tone,
    required this.isAi,
  });

  final String text;
  final String tone; // triage|steady|excellent
  final bool isAi;

  @override
  Widget build(BuildContext context) {
    final colors = _toneColors(tone);
    
    return Card(
      elevation: 4,
      color: colors.background,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _toneIcon(tone),
                  color: colors.foreground,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  _toneTitle(context, tone),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.foreground,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (isAi)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.foreground.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, size: 14, color: colors.foreground),
                        const SizedBox(width: 4),
                        Text(
                          'AI',
                          style: TextStyle(
                            color: colors.foreground,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colors.foreground,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _timestamp(context),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.foreground.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _toneIcon(String tone) => switch (tone) {
    'triage' => Icons.warning_amber_rounded,
    'excellent' => Icons.celebration,
    _ => Icons.wb_sunny,
  };

  String _toneTitle(BuildContext context, String tone) => switch (tone) {
    'triage' => context.l10n.heavyWeek,
    'excellent' => context.l10n.greatDay,
    _ => context.l10n.goodMorning,
  };

  ({Color background, Color foreground}) _toneColors(String tone) => switch (tone) {
    'triage' => (
      background: Colors.red.shade50,
      foreground: Colors.red.shade900,
    ),
    'excellent' => (
      background: Colors.green.shade50,
      foreground: Colors.green.shade900,
    ),
    _ => (
      background: Colors.blue.shade50,
      foreground: Colors.blue.shade900,
    ),
  };

  String _timestamp(BuildContext context) {
    final now = DateTime.now();
    final hour = now.hour;
    
    if (hour < 12) return context.l10n.morningBrief;
    if (hour < 17) return context.l10n.afternoonBrief;
    return context.l10n.eveningBrief;
  }
}
