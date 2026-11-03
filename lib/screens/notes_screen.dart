import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/note_repository.dart';
import '../models/note.dart';
import '../services/auth_service.dart';
import 'note_edit_screen.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key, required this.user});

  final User user;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  late final NoteRepository _repo = NoteRepository(widget.user.uid);
  final _searchCtrl = TextEditingController();

  List<Note> _notes = [];
  List<String> _categories = [];
  String? _category; // null = todas
  String _query = '';
  bool _searching = false;
  bool _trash = false;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _load();
    _sync();
  }

  Future<void> _load() async {
    final notes =
        await _repo.list(query: _query, category: _category, trash: _trash);
    final cats = await _repo.categories();
    if (!mounted) return;
    setState(() {
      _notes = notes;
      _categories = cats;
    });
  }

  Future<void> _sync() async {
    setState(() => _syncing = true);
    final ok = await _repo.sync();
    if (!mounted) return;
    setState(() => _syncing = false);
    await _load();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Sem acesso ao Firebase. Suas notas estão salvas '
              'no aparelho e serão enviadas depois.')));
    }
  }

  Future<void> _openEditor([Note? note]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteEditScreen(
            repo: _repo, categories: _categories, note: note),
      ),
    );
    _load();
  }

  Future<void> _confirmDelete(Note n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir definitivamente?'),
        content: const Text('Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Excluir')),
        ],
      ),
    );
    if (ok == true) {
      await _repo.deletePermanently(n);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                    hintText: 'Pesquisar título ou conteúdo',
                    border: InputBorder.none),
                onChanged: (v) {
                  _query = v;
                  _load();
                },
              )
            : Text(_trash ? 'Lixeira' : 'Minhas notas'),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _searching = !_searching;
                if (!_searching) {
                  _query = '';
                  _searchCtrl.clear();
                }
              });
              _load();
            },
          ),
          IconButton(
            icon: Icon(_trash ? Icons.notes : Icons.delete_outline),
            tooltip: _trash ? 'Voltar às notas' : 'Lixeira',
            onPressed: () {
              setState(() => _trash = !_trash);
              _load();
            },
          ),
          _syncing
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)))
              : IconButton(
                  icon: const Icon(Icons.sync),
                  tooltip: 'Sincronizar',
                  onPressed: _sync),
          IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sair',
              onPressed: () => AuthService().signOut()),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('Todas'),
                    selected: _category == null,
                    onSelected: (_) {
                      setState(() => _category = null);
                      _load();
                    },
                  ),
                ),
                for (final c in _categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c),
                      selected: _category == c,
                      onSelected: (_) {
                        setState(() => _category = c);
                        _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _notes.isEmpty
                ? Center(
                    child: Text(_query.isNotEmpty
                        ? 'Nenhuma nota encontrada.'
                        : _trash
                            ? 'Lixeira vazia.'
                            : 'Nenhuma nota ainda.'))
                : ListView.builder(
                    itemCount: _notes.length,
                    itemBuilder: (_, i) => _tile(_notes[i]),
                  ),
          ),
        ],
      ),
      floatingActionButton: _trash
          ? null
          : FloatingActionButton(
              onPressed: () => _openEditor(),
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _tile(Note n) {
    return ListTile(
      title: Text(n.title.isEmpty ? '(sem título)' : n.title,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${n.category} • ${n.content}',
          maxLines: 2, overflow: TextOverflow.ellipsis),
      onTap: _trash ? null : () => _openEditor(n),
      trailing: _trash
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                icon: const Icon(Icons.restore),
                tooltip: 'Restaurar',
                onPressed: () async {
                  await _repo.restore(n);
                  _load();
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_forever),
                tooltip: 'Excluir definitivamente',
                onPressed: () => _confirmDelete(n),
              ),
            ])
          : Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(n.synced ? Icons.cloud_done : Icons.cloud_off,
                  size: 18, color: n.synced ? Colors.green : Colors.grey),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Mover para a lixeira',
                onPressed: () async {
                  await _repo.moveToTrash(n);
                  _load();
                },
              ),
            ]),
    );
  }
}
