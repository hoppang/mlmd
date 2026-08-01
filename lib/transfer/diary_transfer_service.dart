import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../features/attachments/application/attachment_service.dart';
import '../features/attachments/domain/event_attachment.dart';
import '../repositories/diary_repository.dart';
import 'canonical_transfer_document.dart';
import 'diary_transfer_codec_registry.dart';
import 'diary_transfer_exception.dart';
import 'diary_transfer_header.dart';

class PreparedBackupAttachment {
  const PreparedBackupAttachment({
    required this.attachment,
    required this.bytes,
  });

  final EventAttachment attachment;
  final Uint8List bytes;
}

class PreparedDiaryImport {
  final CanonicalImportDocument document;
  final int schemaVersion;
  final String sourceName;
  final List<PreparedBackupAttachment> attachments;

  const PreparedDiaryImport({
    required this.document,
    required this.schemaVersion,
    required this.sourceName,
    this.attachments = const [],
  });
}

class PreparedDiaryExport {
  const PreparedDiaryExport({
    required this.bytes,
    required this.mode,
    required this.diaryCount,
    required this.attachmentCount,
    required this.missingAttachmentCount,
    required this.schemaVersion,
  });

  final Uint8List bytes;
  final AttachmentExportMode mode;
  final int diaryCount;
  final int attachmentCount;
  final int missingAttachmentCount;
  final int schemaVersion;

  int get estimatedBytes => bytes.length;
  bool get requiresMissingFileConfirmation => missingAttachmentCount > 0;
}

class DiaryExportOutcome {
  final bool cancelled;
  final String fileName;
  final int diaryCount;
  final int attachmentCount;
  final int schemaVersion;

  const DiaryExportOutcome({
    required this.cancelled,
    required this.fileName,
    required this.diaryCount,
    this.attachmentCount = 0,
    required this.schemaVersion,
  });
}

class DiaryTransferService {
  static const maxFileSizeInMegabytes = 100;
  static const maxFileBytes = maxFileSizeInMegabytes * 1024 * 1024;
  static const maxAttachmentCount = 200;
  static const maxAttachmentBytes = 25 * 1024 * 1024;
  static const maxTotalAttachmentBytes = 75 * 1024 * 1024;
  static const _fileTooLargeMessage =
      'Diary backup files may not exceed $maxFileSizeInMegabytes MB.';
  static const _bundleMarker = 'mlmd.backup.bundle';
  static const _bundleVersion = 1;
  static const appVersion = '1.0.0+1';

  final DiaryRepository repository;
  final DiaryTransferCodecRegistry registry;
  final AttachmentManager? attachmentManager;

  DiaryTransferService({
    required this.repository,
    DiaryTransferCodecRegistry? registry,
    this.attachmentManager,
  }) : registry = registry ?? DiaryTransferCodecRegistry.standard();

