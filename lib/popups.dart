import 'package:flutter/material.dart';

Future<String?> showAddTaskPopup(BuildContext context) {
  return _showTaskInputPopup(
    context,
    dialogTitle: 'Nova Tarefa',
    confirmLabel: 'Adicionar',
  );
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
