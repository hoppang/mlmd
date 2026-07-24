import 'dart:convert';

enum EliminationKind { urine, stool, both }

enum EliminationAmount { little, normal, much }

enum StoolConsistency { loose, normal, hard }

enum StoolColor { yellow, brown, green, black, other }

class EliminationRecord {
  const EliminationRecord({
    required this.kind,
    required this.occurredAt,
    this.urineAmount,
    this.stoolAmount,
    this.stoolConsistency,
    this.stoolColor,
    this.note,
  });

  static const schemaVersion = 1;

  final EliminationKind kind;
  final DateTime occurredAt;
  final EliminationAmount? urineAmount;
  final EliminationAmount? stoolAmount;
  final StoolConsistency? stoolConsistency;
  final StoolColor? stoolColor;
  final String? note;

  bool get hasUrine =>
      kind == EliminationKind.urine || kind == EliminationKind.both;

  bool get hasStool =>
      kind == EliminationKind.stool || kind == EliminationKind.both;

  Map<String, Object?> toJson() => {
    'version': schemaVersion,
    'occurredAt': occurredAt.toIso8601String(),
    'urine': hasUrine,
    'stool': hasStool,
    if (urineAmount != null) 'urineAmount': urineAmount!.name,
    if (stoolAmount != null) 'stoolAmount': stoolAmount!.name,
    if (stoolConsistency != null) 'stoolConsistency': stoolConsistency!.name,
    if (stoolColor != null) 'stoolColor': stoolColor!.name,
    if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
  };

  String encode() => jsonEncode(toJson());

  EliminationRecord copyWith({
    EliminationKind? kind,
    DateTime? occurredAt,
    EliminationAmount? urineAmount,
    bool clearUrineAmount = false,
    EliminationAmount? stoolAmount,
    bool clearStoolAmount = false,
    StoolConsistency? stoolConsistency,
    bool clearStoolConsistency = false,
    StoolColor? stoolColor,
    bool clearStoolColor = false,
    String? note,
    bool clearNote = false,
  }) {
    final nextKind = kind ?? this.kind;
    final nextHasStool =
        nextKind == EliminationKind.stool || nextKind == EliminationKind.both;
    final nextHasUrine =
        nextKind == EliminationKind.urine || nextKind == EliminationKind.both;
    return EliminationRecord(
      kind: nextKind,
      occurredAt: occurredAt ?? this.occurredAt,
      urineAmount: nextHasUrine
          ? (clearUrineAmount ? null : urineAmount ?? this.urineAmount)
          : null,
      stoolAmount: nextHasStool
          ? (clearStoolAmount ? null : stoolAmount ?? this.stoolAmount)
          : null,
      stoolConsistency: nextHasStool
          ? (clearStoolConsistency
                ? null
                : stoolConsistency ?? this.stoolConsistency)
          : null,
      stoolColor: nextHasStool
          ? (clearStoolColor ? null : stoolColor ?? this.stoolColor)
          : null,
      note: clearNote ? null : note ?? this.note,
    );
  }

  static EliminationRecord? decode(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map) return null;
      final map = decoded.map((key, value) => MapEntry(key.toString(), value));
      if (map['version'] != schemaVersion) return null;
      final urine = map['urine'];
      final stool = map['stool'];
      if (urine is! bool || stool is! bool || (!urine && !stool)) return null;
      final occurredAtValue = map['occurredAt'];
      if (occurredAtValue is! String) return null;
      final occurredAt = DateTime.tryParse(occurredAtValue);
      if (occurredAt == null) return null;

      final kind = urine && stool
          ? EliminationKind.both
          : urine
          ? EliminationKind.urine
          : EliminationKind.stool;
      final urineAmount = _enumByName(
        EliminationAmount.values,
        map['urineAmount'],
      );
      final stoolAmount = _enumByName(
        EliminationAmount.values,
        map['stoolAmount'],
      );
      final stoolConsistency = _enumByName(
        StoolConsistency.values,
        map['stoolConsistency'],
      );
      final stoolColor = _enumByName(StoolColor.values, map['stoolColor']);
      final note = map['note'];
      if ((map.containsKey('urineAmount') && urineAmount == null) ||
          (map.containsKey('stoolAmount') && stoolAmount == null) ||
          (map.containsKey('stoolConsistency') && stoolConsistency == null) ||
          (map.containsKey('stoolColor') && stoolColor == null) ||
          (note != null && (note is! String || note.trim().isEmpty))) {
        return null;
      }
      if (!urine && urineAmount != null) return null;
      if (!stool &&
          (stoolAmount != null ||
              stoolConsistency != null ||
              stoolColor != null)) {
        return null;
      }
      return EliminationRecord(
        kind: kind,
        occurredAt: occurredAt,
        urineAmount: urineAmount,
        stoolAmount: stoolAmount,
        stoolConsistency: stoolConsistency,
        stoolColor: stoolColor,
        note: note as String?,
      );
    } on FormatException {
      return null;
    }
  }
}

T? _enumByName<T extends Enum>(Iterable<T> values, Object? value) {
  if (value == null) return null;
  if (value is! String) return null;
  for (final item in values) {
    if (item.name == value) return item;
  }
  return null;
}
