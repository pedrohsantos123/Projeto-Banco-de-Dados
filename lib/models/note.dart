import 'package:uuid/uuid.dart';

/// Modelo de nota. O mesmo objeto é usado no SQLite e no Firestore.
class Note {
  final String id;
  final String userId;
  final String title;
  final String content;
  final String category;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool inTrash; // lixeira (exclusão temporária)
  final bool purged; // exclusão definitiva pendente de envio ao Firebase
  final bool synced; // true = já está igual no Firestore

  const Note({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    required this.category,
    required this.createdAt,
    required this.updatedAt,
    this.inTrash = false,
    this.purged = false,
    this.synced = false,
  });

  factory Note.create({
    required String userId,
    required String title,
    required String content,
    required String category,
  }) {
    final now = DateTime.now();
    return Note(
      id: const Uuid().v4(),
      userId: userId,
      title: title,
      content: content,
      category: category,
      createdAt: now,
      updatedAt: now,
    );
  }

  Note copyWith({
    String? title,
    String? content,
    String? category,
    DateTime? updatedAt,
    bool? inTrash,
    bool? purged,
    bool? synced,
  }) {
    return Note(
      id: id,
      userId: userId,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      inTrash: inTrash ?? this.inTrash,
      purged: purged ?? this.purged,
      synced: synced ?? this.synced,
    );
  }

  // ---------- SQLite ----------
  Map<String, Object?> toMap() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'content': content,
        'category': category,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'in_trash': inTrash ? 1 : 0,
        'purged': purged ? 1 : 0,
        'synced': synced ? 1 : 0,
      };

  factory Note.fromMap(Map<String, Object?> m) => Note(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        title: m['title'] as String,
        content: m['content'] as String,
        category: m['category'] as String,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(m['updated_at'] as int),
        inTrash: (m['in_trash'] as int) == 1,
        purged: (m['purged'] as int) == 1,
        synced: (m['synced'] as int) == 1,
      );

  // ---------- Firestore ----------
  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'title': title,
        'content': content,
        'category': category,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'inTrash': inTrash,
      };

  factory Note.fromFirestore(String id, Map<String, dynamic> d) => Note(
        id: id,
        userId: d['userId'] as String,
        title: (d['title'] ?? '') as String,
        content: (d['content'] ?? '') as String,
        category: (d['category'] ?? 'Pessoal') as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(d['createdAt'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(d['updatedAt'] as int),
        inTrash: (d['inTrash'] ?? false) as bool,
        synced: true,
      );
}
