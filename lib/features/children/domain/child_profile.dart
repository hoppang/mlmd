class ChildProfile {
  const ChildProfile({
    required this.childId,
    required this.name,
    required this.createdAt,
    this.birthDate,
    this.familySpaceId,
    this.revision = 1,
    DateTime? updatedAt,
    this.deletedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  static const localChildId = 'local-child';

  final String childId;
  final String name;
  final DateTime? birthDate;
  final DateTime createdAt;
  final String? familySpaceId;
  final int revision;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isLocalChild => childId == localChildId;
  bool get isDeleted => deletedAt != null;

  ChildProfile copyWith({
    String? childId,
    String? name,
    DateTime? birthDate,
    DateTime? createdAt,
    String? familySpaceId,
    int? revision,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearBirthDate = false,
    bool clearDeletedAt = false,
  }) {
    return ChildProfile(
      childId: childId ?? this.childId,
      name: name ?? this.name,
      birthDate: clearBirthDate ? null : birthDate ?? this.birthDate,
      createdAt: createdAt ?? this.createdAt,
      familySpaceId: familySpaceId ?? this.familySpaceId,
      revision: revision ?? this.revision,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : deletedAt ?? this.deletedAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'childId': childId,
      'name': name,
      'birthDate': birthDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'familySpaceId': familySpaceId,
      'revision': revision,
      'updatedAt': updatedAt.toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
    };
  }

  factory ChildProfile.fromJson(Map<String, Object?> json) {
    final createdAt =
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now();
    return ChildProfile(
      childId: json['childId'] as String? ?? localChildId,
      name: json['name'] as String? ?? 'Local child',
      birthDate: DateTime.tryParse(json['birthDate'] as String? ?? ''),
      createdAt: createdAt,
      familySpaceId: json['familySpaceId'] as String?,
      revision: json['revision'] as int? ?? 1,
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? createdAt,
      deletedAt: DateTime.tryParse(json['deletedAt'] as String? ?? ''),
    );
  }

  static ChildProfile localDefault({DateTime? createdAt}) {
    return ChildProfile(
      childId: localChildId,
      name: 'Local child',
      createdAt:
          createdAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ChildProfile &&
        other.childId == childId &&
        other.name == name &&
        other.birthDate == birthDate &&
        other.createdAt == createdAt &&
        other.familySpaceId == familySpaceId &&
        other.revision == revision &&
        other.updatedAt == updatedAt &&
        other.deletedAt == deletedAt;
  }

  @override
  int get hashCode => Object.hash(
    childId,
    name,
    birthDate,
    createdAt,
    familySpaceId,
    revision,
    updatedAt,
    deletedAt,
  );
}
