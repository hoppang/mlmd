import 'diary_transfer_exception.dart';

class DiaryTransferHeader {
  static const expectedFormat = 'mlmd-diary-export';

  final String format;
  final int schemaVersion;

  const DiaryTransferHeader({
    required this.format,
    required this.schemaVersion,
  });

  factory DiaryTransferHeader.decode(Map<String, Object?> json) {
    final format = json['format'];
    final version = json['schemaVersion'];
    if (format != expectedFormat) {
      throw const DiaryTransferException(
        'invalid_format',
        'MLMD diary export file format does not match.',
      );
    }
    if (version is! int || version < 1) {
      throw const DiaryTransferException(
        'invalid_schema_version',
        'schemaVersion must be a positive integer.',
      );
    }
    return DiaryTransferHeader(
      format: format as String,
      schemaVersion: version,
    );
  }
}
