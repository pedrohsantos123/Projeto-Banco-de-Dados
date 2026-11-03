import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/note.dart';

/// Acesso ao banco local (SQLite).
class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();

  Database? _db;

  Future<Database> get _database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'notes.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, _) => db.execute('''
        CREATE TABLE notes(
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          title TEXT NOT NULL,
          content TEXT NOT NULL,
          category TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          in_trash INTEGER NOT NULL DEFAULT 0,
          purged INTEGER NOT NULL DEFAULT 0,
          synced INTEGER NOT NULL DEFAULT 0
        )
      '''),
    );
  }

  Future<void> upsert(Note n) async {
    final db = await _database;
    await db.insert('notes', n.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteRow(String id) async {
    final db = await _database;
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<Note?> getById(String id) async {
    final db = await _database;
    final rows = await db.query('notes', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Note.fromMap(rows.first);
  }

  /// Lista notas visíveis (ou da lixeira), com pesquisa e filtro de categoria.
  Future<List<Note>> list(
    String userId, {
    required bool trash,
    String? query,
    String? category,
  }) async {
    final db = await _database;
    final where = StringBuffer('user_id = ? AND purged = 0 AND in_trash = ?');
    final args = <Object?>[userId, trash ? 1 : 0];

    if (category != null) {
      where.write(' AND category = ?');
      args.add(category);
    }
    final q = query?.trim() ?? '';
    if (q.isNotEmpty) {
      where.write(' AND (title LIKE ? OR content LIKE ?)');
      args.add('%$q%');
      args.add('%$q%');
    }

    final rows = await db.query('notes',
        where: where.toString(), whereArgs: args, orderBy: 'updated_at DESC');
    return rows.map(Note.fromMap).toList();
  }

  /// Todas as linhas do usuário (inclui lixeira e pendentes de exclusão).
  Future<List<Note>> all(String userId) async {
    final db = await _database;
    final rows =
        await db.query('notes', where: 'user_id = ?', whereArgs: [userId]);
    return rows.map(Note.fromMap).toList();
  }

  Future<List<Note>> unsynced(String userId) async {
    final db = await _database;
    final rows = await db.query('notes',
        where: 'user_id = ? AND synced = 0', whereArgs: [userId]);
    return rows.map(Note.fromMap).toList();
  }

  Future<List<String>> distinctCategories(String userId) async {
    final db = await _database;
    final rows = await db.rawQuery(
        'SELECT DISTINCT category FROM notes WHERE user_id = ? AND purged = 0',
        [userId]);
    return rows.map((r) => r['category'] as String).toList();
  }
}
