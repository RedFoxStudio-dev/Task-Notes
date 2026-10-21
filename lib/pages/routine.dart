import 'package:flutter/material.dart';

import '../models.dart';
import '../popups.dart';
import '../storage.dart';

/// Rotina semanal: um conjunto de tarefas por dia da semana, com filtro de
/// dias, progresso, cópia entre dias e reordenação por toque longo.
class RoutinePage extends StatefulWidget {
  const RoutinePage({
    super.key,
    required this.data,
    required this.storage,
    required this.onChanged,
  });

  final AppData data;
  final AppStorage storage;
  final VoidCallback onChanged;

  @override
  State<RoutinePage> createState() => _RoutinePageState();
}

class _RoutinePageState extends State<RoutinePage> {
  int _selectedDay = DateTime.now().weekday;

  int get _today => DateTime.now().weekday;

  List<Task> get _tasks => widget.data.tasksFor(_selectedDay);

  /// Grava as alterações; o histórico só é atualizado para o dia de hoje.
  void _saved() {
    if (_selectedDay == _today) widget.data.recordDay(_selectedDay);
    widget.onChanged();
  }

  Future<void> _addTask() async {
    final title = await showAddTaskPopup(context);
    if (!mounted || title == null || title.isEmpty) return;
    setState(() {
      _tasks.add(Task(id: widget.storage.newId(), title: title));
    });
    _saved();
  }

  Future<void> _editTask(Task task) async {
    final title = await showEditTaskPopup(context, initialValue: task.title);
    if (!mounted || title == null || title.isEmpty) return;
    setState(() => task.title = title);
    _saved();
  }

  Future<void> _deleteTask(Task task) async {
    final confirmed = await showDeleteConfirmPopup(context, title: task.title);
    if (!mounted || confirmed != true) return;
    setState(() => _tasks.remove(task));
    _saved();
  }

  Future<void> _deleteAllTasks() async {
    if (_tasks.isEmpty) return;
    final confirmed = await showDeleteAllConfirmPopup(context);
    if (!mounted || confirmed != true) return;
    setState(() => _tasks.clear());
    _saved();
  }

  void _toggleTask(Task task, bool value) {
    setState(() => task.done = value);
    _saved();
  }

  void _toggleAllTasks() {
    final allDone = _tasks.isNotEmpty && _tasks.every((t) => t.done);
    setState(() {
      for (final task in _tasks) {
        task.done = !allDone;
      }
    });
    _saved();
  }

  Future<void> _copyFromDay() async {
    final choice = await showCopyDayPopup(context, targetDay: _selectedDay);
    if (!mounted || choice == null) return;
    final source = widget.data.tasksFor(choice.sourceDay);
    final copies = source
        .map((t) => Task(
              id: widget.storage.newId(),
              title: t.title,
              period: t.period,
              icon: t.icon,
            ))
        .toList();
    setState(() {
      if (choice.replace) {
        widget.data.days[_selectedDay]!
          ..clear()
          ..addAll(copies);
      } else {
        _tasks.addAll(copies);
      }
    });
    _saved();
  }

  void _onReorder(int oldIndex, int newIndex) {
    // O newIndex do onReorderItem já vem ajustado ao item removido.
    setState(() {
      final task = _tasks.removeAt(oldIndex);
      _tasks.insert(newIndex, task);
    });
    _saved();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = _tasks.where((t) => t.done).length;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _addTask,
        tooltip: 'Nova tarefa',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                for (var day = 1; day <= 7; day++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        day == _today
                            ? '${kWeekdayLabels[day - 1]} · hoje'
                            : kWeekdayLabels[day - 1],
                      ),
                      selected: _selectedDay == day,
                      onSelected: (_) => setState(() => _selectedDay = day),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: _ProgressCard(
                    done: done,
                    total: _tasks.length,
                    onToggleAll: _toggleAllTasks,
                    onCopy: _copyFromDay,
                    onDeleteAll: _deleteAllTasks,
                  ),
                ),
                Expanded(
                  child: _tasks.isEmpty
                      ? _EmptyDay(
                          onAdd: _addTask,
                          dayLabel: kWeekdayLabels[_selectedDay - 1],
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                          children: [
                            ReorderableListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              buildDefaultDragHandles: false,
                              itemCount: _tasks.length,
                              onReorderItem: _onReorder,
                              itemBuilder: (context, index) {
                                final task = _tasks[index];
                                return _TaskCard(
                                  key: ValueKey(task.id),
                                  task: task,
                                  scheme: scheme,
                                  onToggle: _toggleTask,
                                  onEdit: () => _editTask(task),
                                  onDelete: () => _deleteTask(task),
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            Center(
                              child: Text(
                                'Toque longo numa tarefa para a mover',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: scheme.outline),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    super.key,
    required this.task,
    required this.scheme,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final Task task;
  final ColorScheme scheme;
  final void Function(Task task, bool value) onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: ListTile(
        leading: Checkbox(
          value: task.done,
          onChanged: (value) => onToggle(task, value ?? false),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.done ? TextDecoration.lineThrough : null,
            color: task.done ? scheme.outline : null,
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') onEdit();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit_outlined),
                title: Text('Editar'),
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete_outline),
                title: Text('Eliminar'),
              ),
            ),
          ],
        ),
        onTap: () => onToggle(task, !task.done),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.done,
    required this.total,
    required this.onToggleAll,
    required this.onCopy,
    required this.onDeleteAll,
  });

  final int done;
  final int total;
  final VoidCallback onToggleAll;
  final VoidCallback onCopy;
  final VoidCallback onDeleteAll;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$done de $total concluídas',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Marcar/Desmarcar tudo',
                  icon: const Icon(Icons.done_all),
                  onPressed: total == 0 ? null : onToggleAll,
                ),
                IconButton(
                  tooltip: 'Copiar de outro dia',
                  icon: const Icon(Icons.copy_all_outlined),
                  onPressed: onCopy,
                ),
                IconButton(
                  tooltip: 'Eliminar todas',
                  icon: const Icon(Icons.delete_sweep_outlined),
                  onPressed: total == 0 ? null : onDeleteAll,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : done / total,
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

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.onAdd, required this.dayLabel});

  final VoidCallback onAdd;
  final String dayLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.checklist_rounded, size: 64, color: scheme.outline),
          const SizedBox(height: 16),
          const Text('Sem tarefas'),
          const SizedBox(height: 8),
          Text(
            'Toque no + para adicionar tarefas a $dayLabel',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: scheme.outline),
          ),
        ],
      ),
    );
  }
}
