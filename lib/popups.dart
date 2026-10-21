import 'package:flutter/material.dart';

import 'models.dart';

/// Resultado do pop-up de criação/edição de tarefas.
class TaskDraft {
  final String title;
  final int period;
  final String? icon;

  const TaskDraft({required this.title, required this.period, this.icon});
}

/// Pop-up para criar ou editar uma tarefa: título, período e ícone.
Future<TaskDraft?> showTaskEditorPopup(
  BuildContext context, {
  Task? initial,
}) {
  return showDialog<TaskDraft>(
    context: context,
    builder: (context) => _TaskEditorDialog(initial: initial),
  );
}

class _TaskEditorDialog extends StatefulWidget {
  const _TaskEditorDialog({this.initial});

  final Task? initial;

  @override
  State<_TaskEditorDialog> createState() => _TaskEditorDialogState();
}

class _TaskEditorDialogState extends State<_TaskEditorDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial?.title ?? '');
  late int _period = widget.initial?.period ?? 0;
  late String? _icon = widget.initial?.icon;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context)
        .pop(TaskDraft(title: title, period: _period, icon: _icon));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isNew = widget.initial == null;
    return AlertDialog(
      title: Text(isNew ? 'Nova Tarefa' : 'Editar Tarefa'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Tarefa',
                hintText: 'Ex.: Beber 2L de água',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Text('Período',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: scheme.outline)),
            Wrap(
              spacing: 8,
              children: [
                for (var period = 0; period < 3; period++)
                  ChoiceChip(
                    label: Text(kPeriodLabels[period]),
                    selected: _period == period,
                    onSelected: (_) => setState(() => _period = period),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Ícone',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: scheme.outline)),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                IconButton(
                  tooltip: 'Sem ícone',
                  isSelected: _icon == null,
                  icon: const Icon(Icons.block_outlined),
                  onPressed: () => setState(() => _icon = null),
                ),
                for (final entry in kTaskIcons.entries)
                  IconButton(
                    tooltip: entry.key,
                    isSelected: _icon == entry.key,
                    icon: Icon(entry.value),
                    onPressed: () => setState(() => _icon = entry.key),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(isNew ? 'Adicionar' : 'Guardar'),
        ),
      ],
    );
  }
}

/// Escolha de cópia entre dias.
class CopyDayChoice {
  final int sourceDay;
  final bool replace;

  const CopyDayChoice({required this.sourceDay, required this.replace});
}

/// Pop-up para copiar as tarefas de outro dia para o dia indicado.
Future<CopyDayChoice?> showCopyDayPopup(
  BuildContext context, {
  required int targetDay,
}) {
  return showDialog<CopyDayChoice>(
    context: context,
    builder: (context) => _CopyDayDialog(targetDay: targetDay),
  );
}

class _CopyDayDialog extends StatefulWidget {
  const _CopyDayDialog({required this.targetDay});

  final int targetDay;

  @override
  State<_CopyDayDialog> createState() => _CopyDayDialogState();
}

class _CopyDayDialogState extends State<_CopyDayDialog> {
  int? _sourceDay;
  bool _replace = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Copiar tarefas'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Copiar as tarefas de que dia para '
              '${kWeekdayLabels[widget.targetDay - 1]}?',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (var day = 1; day <= 7; day++)
                  if (day != widget.targetDay)
                    ChoiceChip(
                      label: Text(kWeekdayLabels[day - 1]),
                      selected: _sourceDay == day,
                      onSelected: (_) => setState(() => _sourceDay = day),
                    ),
              ],
            ),
            RadioGroup<bool>(
              groupValue: _replace,
              onChanged: (value) => setState(() => _replace = value ?? false),
              child: Column(
                children: [
                  RadioListTile<bool>(
                    value: false,
                    title: const Text('Adicionar às existentes'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  RadioListTile<bool>(
                    value: true,
                    title: const Text('Substituir as existentes'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _sourceDay == null
              ? null
              : () => Navigator.of(context).pop(
                    CopyDayChoice(sourceDay: _sourceDay!, replace: _replace),
                  ),
          child: const Text('Copiar'),
        ),
      ],
    );
  }
}

/// Confirmação de eliminação (tarefa, nota, arquivo...).
Future<bool?> showConfirmPopup(
  BuildContext context, {
  required String title,
  required String content,
  String confirmLabel = 'Eliminar',
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}

Future<bool?> showDeleteConfirmPopup(
  BuildContext context, {
  required String title,
}) {
  return showConfirmPopup(
    context,
    title: 'Eliminar Tarefa',
    content: 'Queres eliminar "$title"?',
  );
}

Future<bool?> showDeleteAllConfirmPopup(BuildContext context) {
  return showConfirmPopup(
    context,
    title: 'Eliminar Tudo',
    content: 'Queres eliminar todas as tarefas?',
  );
}
