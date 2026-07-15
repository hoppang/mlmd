import 'package:objectbox/objectbox.dart';
import 'activity_entity.dart';

@Entity()
class DiaryEntity {
  @Id()
  int id;

  @Property(type: PropertyType.date)
  DateTime date;

  String title;
  String content;

  @Property(type: PropertyType.date)
  DateTime lastModified;

  @HnswIndex(dimensions: 384)
  @Property(type: PropertyType.floatVector)
  List<double>? embedding;

  final activities = ToMany<ActivityEntity>();

  DiaryEntity({
    this.id = 0,
    required this.date,
    required this.title,
    required this.content,
    required this.lastModified,
    this.embedding,
  });
}
