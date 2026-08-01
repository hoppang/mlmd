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
    final appVersion = validator.boundedString(
      json,
      'appVersion',
      r'$',
      V1TransferValidator.maxAppVersionLength,
    );
    final rawDiaries = validator.list(json['diaries'], r'$.diaries');
    if (rawDiaries.length > V1TransferValidator.maxDiaryCount) {
      validator.tooManyDiaries();
    }

    final recordIds = <String>{};
    final diaries = <CanonicalDiary>[];
    var totalActivityCount = 0;
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
      if (rawActivities.length > V1TransferValidator.maxActivitiesPerDiary) {
        throw DiaryTransferException(
          'invalid_document',
          'Invalid diary backup at $path.activities: contains too many activities.',
        );
      }
      totalActivityCount += rawActivities.length;
      if (totalActivityCount > V1TransferValidator.maxTotalActivityCount) {
        throw const DiaryTransferException(
          'invalid_document',
          'The diary backup contains too many activities.',
        );
      }
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
        final rawTimePrecision = activity['timePrecision'];
        final timePrecision = rawTimePrecision == null
            ? 1
            : validator.integer(activity, 'timePrecision', activityPath);
        if (timePrecision != 0 && timePrecision != 1) {
          throw DiaryTransferException(
            'invalid_document',
            'Invalid diary backup at $activityPath.timePrecision: '
                'must be 0 or 1.',
          );
        }
        activities.add(
          CanonicalActivity(
            type: validator.boundedString(
              activity,
              'type',
              activityPath,
              V1TransferValidator.maxActivityTypeLength,
            ),
            time: validator.wallClock(activity, 'time', activityPath),
            timePrecision: timePrecision,
            details: validator.boundedString(
              activity,
              'details',
              activityPath,
              V1TransferValidator.maxActivityDetailsLength,
            ),
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
          title: validator.boundedString(
            item,
            'title',
            path,
            V1TransferValidator.maxTitleLength,
          ),
          summary: validator.boundedString(
            item,
            'summary',
            path,
            V1TransferValidator.maxSummaryLength,
          ),
          content: validator.boundedString(
            item,
            'content',
            path,
            V1TransferValidator.maxContentLength,
          ),
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
