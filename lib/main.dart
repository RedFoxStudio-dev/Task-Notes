import 'package:flutter/material.dart';

import 'models.dart';
import 'popups.dart';
import 'storage.dart';
import 'theme.dart';

void main() {
  runApp(const TaskNoteApp());
}

class TaskNoteApp extends StatefulWidget {
  const TaskNoteApp({super.key});

  @override
  State<TaskNoteApp> createState() => _TaskNoteAppState();
}

class _TaskNoteAppState extends State<TaskNoteApp> with WidgetsBindingObserver {
  final _storage = AppStorage();
  AppData? _data;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Ao voltar do background, reaplica o reset diário (pode ter mudado o dia)
    // e atualiza o histórico de hoje.
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final data = await _storage.loadAndRefresh();
    if (!mounted) return;
    setState(() => _data = data);
  }

  /// Chamado pelas páginas depois de qualquer alteração aos dados.
  void _onDataChanged() {
    setState(() {});
    _storage.save(_data!);
  }

  /// Substitui todos os dados (importação de backup).
  void _onReplaceData(AppData data) {
    setState(() => _data = data);
    _storage.save(data);
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data == null) {
      return MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return MaterialApp(
      title: 'Task Notes',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: data.theme,
      home: RootPage(
        data: data,
        storage: _storage,
        onDataChanged: _onDataChanged,
        onReplaceData: _onReplaceData,
      ),
    );
  }
}

/// Página raiz (interina da fase 0): lista do dia atual sobre os novos dados.
class RootPage extends StatefulWidget {
  const RootPage({
    super.key,
    required this.data,
    required this.storage,
    required this.onDataChanged,
    required this.onReplaceData,
  });

  final AppData data;
  final AppStorage storage;
  final VoidCallback onDataChanged;
  final void Function(AppData data) onReplaceData;

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  int get _today => DateTime.now().weekday;

  List<Task> get _tasks => widget.data.tasksFor(_today);

  void _saved() {
    widget.data.recordDay(_today);
    widget.onDataChanged();
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

  Future<void> _deleteAllTasks() async {
    final confirmed = await showDeleteAllConfirmPopup(context);
    if (!mounted || confirmed != true) return;
    setState(() => _tasks.clear());
    _saved();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Notes'),
        backgroundColor: scheme.inversePrimary,
        actions: [
          IconButton(
            tooltip: 'Marcar/Desmarcar tudo',
            icon: const Icon(Icons.done_all),
            onPressed: _tasks.isEmpty ? null : _toggleAllTasks,
          ),
          IconButton(
            tooltip: 'Eliminar tudo',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _tasks.isEmpty ? null : _deleteAllTasks,
          ),
        ],
      ),
      body: _tasks.isEmpty
          ? const _EmptyState()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                final task = _tasks[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: scheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: ListTile(
                    leading: Checkbox(
                      value: task.done,
                      onChanged: (value) => _toggleTask(task, value ?? false),
                    ),
                    title: Text(
                      task.title,
                      style: TextStyle(
                        decoration:
                            task.done ? TextDecoration.lineThrough : null,
                        color: task.done ? scheme.outline : null,
                      ),
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') _editTask(task);
                        if (value == 'delete') _deleteTask(task);
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
                    onTap: () => _toggleTask(task, !task.done),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTask,
        tooltip: 'Nova tarefa',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.checklist_rounded,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          const Text('Sem tarefas'),
          const SizedBox(height: 8),
          Text(
            'Toque no + para adicionar a tua primeira tarefa',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Theme.of(context).colorScheme.outline),
          ),
        ],
      ),
    );
  }
}
