import '../canonical_transfer_document.dart';
import '../diary_transfer_codec_registry.dart';
import '../diary_transfer_header.dart';
import '../diary_transfer_exception.dart';
import 'v1_transfer_validator.dart';

class V1DiaryImporter implements DiaryImporter {
  final V1TransferValidator validator;

  const V1DiaryImporter({this.validator = const V1TransferValidator()});

  @override
  int get schemaVersion => 1;

  @override
  CanonicalImportDocument decode(Map<String, Object?> json) {
    final header = DiaryTransferHeader.decode(json);
    if (header.schemaVersion != schemaVersion) {
      throw const DiaryTransferException(
        'invalid_schema_version',
        'V1 importer can only decode schema version 1.',
      );
    }
    final exportedAt = validator.utcInstant(json, 'exportedAt', r'$');
    final appVersion = validator.string(json, 'appVersion', r'$');
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
        throw DiaryTransferException(
          'duplicate_record_id',
          'The backup contains duplicate recordId $recordId.',
        );
      }
      final rawActivities = validator.list(
        item['activities'],
        '$path.activities',
      );
      final activities = <CanonicalActivity>[];
      for (
        var activityIndex = 0;
        activityIndex < rawActivities.length;
        activityIndex++
      ) {
        final activityPath = '$path.activities[$activityIndex]';
        final activity = validator.object(
          rawActivities[activityIndex],
          activityPath,
        );
        activities.add(
          CanonicalActivity(
            type: validator.string(activity, 'type', activityPath),
            time: validator.wallClock(activity, 'time', activityPath),
            details: validator.string(activity, 'details', activityPath),
            lastModified: validator.utcInstant(
              activity,
              'lastModified',
              activityPath,
            ),
          ),
        );
      }
      activities.sort((a, b) => a.time.compareTo(b.time));
      diaries.add(
        CanonicalDiary(
          recordId: recordId,
          date: validator.wallClock(item, 'date', path),
          title: validator.string(item, 'title', path),
          summary: validator.string(item, 'summary', path),
          content: validator.string(item, 'content', path),
          lastModified: validator.utcInstant(item, 'lastModified', path),
          activities: List.unmodifiable(activities),
        ),
      );
    }
    diaries.sort((a, b) => a.date.compareTo(b.date));
    return CanonicalImportDocument(
      exportedAt: exportedAt,
      appVersion: appVersion,
      diaries: List.unmodifiable(diaries),
    );
  }
}
