import 'dart:convert';

enum SleepRecordStatus { active, completed }

enum SleepRecordKind { nap, night, unspecified }

enum SleepRecordSource { suggested, user }

enum SleepRecordMarker { restful, restless, wokeUp, frequentWaking }

class SleepRecord {
  SleepRecord({
    required this.status,
    required this.kind,
    required this.source,
    required this.startedAt,
    this.endedAt,
    List<SleepRecordMarker> markers = const [],
    this.endedByAuthorProfileId,
    this.endedByDeviceProfileId,
    this.note,
  }) : markers = List.unmodifiable(markers) {
    if (status == SleepRecordStatus.active) {
      assert(endedAt == null);
    }
  }

  static const schemaVersion = 1;

  final SleepRecordStatus status;
  final SleepRecordKind kind;
  final SleepRecordSource source;
  final DateTime startedAt;
  final DateTime? endedAt;
  final List<SleepRecordMarker> markers;
  final String? endedByAuthorProfileId;
  final String? endedByDeviceProfileId;
  final String? note;

  Map<String, Object?> toJson() => {
    'version': schemaVersion,
    'status': status.name,
    'kind': kind.name,
    'source': source.name,
    'startedAt': startedAt.toIso8601String(),
    if (endedAt != null) 'endedAt': endedAt!.toIso8601String(),
    if (markers.isNotEmpty)
      'markers': markers.map((marker) => marker.name).toList(),
    if (endedByAuthorProfileId != null)
      'endedByAuthorProfileId': endedByAuthorProfileId,
    if (endedByDeviceProfileId != null)
      'endedByDeviceProfileId': endedByDeviceProfileId,
    if (note != null) 'note': note,
  };

  String encode() => jsonEncode(toJson());

  SleepRecord copyWith({
    SleepRecordStatus? status,
    SleepRecordKind? kind,
    SleepRecordSource? source,
    DateTime? startedAt,
    DateTime? endedAt,
    List<SleepRecordMarker>? markers,
    String? endedByAuthorProfileId,
    String? endedByDeviceProfileId,
    String? note,
  }) {
    return SleepRecord(
      status: status ?? this.status,
      kind: kind ?? this.kind,
      source: source ?? this.source,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      markers: markers ?? this.markers,
      endedByAuthorProfileId:
          endedByAuthorProfileId ?? this.endedByAuthorProfileId,
      endedByDeviceProfileId:
          endedByDeviceProfileId ?? this.endedByDeviceProfileId,
      note: note ?? this.note,
    );
  }

  static SleepRecord? decode(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map) return null;
      final map = decoded.map((key, value) => MapEntry(key.toString(), value));
      final version = map['version'];
      if (version != schemaVersion) return null;

      final status = _sleepRecordStatusByName(map['status']);
      final kind = _sleepRecordKindByName(map['kind']);
      final sourceKind = _sleepRecordSourceByName(map['source']);
      final startedAt = _parseDateTime(map['startedAt']);
      final endedAt = _parseDateTime(map['endedAt']);
      final markers = _parseMarkers(map['markers']);
      final endedByAuthorProfileId = map['endedByAuthorProfileId'];
      final endedByDeviceProfileId = map['endedByDeviceProfileId'];
      final note = map['note'];

      if (status == null ||
          kind == null ||
          sourceKind == null ||
          startedAt == null ||
          (map.containsKey('endedAt') && endedAt == null) ||
          (map.containsKey('markers') && markers == null)) {
        return null;
      }

      if (endedByAuthorProfileId != null && endedByAuthorProfileId is! String) {
        return null;
      }
      if (endedByDeviceProfileId != null && endedByDeviceProfileId is! String) {
        return null;
      }
      if (note != null && note is! String) return null;

      if (status == SleepRecordStatus.active) {
        if (endedAt != null) return null;
      } else {
        if (endedAt == null || endedAt.isBefore(startedAt)) return null;
      }

      return SleepRecord(
        status: status,
        kind: kind,
        source: sourceKind,
        startedAt: startedAt,
        endedAt: endedAt,
        markers: markers ?? const [],
        endedByAuthorProfileId: endedByAuthorProfileId as String?,
        endedByDeviceProfileId: endedByDeviceProfileId as String?,
        note: note as String?,
      );
    } on FormatException {
      return null;
    }
  }
}

SleepRecordStatus? _sleepRecordStatusByName(Object? value) {
  if (value is! String) return null;
  for (final item in SleepRecordStatus.values) {
    if (item.name == value) return item;
  }
  return null;
}

SleepRecordKind? _sleepRecordKindByName(Object? value) {
  if (value is! String) return null;
  for (final item in SleepRecordKind.values) {
    if (item.name == value) return item;
  }
  return null;
}

SleepRecordSource? _sleepRecordSourceByName(Object? value) {
  if (value is! String) return null;
  for (final item in SleepRecordSource.values) {
    if (item.name == value) return item;
  }
  return null;
}

List<SleepRecordMarker>? _parseMarkers(Object? value) {
  if (value == null) return const [];
  if (value is! List) return null;
  final seen = <SleepRecordMarker>{};
  final markers = <SleepRecordMarker>[];
  for (final entry in value) {
    final marker = _sleepRecordMarkerByName(entry);
    if (marker == null || !seen.add(marker)) return null;
    markers.add(marker);
  }
  return markers;
}

SleepRecordMarker? _sleepRecordMarkerByName(Object? value) {
  if (value is! String) return null;
  for (final item in SleepRecordMarker.values) {
    if (item.name == value) return item;
  }
  return null;
}

DateTime? _parseDateTime(Object? value) {
  if (value is! String) return null;
  return DateTime.tryParse(value);
}
