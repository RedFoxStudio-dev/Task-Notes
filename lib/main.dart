import 'package:flutter/material.dart';

import 'models.dart';
import 'pages/notes.dart';
import 'pages/routine.dart';
import 'pages/settings.dart';
import 'pages/stats.dart';
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

/// Página raiz: navegação por separadores (Rotina, Estatísticas, ...).
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
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    const titles = ['Task Notes', 'Estatísticas', 'Notas'];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_tab]),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            tooltip: 'Definições',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SettingsPage(
                data: widget.data,
                storage: widget.storage,
                onChanged: widget.onDataChanged,
                onReplaceData: widget.onReplaceData,
              ),
            )),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          RoutinePage(
            data: widget.data,
            storage: widget.storage,
            onChanged: widget.onDataChanged,
          ),
          StatsPage(data: widget.data),
          NotesPage(
            data: widget.data,
            storage: widget.storage,
            onChanged: widget.onDataChanged,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.event_repeat_outlined),
            selectedIcon: Icon(Icons.event_repeat),
            label: 'Rotina',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Estatísticas',
          ),
          NavigationDestination(
            icon: Icon(Icons.sticky_note_2_outlined),
            selectedIcon: Icon(Icons.sticky_note_2),
            label: 'Notas',
          ),
        ],
      ),
    );
  }
}
