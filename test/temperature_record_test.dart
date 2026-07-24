import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/events/domain/medical_guidance.dart';
import 'package:mlmd/features/events/domain/temperature_record.dart';
import 'package:mlmd/l10n/app_localizations_ko.dart';
import 'package:mlmd/models/activity_entity.dart';

void main() {
  final occurredAt = DateTime(2026, 7, 24, 14, 40);

  test('체온 구조화 payload를 측정 부위와 함께 왕복한다', () {
    final record = TemperatureRecord(
      celsius: 38.2,
      occurredAt: occurredAt,
      measurementSite: TemperatureMeasurementSite.forehead,
      note: '잠에서 깬 뒤',
    );

    final decoded = TemperatureRecord.decode(record.encode());

    expect(decoded?.celsius, 38.2);
    expect(decoded?.occurredAt, occurredAt);
    expect(decoded?.measurementSite, TemperatureMeasurementSite.forehead);
    expect(decoded?.note, '잠에서 깬 뒤');
    expect(
      temperatureRecordDetails(AppLocalizationsKo(), record),
      '38.2°C · 이마 · 잠에서 깬 뒤',
    );
  });

  test('알 수 없는 버전과 잘못된 측정 부위를 거부한다', () {
    expect(
      TemperatureRecord.decode(
        '{"schema":"mlmd.temperature","version":2,"celsius":38.0,'
        '"occurredAt":"2026-07-24T14:40:00"}',
      ),
      isNull,
    );
    expect(
      TemperatureRecord.decode(
        '{"schema":"mlmd.temperature","version":1,"celsius":38.0,'
        '"occurredAt":"2026-07-24T14:40:00","measurementSite":"mouth"}',
      ),
      isNull,
    );
  });

  test('38도 이상 체온만 주의와 검토된 링크에 연결한다', () {
    ActivityEntity activity(double celsius) => ActivityEntity(
      type: '체온',
      time: occurredAt,
      details: '${celsius.toStringAsFixed(1)}°C',
      structuredDataJson: TemperatureRecord(
        celsius: celsius,
        occurredAt: occurredAt,
      ).encode(),
      lastModified: occurredAt,
    );

    expect(evaluateMedicalGuidance(activity(37.9)).requiresAttention, isFalse);
    final evaluation = evaluateMedicalGuidance(activity(38));
    expect(evaluation.requiresAttention, isTrue);
    expect(evaluation.links, hasLength(1));
    expect(evaluation.links.single.ruleId, 'aap-temperature-38');
    expect(
      isApprovedGuidanceUri(Uri.parse(evaluation.links.single.sourceUrl)),
      isTrue,
    );
    expect(
      isApprovedGuidanceUri(Uri.parse('http://www.healthychildren.org/test')),
      isFalse,
    );
    expect(
      isApprovedGuidanceUri(Uri.parse('https://example.com/test')),
      isFalse,
    );
  });

  test('구조화 payload가 없는 기존 체온도 숫자를 안전하게 인식한다', () {
    final activity = ActivityEntity(
      type: 'Temperature',
      time: occurredAt,
      details: '38.4°C · Ear',
      lastModified: occurredAt,
    );

    expect(evaluateMedicalGuidance(activity).requiresAttention, isTrue);
  });
}
