import '../../../models/activity_entity.dart';
import 'event_catalog.dart';
import 'temperature_record.dart';

enum GuidanceTopic { temperature }

class GuidanceLinkRule {
  const GuidanceLinkRule({
    required this.ruleId,
    required this.country,
    required this.topic,
    required this.minimumValueInclusive,
    required this.sourceOrganization,
    required this.sourceTitle,
    required this.sourceUrl,
    required this.sourceUpdatedAt,
    required this.lastVerifiedAt,
    required this.priority,
    required this.enabled,
    this.measurementSites,
  });

  final String ruleId;
  final String country;
  final GuidanceTopic topic;
  final double minimumValueInclusive;
  final Set<TemperatureMeasurementSite>? measurementSites;
  final String sourceOrganization;
  final String sourceTitle;
  final String sourceUrl;
  final DateTime sourceUpdatedAt;
  final DateTime lastVerifiedAt;
  final int priority;
  final bool enabled;

  bool matches(TemperatureRecord record) =>
      enabled &&
      record.celsius >= minimumValueInclusive &&
      (measurementSites == null ||
          (record.measurementSite != null &&
              measurementSites!.contains(record.measurementSite)));
}

final guidanceLinkRules = <GuidanceLinkRule>[
  GuidanceLinkRule(
    ruleId: 'aap-temperature-38',
    country: 'US',
    topic: GuidanceTopic.temperature,
    minimumValueInclusive: 38,
    sourceOrganization: 'American Academy of Pediatrics (US)',
    sourceTitle: 'How to Take Your Child’s Temperature',
    sourceUrl:
        'https://www.healthychildren.org/English/health-issues/conditions/fever/Pages/How-to-Take-a-Childs-Temperature.aspx',
    sourceUpdatedAt: DateTime.utc(2024, 4, 17),
    lastVerifiedAt: DateTime.utc(2026, 7, 24),
    priority: 1,
    enabled: true,
  ),
];

class MedicalGuidanceEvaluation {
  const MedicalGuidanceEvaluation({
    required this.requiresAttention,
    required this.reason,
    required this.links,
  });

  static const none = MedicalGuidanceEvaluation(
    requiresAttention: false,
    reason: null,
    links: [],
  );

  final bool requiresAttention;
  final String? reason;
  final List<GuidanceLinkRule> links;
}

MedicalGuidanceEvaluation evaluateMedicalGuidance(ActivityEntity? activity) {
  if (activity == null || !_isTemperatureEvent(activity.type)) {
    return MedicalGuidanceEvaluation.none;
  }
  final record =
      TemperatureRecord.decode(activity.structuredDataJson ?? '') ??
      _legacyTemperatureRecord(activity);
  if (record == null || record.celsius < 38) {
    return MedicalGuidanceEvaluation.none;
  }
  final links = guidanceLinkRules.where((rule) => rule.matches(record)).toList()
    ..sort((a, b) => a.priority.compareTo(b.priority));
  return MedicalGuidanceEvaluation(
    requiresAttention: true,
    reason: '${record.celsius.toStringAsFixed(1)}°C ≥ 38.0°C',
    links: List.unmodifiable(links),
  );
}

bool isApprovedGuidanceUri(Uri uri) =>
    uri.scheme == 'https' &&
    uri.userInfo.isEmpty &&
    uri.host.toLowerCase() == 'www.healthychildren.org';

bool _isTemperatureEvent(String storedType) =>
    eventCatalogItem(EventTypeId.temperature).matches(storedType);

TemperatureRecord? _legacyTemperatureRecord(ActivityEntity activity) {
  final match = RegExp(
    r'(?<!\d)(\d{2}(?:[.,]\d)?)\s*(?:°\s*)?[cC℃]?',
  ).firstMatch(activity.details);
  final celsius = double.tryParse(match?.group(1)?.replaceAll(',', '.') ?? '');
  if (celsius == null) return null;
  return TemperatureRecord(celsius: celsius, occurredAt: activity.time);
}
