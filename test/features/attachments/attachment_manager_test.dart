import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'package:mlmd/features/attachments/application/attachment_service.dart';
import 'package:mlmd/features/attachments/domain/event_attachment.dart';

void main() {
  group('AttachmentManager UX-036', () {
    late Directory tempDir;
    late Directory managedRoot;
    late InMemoryAttachmentRepository repository;
    late LocalAttachmentFileStore fileStore;
    late AttachmentManager manager;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'attachment-manager-test-',
      );
      managedRoot = Directory(p.join(tempDir.path, 'managed'));
      repository = InMemoryAttachmentRepository();
      fileStore = LocalAttachmentFileStore(managedRoot);
      manager = AttachmentManager(
        repository: repository,
        fileStore: fileStore,
        uuid: const Uuid(),
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'importFile preserves the external source and creates independent managed copies',
      () async {
        final source = File(p.join(tempDir.path, 'source.jpg'));
        await source.writeAsBytes([1, 2, 3, 4, 5, 6]);

        final first = await manager.importFile(
          source: source,
          recordId: 'record-a',
          attachmentType: AttachmentType.general,
          sourceKind: AttachmentSourceKind.filePicker,
          mimeType: 'image/jpeg',
          fileName: 'photo.jpg',
          createdAt: DateTime(2026, 7, 28, 10, 0),
        );
        final second = await manager.importFile(
          source: source,
          recordId: 'record-b',
          attachmentType: AttachmentType.general,
          sourceKind: AttachmentSourceKind.filePicker,
          mimeType: 'image/jpeg',
          fileName: 'photo.jpg',
          createdAt: DateTime(2026, 7, 28, 10, 1),
        );

        expect(await source.exists(), isTrue);
        expect(first.managedOriginalUri, isNot(second.managedOriginalUri));
        expect(first.attachmentId, isNot(second.attachmentId));
        expect(first.originalByteSize, 6);
        expect(second.originalByteSize, 6);

        final firstFile = await fileStore.resolve(first.managedOriginalUri);
        final secondFile = await fileStore.resolve(second.managedOriginalUri);
        expect(firstFile, isNotNull);
        expect(secondFile, isNotNull);
        expect(await firstFile!.readAsBytes(), [1, 2, 3, 4, 5, 6]);
        expect(await secondFile!.readAsBytes(), [1, 2, 3, 4, 5, 6]);

        await firstFile.writeAsBytes([9, 9, 9]);
        expect(await source.readAsBytes(), [1, 2, 3, 4, 5, 6]);
        expect(await secondFile.readAsBytes(), [1, 2, 3, 4, 5, 6]);
      },
    );

    test('delete and restore are soft operations', () async {
      final source = File(p.join(tempDir.path, 'source.pdf'));
      await source.writeAsBytes([7, 8, 9]);

      final attachment = await manager.importFile(
        source: source,
        recordId: 'record-a',
        attachmentType: AttachmentType.general,
        sourceKind: AttachmentSourceKind.filePicker,
        mimeType: 'application/pdf',
        createdAt: DateTime(2026, 7, 28, 11, 0),
      );

      await manager.delete(
        attachment.attachmentId,
        deletedAt: DateTime(2026, 7, 28, 12, 0),
      );
      final deleted = repository.getAllAttachments(includeDeleted: true).single;
      expect(deleted.isDeleted, isTrue);
      expect(repository.getAllAttachments(), isEmpty);

      await manager.restore(attachment.attachmentId);
      final restored = repository.getAllAttachments().single;
      expect(restored.isDeleted, isFalse);
      expect(restored.attachmentId, attachment.attachmentId);
    });

    test(
      'purgeDeletedBefore removes only managed copies and metadata past the cutoff',
      () async {
        final source = File(p.join(tempDir.path, 'source.bin'));
        await source.writeAsBytes([10, 11, 12, 13]);

        final before = await manager.importFile(
          source: source,
          recordId: 'record-a',
          attachmentType: AttachmentType.general,
          sourceKind: AttachmentSourceKind.filePicker,
          mimeType: 'application/octet-stream',
          createdAt: DateTime(2026, 7, 28, 9, 0),
        );
        final after = await manager.importFile(
          source: source,
          recordId: 'record-a',
          attachmentType: AttachmentType.general,
          sourceKind: AttachmentSourceKind.filePicker,
          mimeType: 'application/octet-stream',
          createdAt: DateTime(2026, 7, 28, 9, 30),
        );

        await manager.delete(
          before.attachmentId,
          deletedAt: DateTime(2026, 7, 28, 10, 0),
        );
        await manager.delete(
          after.attachmentId,
          deletedAt: DateTime(2026, 7, 28, 12, 0),
        );

        final purged = await manager.purgeDeletedBefore(
          DateTime(2026, 7, 28, 11, 0),
        );

        expect(purged, 1);
        expect(repository.getAllAttachments(includeDeleted: true).length, 1);
        expect(
          repository
              .getAllAttachments(includeDeleted: true)
              .single
              .attachmentId,
          after.attachmentId,
        );
        expect(await source.exists(), isTrue);
        expect(await fileStore.resolve(before.managedOriginalUri), isNull);
        expect(await fileStore.resolve(after.managedOriginalUri), isNotNull);
      },
    );

    test(
      'share selection prefers reduced images except protected types that keep original quality',
      () async {
        final imageSource = File(p.join(tempDir.path, 'photo.jpg'));
        await imageSource.writeAsBytes([1, 1, 1, 1]);
        final protectedSource = File(p.join(tempDir.path, 'protected.jpg'));
        await protectedSource.writeAsBytes([2, 2, 2, 2]);

        final image = await manager.importFile(
          source: imageSource,
          recordId: 'record-a',
          attachmentType: AttachmentType.general,
          sourceKind: AttachmentSourceKind.filePicker,
          mimeType: 'image/jpeg',
          createdAt: DateTime(2026, 7, 28, 13, 0),
        );
        final protected = await manager.importFile(
          source: protectedSource,
          recordId: 'record-a',
          attachmentType: AttachmentType.prescriptionBag,
          sourceKind: AttachmentSourceKind.filePicker,
          mimeType: 'image/jpeg',
          createdAt: DateTime(2026, 7, 28, 13, 1),
        );

        final optimized = File(p.join(tempDir.path, 'optimized.jpg'));
        await optimized.writeAsBytes([3, 3]);
        final optimizedManaged = await fileStore.copyOriginal(
          source: optimized,
          recordId: image.recordId,
          attachmentId: image.attachmentId,
          fileName: 'optimized.jpg',
        );
        await repository.saveAttachment(
          image.copyWith(
            managedOptimizedUri: optimizedManaged.uri.toString(),
            optimizedByteSize: optimizedManaged.byteSize,
          ),
        );

        final reducedShare = await manager.fileForSharing(
          repository.getAllAttachments().firstWhere(
            (a) => a.attachmentId == image.attachmentId,
          ),
          AttachmentShareQuality.reduced,
        );
        final protectedShare = await manager.fileForSharing(
          repository.getAllAttachments().firstWhere(
            (a) => a.attachmentId == protected.attachmentId,
          ),
          AttachmentShareQuality.reduced,
        );

        expect(reducedShare, isNotNull);
        expect(p.basename(reducedShare!.path), 'optimized.jpg');
        expect(protectedShare, isNotNull);
        expect(p.basename(protectedShare!.path), 'protected.jpg');
      },
    );

    test(
      'missing derived cache safely falls back to managed original',
      () async {
        final source = File(p.join(tempDir.path, 'fallback-original.jpg'));
        await source.writeAsBytes([1, 2, 3, 4]);
        final attachment = await manager.importFile(
          source: source,
          recordId: 'record-a',
          attachmentType: AttachmentType.general,
          sourceKind: AttachmentSourceKind.gallery,
          mimeType: 'image/jpeg',
        );
        final missingOptimized = File(
          p.join(tempDir.path, 'missing-optimized.jpg'),
        );
        final withStaleCache = attachment.copyWith(
          managedOptimizedUri: missingOptimized.uri.toString(),
          optimizedByteSize: 1,
        );
        await repository.saveAttachment(withStaleCache);

        final shareFile = await manager.fileForSharing(
          withStaleCache,
          AttachmentShareQuality.reduced,
        );
        final plan = await manager.planExport(
          AttachmentExportMode.reducedAttachments,
        );

        expect(shareFile?.uri, Uri.parse(attachment.managedOriginalUri));
        expect(plan.items.single.usedOriginalFallback, isTrue);
        expect(plan.items.single.byteSize, 4);
        expect(plan.issues, isEmpty);
      },
    );

    test(
      'export recalculates checksum and reports modified managed original',
      () async {
        final source = File(p.join(tempDir.path, 'integrity.jpg'));
        await source.writeAsBytes([1, 2, 3]);
        final attachment = await manager.importFile(
          source: source,
          recordId: 'record-a',
          attachmentType: AttachmentType.general,
          sourceKind: AttachmentSourceKind.gallery,
          mimeType: 'image/jpeg',
        );
        final managed = await fileStore.resolve(attachment.managedOriginalUri);
        await managed!.writeAsBytes([9, 9, 9, 9]);

        final plan = await manager.planExport(
          AttachmentExportMode.originalAttachments,
        );

        expect(plan.items.single.sha256, isNot(attachment.originalSha256));
        expect(plan.items.single.byteSize, 4);
        expect(plan.issues.single.reason, 'managed_file_checksum_mismatch');
        expect(plan.requiresMissingFileConfirmation, isTrue);
      },
    );

    test('managed URI resolution rejects external files', () async {
      final external = File(p.join(tempDir.path, 'external.txt'));
      await external.writeAsString('external');

      expect(await fileStore.resolve(external.uri.toString()), isNull);
      expect(await external.exists(), isTrue);
    });

    test('export plan reports expected size and missing-file issues', () async {
      final goodSource = File(p.join(tempDir.path, 'good.jpg'));
      await goodSource.writeAsBytes([4, 4, 4, 4]);
      final missingReducedSource = File(
        p.join(tempDir.path, 'missing-reduced.jpg'),
      );
      await missingReducedSource.writeAsBytes([5, 5, 5, 5, 5]);

      await manager.importFile(
        source: goodSource,
        recordId: 'record-a',
        attachmentType: AttachmentType.general,
        sourceKind: AttachmentSourceKind.filePicker,
        mimeType: 'image/jpeg',
        createdAt: DateTime(2026, 7, 28, 14, 0),
      );
      final missingReduced = await manager.importFile(
        source: missingReducedSource,
        recordId: 'record-a',
        attachmentType: AttachmentType.general,
        sourceKind: AttachmentSourceKind.filePicker,
        mimeType: 'image/jpeg',
        createdAt: DateTime(2026, 7, 28, 14, 1),
      );

      final optimized = File(p.join(tempDir.path, 'export-optimized.jpg'));
      await optimized.writeAsBytes([6, 6]);
      final optimizedManaged = await fileStore.copyOriginal(
        source: optimized,
        recordId: missingReduced.recordId,
        attachmentId: missingReduced.attachmentId,
        fileName: 'export-optimized.jpg',
      );
      await repository.saveAttachment(
        missingReduced.copyWith(
          managedOptimizedUri: optimizedManaged.uri.toString(),
          optimizedByteSize: optimizedManaged.byteSize,
        ),
      );

      final missingOriginal = await manager.importFile(
        source: File(p.join(tempDir.path, 'missing-original.jpg'))
          ..writeAsBytesSync([7, 7, 7]),
        recordId: 'record-a',
        attachmentType: AttachmentType.general,
        sourceKind: AttachmentSourceKind.filePicker,
        mimeType: 'image/jpeg',
        createdAt: DateTime(2026, 7, 28, 14, 2),
      );

      final missingFile = await fileStore.resolve(
        missingOriginal.managedOriginalUri,
      );
      expect(missingFile, isNotNull);
      await missingFile!.delete();

      final plan = await manager.planExport(
        AttachmentExportMode.reducedAttachments,
      );

      expect(plan.mode, AttachmentExportMode.reducedAttachments);
      expect(plan.items.length, 2);
      expect(plan.issues.length, 1);
      expect(plan.estimatedBytes, 6);
      expect(plan.requiresMissingFileConfirmation, isTrue);
      expect(plan.items.any((item) => item.usedOriginalFallback), isTrue);
      expect(plan.issues.single.attachmentId, missingOriginal.attachmentId);
    });

    test(
      'measureUsage separates original, optimized, and thumbnail bytes',
      () async {
        final original = File(p.join(tempDir.path, 'usage-original.jpg'));
        await original.writeAsBytes([1, 1, 1, 1]);
        final attachment = await manager.importFile(
          source: original,
          recordId: 'record-a',
          attachmentType: AttachmentType.general,
          sourceKind: AttachmentSourceKind.filePicker,
          mimeType: 'image/jpeg',
          createdAt: DateTime(2026, 7, 28, 15, 0),
        );

        final originalFile = await fileStore.resolve(
          attachment.managedOriginalUri,
        );
        final originalPath = originalFile!.path;
        final attachmentDir = Directory(p.dirname(p.dirname(originalPath)));
        final optimizedDir = Directory(p.join(attachmentDir.path, 'optimized'));
        final thumbnailDir = Directory(p.join(attachmentDir.path, 'thumbnail'));
        await optimizedDir.create(recursive: true);
        await thumbnailDir.create(recursive: true);
        final optimizedFile = File(
          p.join(optimizedDir.path, 'usage-optimized.jpg'),
        );
        final thumbnailFile = File(
          p.join(thumbnailDir.path, 'usage-thumb.jpg'),
        );
        await optimizedFile.writeAsBytes([2, 2]);
        await thumbnailFile.writeAsBytes([3]);

        await repository.saveAttachment(
          attachment.copyWith(
            managedOptimizedUri: optimizedFile.uri.toString(),
            thumbnailUri: thumbnailFile.uri.toString(),
            optimizedByteSize: 2,
            thumbnailByteSize: 1,
          ),
        );

        final usage = await fileStore.measureUsage();

        expect(usage.originalBytes, 4);
        expect(usage.optimizedBytes, 2);
        expect(usage.thumbnailBytes, 1);
        expect(usage.totalBytes, 7);
        expect(originalPath, isNotEmpty);
      },
    );
  });
}
