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
      await SharePlus.instance.share(ShareParams(
        text: json,
        subject: 'Task Notes — backup',
      ));
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
          Text('Aspeto', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _PreviewCard(scheme: scheme),
          const SizedBox(height: 16),
          Text('Tema', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto_outlined),
                label: Text('Sistema'),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_outlined),
                label: Text('Claro'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_outlined),
                label: Text('Escuro'),
              ),
            ],
            selected: {widget.data.theme},
            onSelectionChanged: (selection) {
              final mode = selection.first;
              widget.data.themeMode = switch (mode) {
                ThemeMode.light => 'light',
                ThemeMode.dark => 'dark',
                _ => 'system',
              };
              widget.onChanged();
            },
          ),
          const SizedBox(height: 16),
          Text('Cor de destaque',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          _SeedColorPicker(data: widget.data, onChanged: widget.onChanged),
          const SizedBox(height: 16),
          Text('Tamanho do texto',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'small', label: Text('A⁻')),
              ButtonSegment(value: 'normal', label: Text('A')),
              ButtonSegment(value: 'large', label: Text('A⁺')),
            ],
            selected: {widget.data.textScale},
            onSelectionChanged: (selection) {
              widget.data.textScale = selection.first;
              widget.onChanged();
            },
          ),
          const SizedBox(height: 16),
          Text('Fonte da app', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          _AppFontPicker(data: widget.data, onChanged: widget.onChanged),
          const SizedBox(height: 24),
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

/// Cartão de pré-visualização: reflete o tema em tempo real.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: scheme.primaryContainer.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.palette_outlined, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Text('Pré-visualização',
                    style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Assim ficam os cartões e o texto da app.'),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton(
                  onPressed: () {},
                  child: const Text('Botão'),
                ),
                const SizedBox(width: 16),
                const Checkbox(value: true, onChanged: null),
                const Text('Tarefa feita',
                    style: TextStyle(decoration: TextDecoration.lineThrough)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Linha de círculos para escolher a cor de destaque (com opção Dinâmica).
class _SeedColorPicker extends StatelessWidget {
  const _SeedColorPicker({required this.data, required this.onChanged});

  final AppData data;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final isDynamic = data.seed == kDynamicSeed;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _SeedSwatch(
          tooltip: 'Dinâmica (Material You)',
          selected: isDynamic,
          gradient: const [
            Colors.purple,
            Colors.orange,
            Colors.teal,
          ],
          icon: isDynamic
              ? const Icon(Icons.check, size: 20, color: Colors.white)
              : const Icon(Icons.auto_awesome, size: 18, color: Colors.white),
          onTap: () {
            data.seed = kDynamicSeed;
            onChanged();
          },
        ),
        for (final entry in kSeedColors.entries)
          _SeedSwatch(
            tooltip: entry.key,
            selected: data.seed == entry.key,
            color: entry.value,
            onTap: () {
              data.seed = entry.key;
              onChanged();
            },
          ),
      ],
    );
  }
}

class _SeedSwatch extends StatelessWidget {
  const _SeedSwatch({
    required this.tooltip,
    required this.selected,
    required this.onTap,
    this.color,
    this.gradient,
    this.icon,
  });

  final String tooltip;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;
  final List<Color>? gradient;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final checkColor =
        color != null && color!.computeLuminance() > 0.5
            ? Colors.black
            : Colors.white;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: gradient == null ? color : null,
            gradient:
                gradient == null ? null : LinearGradient(colors: gradient!),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2.5 : 1,
            ),
          ),
          child: selected
              ? Icon(Icons.check, size: 20, color: checkColor)
              : icon,
        ),
      ),
    );
  }
}

/// Seletor da fonte global da app.
class _AppFontPicker extends StatelessWidget {
  const _AppFontPicker({required this.data, required this.onChanged});

  final AppData data;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = kNoteFonts[data.appFont]?.label ?? 'Padrão';
    return PopupMenuButton<String>(
      tooltip: 'Escolher fonte da app',
      onSelected: (font) {
        data.appFont = font;
        onChanged();
      },
      itemBuilder: (context) => [
        for (final entry in kNoteFonts.entries)
          PopupMenuItem(
            value: entry.key,
            child: Text(
              entry.value.label,
              style: entry.value.build?.call(fontSize: 16),
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.font_download_outlined, size: 20, color: scheme.primary),
            const SizedBox(width: 6),
            Text(current),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}
