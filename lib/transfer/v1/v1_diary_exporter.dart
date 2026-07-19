import '../canonical_transfer_document.dart';
import '../diary_transfer_codec_registry.dart';
import '../diary_transfer_header.dart';
import 'v1_transfer_dto.dart';

class V1DiaryExporter implements DiaryExporter {
  const V1DiaryExporter();

  @override
  int get schemaVersion => 1;

  @override
  Map<String, Object?> encode(CanonicalExportDocument document) {
    final diaries = [...document.diaries]
      ..sort((a, b) => a.date.compareTo(b.date));
    final dto = V1TransferDocument(
      format: DiaryTransferHeader.expectedFormat,
      schemaVersion: schemaVersion,
      exportedAt: _utc(document.exportedAt),
      appVersion: document.appVersion,
      diaries: diaries
          .map((diary) {
            final activities = [...diary.activities]
              ..sort((a, b) => a.time.compareTo(b.time));
            return V1DiaryItem(
              recordId: diary.recordId,
              date: _wallClock(diary.date),
              title: diary.title,
              summary: diary.summary,
              content: diary.content,
              lastModified: _utc(diary.lastModified),
              activities: activities
                  .map(
                    (activity) => V1ActivityItem(
                      type: activity.type,
                      time: _wallClock(activity.time),
                      details: activity.details,
                      lastModified: _utc(activity.lastModified),
                    ),
                  )
                  .toList(growable: false),
            );
          })
          .toList(growable: false),
    );
    return dto.toJson();
  }

  String _utc(DateTime value) => value.toUtc().toIso8601String();

  String _wallClock(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    String three(int number) => number.toString().padLeft(3, '0');
    return '${value.year.toString().padLeft(4, '0')}-'
        '${two(value.month)}-${two(value.day)}T${two(value.hour)}:'
        '${two(value.minute)}:${two(value.second)}.${three(value.millisecond)}';
  }
}
