import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/note.dart';

/// Acesso ao Cloud Firestore (coleção "notes").
class RemoteRepository {
  final CollectionReference<Map<String, dynamic>> _col =
      FirebaseFirestore.instance.collection('notes');

  Future<void> upsert(Note n) => _col.doc(n.id).set(n.toFirestore());

  Future<void> delete(String id) => _col.doc(id).delete();

  /// Busca somente as notas do usuário (exigido pelas regras de segurança).
  Future<List<Note>> fetchAll(String userId) async {
    final snap = await _col.where('userId', isEqualTo: userId).get();
    return snap.docs.map((d) => Note.fromFirestore(d.id, d.data())).toList();
  }
}
