import 'dart:convert';

enum QuickLaunchEventTarget {
  feeding,
  formulaFeeding,
  breastFeeding,
  expressedMilkFeeding,
  meal,
  water,
  snack,
  sleep,
  diaper,
  pumping,
  temperature,
  medication,
  symptom,
  hospital,
  vaccination,
  accidentInjury,
  careProcedure,
  tummyTime,
  bath,
  growthMeasurement,
  memo,
}

enum QuickLaunchExecutionMode { instant, prefilledForm, category }

enum QuickLaunchRecommendationDecisionStatus {
  pending,
  snoozed,
  applied,
  partiallyApplied,
  skipped,
}

class QuickLaunchRecommendationDecision {
  const QuickLaunchRecommendationDecision({
    required this.childId,
    required this.deviceProfileId,
    required this.milestone,
    required this.recommendationVersion,
    required this.status,
    required this.suggestedAt,
    this.decidedAt,
    this.nextEligibleAt,
    this.previousSlotSnapshot,
  });

  final String childId;
  final String deviceProfileId;
  final GrowthMilestone milestone;
  final int recommendationVersion;
  final QuickLaunchRecommendationDecisionStatus status;
  final DateTime suggestedAt;
  final DateTime? decidedAt;
  final DateTime? nextEligibleAt;
  final String? previousSlotSnapshot;

  QuickLaunchRecommendationDecision copyWith({
    QuickLaunchRecommendationDecisionStatus? status,
    DateTime? decidedAt,
    DateTime? nextEligibleAt,
    String? previousSlotSnapshot,
    bool clearDecidedAt = false,
    bool clearNextEligibleAt = false,
    bool clearPreviousSlotSnapshot = false,
  }) => QuickLaunchRecommendationDecision(
    childId: childId,
    deviceProfileId: deviceProfileId,
    milestone: milestone,
    recommendationVersion: recommendationVersion,
    status: status ?? this.status,
    suggestedAt: suggestedAt,
    decidedAt: clearDecidedAt ? null : decidedAt ?? this.decidedAt,
    nextEligibleAt: clearNextEligibleAt
        ? null
        : nextEligibleAt ?? this.nextEligibleAt,
    previousSlotSnapshot: clearPreviousSlotSnapshot
        ? null
        : previousSlotSnapshot ?? this.previousSlotSnapshot,
  );

  Map<String, Object?> toJson() => {
    'childId': childId,
    'deviceProfileId': deviceProfileId,
    'milestone': milestone.name,
    'recommendationVersion': recommendationVersion,
    'status': status.name,
    'suggestedAt': suggestedAt.toIso8601String(),
    if (decidedAt != null) 'decidedAt': decidedAt!.toIso8601String(),
    if (nextEligibleAt != null)
      'nextEligibleAt': nextEligibleAt!.toIso8601String(),
    if (previousSlotSnapshot != null)
      'previousSlotSnapshot': previousSlotSnapshot,
  };

