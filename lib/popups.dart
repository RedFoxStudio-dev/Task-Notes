import 'package:flutter/material.dart';

import 'models.dart';

Future<String?> showAddTaskPopup(BuildContext context) {
  return _showTaskInputPopup(
    context,
    dialogTitle: 'Nova Tarefa',
    confirmLabel: 'Adicionar',
  );
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

Future<String?> showEditTaskPopup(
  BuildContext context, {
  required String initialValue,
}) {
  return _showTaskInputPopup(
    context,
    dialogTitle: 'Editar Tarefa',
    confirmLabel: 'Guardar',
    initialValue: initialValue,
  );
}

Future<bool?> showDeleteConfirmPopup(
  BuildContext context, {
  required String title,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Eliminar Tarefa'),
      content: Text('Queres eliminar "$title"?'),
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
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
}

Future<bool?> showDeleteAllConfirmPopup(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Eliminar Tudo'),
      content: const Text('Queres eliminar todas as tarefas?'),
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
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
}

Future<String?> _showTaskInputPopup(
  BuildContext context, {
  required String dialogTitle,
  required String confirmLabel,
  String initialValue = '',
}) {
  final controller = TextEditingController(text: initialValue);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(dialogTitle),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Tarefa',
          hintText: 'Ex.: Beber 2L de água',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}
