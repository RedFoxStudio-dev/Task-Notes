import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:task_note/popups.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TaskNoteApp());
}

class Task {
  final String id;
  String title;
  bool done;

  Task({
    required this.id,
    required this.title,
    this.done = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'done': done,
      };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as String,
        title: json['title'] as String,
        done: json['done'] as bool? ?? false,
      );
}

class TaskNoteApp extends StatelessWidget {
  const TaskNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Notes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const TaskListPage(),
    );
  }
}

class TaskListPage extends StatefulWidget {
  const TaskListPage({super.key});

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
  static const _tasksKey = 'tasks';
  static const _lastResetKey = 'last_reset';

  List<Task> _tasks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  String _todayKey() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_tasksKey);
    List<Task> tasks = [];
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        tasks = decoded
            .map((e) => Task.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        tasks = [];
      }
    }

    if (prefs.getString(_lastResetKey) != _todayKey()) {
      for (final task in tasks) {
        task.done = false;
      }
      await prefs.setString(_lastResetKey, _todayKey());
      await _saveTasks(tasks);
    }

    setState(() {
      _tasks = tasks;
      _loading = false;
    });
  }

  Future<void> _saveTasks([List<Task>? tasks]) async {
    final prefs = await SharedPreferences.getInstance();
    final list = tasks ?? _tasks;
    await prefs.setString(
      _tasksKey,
      jsonEncode(list.map((t) => t.toJson()).toList()),
    );
  }

  Future<void> _addTask() async {
    final title = await showAddTaskPopup(context);
    if (title == null || title.isEmpty) return;
    final task = Task(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
    );
    setState(() => _tasks.add(task));
    await _saveTasks();
  }

  Future<void> _editTask(Task task) async {
    final title = await showEditTaskPopup(context, initialValue: task.title);
    if (title == null || title.isEmpty) return;
    setState(() => task.title = title);
    await _saveTasks();
  }

  Future<void> _deleteTask(Task task) async {
    final confirmed = await showDeleteConfirmPopup(
      context,
      title: task.title,
    );
    if (confirmed != true) return;
    setState(() => _tasks.remove(task));
    await _saveTasks();
  }

  Future<void> _toggleTask(Task task, bool value) async {
    setState(() => task.done = value);
    await _saveTasks();
  }

  Future<void> _resetAllTasks() async {
    setState(() {
      for (final task in _tasks) {
        task.done = false;
      }
    });
    await _saveTasks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Notes'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            tooltip: 'Resetar tudo',
            icon: const Icon(Icons.restart_alt),
            onPressed: _tasks.isEmpty ? null : _resetAllTasks,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
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
                          color: Theme.of(context)
                              .colorScheme
                              .outlineVariant
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      child: ListTile(
                        leading: Checkbox(
                          value: task.done,
                          onChanged: (value) =>
                              _toggleTask(task, value ?? false),
                        ),
                        title: Text(
                          task.title,
                          style: TextStyle(
                            decoration:
                                task.done ? TextDecoration.lineThrough : null,
                            color: task.done
                                ? Theme.of(context).colorScheme.outline
                                : null,
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
          Text(
            'Sem tarefas',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Toque no + para adicionar a tua primeira tarefa',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }
}
