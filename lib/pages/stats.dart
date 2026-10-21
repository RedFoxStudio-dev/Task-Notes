import 'package:flutter/material.dart';

import '../models.dart';
import '../storage.dart';

/// Estatísticas: streak diário e semanal, resumo de hoje e heatmap das
/// últimas 12 semanas.
class StatsPage extends StatelessWidget {
  const StatsPage({super.key, required this.data});

  final AppData data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final daily = dailyStreak(data.history);
    final weekly = weeklyStreak(data.history);
    final todayEntry = data.history[dateKey(DateTime.now())];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _StreakCard(
                icon: Icons.local_fire_department,
                color: Colors.deepOrange,
                value: '$daily',
                label: daily == 1 ? 'dia seguido' : 'dias seguidos',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StreakCard(
                icon: Icons.calendar_month_outlined,
                color: scheme.primary,
                value: '$weekly',
                label: weekly == 1 ? 'semana completa' : 'semanas completas',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Hoje', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _TodayCard(entry: todayEntry, scheme: scheme),
        const SizedBox(height: 16),
        Text('Últimas 12 semanas',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _Heatmap(history: data.history, scheme: scheme),
          ),
        ),
      ],
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.outline),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.entry, required this.scheme});

  final DayEntry? entry;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final entry = this.entry;
    if (entry == null || entry.total == 0) {
      return Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Sem tarefas hoje',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: scheme.outline),
          ),
        ),
      );
    }
    final percent = (entry.ratio * 100).round();
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${entry.done} de ${entry.total} concluídas'),
                ),
                Text('$percent%'),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: entry.ratio,
                minHeight: 8,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.history, required this.scheme});

  final Map<String, DayEntry> history;
  final ColorScheme scheme;

  static const _cellSize = 13.0;
  static const _cellGap = 3.0;
  static const _weeks = 12;

  Color _colorFor(DayEntry? entry, bool isFuture) {
    if (isFuture || entry == null || entry.total == 0) {
      return scheme.surfaceContainerHighest;
    }
    if (entry.isComplete) return scheme.primary;
    return scheme.primary.withValues(alpha: 0.35);
  }

  Widget _cell(DateTime date) {
    final entry = history[dateKey(date)];
    final isFuture = date.isAfter(DateTime.now());
    return Tooltip(
      message:
          '${dateKey(date)} · ${entry?.done ?? 0}/${entry?.total ?? 0}',
      child: Container(
        width: _cellSize,
        height: _cellSize,
        margin: const EdgeInsets.only(right: _cellGap),
        decoration: BoxDecoration(
          color: _colorFor(entry, isFuture),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final thisMonday = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: today.weekday - 1));
    final startMonday = thisMonday.subtract(const Duration(days: (_weeks - 1) * 7));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var d = 0; d < 7; d++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1.5),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    kWeekdayLabels[d],
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: scheme.outline),
                  ),
                ),
                for (var w = 0; w < _weeks; w++)
                  _cell(startMonday.add(Duration(days: w * 7 + d))),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Spacer(),
            Text('Menos',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: scheme.outline)),
            const SizedBox(width: 4),
            _legendCell(scheme.surfaceContainerHighest),
            _legendCell(scheme.primary.withValues(alpha: 0.35)),
            _legendCell(scheme.primary),
            const SizedBox(width: 4),
            Text('Mais',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: scheme.outline)),
          ],
        ),
      ],
    );
  }

  Widget _legendCell(Color color) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1.5),
        child: Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      );
}
