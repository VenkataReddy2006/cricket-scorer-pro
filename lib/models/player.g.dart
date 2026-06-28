// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PlayerAdapter extends TypeAdapter<Player> {
  @override
  final int typeId = 0;

  @override
  Player read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Player(
      id: fields[0] as String,
      name: fields[1] as String,
      imageBase64: fields[41] as String?,
      battingMatches: fields[2] as int,
      battingInnings: fields[3] as int,
      battingRuns: fields[4] as int,
      battingNotOuts: fields[5] as int,
      battingBestScore: fields[6] as int,
      battingStrikeRate: fields[7] as double,
      battingAverage: fields[8] as double,
      battingFours: fields[9] as int,
      battingSixes: fields[10] as int,
      battingThirties: fields[11] as int,
      battingFifties: fields[12] as int,
      battingHundreds: fields[13] as int,
      battingDucks: fields[14] as int,
      battingGoldenDucks: fields[15] as int,
      battingBalls: fields[42] as int,
      bowlingMatches: fields[16] as int,
      bowlingInnings: fields[17] as int,
      bowlingOvers: fields[18] as double,
      bowlingWickets: fields[19] as int,
      bowlingMaidens: fields[20] as int,
      bowlingRunsConceded: fields[21] as int,
      bowlingBestWickets: fields[22] as int,
      bowlingBestRuns: fields[23] as int,
      bowlingEconomy: fields[24] as double,
      bowlingStrikeRate: fields[25] as double,
      bowlingAverage: fields[26] as double,
      bowlingWides: fields[27] as int,
      bowlingNoBalls: fields[28] as int,
      bowlingDotBalls: fields[29] as int,
      bowling3W: fields[30] as int,
      bowling5W: fields[31] as int,
      bowling7W: fields[32] as int,
      bowling10W: fields[33] as int,
      fieldingMatches: fields[34] as int,
      fieldingCatches: fields[35] as int,
      fieldingStumpings: fields[36] as int,
      fieldingRunOuts: fields[37] as int,
      captaincyMatches: fields[38] as int,
      captaincyWon: fields[39] as int,
      captaincyLost: fields[40] as int,
      singleStats: (fields[43] as Map?)?.cast<dynamic, dynamic>(),
      pairStats: (fields[44] as Map?)?.cast<dynamic, dynamic>(),
      teamStats: (fields[45] as Map?)?.cast<dynamic, dynamic>(),
      overallStats: (fields[46] as Map?)?.cast<dynamic, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, Player obj) {
    writer
      ..writeByte(47)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(41)
      ..write(obj.imageBase64)
      ..writeByte(2)
      ..write(obj.battingMatches)
      ..writeByte(3)
      ..write(obj.battingInnings)
      ..writeByte(4)
      ..write(obj.battingRuns)
      ..writeByte(5)
      ..write(obj.battingNotOuts)
      ..writeByte(6)
      ..write(obj.battingBestScore)
      ..writeByte(7)
      ..write(obj.battingStrikeRate)
      ..writeByte(8)
      ..write(obj.battingAverage)
      ..writeByte(9)
      ..write(obj.battingFours)
      ..writeByte(10)
      ..write(obj.battingSixes)
      ..writeByte(11)
      ..write(obj.battingThirties)
      ..writeByte(12)
      ..write(obj.battingFifties)
      ..writeByte(13)
      ..write(obj.battingHundreds)
      ..writeByte(14)
      ..write(obj.battingDucks)
      ..writeByte(15)
      ..write(obj.battingGoldenDucks)
      ..writeByte(42)
      ..write(obj.battingBalls)
      ..writeByte(16)
      ..write(obj.bowlingMatches)
      ..writeByte(17)
      ..write(obj.bowlingInnings)
      ..writeByte(18)
      ..write(obj.bowlingOvers)
      ..writeByte(19)
      ..write(obj.bowlingWickets)
      ..writeByte(20)
      ..write(obj.bowlingMaidens)
      ..writeByte(21)
      ..write(obj.bowlingRunsConceded)
      ..writeByte(22)
      ..write(obj.bowlingBestWickets)
      ..writeByte(23)
      ..write(obj.bowlingBestRuns)
      ..writeByte(24)
      ..write(obj.bowlingEconomy)
      ..writeByte(25)
      ..write(obj.bowlingStrikeRate)
      ..writeByte(26)
      ..write(obj.bowlingAverage)
      ..writeByte(27)
      ..write(obj.bowlingWides)
      ..writeByte(28)
      ..write(obj.bowlingNoBalls)
      ..writeByte(29)
      ..write(obj.bowlingDotBalls)
      ..writeByte(30)
      ..write(obj.bowling3W)
      ..writeByte(31)
      ..write(obj.bowling5W)
      ..writeByte(32)
      ..write(obj.bowling7W)
      ..writeByte(33)
      ..write(obj.bowling10W)
      ..writeByte(34)
      ..write(obj.fieldingMatches)
      ..writeByte(35)
      ..write(obj.fieldingCatches)
      ..writeByte(36)
      ..write(obj.fieldingStumpings)
      ..writeByte(37)
      ..write(obj.fieldingRunOuts)
      ..writeByte(38)
      ..write(obj.captaincyMatches)
      ..writeByte(39)
      ..write(obj.captaincyWon)
      ..writeByte(40)
      ..write(obj.captaincyLost)
      ..writeByte(43)
      ..write(obj.singleStats)
      ..writeByte(44)
      ..write(obj.pairStats)
      ..writeByte(45)
      ..write(obj.teamStats)
      ..writeByte(46)
      ..write(obj.overallStats);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayerAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
