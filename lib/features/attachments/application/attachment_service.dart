import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../domain/event_attachment.dart';

abstract interface class AttachmentRepository {
  List<EventAttachment> getAttachmentsForRecord(String recordId);
  Future<EventAttachment> saveAttachment(EventAttachment attachment);
  Future<void> deleteAttachment(String attachmentId);
  Future<void> saveAttachmentsForRecord(
    String recordId,
    List<EventAttachment> attachments,
  );
}

class InMemoryAttachmentRepository implements AttachmentRepository {
  final Map<String, EventAttachment> _attachments = {};
  static const _uuid = Uuid();

  @override
  List<EventAttachment> getAttachmentsForRecord(String recordId) {
    return _attachments.values
        .where((att) => att.recordId == recordId && !att.isDeleted)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Future<EventAttachment> saveAttachment(EventAttachment attachment) async {
    final id = attachment.attachmentId.isEmpty
        ? _uuid.v4()
        : attachment.attachmentId;
    final saved = attachment.copyWith(attachmentId: id);
    _attachments[id] = saved;
    return saved;
  }

  @override
  Future<void> deleteAttachment(String attachmentId) async {
    final existing = _attachments[attachmentId];
    if (existing != null) {
      _attachments[attachmentId] = existing.copyWith(
        deletedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<void> saveAttachmentsForRecord(
    String recordId,
    List<EventAttachment> attachments,
  ) async {
    for (final att in attachments) {
      final updated = att.copyWith(recordId: recordId);
      await saveAttachment(updated);
    }
  }
}

final attachmentRepositoryProvider = Provider<AttachmentRepository>((ref) {
  return InMemoryAttachmentRepository();
});

class AttachmentNotifier extends Notifier<List<EventAttachment>> {
  @override
  List<EventAttachment> build() => const [];

  void loadAttachmentsForRecord(String recordId) {
    state = ref.read(attachmentRepositoryProvider).getAttachmentsForRecord(recordId);
  }

  Future<void> saveAttachmentsForRecord(
    String recordId,
    List<EventAttachment> attachments,
  ) async {
    final repository = ref.read(attachmentRepositoryProvider);
    await repository.saveAttachmentsForRecord(recordId, attachments);
    state = repository.getAttachmentsForRecord(recordId);
  }
}

final attachmentNotifierProvider =
    NotifierProvider<AttachmentNotifier, List<EventAttachment>>(
  AttachmentNotifier.new,
  dependencies: [attachmentRepositoryProvider],
);
