// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_progress_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GameProgressModelAdapter extends TypeAdapter<GameProgressModel> {
  @override
  final int typeId = 3;

  @override
  GameProgressModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GameProgressModel(
      userId: fields[0] as String,
      currentLevel: fields[1] as int? ?? 1,
      currentXP: fields[2] as int? ?? 0,
      totalCoins: fields[3] as int? ?? 0,
      streak: fields[4] as int? ?? 0,
      unlockedModes:
          (fields[5] as List?)?.cast<String>() ?? const <String>[],
      weeklyStreak: fields[6] as int? ?? 0,
      longestStreak: fields[7] as int? ?? 0,
      missedDays: fields[8] as int? ?? 0,
      totalActiveDays: fields[9] as int? ?? 0,
      lastActiveDate: fields[10] as DateTime? ?? DateTime.now(),
    );
  }

  @override
  void write(BinaryWriter writer, GameProgressModel obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.userId)
      ..writeByte(1)
      ..write(obj.currentLevel)
      ..writeByte(2)
      ..write(obj.currentXP)
      ..writeByte(3)
      ..write(obj.totalCoins)
      ..writeByte(4)
      ..write(obj.streak)
      ..writeByte(5)
      ..write(obj.unlockedModes)
      ..writeByte(6)
      ..write(obj.weeklyStreak)
      ..writeByte(7)
      ..write(obj.longestStreak)
      ..writeByte(8)
      ..write(obj.missedDays)
      ..writeByte(9)
      ..write(obj.totalActiveDays)
      ..writeByte(10)
      ..write(obj.lastActiveDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameProgressModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
