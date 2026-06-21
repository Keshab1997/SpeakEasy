// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_level_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GameLevelModelAdapter extends TypeAdapter<GameLevelModel> {
  @override
  final int typeId = 1;

  @override
  GameLevelModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GameLevelModel(
      id: fields[0] as String,
      levelName: fields[1] as String,
      unlocked: fields[2] as bool,
      completed: fields[3] as bool,
      progress: fields[4] as double,
      totalStars: fields[5] as int,
    );
  }

  @override
  void write(BinaryWriter writer, GameLevelModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.levelName)
      ..writeByte(2)
      ..write(obj.unlocked)
      ..writeByte(3)
      ..write(obj.completed)
      ..writeByte(4)
      ..write(obj.progress)
      ..writeByte(5)
      ..write(obj.totalStars);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameLevelModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
