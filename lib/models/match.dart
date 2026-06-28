import 'package:hive/hive.dart';

part 'match.g.dart';

@HiveType(typeId: 1)
class MatchModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String team1Name;

  @HiveField(2)
  String team2Name;

  @HiveField(3)
  DateTime date;

  @HiveField(4)
  String result;

  @HiveField(5)
  bool isCompleted;

  @HiveField(6)
  int overs;

  @HiveField(7)
  int team1Score;

  @HiveField(8)
  int team1Wickets;

  @HiveField(9)
  double team1Overs;

  @HiveField(10)
  int team2Score;

  @HiveField(11)
  int team2Wickets;

  @HiveField(12)
  double team2Overs;

  @HiveField(13)
  Map<dynamic, dynamic> matchData; // Use Map for Hive to store dynamic data like ball-by-ball

  MatchModel({
    required this.id,
    required this.team1Name,
    required this.team2Name,
    required this.date,
    this.result = 'In Progress',
    this.isCompleted = false,
    required this.overs,
    this.team1Score = 0,
    this.team1Wickets = 0,
    this.team1Overs = 0.0,
    this.team2Score = 0,
    this.team2Wickets = 0,
    this.team2Overs = 0.0,
    this.matchData = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'team1Name': team1Name,
      'team2Name': team2Name,
      'date': date.toIso8601String(),
      'result': result,
      'isCompleted': isCompleted,
      'overs': overs,
      'team1Score': team1Score,
      'team1Wickets': team1Wickets,
      'team1Overs': team1Overs,
      'team2Score': team2Score,
      'team2Wickets': team2Wickets,
      'team2Overs': team2Overs,
      'matchData': matchData,
    };
  }

  factory MatchModel.fromJson(Map<String, dynamic> json) {
    return MatchModel(
      id: json['id'] ?? json['_id'] ?? '',
      team1Name: json['team1Name'] ?? '',
      team2Name: json['team2Name'] ?? '',
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      result: json['result'] ?? 'In Progress',
      isCompleted: json['isCompleted'] ?? false,
      overs: json['overs'] ?? 20,
      team1Score: json['team1Score'] ?? 0,
      team1Wickets: json['team1Wickets'] ?? 0,
      team1Overs: (json['team1Overs'] ?? 0).toDouble(),
      team2Score: json['team2Score'] ?? 0,
      team2Wickets: json['team2Wickets'] ?? 0,
      team2Overs: (json['team2Overs'] ?? 0).toDouble(),
      matchData: json['matchData'] ?? {},
    );
  }
}
