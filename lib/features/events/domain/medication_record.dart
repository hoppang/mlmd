import 'dart:convert';

import '../../../l10n/app_localizations.dart';

enum MedicationCategory {
  antipyretic,
  coughCold,
  antibiotic,
  ointment,
  eyeEarNose,
  other,
}

enum MedicationRoute {
  oral,
  suppository,
  topical,
  inhaled,
  other,
  unknown,
}

enum AntipyreticIngredient {
  acetaminophen,
  ibuprofen,
  other,
  unknown,
}

class MedicationRecord {
  const MedicationRecord({
    required this.medicationId,
    required this.category,
    required this.medicationName,
    required this.route,
    required this.administeredAt,
    this.ingredient,
    this.amount,
    this.unit,
    this.administrationSite,
    this.note,
  });

  static const schema = 'mlmd.medication';
  static const version = 1;

  final String medicationId;
  final MedicationCategory category;
  final String medicationName;
  final MedicationRoute route;
  final DateTime administeredAt;
  final AntipyreticIngredient? ingredient;
  final double? amount;
  final String? unit;
  final String? administrationSite;
  final String? note;

  bool get isAntipyretic => category == MedicationCategory.antipyretic;

  bool get requiresIngredientCheck =>
      isAntipyretic &&
      (ingredient == null || ingredient == AntipyreticIngredient.unknown);

  String encode() => jsonEncode({
    'schema': schema,
    'version': version,
    'medicationId': medicationId,
    'category': category.name,
    'medicationName': medicationName,
    'route': route.name,
    'administeredAt': administeredAt.toIso8601String(),
    if (ingredient != null) 'ingredient': ingredient!.name,
    if (amount != null) 'amount': amount,
    if (unit?.trim().isNotEmpty == true) 'unit': unit!.trim(),
    if (administrationSite?.trim().isNotEmpty == true)
      'administrationSite': administrationSite!.trim(),
    if (note?.trim().isNotEmpty == true) 'note': note!.trim(),
  });

  static MedicationRecord? decode(String value) {
    if (value.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic> ||
          decoded['schema'] != schema ||
          decoded['version'] != version) {
        return null;
      }

      final medicationId = decoded['medicationId'];
      final categoryName = decoded['category'];
      final medicationName = decoded['medicationName'];
      final routeName = decoded['route'];
      final administeredAtStr = decoded['administeredAt'];

      if (medicationId is! String ||
          categoryName is! String ||
          medicationName is! String ||
          routeName is! String ||
          administeredAtStr is! String) {
        return null;
      }

      final category = MedicationCategory.values
          .where((e) => e.name == categoryName)
          .firstOrNull;
      final route = MedicationRoute.values
          .where((e) => e.name == routeName)
          .firstOrNull;
      final administeredAt = DateTime.tryParse(administeredAtStr);

      if (category == null || route == null || administeredAt == null) {
        return null;
      }

      final ingredientName = decoded['ingredient'] as String?;
      final ingredient = ingredientName == null
          ? null
          : AntipyreticIngredient.values
              .where((e) => e.name == ingredientName)
              .firstOrNull;

      final amountNum = decoded['amount'];
      final amount = amountNum is num ? amountNum.toDouble() : null;
      final unit = decoded['unit'] as String?;
      final administrationSite = decoded['administrationSite'] as String?;
      final note = decoded['note'] as String?;

      return MedicationRecord(
        medicationId: medicationId,
        category: category,
        medicationName: medicationName,
        route: route,
        administeredAt: administeredAt,
        ingredient: ingredient,
        amount: amount,
        unit: unit,
        administrationSite: administrationSite,
        note: note,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }
}

String medicationCategoryLabel(AppLocalizations loc, MedicationCategory category) =>
    switch (category) {
      MedicationCategory.antipyretic => loc.medicationCategoryAntipyretic,
      MedicationCategory.coughCold => loc.medicationCategoryCoughCold,
      MedicationCategory.antibiotic => loc.medicationCategoryAntibiotic,
      MedicationCategory.ointment => loc.medicationCategoryOintment,
      MedicationCategory.eyeEarNose => loc.medicationCategoryEyeEarNose,
      MedicationCategory.other => loc.medicationCategoryOther,
    };

String medicationRouteLabel(AppLocalizations loc, MedicationRoute route) =>
    switch (route) {
      MedicationRoute.oral => loc.medicationRouteOral,
      MedicationRoute.suppository => loc.medicationRouteSuppository,
      MedicationRoute.topical => loc.medicationRouteTopical,
      MedicationRoute.inhaled => loc.medicationRouteInhaled,
      MedicationRoute.other => loc.medicationRouteOther,
      MedicationRoute.unknown => loc.medicationRouteOther,
    };

String antipyreticIngredientLabel(
  AppLocalizations loc,
  AntipyreticIngredient ingredient,
) => switch (ingredient) {
  AntipyreticIngredient.acetaminophen => loc.ingredientAcetaminophen,
  AntipyreticIngredient.ibuprofen => loc.ingredientIbuprofen,
  AntipyreticIngredient.other => loc.ingredientOther,
  AntipyreticIngredient.unknown => loc.ingredientUnknown,
};

String medicationRecordDetails(AppLocalizations loc, MedicationRecord record) {
  final parts = <String>[];

  if (record.isAntipyretic) {
    if (record.ingredient case final ingredient?) {
      parts.add(antipyreticIngredientLabel(loc, ingredient));
    }
  } else {
    parts.add(medicationCategoryLabel(loc, record.category));
  }

  if (record.amount case final amount?) {
    final unitStr = record.unit ?? 'mL';
    final formattedAmount =
        amount == amount.toInt() ? '${amount.toInt()}' : '$amount';
    parts.add('$formattedAmount$unitStr');
  }

  if (record.administrationSite case final site?) {
    if (site.trim().isNotEmpty) {
      parts.add(site.trim());
    }
  }

  if (record.route != MedicationRoute.oral &&
      record.route != MedicationRoute.unknown) {
    parts.add(medicationRouteLabel(loc, record.route));
  }

  if (record.note?.trim().isNotEmpty == true) {
    parts.add(record.note!.trim());
  }

  return parts.join(' · ');
}
