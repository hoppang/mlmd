import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/duplicate_review/domain/duplicate_detector.dart';
import 'package:mlmd/features/events/domain/event_catalog.dart';
import 'package:mlmd/models/activity_entity.dart';
import 'package:mlmd/models/diary_entity.dart';

void main() {
  final occurredAt = DateTime.utc(2026, 7, 24, 9, 30);

  test('다국어 catalog alias의 다른 기기 exact duplicate를 검출한다', () {
    final korean = _activity(
      recordId: 'record-b',
      type: '투약',
      time: occurredAt,
      details: '  해열제   1회 ',
      deviceId: 'device-b',
      revision: 8,
    );
    final english = _activity(
      recordId: 'record-a',
      type: 'Medication',
      time: occurredAt,
      details: '해열제 1회',
      deviceId: 'device-a',
      revision: 2,
    );
    final firstDiary = _diary('diary-b', korean);
    final secondDiary = _diary('diary-a', english);

    final candidates = detectDuplicateCandidates([firstDiary, secondDiary]);

    expect(candidates, hasLength(1));
    final candidate = candidates.single;
    expect(candidate.pairKey, 'record-a|record-b');
    expect(candidate.firstActivity, same(english));
    expect(candidate.secondActivity, same(korean));
    expect(candidate.firstDiary, same(secondDiary));
    expect(candidate.secondDiary, same(firstDiary));
    expect(candidate.detectorVersion, duplicateDetectorVersion);
    expect(candidate.detectorVersion, 'exact-duplicate-v1');
    expect(candidate.reasons, {
      DuplicateReason.sameType,
      DuplicateReason.exactTime,
      DuplicateReason.exactDetails,
      DuplicateReason.differentDevices,
    });
    expect(candidate.firstCoreSignature.eventTypeId, EventTypeId.medication);
    expect(candidate.firstCoreSignature.occurredAt, occurredAt);
    expect(
      candidate.firstCoreSignature.timePrecision,
      ActivityEntity.timePrecisionExact,
    );
    expect(candidate.firstCoreSignature.normalizedDetails, '해열제 1회');
    expect(candidate.secondCoreSignature.normalizedDetails, '해열제 1회');
  });

  test('입력 순서와 revision은 pair key 및 판정에 영향을 주지 않는다', () {
    final a = _activity(
      recordId: 'record-z',
      type: '症状・体調',
      time: occurredAt,
      details: 'COUGH',
      deviceId: 'device-z',
      revision: 99,
    );
    final b = _activity(
      recordId: 'record-c',
      type: 'Symptom · condition',
      time: occurredAt,
      details: ' cough ',
      deviceId: 'device-c',
      revision: 1,
    );
    final diaryA = _diary('diary-z', a);
    final diaryB = _diary('diary-c', b);

    final forward = detectDuplicateCandidates([diaryA, diaryB]).single;
    final reverse = detectDuplicateCandidates([diaryB, diaryA]).single;

    expect(forward.pairKey, 'record-c|record-z');
    expect(reverse.pairKey, forward.pairKey);
    expect(reverse.firstActivity, same(b));
    expect(reverse.secondActivity, same(a));
  });

  test('same device는 제외한다', () {
    expect(
      _detectPair(
        _activity(
          recordId: 'a',
          type: 'Feeding',
          time: occurredAt,
          details: '120ml',
          deviceId: 'same-device',
        ),
        _activity(
          recordId: 'b',
          type: '수유',
          time: occurredAt,
          details: '120ml',
          deviceId: 'same-device',
        ),
      ),
      isEmpty,
    );
  });

  test('unknown time 또는 missing recordId는 제외한다', () {
    final exact = _activity(
      recordId: 'exact',
      type: 'Sleep',
      time: occurredAt,
      details: 'nap',
      deviceId: 'device-a',
    );
    final unknownTime = _activity(
      recordId: 'unknown',
      type: '수면',
      time: occurredAt,
      details: 'nap',
      deviceId: 'device-b',
      timePrecision: ActivityEntity.timePrecisionUnknown,
    );
    final missingRecordId = _activity(
      recordId: null,
      type: '수면',
      time: occurredAt,
      details: 'nap',
      deviceId: 'device-b',
    );

    expect(_detectPair(exact, unknownTime), isEmpty);
    expect(_detectPair(exact, missingRecordId), isEmpty);
  });

  test('반복 측정을 보존하기 위해 체온은 제외한다', () {
    expect(
      _detectPair(
        _activity(
          recordId: 'a',
          type: '체온',
          time: occurredAt,
          details: '38.2°C',
          deviceId: 'device-a',
        ),
        _activity(
          recordId: 'b',
          type: 'Temperature',
          time: occurredAt,
          details: '38.2°c',
          deviceId: 'device-b',
        ),
      ),
      isEmpty,
    );
  });

  test('near time은 제외한다', () {
    expect(
      _detectPair(
        _activity(
          recordId: 'a',
          type: 'Vaccination',
          time: occurredAt,
          details: 'A',
          deviceId: 'device-a',
        ),
        _activity(
          recordId: 'b',
          type: '예방접종',
          time: occurredAt.add(const Duration(seconds: 1)),
          details: 'A',
          deviceId: 'device-b',
        ),
      ),
      isEmpty,
    );
  });

  test('normalized details가 다르면 제외한다', () {
    expect(
      _detectPair(
        _activity(
          recordId: 'a',
          type: 'Bath',
          time: occurredAt,
          details: '10분',
          deviceId: 'device-a',
        ),
        _activity(
          recordId: 'b',
          type: '목욕',
          time: occurredAt,
          details: '11분',
          deviceId: 'device-b',
        ),
      ),
      isEmpty,
    );
  });
}

List<DuplicateCandidate> _detectPair(
  ActivityEntity first,
  ActivityEntity second,
) => detectDuplicateCandidates([
  _diary('diary-a', first),
  _diary('diary-b', second),
]);

DiaryEntity _diary(String recordId, ActivityEntity activity) {
  final diary = DiaryEntity(
    recordId: recordId,
    date: activity.time,
    title: 'test',
    content: '',
    lastModified: activity.lastModified,
  );
  diary.activities.add(activity);
  return diary;
}

ActivityEntity _activity({
  required String? recordId,
  required String type,
  required DateTime time,
  required String details,
  required String deviceId,
  int revision = 1,
  int timePrecision = ActivityEntity.timePrecisionExact,
}) => ActivityEntity(
  recordId: recordId,
  revision: revision,
  type: type,
  time: time,
  timePrecision: timePrecision,
  details: details,
  lastModified: time,
  createdByDeviceProfileId: deviceId,
);
