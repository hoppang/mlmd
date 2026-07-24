import 'dart:convert';

enum IntakeRecordKind { feeding, meal, water, snack }

enum AmountExpressionKind { qualitative, fraction, exact }

enum QualitativeLevel { sip, little, normal, much }

enum FeedingMethod { breast, bottle, timeOnly }

enum BreastSide { left, right }

enum BottleContents { formula, expressedMilk, other }

enum MealType { breakfast, lunch, dinner, other }

enum IntakeReaction { ateWell, average, refused }

class AmountExpression {
  const AmountExpression.qualitative(this.qualitativeLevel)
    : kind = AmountExpressionKind.qualitative,
      fraction = null,
      exactValue = null,
      unit = null;

  const AmountExpression.fraction(this.fraction)
    : kind = AmountExpressionKind.fraction,
      qualitativeLevel = null,
      exactValue = null,
      unit = null;

  const AmountExpression.exact({required this.exactValue, required this.unit})
    : kind = AmountExpressionKind.exact,
      qualitativeLevel = null,
      fraction = null;

  final AmountExpressionKind kind;
  final QualitativeLevel? qualitativeLevel;
  final double? fraction;
  final num? exactValue;
  final String? unit;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    if (qualitativeLevel != null) 'qualitativeLevel': qualitativeLevel!.name,
    if (fraction != null) 'fraction': fraction,
    if (exactValue != null) 'exactValue': exactValue,
    if (unit != null) 'unit': unit,
  };

  static AmountExpression? fromJson(Object? json) {
    if (json is! Map) return null;
    final map = json.map((key, value) => MapEntry(key.toString(), value));
    final kindName = map['kind'];
    if (kindName is! String) return null;
    final kind = _amountExpressionKindByName(kindName);
    if (kind == null) return null;
    switch (kind) {
      case AmountExpressionKind.qualitative:
        final levelName = map['qualitativeLevel'];
        final level = levelName is String
            ? _qualitativeLevelByName(levelName)
            : null;
        if (level == null) return null;
        return AmountExpression.qualitative(level);
      case AmountExpressionKind.fraction:
        final fraction = _parseFraction(map['fraction']);
        if (fraction == null) return null;
        return AmountExpression.fraction(fraction);
      case AmountExpressionKind.exact:
        final exactValue = _parseNum(map['exactValue']);
        final unit = map['unit'];
        if (exactValue == null || exactValue <= 0) return null;
        if (unit is! String || !_allowedAmountUnits.contains(unit)) return null;
        return AmountExpression.exact(exactValue: exactValue, unit: unit);
    }
  }
}

class IntakeRecord {
  const IntakeRecord({
    required this.kind,
    this.amountExpression,
    this.method,
    this.side,
    this.bottleContents,
    this.mealType,
    this.foodName,
    this.reaction,
    this.memo,
    this.startedAt,
    this.endedAt,
  });

  static const schemaVersion = 1;

  final IntakeRecordKind kind;
  final AmountExpression? amountExpression;
  final FeedingMethod? method;
  final BreastSide? side;
  final BottleContents? bottleContents;
  final MealType? mealType;
  final String? foodName;
  final IntakeReaction? reaction;
  final String? memo;
  final DateTime? startedAt;
  final DateTime? endedAt;

  Map<String, Object?> toJson() => {
    'version': schemaVersion,
    'kind': kind.name,
    if (method != null) 'method': method!.name,
    if (side != null) 'side': side!.name,
    if (bottleContents != null) 'bottleContents': bottleContents!.name,
    if (mealType != null) 'mealType': mealType!.name,
    if (foodName != null) 'foodName': foodName,
    if (reaction != null) 'reaction': reaction!.name,
    if (memo != null) 'memo': memo,
    if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
    if (endedAt != null) 'endedAt': endedAt!.toIso8601String(),
    if (amountExpression != null)
      'amountExpression': amountExpression!.toJson(),
  };

  String encode() => jsonEncode(toJson());

  static IntakeRecord? decode(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map) return null;
      final map = decoded.map((key, value) => MapEntry(key.toString(), value));
      final version = map['version'];
      if (version != schemaVersion) return null;
      final kindName = map['kind'];
      if (kindName is! String) return null;
      final kind = _intakeRecordKindByName(kindName);
      if (kind == null) return null;
      final hasAmountExpression = map.containsKey('amountExpression');
      final amountExpression = hasAmountExpression
          ? AmountExpression.fromJson(map['amountExpression'])
          : null;
      if (hasAmountExpression && amountExpression == null) return null;
      final method = _feedingMethodByName(map['method']);
      final side = _breastSideByName(map['side']);
      final bottleContents = _bottleContentsByName(map['bottleContents']);
      final mealType = _mealTypeByName(map['mealType']);
      final reaction = _intakeReactionByName(map['reaction']);
      final foodName = map['foodName'];
      final memo = map['memo'];
      final startedAt = _parseDateTime(map['startedAt']);
      final endedAt = _parseDateTime(map['endedAt']);
      if ((map.containsKey('method') && method == null) ||
          (map.containsKey('side') && side == null) ||
          (map.containsKey('bottleContents') && bottleContents == null) ||
          (map.containsKey('mealType') && mealType == null) ||
          (map.containsKey('reaction') && reaction == null) ||
          (map.containsKey('startedAt') && startedAt == null) ||
          (map.containsKey('endedAt') && endedAt == null)) {
        return null;
      }
      if (foodName != null && foodName is! String) return null;
      if (memo != null && memo is! String) return null;
      if (!_validateKind(
        kind: kind,
        amountExpression: amountExpression,
        method: method,
        side: side,
        bottleContents: bottleContents,
        mealType: mealType,
        foodName: foodName,
        reaction: reaction,
        memo: memo,
        startedAt: startedAt,
        endedAt: endedAt,
      )) {
        return null;
      }
      return IntakeRecord(
        kind: kind,
        amountExpression: amountExpression,
        method: method,
        side: side,
        bottleContents: bottleContents,
        mealType: mealType,
        foodName: foodName as String?,
        reaction: reaction,
        memo: memo as String?,
        startedAt: startedAt,
        endedAt: endedAt,
      );
    } on FormatException {
      return null;
    }
  }
}

