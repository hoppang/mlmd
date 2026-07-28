import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:objectbox/objectbox.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../data/objectbox_helper.dart';
import '../../../models/attachment_entity.dart';
import '../domain/event_attachment.dart';

abstract interface class AttachmentRepository {
  List<EventAttachment> getAttachmentsForRecord(
    String recordId, {
    bool includeDeleted = false,
  });
  List<EventAttachment> getAllAttachments({bool includeDeleted = false});
  Future<EventAttachment> saveAttachment(EventAttachment attachment);
  Future<void> deleteAttachment(String attachmentId, {DateTime? deletedAt});
  Future<void> restoreAttachment(String attachmentId);
  Future<void> removeAttachmentMetadata(String attachmentId);
  Future<void> saveAttachmentsForRecord(
    String recordId,
    List<EventAttachment> attachments,
  );
}

class InMemoryAttachmentRepository implements AttachmentRepository {
  final Map<String, EventAttachment> _attachments = {};
  static const _uuid = Uuid();

  @override
  List<EventAttachment> getAttachmentsForRecord(
    String recordId, {
    bool includeDeleted = false,
  }) {
    return _sorted(
      _attachments.values.where(
        (attachment) =>
            attachment.recordId == recordId &&
            (includeDeleted || !attachment.isDeleted),
      ),
    );
  }

  @override
  List<EventAttachment> getAllAttachments({bool includeDeleted = false}) {
    return _sorted(
      _attachments.values.where(
        (attachment) => includeDeleted || !attachment.isDeleted,
      ),
    );
  }

  List<EventAttachment> _sorted(Iterable<EventAttachment> attachments) {
    return attachments.toList()
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
  Future<void> deleteAttachment(
    String attachmentId, {
    DateTime? deletedAt,
  }) async {
    final existing = _attachments[attachmentId];
    if (existing != null) {
      _attachments[attachmentId] = existing.copyWith(
        deletedAt: deletedAt ?? DateTime.now(),
      );
    }
  }

  @override
  Future<void> restoreAttachment(String attachmentId) async {
    final existing = _attachments[attachmentId];
    if (existing != null) {
      _attachments[attachmentId] = existing.copyWith(deletedAt: null);
    }
  }

  @override
  Future<void> removeAttachmentMetadata(String attachmentId) async {
    _attachments.remove(attachmentId);
  }

  @override
  Future<void> saveAttachmentsForRecord(
    String recordId,
    List<EventAttachment> attachments,
  ) async {
    for (final attachment in attachments) {
      await saveAttachment(attachment.copyWith(recordId: recordId));
    }
  }
}

class ObjectBoxAttachmentRepository implements AttachmentRepository {
  ObjectBoxAttachmentRepository.fromStore(Store store)
    : _box = Box<AttachmentEntity>(store);

  final Box<AttachmentEntity> _box;
  static const _uuid = Uuid();

  @override
  List<EventAttachment> getAttachmentsForRecord(
    String recordId, {
    bool includeDeleted = false,
  }) {
    return _decode(
      _box.getAll().where(
        (entity) =>
            entity.recordId == recordId &&
            (includeDeleted || entity.deletedAt == null),
      ),
    );
  }

  @override
  List<EventAttachment> getAllAttachments({bool includeDeleted = false}) {
    return _decode(
      _box.getAll().where(
        (entity) => includeDeleted || entity.deletedAt == null,
      ),
    );
  }

  List<EventAttachment> _decode(Iterable<AttachmentEntity> entities) {
    final attachments =
        entities
            .map((entity) => entity.toDomain())
            .whereType<EventAttachment>()
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return attachments;
  }

  AttachmentEntity? _find(String attachmentId) {
    for (final entity in _box.getAll()) {
      if (entity.attachmentId == attachmentId) return entity;
    }
    return null;
  }

  @override
  Future<EventAttachment> saveAttachment(EventAttachment attachment) async {
    final attachmentId = attachment.attachmentId.isEmpty
        ? _uuid.v4()
        : attachment.attachmentId;
    final saved = attachment.copyWith(attachmentId: attachmentId);
    final entity = AttachmentEntity.fromDomain(saved);
    entity.id = _find(attachmentId)?.id ?? 0;
    _box.put(entity);
    return saved;
  }

  @override
  Future<void> deleteAttachment(
    String attachmentId, {
    DateTime? deletedAt,
  }) async {
    final existing = _find(attachmentId);
    final domain = existing?.toDomain();
    if (existing == null || domain == null) return;
    final updated = domain.copyWith(deletedAt: deletedAt ?? DateTime.now());
    final entity = AttachmentEntity.fromDomain(updated)..id = existing.id;
    _box.put(entity);
  }

