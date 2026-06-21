// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'achievement_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AchievementModelAdapter extends TypeAdapter<AchievementModel> {
  @override
  final int typeId = 4;

  @override
  AchievementModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AchievementModel(
      id: fields[0] as String,
      title: fields[1] as String? ?? '',
      description: fields[2] as String? ?? '',
      unlocked: fields[3] as bool? ?? false,
      unlockDate: fields[4] as DateTime?,
      icon: fields[5] as String? ?? '🏅',
      category: fields[6] as String? ?? 'General',
      xpReward: fields[7] as int? ?? 0,
      coinReward: fields[8] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, AchievementModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.unlocked)
      ..writeByte(4)
      ..write(obj.unlockDate)
      ..writeByte(5)
      ..write(obj.icon)
      ..writeByte(6)
      ..write(obj.category)
      ..writeByte(7)
      ..write(obj.xpReward)
      ..writeByte(8)
      ..write(obj.coinReward);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AchievementModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
