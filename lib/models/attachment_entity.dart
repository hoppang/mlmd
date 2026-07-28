import 'package:objectbox/objectbox.dart';

import '../features/attachments/domain/event_attachment.dart';

@Entity()
class AttachmentEntity {
  @Id()
  int id;

  @Unique()
  String attachmentId;

  @Index()
  String recordId;

  String payload;
  @Property(type: PropertyType.dateUtc)
  DateTime createdAt;
  @Property(type: PropertyType.dateUtc)
  DateTime? deletedAt;

  AttachmentEntity({
    this.id = 0,
    required this.attachmentId,
    required this.recordId,
    required this.payload,
    required this.createdAt,
    this.deletedAt,
  });

  factory AttachmentEntity.fromDomain(EventAttachment attachment) {
    return AttachmentEntity(
      attachmentId: attachment.attachmentId,
      recordId: attachment.recordId,
      payload: attachment.encode(),
      createdAt: attachment.createdAt,
      deletedAt: attachment.deletedAt,
    );
  }

  EventAttachment? toDomain() => EventAttachment.decode(payload);
}
