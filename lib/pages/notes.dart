import 'package:flutter/material.dart';

import '../models.dart';
import '../popups.dart';
import '../storage.dart';

/// Bloco de notas: notas guardadas como "ficheiros" (título + conteúdo),
/// cada uma com o seu tipo de letra.
class NotesPage extends StatefulWidget {
  const NotesPage({
    super.key,
    required this.data,
    required this.storage,
    required this.onChanged,
  });

  final AppData data;
  final AppStorage storage;
  final VoidCallback onChanged;

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  List<Note> get _notes {
    final notes = [...widget.data.notes];
    final byTitle = widget.data.noteSort == 'title';
    notes.sort((a, b) {
      if (byTitle) {
        final titleA =
            a.title.trim().isEmpty ? 'Sem título' : a.title.trim().toLowerCase();
        final titleB =
            b.title.trim().isEmpty ? 'Sem título' : b.title.trim().toLowerCase();
        return titleA.compareTo(titleB);
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return notes;
  }

  Future<void> _addNote() async {
    final note = Note(
      id: widget.storage.newId(),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    setState(() => widget.data.notes.add(note));
    widget.onChanged();

    await _openEditor(note);
    if (!mounted) return;
    // Se saiu do editor sem escrever nada, descartar a nota vazia.
    if (note.title.trim().isEmpty && note.content.trim().isEmpty) {
      setState(() => widget.data.notes.remove(note));
      widget.onChanged();
    }
  }

  Future<void> _openEditor(Note note) {
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          NoteEditorPage(note: note, onChanged: widget.onChanged),
    ));
  }

  Future<void> _deleteNote(Note note) async {
    final name = note.title.trim().isEmpty ? 'Sem título' : note.title;
    final confirmed = await showConfirmPopup(
      context,
      title: 'Eliminar Nota',
      content: 'Queres eliminar "$name"?',
    );
    if (!mounted || confirmed != true) return;
    setState(() => widget.data.notes.remove(note));
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final notes = _notes;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'notes-fab',
        onPressed: _addNote,
        tooltip: 'Nova nota',
        child: const Icon(Icons.add),
      ),
      body: notes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sticky_note_2_outlined,
                      size: 64, color: scheme.outline),
                  const SizedBox(height: 16),
                  const Text('Sem notas'),
                  const SizedBox(height: 8),
                  Text(
                    'Toque no + para criar a tua primeira nota',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: scheme.outline),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              children: [
                for (final note in notes)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    child: ListTile(
                      leading: Icon(
                        Icons.sticky_note_2_outlined,
                        color: scheme.primary,
                      ),
                      title: Text(
                        note.title.trim().isEmpty ? 'Sem título' : note.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        note.content.trim().isEmpty
                            ? 'Nota vazia'
                            : note.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        tooltip: 'Eliminar nota',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteNote(note),
                      ),
                      onTap: () => _openEditor(note),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Editor de notas com auto-save e barra de tipos de letra.
class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({super.key, required this.note, required this.onChanged});

  final Note note;
  final VoidCallback onChanged;

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late final _titleController = TextEditingController(text: widget.note.title);
  late final _contentController =
      TextEditingController(text: widget.note.content);

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_autosave);
    _contentController.addListener(_autosave);
  }

  @override
  void dispose() {
    _titleController.removeListener(_autosave);
    _contentController.removeListener(_autosave);
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _autosave() {
    widget.note
      ..title = _titleController.text
      ..content = _contentController.text
      ..updatedAt = DateTime.now().millisecondsSinceEpoch;
    widget.onChanged();
  }

  void _setFont(String fontFamily) {
    setState(() {
      widget.note.fontFamily = fontFamily;
      widget.note.updatedAt = DateTime.now().millisecondsSinceEpoch;
    });
    widget.onChanged();
  }

  void _setSize(double fontSize) {
    setState(() {
      widget.note.fontSize = fontSize;
      widget.note.updatedAt = DateTime.now().millisecondsSinceEpoch;
    });
    widget.onChanged();
  }

  TextStyle _contentStyle() {
    final build = kNoteFonts[widget.note.fontFamily]?.build;
    return build?.call(fontSize: widget.note.fontSize) ??
        TextStyle(fontSize: widget.note.fontSize);
  }

  String get _fontLabel => kNoteFonts[widget.note.fontFamily]?.label ?? 'Padrão';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Nota')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              style: Theme.of(context).textTheme.titleLarge,
              decoration: const InputDecoration(
                hintText: 'Título',
                border: InputBorder.none,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                PopupMenuButton<String>(
                  tooltip: 'Tipo de letra',
                  onSelected: _setFont,
                  itemBuilder: (context) => [
                    for (final entry in kNoteFonts.entries)
                      PopupMenuItem(
                        value: entry.key,
                        child: Text(
                          entry.value.label,
                          style:
                              entry.value.build?.call(fontSize: 16),
                        ),
                      ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.font_download_outlined,
                            size: 20, color: scheme.primary),
                        const SizedBox(width: 6),
                        Text(_fontLabel),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<double>(
                  tooltip: 'Tamanho da letra',
                  onSelected: _setSize,
                  itemBuilder: (context) => [
                    for (final size in const [14.0, 16.0, 20.0])
                      PopupMenuItem(
                        value: size,
                        child: Text('${size.toInt()}'),
                      ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.format_size,
                            size: 20, color: scheme.primary),
                        const SizedBox(width: 6),
                        Text('${widget.note.fontSize.toInt()}'),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'guarda automaticamente',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: scheme.outline),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _contentController,
                keyboardType: TextInputType.multiline,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                textCapitalization: TextCapitalization.sentences,
                style: _contentStyle(),
                decoration: const InputDecoration(
                  hintText: 'Escreve aqui…',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
