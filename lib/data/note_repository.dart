import 'local_db.dart';
import 'remote_repository.dart';
import '../models/note.dart';

const defaultCategories = ['Estudos', 'Trabalho', 'Pessoal'];

/// Padrão Repository: a interface só conversa com esta classe.
/// Estratégia "local-first": toda escrita vai primeiro ao SQLite e depois
/// tenta ir ao Firestore. Se falhar, a nota fica com synced = false e é
/// reenviada na próxima sincronização.
class NoteRepository {
  NoteRepository(this.userId);

  final String userId;
  final LocalDb _local = LocalDb.instance;
  final RemoteRepository _remote = RemoteRepository();

  // ---------- Consultas (sempre no SQLite, funcionam offline) ----------
  Future<List<Note>> list(
          {String? query, String? category, bool trash = false}) =>
      _local.list(userId, trash: trash, query: query, category: category);

  Future<List<String>> categories() async {
    final used = await _local.distinctCategories(userId);
    return {...defaultCategories, ...used}.toList();
  }

  // ---------- Escritas ----------
  Future<void> save(Note note) async {
    final n = note.copyWith(updatedAt: DateTime.now(), synced: false);
    await _local.upsert(n);
    await _push(n);
  }

  Future<void> moveToTrash(Note note) => save(note.copyWith(inTrash: true));

  Future<void> restore(Note note) => save(note.copyWith(inTrash: false));

  /// Exclusão definitiva: marca como "purged" e remove do Firestore.
  /// Se estiver offline, a linha local permanece até a próxima sincronização.
  Future<void> deletePermanently(Note note) async {
    final n = note.copyWith(purged: true, synced: false);
    await _local.upsert(n);
    await _push(n);
  }

  /// Retorna true se conseguiu enviar ao Firebase.
  Future<bool> _push(Note n) async {
    try {
      if (n.purged) {
        await _remote.delete(n.id);
        await _local.deleteRow(n.id);
      } else {
        await _remote.upsert(n);
        await _local.upsert(n.copyWith(synced: true));
      }
      return true;
    } catch (_) {
      return false; // sem conexão / permissão negada: mantém pendente
    }
  }

  // ---------- Sincronização ----------
  /// 1) envia pendências locais; 2) baixa o que está na nuvem.
  /// Conflitos: vence a versão com updatedAt mais recente.
  /// Retorna false se houve falha de conexão/acesso.
  Future<bool> sync() async {
    try {
      for (final n in await _local.unsynced(userId)) {
        if (!await _push(n)) return false;
      }

      final remote = await _remote.fetchAll(userId);
      final remoteIds = remote.map((r) => r.id).toSet();

      for (final r in remote) {
        final local = await _local.getById(r.id);
        if (local == null ||
            (local.synced && r.updatedAt.isAfter(local.updatedAt))) {
          await _local.upsert(r.copyWith(synced: true));
        }
      }

      // Nota apagada definitivamente em outro aparelho: remove localmente.
      for (final l in await _local.all(userId)) {
        if (l.synced && !remoteIds.contains(l.id)) {
          await _local.deleteRow(l.id);
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
