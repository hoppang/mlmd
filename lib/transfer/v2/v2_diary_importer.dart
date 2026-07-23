import '../canonical_transfer_document.dart';
import '../diary_transfer_codec_registry.dart';
import '../diary_transfer_exception.dart';
import '../diary_transfer_header.dart';
import '../v1/v1_transfer_validator.dart';

class V2DiaryImporter implements DiaryImporter {
  const V2DiaryImporter({this.validator = const V1TransferValidator()});

  final V1TransferValidator validator;

  @override
  int get schemaVersion => 2;

  @override
  CanonicalImportDocument decode(Map<String, Object?> json) {
    final header = DiaryTransferHeader.decode(json);
    if (header.schemaVersion != schemaVersion) {
      throw const DiaryTransferException(
        'invalid_schema_version',
        'V2 importer can only decode schema version 2.',
      );
    }
    final authors = _authors(json);
    final devices = _devices(json);
    final authorIds = authors.map((item) => item.authorProfileId).toSet();
    final deviceIds = devices.map((item) => item.deviceProfileId).toSet();
    final rawDiaries = validator.list(json['diaries'], r'$.diaries');
    if (rawDiaries.length > V1TransferValidator.maxDiaryCount) {
      validator.tooManyDiaries();
    }
    final recordIds = <String>{};
    final diaries = <CanonicalDiary>[];
    for (var index = 0; index < rawDiaries.length; index++) {
      final path =
          r'$.diaries['
          '${index.toString()}]';
      final item = validator.object(rawDiaries[index], path);
      final recordId = validator.uuid(item, 'recordId', path);
      if (!recordIds.add(recordId)) {
        _invalid(path, 'contains duplicate recordId $recordId');
      }
      final activities = _activities(
        item,
        path,
        authorIds: authorIds,
        deviceIds: deviceIds,
      );
      final createdByAuthor = validator.uuid(
        item,
        'createdByAuthorProfileId',
        path,
      );
      final createdByDevice = validator.uuid(
        item,
        'createdByDeviceProfileId',
        path,
      );
      final modifiedByAuthor = validator.uuid(
        item,
        'lastModifiedByAuthorProfileId',
        path,
      );
      final modifiedByDevice = validator.uuid(
        item,
        'lastModifiedByDeviceProfileId',
        path,
      );
      _validateReferences(
        path,
        authorIds: authorIds,
        deviceIds: deviceIds,
        createdByAuthor: createdByAuthor,
        createdByDevice: createdByDevice,
        modifiedByAuthor: modifiedByAuthor,
        modifiedByDevice: modifiedByDevice,
      );
      diaries.add(
        CanonicalDiary(
          recordId: recordId,
          date: validator.wallClock(item, 'date', path),
          title: validator.string(item, 'title', path),
          summary: validator.string(item, 'summary', path),
          content: validator.string(item, 'content', path),
          createdAt: validator.utcInstant(item, 'createdAt', path),
          createdByAuthorProfileId: createdByAuthor,
          createdByDeviceProfileId: createdByDevice,
          lastModifiedByAuthorProfileId: modifiedByAuthor,
          lastModifiedByDeviceProfileId: modifiedByDevice,
          lastModified: validator.utcInstant(item, 'lastModified', path),
          activities: List.unmodifiable(activities),
        ),
      );
    }
    diaries.sort((a, b) => a.date.compareTo(b.date));
    return CanonicalImportDocument(
      exportedAt: validator.utcInstant(json, 'exportedAt', r'$'),
      appVersion: validator.string(json, 'appVersion', r'$'),
      authorProfiles: List.unmodifiable(authors),
      deviceProfiles: List.unmodifiable(devices),
      diaries: List.unmodifiable(diaries),
    );
  }

  List<CanonicalAuthorProfile> _authors(Map<String, Object?> json) {
    final raw = validator.list(json['authorProfiles'], r'$.authorProfiles');
    final ids = <String>{};
    final result = <CanonicalAuthorProfile>[];
    for (var index = 0; index < raw.length; index++) {
      final path =
          r'$.authorProfiles['
          '${index.toString()}]';
      final item = validator.object(raw[index], path);
      final id = validator.uuid(item, 'authorProfileId', path);
      if (!ids.add(id)) _invalid(path, 'contains a duplicate profile ID');
      final nickname = validator.string(item, 'nickname', path).trim();
      if (nickname.isEmpty || nickname.length > 30) {
        _invalid('$path.nickname', 'must contain 1 to 30 characters');
      }
      final colorValue = validator.integer(item, 'colorValue', path);
      if (colorValue < 0 || colorValue > 0xFFFFFFFF) {
        _invalid('$path.colorValue', 'must be a 32-bit ARGB value');
      }
      result.add(
        CanonicalAuthorProfile(
          authorProfileId: id,
          nickname: nickname,
          colorValue: colorValue,
          createdAt: validator.utcInstant(item, 'createdAt', path),
        ),
      );
    }
    return result;
  }