  Uint8List buildExportBytes({int? targetSchemaVersion}) {
    final json = _buildRecordsJson(targetSchemaVersion: targetSchemaVersion);
    return Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(json)),
    );
  }

  Future<PreparedDiaryExport> prepareExport({
    AttachmentExportMode mode = AttachmentExportMode.recordsOnly,
    int? targetSchemaVersion,
  }) async {
    final version = targetSchemaVersion ?? registry.latestSchemaVersion;
    final records = _buildRecordsJson(targetSchemaVersion: version);
    final manager = attachmentManager;
    if (mode == AttachmentExportMode.recordsOnly || manager == null) {
      final bytes = Uint8List.fromList(
        utf8.encode(const JsonEncoder.withIndent('  ').convert(records)),
      );
      return PreparedDiaryExport(
        bytes: bytes,
        mode: AttachmentExportMode.recordsOnly,
        diaryCount: repository.getDiaries().length,
        attachmentCount: 0,
        missingAttachmentCount: 0,
        schemaVersion: version,
      );
    }

    final plan = await manager.planExport(mode);
    final attachments = <Map<String, Object?>>[];
    for (final item in plan.items) {
      final bytes = await item.file.readAsBytes();
      final portable = item.attachment.copyWith(
        managedOriginalUri: '',
        managedOptimizedUri: null,
        thumbnailUri: null,
        originalByteSize: bytes.length,
        optimizedByteSize: null,
        thumbnailByteSize: null,
        originalSha256: item.sha256,
        missingReason: null,
      );
      attachments.add({
        'metadata': jsonDecode(portable.encode()),
        'sha256': item.sha256,
        'bytes': base64Encode(bytes),
      });
    }
    final envelope = <String, Object?>{
      'bundle': _bundleMarker,
      'bundleVersion': _bundleVersion,
      'attachmentMode': mode.name,
      'records': records,
      'attachments': attachments,
    };
    final bytes = Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(envelope)),
    );
    if (bytes.length > maxFileBytes) {
      throw const DiaryTransferException(
        'file_too_large',
        _fileTooLargeMessage,
      );
    }
    return PreparedDiaryExport(
      bytes: bytes,
      mode: mode,
      diaryCount: repository.getDiaries().length,
      attachmentCount: attachments.length,
      missingAttachmentCount: plan.issues.length,
      schemaVersion: version,
    );
  }

  PreparedDiaryImport decodeImportBytes(
    List<int> bytes, {
    String sourceName = 'backup.mlmd.json',
  }) {
    if (bytes.length > maxFileBytes) {
      throw const DiaryTransferException(
        'file_too_large',
        _fileTooLargeMessage,
      );
    }
    final decoded = _decodeJson(bytes);
    final isBundle = decoded['bundle'] == _bundleMarker;
    final records = isBundle
        ? _stringKeyedMap(decoded['records'], field: 'records')
        : decoded;
    final header = DiaryTransferHeader.decode(records);
    final document = registry.decode(records);
    final attachments = isBundle
        ? _decodeAttachments(decoded['attachments'])
        : const <PreparedBackupAttachment>[];
    return PreparedDiaryImport(
      document: document,
      schemaVersion: header.schemaVersion,
      sourceName: sourceName,
      attachments: attachments,
    );
  }

  Future<PreparedDiaryImport?> pickAndPrepareImport({
    String? dialogTitle,
  }) async {
    final selected = await FilePicker.pickFile(
      dialogTitle: dialogTitle ?? 'Import MLMD diary backup',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (selected == null) return null;
    if (selected.size > maxFileBytes) {
      throw const DiaryTransferException(
        'file_too_large',
        _fileTooLargeMessage,
      );
    }
    return decodeImportBytes(
      await selected.readAsBytes(),
      sourceName: selected.name,
    );
  }

  ImportPreview preview(
    PreparedDiaryImport prepared,
    ImportConflictPolicy policy,
  ) => repository.previewImport(prepared.document, policy);

  ImportResult apply(
    PreparedDiaryImport prepared,
    ImportConflictPolicy policy,
  ) => repository.importDocument(prepared.document, policy);

  Future<ImportResult> applyWithAutomaticBackup(
    PreparedDiaryImport prepared,
    ImportConflictPolicy policy, {
    Directory? backupDirectory,
    DateTime? createdAt,
  }) async {
    await createAutomaticBackup(
      backupDirectory: backupDirectory,
      createdAt: createdAt,
    );
    final result = apply(prepared, policy);
    final manager = attachmentManager;
    if (manager == null || prepared.attachments.isEmpty) return result;

    final importedRecordIds = result.affectedRecordIds.toSet();
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'mlmd-attachment-import-',
    );
    try {
      for (var index = 0; index < prepared.attachments.length; index++) {
        final preparedAttachment = prepared.attachments[index];
        if (!importedRecordIds.contains(
          preparedAttachment.attachment.recordId,
        )) {
          continue;
        }
        final source = File(
          p.join(temporaryDirectory.path, 'attachment-$index.bin'),
        );
        await source.writeAsBytes(preparedAttachment.bytes, flush: true);
        await manager.importBackupFile(
          source: source,
          attachment: preparedAttachment.attachment,
        );
      }
    } finally {
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
    }
    return result;
  }

  Future<File> createAutomaticBackup({
    Directory? backupDirectory,
    DateTime? createdAt,
  }) async {
    final directory =
        backupDirectory ??
        Directory(
          p.join(
            (await getApplicationSupportDirectory()).path,
            'automatic-backups',
          ),
        );
    await directory.create(recursive: true);
    final timestamp = createdAt ?? DateTime.now();
    final fileName = 'before-import-${_fileName(timestamp)}';
    final target = File(p.join(directory.path, fileName));
    final temporary = File('${target.path}.tmp');
    try {
      final prepared = await prepareExport(
        mode: attachmentManager == null
            ? AttachmentExportMode.recordsOnly
            : AttachmentExportMode.originalAttachments,
      );
      await temporary.writeAsBytes(prepared.bytes, flush: true);
      return await temporary.rename(target.path);
    } catch (_) {
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
  }

  Future<DiaryExportOutcome> exportToPlatform({
    PreparedDiaryExport? prepared,
    int? targetSchemaVersion,
    String? dialogTitle,
    String? shareSubject,
  }) async {
    final export =
        prepared ??
        await prepareExport(targetSchemaVersion: targetSchemaVersion);
    final fileName = _fileName(DateTime.now());

    if (Platform.isWindows) {
      final selectedPath = await FilePicker.saveFile(
        dialogTitle: dialogTitle ?? 'Export MLMD diary backup',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: export.bytes,
      );
      if (selectedPath == null) {
        return DiaryExportOutcome(
          cancelled: true,
          fileName: fileName,
          diaryCount: export.diaryCount,
          attachmentCount: export.attachmentCount,
          schemaVersion: export.schemaVersion,
        );
      }
    } else {
      final tempDirectory = await getTemporaryDirectory();
      final tempFile = File(p.join(tempDirectory.path, fileName));
      await tempFile.writeAsBytes(export.bytes, flush: true);
      try {
        final result = await SharePlus.instance.share(
          ShareParams(
            files: [XFile(tempFile.path, mimeType: 'application/json')],
            subject: shareSubject ?? 'MLMD diary backup',
          ),
        );
        if (result.status == ShareResultStatus.dismissed) {
          return DiaryExportOutcome(
            cancelled: true,
            fileName: fileName,
            diaryCount: export.diaryCount,
            attachmentCount: export.attachmentCount,
            schemaVersion: export.schemaVersion,
          );
        }
      } finally {
        if (await tempFile.exists()) await tempFile.delete();
      }
    }
    return DiaryExportOutcome(
      cancelled: false,
      fileName: fileName,
      diaryCount: export.diaryCount,
      attachmentCount: export.attachmentCount,
      schemaVersion: export.schemaVersion,
    );
  }

  Map<String, Object?> _buildRecordsJson({int? targetSchemaVersion}) {
    final document = repository.createExportDocument(appVersion: appVersion);
    return registry.encode(document, targetSchemaVersion: targetSchemaVersion);
  }

  Map<String, Object?> _decodeJson(List<int> bytes) {
    late final String source;
    try {
      source = const Utf8Decoder(allowMalformed: false).convert(bytes);
    } on FormatException catch (error) {
      throw DiaryTransferException(
        'invalid_utf8',
        'The diary backup is not valid UTF-8.',
        error,
      );
    }
    late final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw DiaryTransferException(
        'invalid_json',
        'The diary backup is not valid JSON.',
        error,
      );
    }
    return _stringKeyedMap(decoded, field: 'document');
  }

  Map<String, Object?> _stringKeyedMap(Object? value, {required String field}) {
    if (value is! Map) {
      throw DiaryTransferException(
        'invalid_document',
        '$field must be an object.',
      );
    }
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw DiaryTransferException(
          'invalid_document',
          '$field contains a non-string key.',
        );
      }
      result[entry.key as String] = entry.value;
    }
    return result;
  }

  List<PreparedBackupAttachment> _decodeAttachments(Object? value) {
    if (value is! List) {
      throw const DiaryTransferException(
        'invalid_attachments',
        'The backup attachment list is invalid.',
      );
    }
    if (value.length > maxAttachmentCount) {
      throw const DiaryTransferException(
        'too_many_attachments',
        'The backup contains too many attachments.',
      );
    }
    final result = <PreparedBackupAttachment>[];
    var totalDecodedBytes = 0;
    for (final raw in value) {
      final item = _stringKeyedMap(raw, field: 'attachment');
      final metadata = item['metadata'];
      final encodedBytes = item['bytes'];
      final expectedHash = item['sha256'];
      if (metadata is! Map ||
          encodedBytes is! String ||
          expectedHash is! String) {
        throw const DiaryTransferException(
          'invalid_attachment',
          'A backup attachment is incomplete.',
        );
      }
      if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(expectedHash)) {
        throw const DiaryTransferException(
          'invalid_attachment',
          'A backup attachment has an invalid SHA-256 digest.',
        );
      }
      if (metadata.length > 32) {
        throw const DiaryTransferException(
          'invalid_attachment',
          'A backup attachment has too many metadata fields.',
        );
      }
      for (final entry in metadata.entries) {
        if (entry.key is! String ||
            (entry.value is String && (entry.value as String).length > 4096)) {
          throw const DiaryTransferException(
            'invalid_attachment',
            'A backup attachment has oversized or invalid metadata.',
          );
        }
      }
      final maxEncodedLength = ((maxAttachmentBytes + 2) ~/ 3) * 4;
      if (encodedBytes.length > maxEncodedLength) {
        throw const DiaryTransferException(
          'attachment_too_large',
          'A backup attachment exceeds the allowed size.',
        );
      }
      Uint8List bytes;
      try {
        bytes = base64Decode(encodedBytes);
      } on FormatException catch (error) {
        throw DiaryTransferException(
          'invalid_attachment',
          'A backup attachment is not valid base64.',
          error,
        );
      }
      if (bytes.length > maxAttachmentBytes) {
        throw const DiaryTransferException(
          'attachment_too_large',
          'A backup attachment exceeds the allowed size.',
        );
      }
      totalDecodedBytes += bytes.length;
      if (totalDecodedBytes > maxTotalAttachmentBytes) {
        throw const DiaryTransferException(
          'attachments_too_large',
          'The backup attachments exceed the allowed total size.',
        );
      }
      final actualHash = crypto.sha256.convert(bytes).toString();
      if (actualHash != expectedHash.toLowerCase()) {
        throw const DiaryTransferException(
          'attachment_checksum_mismatch',
          'A backup attachment failed its integrity check.',
        );
      }
      final attachment = EventAttachment.decode(jsonEncode(metadata));
      if (attachment == null ||
          attachment.attachmentId.isEmpty ||
          attachment.recordId.isEmpty) {
        throw const DiaryTransferException(
          'invalid_attachment',
          'A backup attachment has invalid metadata.',
        );
      }
      result.add(
        PreparedBackupAttachment(attachment: attachment, bytes: bytes),
      );
    }
    return result;
  }

  String _fileName(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return 'mlmd-diary-${value.year}${two(value.month)}${two(value.day)}-'
        '${two(value.hour)}${two(value.minute)}${two(value.second)}.mlmd.json';
  }
}