  @override
  Future<void> restoreAttachment(String attachmentId) async {
    final existing = _find(attachmentId);
    final domain = existing?.toDomain();
    if (existing == null || domain == null) return;
    final entity = AttachmentEntity.fromDomain(domain.copyWith(deletedAt: null))
      ..id = existing.id;
    _box.put(entity);
  }

  @override
  Future<void> removeAttachmentMetadata(String attachmentId) async {
    final existing = _find(attachmentId);
    if (existing != null) _box.remove(existing.id);
  }

  @override
  Future<void> saveAttachmentsForRecord(
    String recordId,
    List<EventAttachment> attachments,
  ) async {
    for (final attachment in attachments) {
      await saveAttachment(attachment.copyWith(recordId: recordId));
    }
  }
}

class ManagedAttachmentFile {
  const ManagedAttachmentFile({
    required this.uri,
    required this.byteSize,
    required this.sha256,
  });

  final Uri uri;
  final int byteSize;
  final String sha256;
}

class AttachmentStorageUsage {
  const AttachmentStorageUsage({
    required this.originalBytes,
    required this.optimizedBytes,
    required this.thumbnailBytes,
  });

  final int originalBytes;
  final int optimizedBytes;
  final int thumbnailBytes;

  int get totalBytes => originalBytes + optimizedBytes + thumbnailBytes;
}

enum AttachmentDerivativeKind { optimized, thumbnail }

abstract interface class AttachmentFileStore {
  Future<ManagedAttachmentFile> copyOriginal({
    required File source,
    required String recordId,
    required String attachmentId,
    required String fileName,
  });
  Future<File?> resolve(String managedUri);
  Future<ManagedAttachmentFile> copyDerived({
    required File source,
    required EventAttachment attachment,
    required AttachmentDerivativeKind kind,
  });
  Future<void> deleteDerivedFiles(EventAttachment attachment);
  Future<void> purgeManagedFiles(EventAttachment attachment);
  Future<AttachmentStorageUsage> measureUsage();
}

class LocalAttachmentFileStore implements AttachmentFileStore {
  LocalAttachmentFileStore(this.rootDirectory);

  final Directory rootDirectory;
  static final HashAlgorithm _sha256 = Sha256();

  Directory get _attachmentsRoot =>
      Directory(p.join(rootDirectory.path, 'attachments'));

  @override
  Future<ManagedAttachmentFile> copyOriginal({
    required File source,
    required String recordId,
    required String attachmentId,
    required String fileName,
  }) async {
    if (!await source.exists()) {
      throw FileSystemException(
        'Attachment source does not exist.',
        source.path,
      );
    }
    final safeRecordId = _safeSegment(recordId, fallback: 'pending-record');
    final safeAttachmentId = _safeSegment(attachmentId);
    final safeName = _safeFileName(fileName);
    final destinationDirectory = Directory(
      p.join(_attachmentsRoot.path, safeRecordId, safeAttachmentId, 'original'),
    );
    await destinationDirectory.create(recursive: true);
    if (!await _isManagedEntity(destinationDirectory)) {
      throw FileSystemException(
        'Attachment destination escaped the managed storage root.',
        destinationDirectory.path,
      );
    }
    final destination = File(p.join(destinationDirectory.path, safeName));
    await source.copy(destination.path);
    final byteSize = await destination.length();
    final hashSink = _sha256.newHashSink();
    await for (final chunk in destination.openRead()) {
      hashSink.add(chunk);
    }
    hashSink.close();
    final hash = await hashSink.hash();
    return ManagedAttachmentFile(
      uri: destination.uri,
      byteSize: byteSize,
      sha256: hash.bytes
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join(),
    );
  }

  @override
  Future<File?> resolve(String managedUri) async {
    final uri = Uri.tryParse(managedUri);
    if (uri == null || uri.scheme != 'file') return null;
    final file = File.fromUri(uri);
    if (!await file.exists() || !await _isManagedEntity(file)) return null;
    return file;
  }

