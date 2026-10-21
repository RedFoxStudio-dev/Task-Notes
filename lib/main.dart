import 'package:flutter/material.dart';

import 'models.dart';
import 'pages/routine.dart';
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

/// Página raiz (fase 1): rotina semanal; navegação por separadores chega na
/// fase 3, com as páginas de estatísticas e notas.
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Notes'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: RoutinePage(
        data: widget.data,
        storage: widget.storage,
        onChanged: widget.onDataChanged,
      ),
    );
  }
}
