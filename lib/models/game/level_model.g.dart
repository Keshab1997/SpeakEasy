// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'level_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LevelModelAdapter extends TypeAdapter<LevelModel> {
  @override
  final int typeId = 5;

  @override
  LevelModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LevelModel(
      id: fields[0] as String,
      name: fields[1] as String? ?? '',
      description: fields[2] as String? ?? '',
      order: fields[3] as int? ?? 0,
      unlocked: fields[4] as bool? ?? false,
      completed: fields[5] as bool? ?? false,
      totalStars: fields[6] as int? ?? 0,
      requiredXP: fields[7] as int? ?? 0,
      categories: (fields[8] as List?)
              ?.map((c) => TenseCategory.fromMap(Map<String, dynamic>.from(c as Map)))
              .toList() ??
          const <TenseCategory>[],
    );
  }

  @override
  void write(BinaryWriter writer, LevelModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.order)
      ..writeByte(4)
      ..write(obj.unlocked)
      ..writeByte(5)
      ..write(obj.completed)
      ..writeByte(6)
      ..write(obj.totalStars)
      ..writeByte(7)
      ..write(obj.requiredXP)
      ..writeByte(8)
      ..write(obj.categories.map((c) => c.toMap()).toList());
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LevelModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TenseCategoryAdapter extends TypeAdapter<TenseCategory> {
  @override
  final int typeId = 6;

  @override
  TenseCategory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TenseCategory(
      id: fields[0] as String,
      name: fields[1] as String? ?? '',
      description: fields[2] as String? ?? '',
      questionCount: fields[3] as int? ?? 0,
      unlocked: fields[4] as bool? ?? false,
      completed: fields[5] as bool? ?? false,
      stars: fields[6] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, TenseCategory obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.questionCount)
      ..writeByte(4)
      ..write(obj.unlocked)
      ..writeByte(5)
      ..write(obj.completed)
      ..writeByte(6)
      ..write(obj.stars);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TenseCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