  @override
  Future<ManagedAttachmentFile> copyDerived({
    required File source,
    required EventAttachment attachment,
    required AttachmentDerivativeKind kind,
  }) async {
    if (!attachment.isImage) {
      throw ArgumentError('Only image attachments can have derived files.');
    }
    final original = await resolve(attachment.managedOriginalUri);
    if (original == null) {
      throw FileSystemException(
        'Managed attachment original does not exist.',
        attachment.managedOriginalUri,
      );
    }
    final directory = Directory(p.join(original.parent.parent.path, kind.name));
    await directory.create(recursive: true);
    if (!await _isManagedEntity(directory)) {
      throw FileSystemException(
        'Attachment derivative escaped the managed storage root.',
        directory.path,
      );
    }
    final extension = p.extension(source.path);
    final destination = File(
      p.join(
        directory.path,
        '${kind.name}${extension.isEmpty ? '.jpg' : extension}',
      ),
    );
    await source.copy(destination.path);
    final hashSink = _sha256.newHashSink();
    await for (final chunk in destination.openRead()) {
      hashSink.add(chunk);
    }
    hashSink.close();
    final hash = await hashSink.hash();
    return ManagedAttachmentFile(
      uri: destination.uri,
      byteSize: await destination.length(),
      sha256: hash.bytes
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join(),
    );
  }

  @override
  Future<void> deleteDerivedFiles(EventAttachment attachment) async {
    for (final uri in [
      attachment.managedOptimizedUri,
      attachment.thumbnailUri,
    ]) {
      if (uri == null) continue;
      final file = await resolve(uri);
      if (file != null) await file.delete();
    }
    await _deleteEmptyParents(attachment);
  }

  @override
  Future<void> purgeManagedFiles(EventAttachment attachment) async {
    final originalUri = Uri.tryParse(attachment.managedOriginalUri);
    if (originalUri == null || originalUri.scheme != 'file') return;
    final attachmentDirectory = File.fromUri(originalUri).parent.parent;
    if (!await attachmentDirectory.exists() ||
        !await _isManagedEntity(attachmentDirectory) ||
        p.equals(
          p.normalize(p.absolute(attachmentDirectory.path)),
          p.normalize(p.absolute(_attachmentsRoot.path)),
        )) {
      return;
    }
    await attachmentDirectory.delete(recursive: true);
  }

  Future<void> _deleteEmptyParents(EventAttachment attachment) async {
    final original = await resolve(attachment.managedOriginalUri);
    if (original == null) return;
    final attachmentDirectory = original.parent.parent;
    for (final child in attachmentDirectory.listSync()) {
      if (child is Directory && child.path != original.parent.path) {
        if (child.listSync().isEmpty) await child.delete();
      }
    }
  }

  @override
  Future<AttachmentStorageUsage> measureUsage() async {
    var original = 0;
    var optimized = 0;
    var thumbnail = 0;
    if (!await _attachmentsRoot.exists()) {
      return const AttachmentStorageUsage(
        originalBytes: 0,
        optimizedBytes: 0,
        thumbnailBytes: 0,
      );
    }
    await for (final entity in _attachmentsRoot.list(recursive: true)) {
      if (entity is! File) continue;
      final size = await entity.length();
      final parentName = p.basename(entity.parent.path);
      if (parentName == 'original') {
        original += size;
      } else if (parentName == 'optimized') {
        optimized += size;
      } else {
        thumbnail += size;
      }
    }
    return AttachmentStorageUsage(
      originalBytes: original,
      optimizedBytes: optimized,
      thumbnailBytes: thumbnail,
    );
  }

  bool _isManagedPath(String candidate) {
    final root = p.normalize(p.absolute(_attachmentsRoot.path));
    final normalized = p.normalize(p.absolute(candidate));
    return p.isWithin(root, normalized);
  }

  Future<bool> _isManagedEntity(FileSystemEntity entity) async {
    if (!_isManagedPath(entity.path) ||
        !await _attachmentsRoot.exists() ||
        !await entity.exists()) {
      return false;
    }
    try {
      final canonicalRoot = p.normalize(
        await _attachmentsRoot.resolveSymbolicLinks(),
      );
      final canonicalCandidate = p.normalize(
        await entity.resolveSymbolicLinks(),
      );
      return p.isWithin(canonicalRoot, canonicalCandidate);
    } on FileSystemException {
      return false;
    }
  }

  String _safeSegment(String value, {String? fallback}) {
    final trimmed = value.trim();
    final safe = trimmed.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (safe.isEmpty || safe == '.' || safe == '..') {
      if (fallback != null) return fallback;
      throw ArgumentError.value(
        value,
        'value',
        'Unsafe attachment path segment',
      );
    }
    return safe;
  }

  String _safeFileName(String value) {
    final name = p
        .basename(value.trim())
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    return name.isEmpty ? 'attachment.bin' : name;
  }
}

class AttachmentExportItem {
  const AttachmentExportItem({
    required this.attachment,
    required this.file,
    required this.sha256,
    required this.byteSize,
    required this.usedOriginalFallback,
  });

