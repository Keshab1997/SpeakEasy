// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_result_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GameResultModelAdapter extends TypeAdapter<GameResultModel> {
  @override
  final int typeId = 2;

  @override
  GameResultModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GameResultModel(
      score: fields[0] as int,
      correctAnswers: fields[1] as int,
      wrongAnswers: fields[2] as int,
      accuracy: fields[3] as double,
      earnedXP: fields[4] as int,
      earnedCoins: fields[5] as int,
      completedTime: fields[6] as DateTime?,
      gameType: fields[7] as String,
      durationSeconds: fields[8] as int,
      isBossWin: fields[9] as bool,
      isDailyChallengeWin: fields[10] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, GameResultModel obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.score)
      ..writeByte(1)
      ..write(obj.correctAnswers)
      ..writeByte(2)
      ..write(obj.wrongAnswers)
      ..writeByte(3)
      ..write(obj.accuracy)
      ..writeByte(4)
      ..write(obj.earnedXP)
      ..writeByte(5)
      ..write(obj.earnedCoins)
      ..writeByte(6)
      ..write(obj.completedTime)
      ..writeByte(7)
      ..write(obj.gameType)
      ..writeByte(8)
      ..write(obj.durationSeconds)
      ..writeByte(9)
      ..write(obj.isBossWin)
      ..writeByte(10)
      ..write(obj.isDailyChallengeWin);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameResultModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
