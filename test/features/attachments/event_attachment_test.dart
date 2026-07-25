import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/attachments/application/attachment_service.dart';
import 'package:mlmd/features/attachments/domain/event_attachment.dart';

void main() {
  group('EventAttachment Domain & Service Tests', () {
    test('encode and decode prescription bag attachment', () {
      final now = DateTime(2026, 7, 25, 15, 0);
      final attachment = EventAttachment(
        attachmentId: 'att-001',
        recordId: 'rec-001',
        attachmentType: AttachmentType.prescriptionBag,
        fileName: 'prescription_bag_123.jpg',
        mimeType: 'image/jpeg',
        sourceKind: AttachmentSourceKind.inAppCamera,
        managedOriginalUri: 'app_storage://prescription_bag_123.jpg',
        createdAt: now,
      );

      final jsonString = attachment.encode();
      final decoded = EventAttachment.decode(jsonString);

      expect(decoded, isNotNull);
      expect(decoded!.attachmentId, 'att-001');
      expect(decoded.recordId, 'rec-001');
      expect(decoded.attachmentType, AttachmentType.prescriptionBag);
      expect(decoded.fileName, 'prescription_bag_123.jpg');
      expect(decoded.mimeType, 'image/jpeg');
      expect(decoded.sourceKind, AttachmentSourceKind.inAppCamera);
      expect(decoded.managedOriginalUri, 'app_storage://prescription_bag_123.jpg');
      expect(decoded.isDeleted, isFalse);
    });

    test('InMemoryAttachmentRepository saves and retrieves attachments by recordId', () async {
      final repo = InMemoryAttachmentRepository();
      final now = DateTime.now();

      final att1 = EventAttachment(
        attachmentId: 'att-1',
        recordId: 'rec-A',
        attachmentType: AttachmentType.prescriptionBag,
        fileName: 'bag.jpg',
        mimeType: 'image/jpeg',
        sourceKind: AttachmentSourceKind.inAppCamera,
        managedOriginalUri: 'app_storage://bag.jpg',
        createdAt: now,
      );

      final att2 = EventAttachment(
        attachmentId: 'att-2',
        recordId: 'rec-A',
        attachmentType: AttachmentType.general,
        fileName: 'doc.pdf',
        mimeType: 'application/pdf',
        sourceKind: AttachmentSourceKind.filePicker,
        managedOriginalUri: 'app_storage://doc.pdf',
        createdAt: now.add(const Duration(minutes: 1)),
      );

      await repo.saveAttachment(att1);
      await repo.saveAttachment(att2);

      final listA = repo.getAttachmentsForRecord('rec-A');
      expect(listA.length, 2);
      expect(listA[0].attachmentType, AttachmentType.prescriptionBag);
      expect(listA[1].attachmentType, AttachmentType.general);

      final listB = repo.getAttachmentsForRecord('rec-B');
      expect(listB, isEmpty);

      await repo.deleteAttachment('att-1');
      final listAAfterDelete = repo.getAttachmentsForRecord('rec-A');
      expect(listAAfterDelete.length, 1);
      expect(listAAfterDelete[0].attachmentId, 'att-2');
    });
  });
}
