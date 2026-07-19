import '../diary_transfer_exception.dart';

class V1TransferValidator {
  static const maxDiaryCount = 50000;
  static final _uuidV4 = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );
  static final _wallClock = RegExp(
    r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?$',
  );

  const V1TransferValidator();

  Map<String, Object?> object(Object? value, String path) {
    if (value is! Map) _invalid(path, 'must be an object');
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) _invalid(path, 'contains a non-string key');
      result[entry.key as String] = entry.value;
    }
    return result;
  }

  List<Object?> list(Object? value, String path) {
    if (value is! List) _invalid(path, 'must be an array');
    return value.cast<Object?>();
  }

  String string(Map<String, Object?> json, String key, String path) {
    final value = json[key];
    if (value is! String) _invalid('$path.$key', 'must be a string');
    return value;
  }

  int integer(Map<String, Object?> json, String key, String path) {
    final value = json[key];
    if (value is! int) _invalid('$path.$key', 'must be an integer');
    return value;
  }

  String uuid(Map<String, Object?> json, String key, String path) {
    final value = string(json, key, path);
    if (!_uuidV4.hasMatch(value)) _invalid('$path.$key', 'must be a UUID v4');
    return value.toLowerCase();
  }

  DateTime utcInstant(Map<String, Object?> json, String key, String path) {
    final value = string(json, key, path);
    if (!value.endsWith('Z')) {
      _invalid('$path.$key', 'must be a UTC ISO 8601 timestamp ending in Z');
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null || !parsed.isUtc) {
      _invalid('$path.$key', 'is not a valid UTC timestamp');
    }
    return parsed;
  }

  DateTime wallClock(Map<String, Object?> json, String key, String path) {
    final value = string(json, key, path);
    if (!_wallClock.hasMatch(value)) {
      _invalid('$path.$key', 'must be a local wall-clock ISO 8601 timestamp');
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null || parsed.isUtc) {
      _invalid('$path.$key', 'is not a valid wall-clock timestamp');
    }
    return parsed;
  }

  Never tooManyDiaries() =>
      _invalid(r'$.diaries', 'contains more than $maxDiaryCount diary records');

  Never _invalid(String path, String reason) {
    throw DiaryTransferException(
      'invalid_document',
      'Invalid diary backup at $path: $reason.',
    );
  }
}