  factory QuickLaunchRecommendationDecision.fromJson(
    Map<String, dynamic> json,
  ) {
    final milestone = _enumByName(GrowthMilestone.values, json['milestone']);
    final status = _enumByName(
      QuickLaunchRecommendationDecisionStatus.values,
      json['status'],
    );
    final suggestedAt = DateTime.tryParse(json['suggestedAt'] as String? ?? '');
    if (milestone == null || status == null || suggestedAt == null) {
      throw const FormatException('Invalid quick launch recommendation');
    }
    return QuickLaunchRecommendationDecision(
      childId: json['childId'] as String,
      deviceProfileId: json['deviceProfileId'] as String,
      milestone: milestone,
      recommendationVersion:
          (json['recommendationVersion'] as num?)?.toInt() ?? 1,
      status: status,
      suggestedAt: suggestedAt,
      decidedAt: DateTime.tryParse(json['decidedAt'] as String? ?? ''),
      nextEligibleAt: DateTime.tryParse(
        json['nextEligibleAt'] as String? ?? '',
      ),
      previousSlotSnapshot: json['previousSlotSnapshot'] as String?,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory QuickLaunchRecommendationDecision.fromJsonString(String source) =>
      QuickLaunchRecommendationDecision.fromJson(
        jsonDecode(source) as Map<String, dynamic>,
      );
}

class QuickLaunchSlot {
  const QuickLaunchSlot({
    required this.slotIndex,
    this.eventTypeId,
    this.executionMode = QuickLaunchExecutionMode.instant,
    this.structuredPresetJson,
    this.displayLabel,
    this.childId,
    this.deviceProfileId,
  });

  final int slotIndex;
  final QuickLaunchEventTarget? eventTypeId;
  final QuickLaunchExecutionMode executionMode;
  final String? structuredPresetJson;
  final String? displayLabel;
  final String? childId;
  final String? deviceProfileId;

  bool get hasEventType => eventTypeId != null;

  QuickLaunchSlot copyWith({
    int? slotIndex,
    QuickLaunchEventTarget? eventTypeId,
    QuickLaunchExecutionMode? executionMode,
    String? structuredPresetJson,
    String? displayLabel,
    String? childId,
    String? deviceProfileId,
    bool clearEventType = false,
    bool clearStructuredPresetJson = false,
    bool clearDisplayLabel = false,
    bool clearChildId = false,
    bool clearDeviceProfileId = false,
  }) {
    return QuickLaunchSlot(
      slotIndex: slotIndex ?? this.slotIndex,
      eventTypeId: clearEventType ? null : eventTypeId ?? this.eventTypeId,
      executionMode: executionMode ?? this.executionMode,
      structuredPresetJson: clearStructuredPresetJson
          ? null
          : structuredPresetJson ?? this.structuredPresetJson,
      displayLabel: clearDisplayLabel
          ? null
          : displayLabel ?? this.displayLabel,
      childId: clearChildId ? null : childId ?? this.childId,
      deviceProfileId: clearDeviceProfileId
          ? null
          : deviceProfileId ?? this.deviceProfileId,
    );
  }

  Map<String, dynamic> toJson() => {
    'slotIndex': slotIndex,
    'eventTypeId': eventTypeId?.name,
    'executionMode': executionMode.name,
    'structuredPresetJson': structuredPresetJson,
    'displayLabel': displayLabel,
    'childId': childId,
    'deviceProfileId': deviceProfileId,
  };

  factory QuickLaunchSlot.fromJson(Map<String, dynamic> json) {
    return QuickLaunchSlot(
      slotIndex: (json['slotIndex'] as num?)?.toInt() ?? 0,
      eventTypeId: _eventTypeIdFromJson(json['eventTypeId']),
      executionMode: _executionModeFromJson(json['executionMode']),
      structuredPresetJson: json['structuredPresetJson'] as String?,
      displayLabel: json['displayLabel'] as String?,
      childId: json['childId'] as String?,
      deviceProfileId: json['deviceProfileId'] as String?,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory QuickLaunchSlot.fromJsonString(String jsonString) =>
      QuickLaunchSlot.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);

  static QuickLaunchEventTarget? _eventTypeIdFromJson(Object? value) {
    final raw = value as String?;
    if (raw == null || raw.isEmpty) return null;
    for (final item in QuickLaunchEventTarget.values) {
      if (item.name == raw) return item;
    }
    return null;
  }

  static QuickLaunchExecutionMode _executionModeFromJson(Object? value) {
    final raw = value as String?;
    for (final item in QuickLaunchExecutionMode.values) {
      if (item.name == raw) return item;
    }
    return QuickLaunchExecutionMode.instant;
  }

  @override
  bool operator ==(Object other) {
    return other is QuickLaunchSlot &&
        other.slotIndex == slotIndex &&
        other.eventTypeId == eventTypeId &&
        other.executionMode == executionMode &&
        other.structuredPresetJson == structuredPresetJson &&
        other.displayLabel == displayLabel &&
        other.childId == childId &&
        other.deviceProfileId == deviceProfileId;
  }

  @override
  int get hashCode => Object.hash(
    slotIndex,
    eventTypeId,
    executionMode,
    structuredPresetJson,
    displayLabel,
    childId,
    deviceProfileId,
  );
}

const quickLaunchSlotCount = 5;

class QuickLaunchLayout {
  const QuickLaunchLayout({required this.slots})
    : assert(slots.length == quickLaunchSlotCount);

  final List<QuickLaunchSlot> slots;

  factory QuickLaunchLayout.empty({String? childId, String? deviceProfileId}) {
    return QuickLaunchLayout(
      slots: List.generate(
        quickLaunchSlotCount,
        (index) => QuickLaunchSlot(
          slotIndex: index,
          childId: childId,
          deviceProfileId: deviceProfileId,
        ),
      ),
    );
  }

  QuickLaunchSlot slotAt(int index) => slots[index];

  QuickLaunchLayout copyWithSlot(int index, QuickLaunchSlot slot) {
    final next = List<QuickLaunchSlot>.from(slots);
    next[index] = slot.copyWith(slotIndex: index);
    return QuickLaunchLayout(slots: next);
  }

  Map<String, dynamic> toJson() => {
    'slots': slots.map((slot) => slot.toJson()).toList(growable: false),
  };

  factory QuickLaunchLayout.fromJson(Map<String, dynamic> json) {
    final rawSlots = (json['slots'] as List<dynamic>? ?? const []);
    final slots = rawSlots
        .map((value) => QuickLaunchSlot.fromJson(value as Map<String, dynamic>))
        .toList(growable: false);
    if (slots.length != quickLaunchSlotCount) {
      throw FormatException(
        'Expected $quickLaunchSlotCount quick launch slots, got ${slots.length}',
      );
    }
    return QuickLaunchLayout(slots: slots);
  }

  String toJsonString() => jsonEncode(toJson());

  factory QuickLaunchLayout.fromJsonString(String jsonString) =>
      QuickLaunchLayout.fromJson(
        jsonDecode(jsonString) as Map<String, dynamic>,
      );

  @override
  bool operator ==(Object other) {
    if (other is! QuickLaunchLayout || other.slots.length != slots.length) {
      return false;
    }
    for (var i = 0; i < slots.length; i++) {
      if (other.slots[i] != slots[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(slots);
}

enum GrowthMilestone { newborn, month3, month6, year1 }

enum GrowthRecommendationState { notDue, due, overdue }

class GrowthAgeBand {
  const GrowthAgeBand({
    required this.completedMonths,
    required this.daysIntoCurrentMonth,
  });

  final int completedMonths;
  final int daysIntoCurrentMonth;

  bool get isNewborn => completedMonths < 3;
}

class GrowthMilestoneDecision {
  const GrowthMilestoneDecision({
    required this.milestone,
    required this.status,
    required this.ageBand,
    required this.targetDate,
  });

  final GrowthMilestone milestone;
  final GrowthRecommendationState status;
  final GrowthAgeBand ageBand;
  final DateTime targetDate;
}

class GrowthAgeCalculator {
  const GrowthAgeCalculator();

  GrowthAgeBand ageBandOn({
    required DateTime birthDate,
    required DateTime asOf,
  }) {
    final birth = _dateOnly(birthDate);
    final now = _dateOnly(asOf);
    if (now.isBefore(birth)) {
      return const GrowthAgeBand(completedMonths: 0, daysIntoCurrentMonth: 0);
    }

    var months = (now.year - birth.year) * 12 + now.month - birth.month;
    final anchor = _safeAddMonths(birth, months);
    if (anchor.isAfter(now)) {
      months -= 1;
    }
    final adjustedAnchor = _safeAddMonths(birth, months);
    return GrowthAgeBand(
      completedMonths: months,
      daysIntoCurrentMonth: now.difference(adjustedAnchor).inDays,
    );
  }

  GrowthMilestoneDecision? decisionFor({
    required DateTime birthDate,
    required DateTime asOf,
  }) {
    final ageBand = ageBandOn(birthDate: birthDate, asOf: asOf);
    final milestone = milestoneFor(ageBand.completedMonths);
    if (milestone == null) return null;

    final targetDate = _milestoneTargetDate(birthDate, milestone);
    final current = _dateOnly(asOf);
    final status = current.isBefore(targetDate)
        ? GrowthRecommendationState.notDue
        : current.isAtSameMomentAs(targetDate)
        ? GrowthRecommendationState.due
        : GrowthRecommendationState.overdue;
    return GrowthMilestoneDecision(
      milestone: milestone,
      status: status,
      ageBand: ageBand,
      targetDate: targetDate,
    );
  }

  GrowthMilestone? milestoneFor(int completedMonths) {
    if (completedMonths < 0) return null;
    if (completedMonths < 3) return GrowthMilestone.newborn;
    if (completedMonths < 6) return GrowthMilestone.month3;
    if (completedMonths < 12) return GrowthMilestone.month6;
    return GrowthMilestone.year1;
  }

  DateTime _milestoneTargetDate(DateTime birthDate, GrowthMilestone milestone) {
    final birth = _dateOnly(birthDate);
    return switch (milestone) {
      GrowthMilestone.newborn => birth,
      GrowthMilestone.month3 => _safeAddMonths(birth, 3),
      GrowthMilestone.month6 => _safeAddMonths(birth, 6),
      GrowthMilestone.year1 => _safeAddMonths(birth, 12),
    };
  }

  DateTime _safeAddMonths(DateTime date, int monthsToAdd) {
    final totalMonths = (date.year * 12) + (date.month - 1) + monthsToAdd;
    final year = totalMonths ~/ 12;
    final month = (totalMonths % 12) + 1;
    final day = date.day.clamp(1, _daysInMonth(year, month)).toInt();
    return DateTime(year, month, day);
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  int _daysInMonth(int year, int month) {
    final nextMonth = month == 12
        ? DateTime(year + 1, 1, 1)
        : DateTime(year, month + 1, 1);
    return nextMonth.difference(DateTime(year, month, 1)).inDays;
  }
}

class QuickLaunchRecommendationTemplate {
  const QuickLaunchRecommendationTemplate({
    required this.slotIndex,
    required this.eventTypeId,
    required this.executionMode,
    required this.displayLabel,
    this.structuredPresetJson,
    this.childId,
    this.deviceProfileId,
  });

  final int slotIndex;
  final QuickLaunchEventTarget eventTypeId;
  final QuickLaunchExecutionMode executionMode;
  final String displayLabel;
  final String? structuredPresetJson;
  final String? childId;
  final String? deviceProfileId;

  QuickLaunchSlot toSlot() => QuickLaunchSlot(
    slotIndex: slotIndex,
    eventTypeId: eventTypeId,
    executionMode: executionMode,
    structuredPresetJson: structuredPresetJson,
    displayLabel: displayLabel,
    childId: childId,
    deviceProfileId: deviceProfileId,
  );
}

class QuickLaunchRecommendationBuilder {
  const QuickLaunchRecommendationBuilder();

  QuickLaunchLayout buildForMilestone({
    required GrowthMilestone milestone,
    String? childId,
    String? deviceProfileId,
  }) {
    final templates = switch (milestone) {
      GrowthMilestone.newborn => [
        const QuickLaunchRecommendationTemplate(
          slotIndex: 0,
          eventTypeId: QuickLaunchEventTarget.feeding,
          executionMode: QuickLaunchExecutionMode.category,
          displayLabel: 'feeding',
        ),
        const QuickLaunchRecommendationTemplate(
          slotIndex: 1,
          eventTypeId: QuickLaunchEventTarget.diaper,
          executionMode: QuickLaunchExecutionMode.instant,
          displayLabel: 'diaperUrine',
          structuredPresetJson: '{"kind":"urine"}',
        ),
        const QuickLaunchRecommendationTemplate(
          slotIndex: 2,
          eventTypeId: QuickLaunchEventTarget.diaper,
          executionMode: QuickLaunchExecutionMode.instant,
          displayLabel: 'diaperStool',
          structuredPresetJson: '{"kind":"stool"}',
        ),
        const QuickLaunchRecommendationTemplate(
          slotIndex: 3,
          eventTypeId: QuickLaunchEventTarget.sleep,
          executionMode: QuickLaunchExecutionMode.instant,
          displayLabel: 'sleep',
        ),
      ],
      GrowthMilestone.month3 => [
        const QuickLaunchRecommendationTemplate(
          slotIndex: 0,
          eventTypeId: QuickLaunchEventTarget.feeding,
          executionMode: QuickLaunchExecutionMode.category,
          displayLabel: 'feeding',
        ),
        const QuickLaunchRecommendationTemplate(
          slotIndex: 1,
          eventTypeId: QuickLaunchEventTarget.sleep,
          executionMode: QuickLaunchExecutionMode.instant,
          displayLabel: 'sleep',
        ),
        const QuickLaunchRecommendationTemplate(
          slotIndex: 2,
          eventTypeId: QuickLaunchEventTarget.diaper,
          executionMode: QuickLaunchExecutionMode.instant,
          displayLabel: 'diaperUrine',
          structuredPresetJson: '{"kind":"urine"}',
        ),
        const QuickLaunchRecommendationTemplate(
          slotIndex: 3,
          eventTypeId: QuickLaunchEventTarget.tummyTime,
          executionMode: QuickLaunchExecutionMode.prefilledForm,
          displayLabel: 'tummyTime',
        ),
      ],
      GrowthMilestone.month6 => [
        const QuickLaunchRecommendationTemplate(
          slotIndex: 0,
          eventTypeId: QuickLaunchEventTarget.feeding,
          executionMode: QuickLaunchExecutionMode.category,
          displayLabel: 'feeding',
        ),
        const QuickLaunchRecommendationTemplate(
          slotIndex: 1,
          eventTypeId: QuickLaunchEventTarget.meal,
          executionMode: QuickLaunchExecutionMode.prefilledForm,
          displayLabel: 'meal',
        ),
        const QuickLaunchRecommendationTemplate(
          slotIndex: 2,
          eventTypeId: QuickLaunchEventTarget.water,
          executionMode: QuickLaunchExecutionMode.prefilledForm,
          displayLabel: 'water',
        ),
        const QuickLaunchRecommendationTemplate(
          slotIndex: 3,
          eventTypeId: QuickLaunchEventTarget.sleep,
          executionMode: QuickLaunchExecutionMode.instant,
          displayLabel: 'sleep',
        ),
      ],
      GrowthMilestone.year1 => [
        const QuickLaunchRecommendationTemplate(
          slotIndex: 0,
          eventTypeId: QuickLaunchEventTarget.meal,
          executionMode: QuickLaunchExecutionMode.prefilledForm,
          displayLabel: 'meal',
        ),
        const QuickLaunchRecommendationTemplate(
          slotIndex: 1,
          eventTypeId: QuickLaunchEventTarget.snack,
          executionMode: QuickLaunchExecutionMode.prefilledForm,
          displayLabel: 'snack',
        ),
        const QuickLaunchRecommendationTemplate(
          slotIndex: 2,
          eventTypeId: QuickLaunchEventTarget.water,
          executionMode: QuickLaunchExecutionMode.prefilledForm,
          displayLabel: 'water',
        ),
        const QuickLaunchRecommendationTemplate(
          slotIndex: 3,
          eventTypeId: QuickLaunchEventTarget.sleep,
          executionMode: QuickLaunchExecutionMode.instant,
          displayLabel: 'sleep',
        ),
      ],
    };
    return QuickLaunchLayout(
      slots: [
        for (final template in templates)
          template.toSlot().copyWith(
            childId: childId,
            deviceProfileId: deviceProfileId,
          ),
        for (
          var index = templates.length;
          index < quickLaunchSlotCount;
          index++
        )
          QuickLaunchSlot(
            slotIndex: index,
            childId: childId,
            deviceProfileId: deviceProfileId,
          ),
      ],
    );
  }
}

T? _enumByName<T extends Enum>(Iterable<T> values, Object? raw) {
  if (raw is! String) return null;
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return null;
}
