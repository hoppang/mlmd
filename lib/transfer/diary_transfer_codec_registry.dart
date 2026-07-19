import 'canonical_transfer_document.dart';
import 'diary_transfer_exception.dart';
import 'diary_transfer_header.dart';
import 'v1/v1_diary_exporter.dart';
import 'v1/v1_diary_importer.dart';

abstract interface class DiaryImporter {
  int get schemaVersion;
  CanonicalImportDocument decode(Map<String, Object?> json);
}

abstract interface class DiaryExporter {
  int get schemaVersion;
  Map<String, Object?> encode(CanonicalExportDocument document);
}

class DiaryTransferCodecRegistry {
  final Map<int, DiaryImporter> importers;
  final Map<int, DiaryExporter> exporters;
  final int latestSchemaVersion;

  DiaryTransferCodecRegistry({
    required Iterable<DiaryImporter> importers,
    required Iterable<DiaryExporter> exporters,
    required this.latestSchemaVersion,
  }) : importers = {for (final codec in importers) codec.schemaVersion: codec},
       exporters = {for (final codec in exporters) codec.schemaVersion: codec} {
    if (!this.importers.containsKey(latestSchemaVersion) ||
        !this.exporters.containsKey(latestSchemaVersion)) {
      throw ArgumentError('The latest schema version must have both codecs.');
    }
  }

  factory DiaryTransferCodecRegistry.standard() => DiaryTransferCodecRegistry(
    importers: [const V1DiaryImporter()],
    exporters: [const V1DiaryExporter()],
    latestSchemaVersion: 1,
  );

  DiaryImporter importerFor(int version) {
    final importer = importers[version];
    if (importer == null) {
      throw DiaryTransferException(
        'unsupported_schema_version',
        'Diary backup schema version $version is not supported.',
      );
    }
    return importer;
  }

  DiaryExporter exporterFor(int version) {
    final exporter = exporters[version];
    if (exporter == null) {
      throw DiaryTransferException(
        'unsupported_export_version',
        'Diary export schema version $version is not supported.',
      );
    }
    return exporter;
  }

  CanonicalImportDocument decode(Map<String, Object?> json) {
    final header = DiaryTransferHeader.decode(json);
    return importerFor(header.schemaVersion).decode(json);
  }

  Map<String, Object?> encode(
    CanonicalExportDocument document, {
    int? targetSchemaVersion,
  }) {
    return exporterFor(
      targetSchemaVersion ?? latestSchemaVersion,
    ).encode(document);
  }
}
