class ChildProfile {
  const ChildProfile({
    required this.childId,
    required this.name,
    required this.createdAt,
    this.birthDate,
  });

  static const localChildId = 'local-child';

  final String childId;
  final String name;
  final DateTime? birthDate;
  final DateTime createdAt;

  bool get isLocalChild => childId == localChildId;

  ChildProfile copyWith({
    String? childId,
    String? name,
    DateTime? birthDate,
    DateTime? createdAt,
    bool clearBirthDate = false,
  }) {
    return ChildProfile(
      childId: childId ?? this.childId,
      name: name ?? this.name,
      birthDate: clearBirthDate ? null : birthDate ?? this.birthDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'childId': childId,
      'name': name,
      'birthDate': birthDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ChildProfile.fromJson(Map<String, Object?> json) {
    return ChildProfile(
      childId: json['childId'] as String? ?? localChildId,
      name: json['name'] as String? ?? 'Local child',
      birthDate: DateTime.tryParse(json['birthDate'] as String? ?? ''),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
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
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(childId, name, birthDate, createdAt);
}
