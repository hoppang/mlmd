import '../canonical_transfer_document.dart';
import '../diary_transfer_codec_registry.dart';
import '../diary_transfer_header.dart';

class V2DiaryExporter implements DiaryExporter {
  const V2DiaryExporter();

  @override
  int get schemaVersion => 2;

  @override
  Map<String, Object?> encode(CanonicalExportDocument document) {
    final authors = [...document.authorProfiles]
      ..sort((a, b) => a.authorProfileId.compareTo(b.authorProfileId));
    final devices = [...document.deviceProfiles]
      ..sort((a, b) => a.deviceProfileId.compareTo(b.deviceProfileId));
    final diaries = [...document.diaries]
      ..sort((a, b) => a.date.compareTo(b.date));
    return {
      'format': DiaryTransferHeader.expectedFormat,
      'schemaVersion': schemaVersion,
      'exportedAt': _utc(document.exportedAt),
      'appVersion': document.appVersion,
      'authorProfiles': authors
          .map(
            (profile) => {
              'authorProfileId': profile.authorProfileId,
              'nickname': profile.nickname,
              'colorValue': profile.colorValue,
              'createdAt': _utc(profile.createdAt),
            },
          )
          .toList(growable: false),
      'deviceProfiles': devices
          .map(
            (profile) => {
              'deviceProfileId': profile.deviceProfileId,
              'createdAt': _utc(profile.createdAt),
            },
          )
          .toList(growable: false),
      'diaries': diaries.map(_diary).toList(growable: false),
    };
  }

  Map<String, Object?> _diary(CanonicalDiary diary) {
    final activities = [...diary.activities]
      ..sort((a, b) => a.time.compareTo(b.time));
    return {
      'recordId': diary.recordId,
      'date': _wallClock(diary.date),
      'title': diary.title,
      'summary': diary.summary,
      'content': diary.content,
      'createdAt': _utc(diary.createdAt!),
      'createdByAuthorProfileId': diary.createdByAuthorProfileId,
      'createdByDeviceProfileId': diary.createdByDeviceProfileId,
      'lastModifiedByAuthorProfileId': diary.lastModifiedByAuthorProfileId,
      'lastModifiedByDeviceProfileId': diary.lastModifiedByDeviceProfileId,
      'lastModified': _utc(diary.lastModified),
      'activities': activities.map(_activity).toList(growable: false),
    };
  }

  Map<String, Object?> _activity(CanonicalActivity activity) => {
    'type': activity.type,
    'time': _wallClock(activity.time),
    'timePrecision': activity.timePrecision,
    'details': activity.details,
    if (activity.structuredDataJson != null)
      'structuredDataJson': activity.structuredDataJson,
    'createdAt': _utc(activity.createdAt!),
    'createdByAuthorProfileId': activity.createdByAuthorProfileId,
    'createdByDeviceProfileId': activity.createdByDeviceProfileId,
    'lastModifiedByAuthorProfileId': activity.lastModifiedByAuthorProfileId,
    'lastModifiedByDeviceProfileId': activity.lastModifiedByDeviceProfileId,
    'lastModified': _utc(activity.lastModified),
  };

  String _utc(DateTime value) => value.toUtc().toIso8601String();

  String _wallClock(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    String three(int number) => number.toString().padLeft(3, '0');
    return '${value.year.toString().padLeft(4, '0')}-'
        '${two(value.month)}-${two(value.day)}T${two(value.hour)}:'
        '${two(value.minute)}:${two(value.second)}.${three(value.millisecond)}';
  }
}