  final EventAttachment attachment;
  final File file;
  final String sha256;
  final int byteSize;
  final bool usedOriginalFallback;
}

class AttachmentExportIssue {
  const AttachmentExportIssue({
    required this.attachmentId,
    required this.fileName,
    required this.reason,
  });

  final String attachmentId;
  final String fileName;
  final String reason;
}

class AttachmentExportPlan {
  const AttachmentExportPlan({
    required this.mode,
    required this.items,
    required this.issues,
  });

  final AttachmentExportMode mode;
  final List<AttachmentExportItem> items;
  final List<AttachmentExportIssue> issues;

  int get estimatedBytes =>
      items.fold(0, (total, item) => total + item.byteSize);
  bool get requiresMissingFileConfirmation => issues.isNotEmpty;
}

class AttachmentManager {
  AttachmentManager({
    required this.repository,
    required this.fileStore,
    this._uuid = const Uuid(),
  });

  final AttachmentRepository repository;
  final AttachmentFileStore fileStore;
  final Uuid _uuid;

  Future<EventAttachment> importFile({
    required File source,
    required String recordId,
    required AttachmentType attachmentType,
    required AttachmentSourceKind sourceKind,
    required String mimeType,
    String? fileName,
    String? createdByAuthorProfileId,
    String? createdByDeviceProfileId,
    DateTime? createdAt,
  }) async {
    final attachmentId = _uuid.v4();
    final managed = await fileStore.copyOriginal(
      source: source,
      recordId: recordId,
      attachmentId: attachmentId,
      fileName: fileName ?? p.basename(source.path),
    );
    final attachment = EventAttachment(
      attachmentId: attachmentId,
      recordId: recordId,
      attachmentType: attachmentType,
      fileName: fileName ?? p.basename(source.path),
      mimeType: mimeType,
      sourceKind: sourceKind,
      managedOriginalUri: managed.uri.toString(),
      createdByAuthorProfileId: createdByAuthorProfileId,
      createdByDeviceProfileId: createdByDeviceProfileId,
      createdAt: createdAt ?? DateTime.now(),
      originalByteSize: managed.byteSize,
      originalSha256: managed.sha256,
    );
    return repository.saveAttachment(attachment);
  }

  Future<EventAttachment> importBackupFile({
    required File source,
    required EventAttachment attachment,
  }) async {
    final existing = repository
        .getAllAttachments(includeDeleted: true)
        .where((candidate) => candidate.attachmentId == attachment.attachmentId)
        .firstOrNull;
    if (existing != null &&
        existing.originalSha256 != null &&
        existing.originalSha256 == attachment.originalSha256) {
      return existing;
    }

    final attachmentId = existing == null
        ? attachment.attachmentId
        : _uuid.v4();
    final managed = await fileStore.copyOriginal(
      source: source,
      recordId: attachment.recordId,
      attachmentId: attachmentId,
      fileName: attachment.fileName,
    );
    final restored = attachment.copyWith(
      attachmentId: attachmentId,
      managedOriginalUri: managed.uri.toString(),
      managedOptimizedUri: null,
      thumbnailUri: null,
      deletedAt: null,
      originalByteSize: managed.byteSize,
      optimizedByteSize: null,
      thumbnailByteSize: null,
      originalSha256: managed.sha256,
      missingReason: null,
    );
    return repository.saveAttachment(restored);
  }

  Future<void> delete(String attachmentId, {DateTime? deletedAt}) {
    return repository.deleteAttachment(attachmentId, deletedAt: deletedAt);
  }

  Future<void> restore(String attachmentId) {
    return repository.restoreAttachment(attachmentId);
  }

  Future<int> purgeDeletedBefore(DateTime cutoff) async {
    final expired = repository
        .getAllAttachments(includeDeleted: true)
        .where(
          (attachment) =>
              attachment.deletedAt != null &&
              !attachment.deletedAt!.isAfter(cutoff),
        )
        .toList();
    for (final attachment in expired) {
      await fileStore.purgeManagedFiles(attachment);
      await repository.removeAttachmentMetadata(attachment.attachmentId);
    }
    return expired.length;
  }

  Future<void> clearDerivedCache() async {
    for (final attachment in repository.getAllAttachments(
      includeDeleted: true,
    )) {
      await fileStore.deleteDerivedFiles(attachment);
      if (attachment.managedOptimizedUri != null ||
          attachment.thumbnailUri != null) {
        await repository.saveAttachment(
          attachment.copyWith(
            managedOptimizedUri: null,
            thumbnailUri: null,
            optimizedByteSize: null,
            thumbnailByteSize: null,
          ),
        );
      }
    }
  }

