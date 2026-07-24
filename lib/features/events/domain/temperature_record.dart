import 'dart:convert';

import '../../../l10n/app_localizations.dart';

enum TemperatureMeasurementSite { axillary, ear, forehead, rectal, other }

class TemperatureRecord {
  const TemperatureRecord({
    required this.celsius,
    required this.occurredAt,
    this.measurementSite,
    this.note,
  });

  static const schema = 'mlmd.temperature';
  static const version = 1;

  final double celsius;
  final DateTime occurredAt;
  final TemperatureMeasurementSite? measurementSite;
  final String? note;

  String encode() => jsonEncode({
    'schema': schema,
    'version': version,
    'celsius': celsius,
    'occurredAt': occurredAt.toIso8601String(),
    'measurementSite': measurementSite?.name,
    if (note?.trim().isNotEmpty == true) 'note': note!.trim(),
  });

  static TemperatureRecord? decode(String value) {
    if (value.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic> ||
          decoded['schema'] != schema ||
          decoded['version'] != version) {
        return null;
      }
      final celsius = decoded['celsius'];
      final occurredAt = DateTime.tryParse(
        decoded['occurredAt'] as String? ?? '',
      );
      if (celsius is! num ||
          !celsius.toDouble().isFinite ||
          celsius <= 0 ||
          occurredAt == null) {
        return null;
      }
      final siteName = decoded['measurementSite'];
      final site = siteName == null
          ? null
          : TemperatureMeasurementSite.values
                .where((candidate) => candidate.name == siteName)
                .firstOrNull;
      if (siteName != null && site == null) return null;
      final note = decoded['note'];
      if (note != null && note is! String) return null;
      return TemperatureRecord(
        celsius: celsius.toDouble(),
        occurredAt: occurredAt,
        measurementSite: site,
        note: note as String?,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }
}

String temperatureMeasurementSiteLabel(
  AppLocalizations loc,
  TemperatureMeasurementSite site,
) => switch (site) {
  TemperatureMeasurementSite.axillary => loc.temperatureSiteAxillary,
  TemperatureMeasurementSite.ear => loc.temperatureSiteEar,
  TemperatureMeasurementSite.forehead => loc.temperatureSiteForehead,
  TemperatureMeasurementSite.rectal => loc.temperatureSiteRectal,
  TemperatureMeasurementSite.other => loc.temperatureSiteOther,
};

String temperatureRecordDetails(
  AppLocalizations loc,
  TemperatureRecord record,
) {
  final parts = <String>[
    '${record.celsius.toStringAsFixed(1)}°C',
    if (record.measurementSite case final site?)
      temperatureMeasurementSiteLabel(loc, site),
    if (record.note?.trim().isNotEmpty == true) record.note!.trim(),
  ];
  return parts.join(' · ');
}