AmountExpressionKind? _amountExpressionKindByName(String name) {
  for (final value in AmountExpressionKind.values) {
    if (value.name == name) return value;
  }
  return null;
}

QualitativeLevel? _qualitativeLevelByName(String name) {
  for (final value in QualitativeLevel.values) {
    if (value.name == name) return value;
  }
  return null;
}

IntakeRecordKind? _intakeRecordKindByName(String name) {
  for (final value in IntakeRecordKind.values) {
    if (value.name == name) return value;
  }
  return null;
}

FeedingMethod? _feedingMethodByName(Object? value) {
  if (value is! String) return null;
  for (final item in FeedingMethod.values) {
    if (item.name == value) return item;
  }
  return null;
}

BreastSide? _breastSideByName(Object? value) {
  if (value is! String) return null;
  for (final item in BreastSide.values) {
    if (item.name == value) return item;
  }
  return null;
}

BottleContents? _bottleContentsByName(Object? value) {
  if (value is! String) return null;
  for (final item in BottleContents.values) {
    if (item.name == value) return item;
  }
  return null;
}

MealType? _mealTypeByName(Object? value) {
  if (value is! String) return null;
  for (final item in MealType.values) {
    if (item.name == value) return item;
  }
  return null;
}

IntakeReaction? _intakeReactionByName(Object? value) {
  if (value is! String) return null;
  for (final item in IntakeReaction.values) {
    if (item.name == value) return item;
  }
  return null;
}

bool _validateKind({
  required IntakeRecordKind kind,
  required AmountExpression? amountExpression,
  required FeedingMethod? method,
  required BreastSide? side,
  required BottleContents? bottleContents,
  required MealType? mealType,
  required String? foodName,
  required IntakeReaction? reaction,
  required String? memo,
  required DateTime? startedAt,
  required DateTime? endedAt,
}) {
  final hasOnlyAllowedExtras = switch (kind) {
    IntakeRecordKind.feeding =>
      mealType == null && foodName == null && reaction == null,
    IntakeRecordKind.meal =>
      method == null && side == null && bottleContents == null,
    IntakeRecordKind.water =>
      method == null &&
          side == null &&
          bottleContents == null &&
          mealType == null &&
          foodName == null &&
          startedAt == null &&
          endedAt == null,
    IntakeRecordKind.snack =>
      method == null &&
          side == null &&
          bottleContents == null &&
          startedAt == null &&
          endedAt == null,
  };
  if (!hasOnlyAllowedExtras) return false;

  switch (kind) {
    case IntakeRecordKind.feeding:
      if (method == null) return false;
      if (method == FeedingMethod.bottle && bottleContents == null) {
        return false;
      }
      if (method != FeedingMethod.bottle && bottleContents != null) {
        return false;
      }
      if (method == FeedingMethod.breast && side == null) return false;
      if (method != FeedingMethod.breast && side != null) return false;
      if (method != FeedingMethod.bottle && amountExpression != null) {
        return false;
      }
      if (method == FeedingMethod.breast &&
          startedAt != null &&
          endedAt != null &&
          startedAt.isAfter(endedAt)) {
        return false;
      }
      if (method == FeedingMethod.timeOnly && amountExpression != null) {
        return false;
      }
      return true;
    case IntakeRecordKind.meal:
      return mealType != null && amountExpression != null;
    case IntakeRecordKind.water:
      return amountExpression != null && foodName == null;
    case IntakeRecordKind.snack:
      return amountExpression != null;
  }
}

DateTime? _parseDateTime(Object? value) {
  if (value is! String) return null;
  return DateTime.tryParse(value);
}

const _allowedAmountUnits = {'ml', 'oz', 'g'};

double? _parseFraction(Object? value) {
  final parsed = _parseNum(value);
  if (parsed == null) return null;
  const allowed = [0.25, 0.5, 0.75, 1.0];
  for (final candidate in allowed) {
    if ((parsed - candidate).abs() < 1e-9) return candidate;
  }
  return null;
}

num? _parseNum(Object? value) {
  if (value is num) return value;
  return null;
}