  Future<EventAttachment> saveDerivedFile({
    required EventAttachment attachment,
    required File source,
    required AttachmentDerivativeKind kind,
  }) async {
    final managed = await fileStore.copyDerived(
      source: source,
      attachment: attachment,
      kind: kind,
    );
    final updated = kind == AttachmentDerivativeKind.optimized
        ? attachment.copyWith(
            managedOptimizedUri: managed.uri.toString(),
            optimizedByteSize: managed.byteSize,
          )
        : attachment.copyWith(
            thumbnailUri: managed.uri.toString(),
            thumbnailByteSize: managed.byteSize,
          );
    return repository.saveAttachment(updated);
  }

  Future<File?> fileForSharing(
    EventAttachment attachment,
    AttachmentShareQuality quality,
  ) async {
    final useOriginal =
        quality == AttachmentShareQuality.original ||
        !attachment.isImage ||
        attachment.keepsOriginalQuality ||
        attachment.managedOptimizedUri == null;
    final selected = await fileStore.resolve(
      useOriginal
          ? attachment.managedOriginalUri
          : attachment.managedOptimizedUri!,
    );
    if (selected != null || useOriginal) return selected;
    return fileStore.resolve(attachment.managedOriginalUri);
  }

  Future<AttachmentExportPlan> planExport(AttachmentExportMode mode) async {
    if (mode == AttachmentExportMode.recordsOnly) {
      return const AttachmentExportPlan(
        mode: AttachmentExportMode.recordsOnly,
        items: [],
        issues: [],
      );
    }
    final items = <AttachmentExportItem>[];
    final issues = <AttachmentExportIssue>[];
    for (final attachment in repository.getAllAttachments()) {
      final wantsReduced =
          mode == AttachmentExportMode.reducedAttachments &&
          attachment.isImage &&
          !attachment.keepsOriginalQuality;
      final reducedUri = attachment.managedOptimizedUri;
      var selectedUri = wantsReduced && reducedUri != null
          ? reducedUri
          : attachment.managedOriginalUri;
      var file = await fileStore.resolve(selectedUri);
      var usedOriginalFallback = wantsReduced && reducedUri == null;
      if (file == null && wantsReduced && reducedUri != null) {
        selectedUri = attachment.managedOriginalUri;
        file = await fileStore.resolve(selectedUri);
        usedOriginalFallback = true;
      }
      if (file == null) {
        issues.add(
          AttachmentExportIssue(
            attachmentId: attachment.attachmentId,
            fileName: attachment.fileName,
            reason: attachment.missingReason ?? 'managed_file_missing',
          ),
        );
        continue;
      }
      final actualSha256 = await _sha256For(file);
      if (selectedUri == attachment.managedOriginalUri &&
          attachment.originalSha256 != null &&
          attachment.originalSha256 != actualSha256) {
        issues.add(
          AttachmentExportIssue(
            attachmentId: attachment.attachmentId,
            fileName: attachment.fileName,
            reason: 'managed_file_checksum_mismatch',
          ),
        );
      }
      items.add(
        AttachmentExportItem(
          attachment: attachment,
          file: file,
          sha256: actualSha256,
          byteSize: await file.length(),
          usedOriginalFallback: usedOriginalFallback,
        ),
      );
    }
    return AttachmentExportPlan(mode: mode, items: items, issues: issues);
  }

  Future<String> _sha256For(File file) async {
    final sink = Sha256().newHashSink();
    await for (final chunk in file.openRead()) {
      sink.add(chunk);
    }
    sink.close();
    final hash = await sink.hash();
    return hash.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}

final attachmentRepositoryProvider = Provider<AttachmentRepository>((ref) {
  return ObjectBoxAttachmentRepository.fromStore(
    ref.watch(objectBoxProvider).store,
  );
}, dependencies: [objectBoxProvider]);

final attachmentFileStoreProvider = FutureProvider<AttachmentFileStore>((
  ref,
) async {
  final documents = await getApplicationDocumentsDirectory();
  return LocalAttachmentFileStore(
    Directory(p.join(documents.path, 'mlmd-managed')),
  );
});

class AttachmentNotifier extends Notifier<List<EventAttachment>> {
  @override
  List<EventAttachment> build() => const [];

  void loadAttachmentsForRecord(String recordId) {
    state = ref
        .read(attachmentRepositoryProvider)
        .getAttachmentsForRecord(recordId);
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
