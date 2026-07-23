import 'package:objectbox/objectbox.dart';

@Entity()
class AuthorProfileEntity {
  @Id()
  int id;

  @Index()
  String authorProfileId;

  String nickname;

  /// Flutter의 ARGB 정수 색상 값이다.
  int colorValue;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  /// 현재 설치에서 새 기록에 자동 적용할 프로필인지 나타내는 로컬 상태다.
  /// 백업으로 내보내거나 다른 기기에서 복원하지 않는다.
  bool isCurrent;

  AuthorProfileEntity({
    this.id = 0,
    required this.authorProfileId,
    required this.nickname,
    required this.colorValue,
    required this.createdAt,
    this.isCurrent = false,
  });
}
