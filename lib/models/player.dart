import 'package:hive/hive.dart';

part 'player.g.dart';

@HiveType(typeId: 0)
class Player extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(41)
  String? imageBase64;

  // Batting
  @HiveField(2)
  int battingMatches;
  @HiveField(3)
  int battingInnings;
  @HiveField(4)
  int battingRuns;
  @HiveField(5)
  int battingNotOuts;
  @HiveField(6)
  int battingBestScore;
  @HiveField(7)
  double battingStrikeRate;
  @HiveField(8)
  double battingAverage;
  @HiveField(9)
  int battingFours;
  @HiveField(10)
  int battingSixes;
  @HiveField(11)
  int battingThirties;
  @HiveField(12)
  int battingFifties;
  @HiveField(13)
  int battingHundreds;
  @HiveField(14)
  int battingDucks;
  @HiveField(15)
  int battingGoldenDucks;
  @HiveField(42)
  int battingBalls;

  // Bowling
  @HiveField(16)
  int bowlingMatches;
  @HiveField(17)
  int bowlingInnings;
  @HiveField(18)
  double bowlingOvers;
  @HiveField(19)
  int bowlingWickets;
  @HiveField(20)
  int bowlingMaidens;
  @HiveField(21)
  int bowlingRunsConceded;
  @HiveField(22)
  int bowlingBestWickets;
  @HiveField(23)
  int bowlingBestRuns;
  @HiveField(24)
  double bowlingEconomy;
  @HiveField(25)
  double bowlingStrikeRate;
  @HiveField(26)
  double bowlingAverage;
  @HiveField(27)
  int bowlingWides;
  @HiveField(28)
  int bowlingNoBalls;
  @HiveField(29)
  int bowlingDotBalls;
  @HiveField(30)
  int bowling3W;
  @HiveField(31)
  int bowling5W;
  @HiveField(32)
  int bowling7W;
  @HiveField(33)
  int bowling10W;

  // Fielding
  @HiveField(34)
  int fieldingMatches;
  @HiveField(35)
  int fieldingCatches;
  @HiveField(36)
  int fieldingStumpings;
  @HiveField(37)
  int fieldingRunOuts;

  // Captaincy
  @HiveField(38)
  int captaincyMatches;
  @HiveField(39)
  int captaincyWon;
  @HiveField(40)
  int captaincyLost;

  @HiveField(43)
  Map<dynamic, dynamic>? singleStats;

  @HiveField(44)
  Map<dynamic, dynamic>? pairStats;

  @HiveField(45)
  Map<dynamic, dynamic>? teamStats;

  @HiveField(46)
  Map<dynamic, dynamic>? overallStats;

  Player({
    required this.id,
    required this.name,
    this.imageBase64,
    this.battingMatches = 0,
    this.battingInnings = 0,
    this.battingRuns = 0,
    this.battingNotOuts = 0,
    this.battingBestScore = 0,
    this.battingStrikeRate = 0.0,
    this.battingAverage = 0.0,
    this.battingFours = 0,
    this.battingSixes = 0,
    this.battingThirties = 0,
    this.battingFifties = 0,
    this.battingHundreds = 0,
    this.battingDucks = 0,
    this.battingGoldenDucks = 0,
    this.battingBalls = 0,
    this.bowlingMatches = 0,
    this.bowlingInnings = 0,
    this.bowlingOvers = 0.0,
    this.bowlingWickets = 0,
    this.bowlingMaidens = 0,
    this.bowlingRunsConceded = 0,
    this.bowlingBestWickets = 0,
    this.bowlingBestRuns = 0,
    this.bowlingEconomy = 0.0,
    this.bowlingStrikeRate = 0.0,
    this.bowlingAverage = 0.0,
    this.bowlingWides = 0,
    this.bowlingNoBalls = 0,
    this.bowlingDotBalls = 0,
    this.bowling3W = 0,
    this.bowling5W = 0,
    this.bowling7W = 0,
    this.bowling10W = 0,
    this.fieldingMatches = 0,
    this.fieldingCatches = 0,
    this.fieldingStumpings = 0,
    this.fieldingRunOuts = 0,
    this.captaincyMatches = 0,
    this.captaincyWon = 0,
    this.captaincyLost = 0,
    this.singleStats,
    this.pairStats,
    this.teamStats,
    this.overallStats,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imageBase64': imageBase64,
      'singleStats': singleStats,
      'pairStats': pairStats,
      'teamStats': teamStats,
      'overallStats': overallStats,
      'batting': {
        'matches': battingMatches,
        'innings': battingInnings,
        'runs': battingRuns,
        'balls': battingBalls,
        'notOuts': battingNotOuts,
        'bestScore': battingBestScore,
        'strikeRate': battingStrikeRate,
        'average': battingAverage,
        'fours': battingFours,
        'sixes': battingSixes,
        'thirties': battingThirties,
        'fifties': battingFifties,
        'hundreds': battingHundreds,
        'ducks': battingDucks,
        'goldenDucks': battingGoldenDucks,
      },
      'bowling': {
        'matches': bowlingMatches,
        'innings': bowlingInnings,
        'overs': bowlingOvers,
        'wickets': bowlingWickets,
        'maidens': bowlingMaidens,
        'runsConceded': bowlingRunsConceded,
        'bestBowlingWickets': bowlingBestWickets,
        'bestBowlingRuns': bowlingBestRuns,
        'economy': bowlingEconomy,
        'strikeRate': bowlingStrikeRate,
        'average': bowlingAverage,
        'wides': bowlingWides,
        'noBalls': bowlingNoBalls,
        'dotBalls': bowlingDotBalls,
        'threeWickets': bowling3W,
        'fiveWickets': bowling5W,
        'sevenWickets': bowling7W,
        'tenWickets': bowling10W,
      },
      'fielding': {
        'matches': fieldingMatches,
        'catches': fieldingCatches,
        'stumpings': fieldingStumpings,
        'runOuts': fieldingRunOuts,
      },
      'captaincy': {
        'matches': captaincyMatches,
        'won': captaincyWon,
        'lost': captaincyLost,
      }
    };
  }

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      imageBase64: json['imageBase64'],
      battingMatches: json['batting']?['matches'] ?? 0,
      battingInnings: json['batting']?['innings'] ?? 0,
      battingRuns: json['batting']?['runs'] ?? 0,
      battingNotOuts: json['batting']?['notOuts'] ?? 0,
      battingBestScore: json['batting']?['bestScore'] ?? 0,
      battingStrikeRate: (json['batting']?['strikeRate'] ?? 0).toDouble(),
      battingAverage: (json['batting']?['average'] ?? 0).toDouble(),
      battingFours: json['batting']?['fours'] ?? 0,
      battingSixes: json['batting']?['sixes'] ?? 0,
      battingThirties: json['batting']?['thirties'] ?? 0,
      battingFifties: json['batting']?['fifties'] ?? 0,
      battingHundreds: json['batting']?['hundreds'] ?? 0,
      battingDucks: json['batting']?['ducks'] ?? 0,
      battingGoldenDucks: json['batting']?['goldenDucks'] ?? 0,
      battingBalls: json['batting']?['balls'] ?? 0,
      
      bowlingMatches: json['bowling']?['matches'] ?? 0,
      bowlingInnings: json['bowling']?['innings'] ?? 0,
      bowlingOvers: (json['bowling']?['overs'] ?? 0).toDouble(),
      bowlingWickets: json['bowling']?['wickets'] ?? 0,
      bowlingMaidens: json['bowling']?['maidens'] ?? 0,
      bowlingRunsConceded: json['bowling']?['runsConceded'] ?? 0,
      bowlingBestWickets: json['bowling']?['bestBowlingWickets'] ?? 0,
      bowlingBestRuns: json['bowling']?['bestBowlingRuns'] ?? 0,
      bowlingEconomy: (json['bowling']?['economy'] ?? 0).toDouble(),
      bowlingStrikeRate: (json['bowling']?['strikeRate'] ?? 0).toDouble(),
      bowlingAverage: (json['bowling']?['average'] ?? 0).toDouble(),
      bowlingWides: json['bowling']?['wides'] ?? 0,
      bowlingNoBalls: json['bowling']?['noBalls'] ?? 0,
      bowlingDotBalls: json['bowling']?['dotBalls'] ?? 0,
      bowling3W: json['bowling']?['threeWickets'] ?? 0,
      bowling5W: json['bowling']?['fiveWickets'] ?? 0,
      bowling7W: json['bowling']?['sevenWickets'] ?? 0,
      bowling10W: json['bowling']?['tenWickets'] ?? 0,

      fieldingMatches: json['fielding']?['matches'] ?? 0,
      fieldingCatches: json['fielding']?['catches'] ?? 0,
      fieldingStumpings: json['fielding']?['stumpings'] ?? 0,
      fieldingRunOuts: json['fielding']?['runOuts'] ?? 0,

      captaincyMatches: json['captaincy']?['matches'] ?? 0,
      captaincyWon: json['captaincy']?['won'] ?? 0,
      captaincyLost: json['captaincy']?['lost'] ?? 0,

      singleStats: json['singleStats'] is Map ? Map<dynamic, dynamic>.from(json['singleStats']) : null,
      pairStats: json['pairStats'] is Map ? Map<dynamic, dynamic>.from(json['pairStats']) : null,
      teamStats: json['teamStats'] is Map ? Map<dynamic, dynamic>.from(json['teamStats']) : null,
      overallStats: json['overallStats'] is Map ? Map<dynamic, dynamic>.from(json['overallStats']) : null,
    );
  }

  dynamic getStat(String mode, String key, {dynamic defaultValue = 0}) {
    if (mode == 'Single') {
      return singleStats?[key] ?? defaultValue;
    } else if (mode == 'Pair') {
      return pairStats?[key] ?? defaultValue;
    } else if (mode == 'Overall') {
      recalculateOverallStats();
      return overallStats?[key] ?? defaultValue;
    } else {
      // Team mode and Fallback use the top-level fields
      switch (key) {
        case 'battingMatches': return battingMatches;
        case 'battingInnings': return battingInnings;
        case 'battingRuns': return battingRuns;
        case 'battingNotOuts': return battingNotOuts;
        case 'battingBestScore': return battingBestScore;
        case 'battingStrikeRate': return battingStrikeRate;
        case 'battingAverage': return battingAverage;
        case 'battingFours': return battingFours;
        case 'battingSixes': return battingSixes;
        case 'battingThirties': return battingThirties;
        case 'battingFifties': return battingFifties;
        case 'battingHundreds': return battingHundreds;
        case 'battingDucks': return battingDucks;
        case 'battingGoldenDucks': return battingGoldenDucks;
        case 'battingBalls': return battingBalls;
        case 'bowlingMatches': return bowlingMatches;
        case 'bowlingInnings': return bowlingInnings;
        case 'bowlingOvers': return bowlingOvers;
        case 'bowlingWickets': return bowlingWickets;
        case 'bowlingMaidens': return bowlingMaidens;
        case 'bowlingRunsConceded': return bowlingRunsConceded;
        case 'bowlingBestWickets': return bowlingBestWickets;
        case 'bowlingBestRuns': return bowlingBestRuns;
        case 'bowlingEconomy': return bowlingEconomy;
        case 'bowlingStrikeRate': return bowlingStrikeRate;
        case 'bowlingAverage': return bowlingAverage;
        case 'bowling3W': return bowling3W;
        case 'bowling5W': return bowling5W;
        case 'bowling7W': return bowling7W;
        case 'bowling10W': return bowling10W;
        case 'fieldingMatches': return fieldingMatches;
        case 'fieldingCatches': return fieldingCatches;
        case 'fieldingStumpings': return fieldingStumpings;
        case 'fieldingRunOuts': return fieldingRunOuts;
        case 'captaincyMatches': return captaincyMatches;
        case 'captaincyWon': return captaincyWon;
        case 'captaincyLost': return captaincyLost;
        default: return defaultValue;
      }
    }
  }

  void updateStatsForMode(String mode, Map<String, dynamic> updates) {
    if (mode == 'Single') {
      final newStats = Map<dynamic, dynamic>.from(singleStats ?? {});
      updates.forEach((key, value) {
        newStats[key] = value;
      });
      singleStats = newStats;
    } else if (mode == 'Pair') {
      final newStats = Map<dynamic, dynamic>.from(pairStats ?? {});
      updates.forEach((key, value) {
        newStats[key] = value;
      });
      pairStats = newStats;
    } else if (mode == 'Team') {
      final newStats = Map<dynamic, dynamic>.from(teamStats ?? {});
      updates.forEach((key, value) {
        newStats[key] = value;
      });
      teamStats = newStats;
    }

    // Always recalculate Overall stats based on Single, Pair, and Team stats combined.
    // Instead of directly updating the fields, we can update overallStats map
    // or just calculate it dynamically when requested, but since we are storing it:
    recalculateOverallStats();
  }

  void recalculateOverallStats() {
    overallStats = {};
    // Calculate simple sums for counts, and proper averages/rates later if needed.
    // However, given the complexity of the stats, we should sum them up.
    
    // We get keys from single, pair. We also add standard keys.
    Set<String> allKeys = {
      'battingMatches', 'battingInnings', 'battingRuns', 'battingBalls', 'battingFours', 'battingSixes',
      'battingBestScore', 'battingHundreds', 'battingFifties', 'battingThirties', 'battingDucks', 'battingGoldenDucks', 'battingNotOuts',
      'bowlingMatches', 'bowlingInnings', 'bowlingOvers', 'bowlingWickets', 'bowlingMaidens', 'bowlingRunsConceded',
      'bowlingBestWickets', 'bowlingBestRuns', 'bowling3W', 'bowling5W', 'bowling7W', 'bowling10W',
      'fieldingMatches', 'fieldingCatches', 'fieldingStumpings', 'fieldingRunOuts',
      'captaincyMatches', 'captaincyWon', 'captaincyLost'
    };
    if (singleStats != null) allKeys.addAll(singleStats!.keys.cast<String>());
    if (pairStats != null) allKeys.addAll(pairStats!.keys.cast<String>());
    if (teamStats != null) allKeys.addAll(teamStats!.keys.cast<String>());

    for (var key in allKeys) {
      if (key == 'status' || key == 'battingAverage' || key == 'battingStrikeRate' || key == 'bowlingAverage' || key == 'bowlingEconomy' || key == 'bowlingStrikeRate') continue; // skip non-numeric and derived averages
      
      num singleVal = singleStats?[key] ?? 0;
      num pairVal = pairStats?[key] ?? 0;
      num teamVal = getStat('Team', key, defaultValue: 0) as num;

      // Special handling for max values like 'bestScore', 'bestWickets'
      if (key == 'bestScore' || key == 'battingBestScore') {
        overallStats![key] = [singleVal, pairVal, teamVal].reduce((a, b) => a > b ? a : b);
      } else if (key == 'bestWickets' || key == 'bowlingBestWickets') {
         overallStats![key] = [singleVal, pairVal, teamVal].reduce((a, b) => a > b ? a : b);
      } else {
        // Sum the others
        overallStats![key] = singleVal + pairVal + teamVal;
      }
    }
    
    // Recalculate derived stats for overall
    if (overallStats!.containsKey('battingRuns')) {
      int runs = (overallStats!['battingRuns'] ?? 0) as int;
      int dismissals = ((overallStats!['battingInnings'] ?? 0) as int) - ((overallStats!['battingNotOuts'] ?? 0) as int);
      overallStats!['battingAverage'] = dismissals > 0 ? (runs / dismissals) : runs.toDouble();
      
      int balls = (overallStats!['battingBalls'] ?? 0) as int;
      overallStats!['battingStrikeRate'] = balls > 0 ? (runs / balls) * 100 : 0.0;
    }
    
    if (overallStats!.containsKey('bowlingRunsConceded')) {
      int runsConceded = (overallStats!['bowlingRunsConceded'] ?? 0) as int;
      int wickets = (overallStats!['bowlingWickets'] ?? 0) as int;
      double overs = (overallStats!['bowlingOvers'] ?? 0).toDouble();
      
      overallStats!['bowlingAverage'] = wickets > 0 ? (runsConceded / wickets) : 0.0;
      overallStats!['bowlingEconomy'] = overs > 0 ? (runsConceded / overs) : 0.0;
      
      int ballsBowled = (overs.toInt() * 6) + ((overs - overs.toInt()) * 10).round();
      overallStats!['bowlingStrikeRate'] = wickets > 0 ? (ballsBowled / wickets) : 0.0;
    }
  }
}