  List<CanonicalDeviceProfile> _devices(Map<String, Object?> json) {
    final raw = validator.list(json['deviceProfiles'], r'$.deviceProfiles');
    final ids = <String>{};
    final result = <CanonicalDeviceProfile>[];
    for (var index = 0; index < raw.length; index++) {
      final path =
          r'$.deviceProfiles['
          '${index.toString()}]';
      final item = validator.object(raw[index], path);
      final id = validator.uuid(item, 'deviceProfileId', path);
      if (!ids.add(id)) _invalid(path, 'contains a duplicate profile ID');
      result.add(
        CanonicalDeviceProfile(
          deviceProfileId: id,
          createdAt: validator.utcInstant(item, 'createdAt', path),
        ),
      );
    }
    return result;
  }

  List<CanonicalActivity> _activities(
    Map<String, Object?> diary,
    String path, {
    required Set<String> authorIds,
    required Set<String> deviceIds,
  }) {
    final raw = validator.list(diary['activities'], '$path.activities');
    final result = <CanonicalActivity>[];
    for (var index = 0; index < raw.length; index++) {
      final activityPath = '$path.activities[$index]';
      final item = validator.object(raw[index], activityPath);
      final timePrecision = validator.integer(
        item,
        'timePrecision',
        activityPath,
      );
      if (timePrecision != 0 && timePrecision != 1) {
        _invalid('$activityPath.timePrecision', 'must be 0 or 1');
      }
      final createdByAuthor = validator.uuid(
        item,
        'createdByAuthorProfileId',
        activityPath,
      );
      final createdByDevice = validator.uuid(
        item,
        'createdByDeviceProfileId',
        activityPath,
      );
      final modifiedByAuthor = validator.uuid(
        item,
        'lastModifiedByAuthorProfileId',
        activityPath,
      );
      final modifiedByDevice = validator.uuid(
        item,
        'lastModifiedByDeviceProfileId',
        activityPath,
      );
      _validateReferences(
        activityPath,
        authorIds: authorIds,
        deviceIds: deviceIds,
        createdByAuthor: createdByAuthor,
        createdByDevice: createdByDevice,
        modifiedByAuthor: modifiedByAuthor,
        modifiedByDevice: modifiedByDevice,
      );
      result.add(
        CanonicalActivity(
          type: validator.string(item, 'type', activityPath),
          time: validator.wallClock(item, 'time', activityPath),
          timePrecision: timePrecision,
          details: validator.string(item, 'details', activityPath),
          createdAt: validator.utcInstant(item, 'createdAt', activityPath),
          createdByAuthorProfileId: createdByAuthor,
          createdByDeviceProfileId: createdByDevice,
          lastModifiedByAuthorProfileId: modifiedByAuthor,
          lastModifiedByDeviceProfileId: modifiedByDevice,
          lastModified: validator.utcInstant(
            item,
            'lastModified',
            activityPath,
          ),
        ),
      );
    }
    result.sort((a, b) => a.time.compareTo(b.time));
    return result;
  }

  void _validateReferences(
    String path, {
    required Set<String> authorIds,
    required Set<String> deviceIds,
    required String createdByAuthor,
    required String createdByDevice,
    required String modifiedByAuthor,
    required String modifiedByDevice,
  }) {
    if (!authorIds.contains(createdByAuthor) ||
        !authorIds.contains(modifiedByAuthor)) {
      _invalid(path, 'references an unknown author profile');
    }
    if (!deviceIds.contains(createdByDevice) ||
        !deviceIds.contains(modifiedByDevice)) {
      _invalid(path, 'references an unknown device profile');
    }
  }

  Never _invalid(String path, String reason) {
    throw DiaryTransferException(
      'invalid_document',
      'Invalid diary backup at $path: $reason.',
    );
  }
}
