import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

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

  /// Substitui todos os dados por um backup importado.
  Future<void> _import() async {
    final raw = await showImportBackupPopup(context);
    if (!mounted || raw == null || raw.isEmpty) return;

    final parsed = widget.storage.importJson(raw);
    if (parsed == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text('Backup inválido: o JSON não está no formato esperado.'),
      ));
      return;
    }

    final confirmed = await showConfirmPopup(
      context,
      title: 'Importar backup',
      content: 'Isto vai substituir todos os dados atuais (rotina, histórico, '
          'notas, arquivo e tema). Continuar?',
      confirmLabel: 'Importar',
    );
    if (!mounted || confirmed != true) return;
    widget.onReplaceData(parsed);
  }

  /// Exporta tudo (rotina, histórico, notas, arquivo e tema) como JSON,
  /// copiando-o para a área de transferência e abrindo a partilha.
  Future<void> _export() async {
    final json = widget.storage.exportJson(widget.data);
    await Clipboard.setData(ClipboardData(text: json));
    var shared = false;
    try {
      await Share.share(json, subject: 'Task Notes — backup');
      shared = true;
    } catch (_) {
      // Sem partilha disponível (ex.: plataforma sem suporte).
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        shared
            ? 'Backup partilhado e copiado para a área de transferência.'
            : 'Backup copiado para a área de transferência.',
      ),
    ));
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
          Text('Backup', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.share_outlined),
                  title: const Text('Exportar backup'),
                  subtitle: const Text(
                    'Partilha ou copia todos os dados (JSON).',
                  ),
                  onTap: _export,
                ),
                ListTile(
                  leading: const Icon(Icons.file_download_outlined),
                  title: const Text('Importar backup'),
                  subtitle: const Text(
                    'Cola um JSON exportado anteriormente.',
                  ),
                  onTap: _import,
                ),
              ],
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
