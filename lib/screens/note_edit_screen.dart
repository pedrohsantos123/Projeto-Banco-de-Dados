import 'package:flutter/material.dart';

import '../data/note_repository.dart';
import '../models/note.dart';

/// Criação e edição de nota. Se [note] for null, cria uma nova.
class NoteEditScreen extends StatefulWidget {
  const NoteEditScreen({
    super.key,
    required this.repo,
    required this.categories,
    this.note,
  });

  final NoteRepository repo;
  final List<String> categories;
  final Note? note;

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> {
  late final TextEditingController _title;
  late final TextEditingController _content;
  late List<String> _categories;
  late String _category;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.note?.title ?? '');
    _content = TextEditingController(text: widget.note?.content ?? '');
    _categories = [...widget.categories];
    _category = widget.note?.category ?? _categories.first;
    if (!_categories.contains(_category)) _categories.add(_category);
  }

  Future<void> _newCategory() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova categoria'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Criar')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    setState(() {
      if (!_categories.contains(name)) _categories.add(name);
      _category = name;
    });
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final content = _content.text.trim();
    if (title.isEmpty && content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Escreva um título ou conteúdo.')));
      return;
    }
    final old = widget.note;
    final note = old == null
        ? Note.create(
            userId: widget.repo.userId,
            title: title,
            content: content,
            category: _category)
        : old.copyWith(title: title, content: content, category: _category);
    await widget.repo.save(note);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? 'Nova nota' : 'Editar nota'),
        actions: [
          IconButton(
              icon: const Icon(Icons.check), tooltip: 'Salvar', onPressed: _save),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                  labelText: 'Título', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _category,
                    decoration: const InputDecoration(
                        labelText: 'Categoria', border: OutlineInputBorder()),
                    items: _categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _category = v ?? _category),
                  ),
                ),
                IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Nova categoria',
                    onPressed: _newCategory),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _content,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                    labelText: 'Conteúdo', border: OutlineInputBorder()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
