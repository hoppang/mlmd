import 'package:objectbox/objectbox.dart';
import 'diary_entity.dart';

@Entity()
class ActivityEntity {
  @Id()
  int id;

  String type; // 활동 타입 (수유, 수면, 투약 등)

  @Property(type: PropertyType.date)
  DateTime time; // 시간

  String details; // 상세정보(용량, 시간 등)

  @Property(type: PropertyType.date)
  DateTime lastModified;

  final diary = ToOne<DiaryEntity>();

  ActivityEntity({
    this.id = 0,
    required this.type,
    required this.time,
    required this.details,
    required this.lastModified,
  });
}
