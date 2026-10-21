import 'package:flutter/material.dart';

import '../models.dart';
import '../popups.dart';
import '../storage.dart';

/// Definições: arquivo de tarefas (restaurar/eliminar) e, mais à frente,
/// backup e tema.
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.data,
    required this.storage,
    required this.onChanged,
    required this.onReplaceData,
  });

  final AppData data;
  final AppStorage storage;
  final VoidCallback onChanged;
  final void Function(AppData data) onReplaceData;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  void _restore(Task task) {
    final day = task.day ?? DateTime.now().weekday;
    widget.data.tasksFor(day).add(task..day = null);
    widget.data.archive.remove(task);
    widget.onChanged();
  }

  Future<void> _deleteForever(Task task) async {
    final confirmed = await showConfirmPopup(
      context,
      title: 'Eliminar definitivamente',
      content: '"${task.title}" será apagada para sempre. Continuar?',
    );
    if (!mounted || confirmed != true) return;
    setState(() => widget.data.archive.remove(task));
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Definições')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Arquivo', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (widget.data.archive.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Sem tarefas arquivadas. As tarefas arquivadas ficam aqui e '
                'podem ser restauradas para o dia de origem.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: scheme.outline),
              ),
            ),
          for (final task in widget.data.archive)
            Card(
              elevation: 0,
              child: ListTile(
                leading: Icon(taskIcon(task.icon) ?? Icons.archive_outlined),
                title: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  'Arquivada de ${task.day != null ? kWeekdayLabels[task.day! - 1] : '—'}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Restaurar',
                      icon: const Icon(Icons.restore),
                      onPressed: () => _restore(task),
                    ),
                    IconButton(
                      tooltip: 'Eliminar definitivamente',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _deleteForever(task),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Task Notes v2',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: scheme.outline),
            ),
          ),
        ],
      ),
    );
  }
}
