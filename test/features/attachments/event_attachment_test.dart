import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/attachments/application/attachment_service.dart';
import 'package:mlmd/features/attachments/domain/event_attachment.dart';
import 'package:mlmd/objectbox.g.dart';

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
      expect(
        decoded.managedOriginalUri,
        'app_storage://prescription_bag_123.jpg',
      );
      expect(decoded.isDeleted, isFalse);
    });

    test('decodes v1 attachment metadata for backward compatibility', () {
      const encodedV1 =
          '{"schema":"mlmd.attachment","version":1,'
          '"attachmentId":"legacy","recordId":"record",'
          '"attachmentType":"general","fileName":"legacy.pdf",'
          '"mimeType":"application/pdf","sourceKind":"filePicker",'
          '"managedOriginalUri":"app_storage://legacy.pdf",'
          '"createdAt":"2026-07-20T00:00:00.000Z"}';

      final decoded = EventAttachment.decode(encodedV1);

      expect(decoded, isNotNull);
      expect(decoded!.attachmentId, 'legacy');
      expect(decoded.originalByteSize, isNull);
      expect(decoded.isDeleted, isFalse);
    });

    test(
      'InMemoryAttachmentRepository saves and retrieves attachments by recordId',
      () async {
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
      },
    );

    test(
      'ObjectBox repository persists metadata and restores soft deletes',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'attachment-objectbox-',
        );
        final store = await openStore(directory: directory.path);
        addTearDown(() async {
          store.close();
          await directory.delete(recursive: true);
        });
        final repository = ObjectBoxAttachmentRepository.fromStore(store);
        final attachment = EventAttachment(
          attachmentId: 'persistent-att',
          recordId: 'persistent-record',
          attachmentType: AttachmentType.general,
          fileName: 'photo.jpg',
          mimeType: 'image/jpeg',
          sourceKind: AttachmentSourceKind.gallery,
          managedOriginalUri: Uri.file('managed/photo.jpg').toString(),
          createdAt: DateTime.utc(2026, 7, 28),
          originalByteSize: 42,
          originalSha256: 'abc123',
        );

        await repository.saveAttachment(attachment);
        final reopened = ObjectBoxAttachmentRepository.fromStore(store);
        expect(
          reopened
              .getAttachmentsForRecord('persistent-record')
              .single
              .originalByteSize,
          42,
        );

        await reopened.deleteAttachment(
          attachment.attachmentId,
          deletedAt: DateTime.utc(2026, 7, 29),
        );
        expect(reopened.getAttachmentsForRecord('persistent-record'), isEmpty);
        expect(
          reopened
              .getAttachmentsForRecord(
                'persistent-record',
                includeDeleted: true,
              )
              .single
              .isDeleted,
          isTrue,
        );

        await reopened.restoreAttachment(attachment.attachmentId);
        expect(
          reopened
              .getAttachmentsForRecord('persistent-record')
              .single
              .isDeleted,
          isFalse,
        );
      },
    );
  });
}
