import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../repositories/diary_repository.dart';
import 'canonical_transfer_document.dart';
import 'diary_transfer_codec_registry.dart';
import 'diary_transfer_exception.dart';
import 'diary_transfer_header.dart';

class PreparedDiaryImport {
  final CanonicalImportDocument document;
  final int schemaVersion;
  final String sourceName;

  const PreparedDiaryImport({
    required this.document,
    required this.schemaVersion,
    required this.sourceName,
  });
}

class DiaryExportOutcome {
  final bool cancelled;
  final String fileName;
  final int diaryCount;
  final int schemaVersion;

  const DiaryExportOutcome({
    required this.cancelled,
    required this.fileName,
    required this.diaryCount,
    required this.schemaVersion,
  });
}

class DiaryTransferService {
  static const maxFileSizeInMegabytes = 100;
  static const maxFileBytes = maxFileSizeInMegabytes * 1024 * 1024;
  static const _fileTooLargeMessage =
      'Diary backup files may not exceed $maxFileSizeInMegabytes MB.';
  static const appVersion = '1.0.0+1';

  final DiaryRepository repository;
  final DiaryTransferCodecRegistry registry;

  DiaryTransferService({
    required this.repository,
    DiaryTransferCodecRegistry? registry,
  }) : registry = registry ?? DiaryTransferCodecRegistry.standard();

  Uint8List buildExportBytes({int? targetSchemaVersion}) {
    final document = repository.createExportDocument(appVersion: appVersion);
    final json = registry.encode(
      document,
      targetSchemaVersion: targetSchemaVersion,
    );
    return Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(json)),
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
    if (decoded is! Map) {
      throw const DiaryTransferException(
        'invalid_document',
        'The top-level JSON value must be an object.',
      );
    }
    final json = <String, Object?>{};
    for (final entry in decoded.entries) {
      if (entry.key is! String) {
        throw const DiaryTransferException(
          'invalid_document',
          'The top-level JSON object contains a non-string key.',
        );
      }
      json[entry.key as String] = entry.value;
    }
    final header = DiaryTransferHeader.decode(json);
    final document = registry.decode(json);
    return PreparedDiaryImport(
      document: document,
      schemaVersion: header.schemaVersion,
      sourceName: sourceName,
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

  /// 가져오기를 적용하기 직전에 현재 기록의 복구용 스냅샷을 앱 저장소에
  /// 원자적으로 기록합니다. 실제 반영도 저장소의 단일 트랜잭션에서 수행됩니다.
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
    return apply(prepared, policy);
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
      await temporary.writeAsBytes(buildExportBytes(), flush: true);
      return await temporary.rename(target.path);
    } catch (_) {
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
  }

  Future<DiaryExportOutcome> exportToPlatform({
    int? targetSchemaVersion,
    String? dialogTitle,
    String? shareSubject,
  }) async {
    final version = targetSchemaVersion ?? registry.latestSchemaVersion;
    final bytes = buildExportBytes(targetSchemaVersion: version);
    final fileName = _fileName(DateTime.now());
    final diaryCount = repository.getDiaries().length;

    if (Platform.isWindows) {
      final selectedPath = await FilePicker.saveFile(
        dialogTitle: dialogTitle ?? 'Export MLMD diary backup',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: bytes,
      );
      if (selectedPath == null) {
        return DiaryExportOutcome(
          cancelled: true,
          fileName: fileName,
          diaryCount: diaryCount,
          schemaVersion: version,
        );
      }
    } else {
      final tempDirectory = await getTemporaryDirectory();
      final tempFile = File(p.join(tempDirectory.path, fileName));
      await tempFile.writeAsBytes(bytes, flush: true);
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
            diaryCount: diaryCount,
            schemaVersion: version,
          );
        }
      } finally {
        if (await tempFile.exists()) await tempFile.delete();
      }
    }
    return DiaryExportOutcome(
      cancelled: false,
      fileName: fileName,
      diaryCount: diaryCount,
      schemaVersion: version,
    );
  }

  String _fileName(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return 'mlmd-diary-${value.year}${two(value.month)}${two(value.day)}-'
        '${two(value.hour)}${two(value.minute)}${two(value.second)}.mlmd.json';
  }
}
