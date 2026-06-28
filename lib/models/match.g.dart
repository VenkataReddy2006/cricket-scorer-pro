// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'match.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MatchModelAdapter extends TypeAdapter<MatchModel> {
  @override
  final int typeId = 1;

  @override
  MatchModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MatchModel(
      id: fields[0] as String,
      team1Name: fields[1] as String,
      team2Name: fields[2] as String,
      date: fields[3] as DateTime,
      result: fields[4] as String,
      isCompleted: fields[5] as bool,
      overs: fields[6] as int,
      team1Score: fields[7] as int,
      team1Wickets: fields[8] as int,
      team1Overs: fields[9] as double,
      team2Score: fields[10] as int,
      team2Wickets: fields[11] as int,
      team2Overs: fields[12] as double,
      matchData: (fields[13] as Map).cast<dynamic, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, MatchModel obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.team1Name)
      ..writeByte(2)
      ..write(obj.team2Name)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.result)
      ..writeByte(5)
      ..write(obj.isCompleted)
      ..writeByte(6)
      ..write(obj.overs)
      ..writeByte(7)
      ..write(obj.team1Score)
      ..writeByte(8)
      ..write(obj.team1Wickets)
      ..writeByte(9)
      ..write(obj.team1Overs)
      ..writeByte(10)
      ..write(obj.team2Score)
      ..writeByte(11)
      ..write(obj.team2Wickets)
      ..writeByte(12)
      ..write(obj.team2Overs)
      ..writeByte(13)
      ..write(obj.matchData);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MatchModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
