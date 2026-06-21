// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_question_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GameQuestionModelAdapter extends TypeAdapter<GameQuestionModel> {
  @override
  final int typeId = 0;

  @override
  GameQuestionModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GameQuestionModel(
      id: fields[0] as String,
      tenseType: fields[1] as String,
      question: fields[2] as String,
      options: (fields[3] as List).cast<String>(),
      correctAnswer: fields[4] as String,
      explanation: fields[5] as String,
      difficulty: fields[6] as String,
      mode: fields[7] as String,
      xpReward: fields[8] as int,
      coinReward: fields[9] as int,
    );
  }

  @override
  void write(BinaryWriter writer, GameQuestionModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.tenseType)
      ..writeByte(2)
      ..write(obj.question)
      ..writeByte(3)
      ..write(obj.options)
      ..writeByte(4)
      ..write(obj.correctAnswer)
      ..writeByte(5)
      ..write(obj.explanation)
      ..writeByte(6)
      ..write(obj.difficulty)
      ..writeByte(7)
      ..write(obj.mode)
      ..writeByte(8)
      ..write(obj.xpReward)
      ..writeByte(9)
      ..write(obj.coinReward);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameQuestionModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
