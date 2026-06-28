import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../models/match.dart';
import '../models/player.dart';
import '../providers/cricket_provider.dart';
import '../rewarded_ad_helper.dart';
import 'scorecard_screen.dart';
import '../widgets/glass_container.dart';
import '../responsive_helper.dart';

class SingleModeScreen extends StatefulWidget {
  final MatchModel? match;
  const SingleModeScreen({super.key, this.match});

  @override
  State<SingleModeScreen> createState() => _SingleModeScreenState();
}

class _SingleModeScreenState extends State<SingleModeScreen> {
  String? _matchId;
  int _step = 0; // 0: Player Selection, 1: Order Assignment, 2: Settings, 3: Scoreboard, 4: Results

  // Wizard State
  List<Player> _selectedPlayers = [];
  List<String> _battingOrder = []; // Ordered player IDs
  List<String> _manualOrderTemp = []; // Tracks tap sequence for manual ordering
  String _orderMode = ''; // 'random' or 'manual'
  String _searchQuery = '';

  // Settings State
  int _overs = 2;
  int _wideRuns = 1;
  int _noBallRuns = 1;
  bool _reballWide = true;
  bool _reballNoBall = true;

  late TextEditingController _oversCtrl;
  late TextEditingController _noBallRunsCtrl;
  late TextEditingController _wideRunsCtrl;

  // Scoring State
  int _currentBatsmanIndex = 0;
  Map<String, Map<String, dynamic>> _playerStats = {}; // id -> { runs, balls, 4s, 6s, status }
  List<String> _currentOverBalls = [];
  String? _bowlerId; // Selected bowler

  bool _isWide = false;
  bool _isNoBall = false;
  bool _isByes = false;
  bool _isLegByes = false;
  bool _isWicket = false;

  List<Map<String, dynamic>> _undoHistory = [];
  List<Map<String, dynamic>> _balls = [];

  // Celebrations State
  String? _celebrationText;
  String? _celebrationSubtitle;
  bool _isDisplayingCelebration = false;
  Timer? _celebrationTimer;

  final List<String> _sixPhrases = const [
    "MASSIVE SIX!",
    "OUT OF THE PARK!",
    "MONSTER MAXIMUM!",
    "HUGE HIT!",
    "SHOT OF THE DAY!",
    "INTO THE CLOUDS!",
    "FLOWN INTO THE STANDS!",
    "CRACKING MAXIMUM!",
  ];

  final List<String> _fourPhrases = const [
    "CLASSY BOUNDARY!",
    "CRACKING FOUR!",
    "ELEGANT BOUNDARY!",
    "DELIGHTFUL SHOT!",
    "BEAUTIFUL FOUR!",
    "SMASHED FOR FOUR!",
  ];

  @override
  void initState() {
    super.initState();
    if (widget.match != null) {
      _matchId = widget.match!.id;
      final data = widget.match!.matchData;
      _step = data['step'] ?? 3;
      _overs = data['overs'] ?? 2;
      _wideRuns = data['wideRuns'] ?? 1;
      _noBallRuns = data['noBallRuns'] ?? 1;
      _reballWide = data['reballWide'] ?? true;
      _reballNoBall = data['reballNoBall'] ?? true;
      _currentBatsmanIndex = data['currentBatsmanIndex'] ?? 0;
      _battingOrder = List<String>.from(data['battingOrder'] ?? []);
      
      if (data['playerStats'] != null) {
        _playerStats = Map<String, Map<String, dynamic>>.from(
          (data['playerStats'] as Map).map(
            (k, v) => MapEntry(k as String, Map<String, dynamic>.from(v)),
          ),
        );
      }
      
      _currentOverBalls = List<String>.from(data['currentOverBalls'] ?? []);
      _bowlerId = data['bowlerId'];
      
      if (data['balls'] != null) {
        _balls = List<Map<String, dynamic>>.from(
          (data['balls'] as List).map((e) => Map<String, dynamic>.from(e))
        );
      }
      
      if (data['undoHistory'] != null) {
        _undoHistory = List<Map<String, dynamic>>.from(
          (data['undoHistory'] as List).map((e) => Map<String, dynamic>.from(e))
        );
      }
      
      if (data['selectedPlayers'] != null) {
        final allPlayers = Provider.of<CricketProvider>(context, listen: false).players;
        final selectedIds = List<String>.from(data['selectedPlayers']);
        _selectedPlayers = allPlayers.where((p) => selectedIds.contains(p.id)).toList();
      }
    }

    _oversCtrl = TextEditingController(text: '$_overs');
    _noBallRunsCtrl = TextEditingController(text: '$_noBallRuns');
    _wideRunsCtrl = TextEditingController(text: '$_wideRuns');
  }

  @override
  void dispose() {
    _oversCtrl.dispose();
    _noBallRunsCtrl.dispose();
    _wideRunsCtrl.dispose();
    _celebrationTimer?.cancel();
    super.dispose();
  }

  void _triggerCelebration(String main, String sub) {
    setState(() {
      _celebrationText = main;
      _celebrationSubtitle = sub;
      _isDisplayingCelebration = true;
    });
    _celebrationTimer?.cancel();
    _celebrationTimer = Timer(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() {
          _isDisplayingCelebration = false;
        });
      }
    });
  }

  String _getPlayerName(String? id) {
    if (id == null || id.isEmpty) return 'Unknown';
    final provider = Provider.of<CricketProvider>(context, listen: false);
    final p = provider.players.firstWhere(
      (x) => x.id == id,
      orElse: () => Player(id: '', name: 'Unknown'),
    );
    return p.name;
  }

  Map<String, Map<String, dynamic>> _calculateBowlerStats() {
    Map<String, Map<String, dynamic>> bowlerStats = {};
    for (var p in _selectedPlayers) {
      bowlerStats[p.id] = {
        'overs': 0.0,
        'balls': 0,
        'runs': 0,
        'wickets': 0,
        'economy': 0.0,
      };
    }

    for (var ball in _balls) {
      final bowlerId = ball['bowlerId'];
      if (bowlerId == null || bowlerId.isEmpty) continue;
      if (!bowlerStats.containsKey(bowlerId)) {
        bowlerStats[bowlerId] = {
          'overs': 0.0,
          'balls': 0,
          'runs': 0,
          'wickets': 0,
          'economy': 0.0,
        };
      }
      
      final stats = bowlerStats[bowlerId]!;
      final bool isW = ball['isWide'] ?? false;
      final bool isNb = ball['isNoBall'] ?? false;
      final bool isWicket = ball['isWicket'] ?? false;
      final int runsVal = ball['runs'] ?? 0;
      final int runsToAddVal = ball['runsToAdd'] ?? 0;
      final bool isB = ball['isByes'] ?? false;
      final bool isLb = ball['isLegByes'] ?? false;

      if (!isW && !isNb) {
        stats['balls'] = (stats['balls'] as int) + 1;
      }
      
      int conceded = 0;
      if (!isB && !isLb) {
        conceded = runsToAddVal;
      } else {
        if (isW) conceded = runsToAddVal;
        else if (isNb) conceded = _noBallRuns;
      }
      stats['runs'] = (stats['runs'] as int) + conceded;

      if (isWicket) {
        stats['wickets'] = (stats['wickets'] as int) + 1;
      }
    }

    bowlerStats.forEach((id, stats) {
      int b = stats['balls'] as int;
      int r = stats['runs'] as int;
      stats['overs'] = b ~/ 6 + (b % 6) / 10.0;
      double oversFraction = b / 6.0;
      stats['economy'] = oversFraction > 0 ? r / oversFraction : 0.0;
    });

    return bowlerStats;
  }

  String _getOrdinal(int num) {
    if (num >= 11 && num <= 13) return '${num}th';
    switch (num % 10) {
      case 1: return '${num}st';
      case 2: return '${num}nd';
      case 3: return '${num}rd';
      default: return '${num}th';
    }
  }

  // Save historical snapshot for Undo
  void _saveUndoState() {
    final statsCopy = _playerStats.map((k, v) => MapEntry(k, Map<String, dynamic>.from(v)));
    _undoHistory.add({
      'currentBatsmanIndex': _currentBatsmanIndex,
      'playerStats': statsCopy,
      'currentOverBalls': List<String>.from(_currentOverBalls),
      'isWide': _isWide,
      'isNoBall': _isNoBall,
      'isByes': _isByes,
      'isLegByes': _isLegByes,
      'isWicket': _isWicket,
      'bowlerId': _bowlerId,
      'balls': List<Map<String, dynamic>>.from(_balls),
    });
  }

  void _undoLastBall() {
    if (_undoHistory.isEmpty) return;
    final last = _undoHistory.removeLast();
    setState(() {
      _currentBatsmanIndex = last['currentBatsmanIndex'];
      _playerStats = Map<String, Map<String, dynamic>>.from(last['playerStats']);
      _currentOverBalls = List<String>.from(last['currentOverBalls']);
      _isWide = last['isWide'];
      _isNoBall = last['isNoBall'];
      _isByes = last['isByes'];
      _isLegByes = last['isLegByes'];
      _isWicket = last['isWicket'];
      _bowlerId = last['bowlerId'];
      _balls = List<Map<String, dynamic>>.from(last['balls'] ?? []);
    });
  }

  Future<void> _executeScore(int runs) async {
    if (_battingOrder.isEmpty) return;
    
    _saveUndoState();

    String currentBatsmanId = _battingOrder[_currentBatsmanIndex];
    var stats = _playerStats[currentBatsmanId]!;

    int runsToAdd = runs;
    if (_isWide) runsToAdd += _wideRuns;
    if (_isNoBall) runsToAdd += _noBallRuns;

    // Striker Stats Updates
    final bool countsAsBallFaced = (!_isWide) || (_isWide && !_reballWide);
    if (countsAsBallFaced) {
      stats['balls'] = (stats['balls'] ?? 0) + 1;
      if (!_isByes && !_isLegByes) {
        stats['runs'] = (stats['runs'] ?? 0) + runs;
        if (runs == 4) stats['4s'] = (stats['4s'] ?? 0) + 1;
        if (runs == 6) stats['6s'] = (stats['6s'] ?? 0) + 1;
      }
    } else {
      // Wides add to batsman runs in this custom solo practice format
      stats['runs'] = (stats['runs'] ?? 0) + runsToAdd;
    }

    if (_isNoBall) {
      if (!_isWide && !_isByes && !_isLegByes) {
        // Runs from bat already added
      }
      if (!_isWide) {
        stats['runs'] = (stats['runs'] ?? 0) + _noBallRuns;
      }
    }

    // Trigger Boundary Animations
    if (runs == 4 && !_isWide && !_isByes && !_isLegByes) {
      final phrase = _fourPhrases[math.Random().nextInt(_fourPhrases.length)];
      _triggerCelebration(phrase, "by ${_getPlayerName(currentBatsmanId)}");
    } else if (runs == 6 && !_isWide && !_isByes && !_isLegByes) {
      final phrase = _sixPhrases[math.Random().nextInt(_sixPhrases.length)];
      _triggerCelebration(phrase, "by ${_getPlayerName(currentBatsmanId)}");
    }

    // Wicket checking
    if (_isWicket) {
      Map<String, dynamic>? wicketDetails = await _showWicketDetailsFullScreen(context, currentBatsmanId);
      if (wicketDetails == null) {
        _undoLastBall();
        return;
      }
      String wicketType = wicketDetails['wicketType'];
      String? fielderId = wicketDetails['fielderId'];

      final bStats = _playerStats[currentBatsmanId]!;
      final batsmanBalls = bStats['balls'] ?? 0;
      final bOversStr = "${batsmanBalls ~/ 6}.${batsmanBalls % 6}";
      String bowlerName = _bowlerId != null ? _getPlayerName(_bowlerId) : 'Bowler';
      String strikerName = _getPlayerName(currentBatsmanId);
      String fielderName = fielderId != null ? _getPlayerName(fielderId) : '';
      
      String statusString = 'out';
      if (wicketType == 'Bowled') {
        statusString = 'b $bowlerName';
      } else if (wicketType == 'Caught') {
        statusString = 'c $fielderName b $bowlerName';
      } else if (wicketType == 'LBW') {
        statusString = 'lbw b $bowlerName';
      } else if (wicketType == 'Run Out') {
        statusString = 'run out ($fielderName)';
      } else if (wicketType == 'Stumped') {
        statusString = 'st $fielderName b $bowlerName';
      } else if (wicketType == 'Hit Wicket') {
        statusString = 'hit wicket b $bowlerName';
      }

      stats['status'] = statusString;
      _currentOverBalls.add('W');

      String description = 'OUT! $strikerName is out $wicketType';
      if (fielderName.isNotEmpty) description += ' by $fielderName';
      description += ' off the bowling of $bowlerName.';
      
      _balls.add({
        'over': bOversStr,
        'strikerId': currentBatsmanId,
        'bowlerId': _bowlerId,
        'runs': runs,
        'runsToAdd': runsToAdd,
        'isWide': _isWide,
        'isNoBall': _isNoBall,
        'isByes': _isByes,
        'isLegByes': _isLegByes,
        'isWicket': _isWicket,
        'wicketType': wicketType,
        'fielderId': fielderId,
        'description': description,
      });

      _resetChecks();
      _finishBatsmanInnings(currentBatsmanId, out: true);
      return;
    }

    // Timeline labels
    String ballLabel = runs.toString();
    if (_isWide) ballLabel = '${runs}wd';
    else if (_isNoBall) ballLabel = '${runs}nb';
    else if (_isByes) ballLabel = '${runs}b';
    else if (_isLegByes) ballLabel = '${runs}lb';
    _currentOverBalls.add(ballLabel);

    // Append ball record
    final bStats = _playerStats[currentBatsmanId]!;
    final batsmanBalls = bStats['balls'] ?? 0;
    final bOversStr = "${batsmanBalls ~/ 6}.${batsmanBalls % 6}";
    String bowlerName = _bowlerId != null ? _getPlayerName(_bowlerId) : 'Bowler';
    String strikerName = _getPlayerName(currentBatsmanId);

    String description = '';
    String extrasText = '';
    if (_isWide) extrasText = ' (Wide)';
    else if (_isNoBall) extrasText = ' (No Ball)';
    else if (_isByes) extrasText = ' (Byes)';
    else if (_isLegByes) extrasText = ' (Leg Byes)';

    if (runs == 0) {
      description = '$bowlerName to $strikerName, no run$extrasText.';
    } else if (runs == 4) {
      description = 'FOUR! $bowlerName to $strikerName, driven away for a boundary$extrasText!';
    } else if (runs == 6) {
      description = 'SIX! $bowlerName to $strikerName, launched over the ropes for a maximum$extrasText!';
    } else {
      description = '$bowlerName to $strikerName, $runs run${runs > 1 ? 's' : ''}$extrasText.';
    }

    _balls.add({
      'over': bOversStr,
      'strikerId': currentBatsmanId,
      'bowlerId': _bowlerId,
      'runs': runs,
      'runsToAdd': runsToAdd,
      'isWide': _isWide,
      'isNoBall': _isNoBall,
      'isByes': _isByes,
      'isLegByes': _isLegByes,
      'isWicket': _isWicket,
      'wicketType': null,
      'fielderId': null,
      'description': description,
    });

    _resetChecks();

    // Check target completion for last batsman
    final isLastBatsman = _currentBatsmanIndex > 0 && _currentBatsmanIndex == _battingOrder.length - 1;
    if (isLastBatsman) {
      int highestScore = 0;
      for (int i = 0; i < _currentBatsmanIndex; i++) {
        final pid = _battingOrder[i];
        final prevRuns = _playerStats[pid]?['runs'] ?? 0;
        if (prevRuns > highestScore) {
          highestScore = prevRuns;
        }
      }
      final target = highestScore + 1;
      if ((stats['runs'] ?? 0) >= target) {
        stats['status'] = 'Target Completed';
        _finishBatsmanInnings(currentBatsmanId, out: false);
        return;
      }
    }

    // Check legal balls count
    int legalBalls = _currentOverBalls.where((b) {
      final isWd = b.contains('wd');
      final isNb = b.contains('nb');
      if (isWd && _reballWide) return false;
      if (isNb && _reballNoBall) return false;
      return true;
    }).length;
    int totalLegalBalls = stats['balls'] ?? 0;

    if (totalLegalBalls >= _overs * 6) {
      stats['status'] = 'Overs Completed';
      _finishBatsmanInnings(currentBatsmanId, out: false);
    } else {
      if (legalBalls >= 6) {
        _currentOverBalls.clear();
        
        final currentBatsmanId = _battingOrder[_currentBatsmanIndex];
        final nonBatting = _selectedPlayers.where((p) => p.id != currentBatsmanId && p.id != _bowlerId).toList();
        final finalNonBatting = nonBatting.isNotEmpty
            ? nonBatting
            : _selectedPlayers.where((p) => p.id != currentBatsmanId).toList();

        if (finalNonBatting.isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => SimpleDialog(
                  backgroundColor: const Color(0xFF1E293B),
                  title: const Text('Over Completed! Select Next Bowler', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  children: finalNonBatting.map((player) {
                    return SimpleDialogOption(
                      onPressed: () {
                        setState(() {
                          _bowlerId = player.id;
                        });
                        Navigator.pop(ctx);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(player.name, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                      ),
                    );
                  }).toList(),
                ),
              );
            }
          });
        }
      }
      setState(() {});
    }
  }

  void _resetChecks() {
    setState(() {
      _isWide = false;
      _isNoBall = false;
      _isByes = false;
      _isLegByes = false;
      _isWicket = false;
    });
  }

  void _finishBatsmanInnings(String batsmanId, {required bool out}) {
    final name = _getPlayerName(batsmanId);
    final runs = _playerStats[batsmanId]?['runs'] ?? 0;
    final balls = _playerStats[batsmanId]?['balls'] ?? 0;

    if (_currentBatsmanIndex + 1 < _battingOrder.length) {
      String nextName = _getPlayerName(_battingOrder[_currentBatsmanIndex + 1]);
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog.fullscreen(
          backgroundColor: const Color(0xFF0F172A),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.sports_cricket,
                    color: Colors.cyanAccent,
                    size: 80,
                  ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
                  const SizedBox(height: 24),
                  Text(
                    out ? "$name is OUT!" : "Innings Completed!",
                    style: TextStyle(
                      color: out ? Colors.redAccent : Colors.greenAccent,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "$name scored $runs runs off $balls balls",
                    style: const TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                  const SizedBox(height: 48),
                  const Text(
                    "NEXT BATSMAN:",
                    style: TextStyle(color: Colors.white38, fontSize: 14, letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    nextName,
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 48),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _currentBatsmanIndex++;
                        _currentOverBalls.clear();
                        _playerStats[_battingOrder[_currentBatsmanIndex]]!['status'] = 'Batting';
                      });

                      final nextBatsmanId = _battingOrder[_currentBatsmanIndex];
                      final nonBatting = _selectedPlayers.where((p) => p.id != nextBatsmanId).toList();
                      if (nonBatting.isNotEmpty) {
                        Future.delayed(const Duration(milliseconds: 100), () {
                          if (mounted) {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (ctx2) => SimpleDialog(
                                backgroundColor: const Color(0xFF1E293B),
                                title: const Text('Select Bowler for New Batsman', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                children: nonBatting.map((player) {
                                  return SimpleDialogOption(
                                    onPressed: () {
                                      setState(() {
                                        _bowlerId = player.id;
                                      });
                                      Navigator.pop(ctx2);
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                                      child: Text(player.name, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                                    ),
                                  );
                                }).toList(),
                              ),
                            );
                          }
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      minimumSize: const Size(220, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: const Text(
                      "START INNINGS",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog.fullscreen(
          backgroundColor: const Color(0xFF0F172A),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.emoji_events,
                    color: Colors.amber,
                    size: 90,
                  ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
                  const SizedBox(height: 24),
                  const Text(
                    "MATCH COMPLETE!",
                    style: TextStyle(
                      color: Colors.tealAccent,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "$name scored $runs runs off $balls balls as the final batsman.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 48),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _step = 4; // Move to results step
                      });
                      RewardedAdHelper.showAd();
                      _saveMatchToDatabase(pop: false);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      minimumSize: const Size(220, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: const Text(
                      "VIEW SCORECARD",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }

  void _showLiveScorecardDialog() {
    String selectedTab = 'scorecard'; // 'scorecard' or 'commentary'
    int selectedBatsmanIdx = _currentBatsmanIndex;

    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: const Color(0xFF0F172A),
        child: StatefulBuilder(
          builder: (context, setStateDialog) {
            final isScorecard = selectedTab == 'scorecard';
            
            final selectedBatsmanId = _battingOrder[selectedBatsmanIdx];
            final inningsBalls = _balls.where((ball) => ball['strikerId'] == selectedBatsmanId).toList();

            Map<String, Map<String, dynamic>> calculateInningsBowlers() {
              Map<String, Map<String, dynamic>> bowlerStats = {};
              for (var p in _selectedPlayers) {
                bowlerStats[p.id] = {
                  'overs': 0.0,
                  'balls': 0,
                  'runs': 0,
                  'wickets': 0,
                  'economy': 0.0,
                };
              }

              for (var ball in inningsBalls) {
                final bowlerId = ball['bowlerId'];
                if (bowlerId == null || bowlerId.isEmpty) continue;
                if (!bowlerStats.containsKey(bowlerId)) {
                  bowlerStats[bowlerId] = {
                    'overs': 0.0,
                    'balls': 0,
                    'runs': 0,
                    'wickets': 0,
                    'economy': 0.0,
                  };
                }
                
                final stats = bowlerStats[bowlerId]!;
                final bool isW = ball['isWide'] ?? false;
                final bool isNb = ball['isNoBall'] ?? false;
                final bool isWicket = ball['isWicket'] ?? false;
                final int runsVal = ball['runs'] ?? 0;
                final int runsToAddVal = ball['runsToAdd'] ?? 0;
                final bool isB = ball['isByes'] ?? false;
                final bool isLb = ball['isLegByes'] ?? false;

                if (!isW && !isNb) {
                  stats['balls'] = (stats['balls'] as int) + 1;
                }
                
                int conceded = 0;
                if (!isB && !isLb) {
                  conceded = runsToAddVal;
                } else {
                  if (isW) conceded = runsToAddVal;
                  else if (isNb) conceded = _noBallRuns;
                }
                stats['runs'] = (stats['runs'] as int) + conceded;

                if (isWicket) {
                  stats['wickets'] = (stats['wickets'] as int) + 1;
                }
              }

              bowlerStats.forEach((id, stats) {
                int b = stats['balls'] as int;
                int r = stats['runs'] as int;
                stats['overs'] = b ~/ 6 + (b % 6) / 10.0;
                double oversFraction = b / 6.0;
                stats['economy'] = oversFraction > 0 ? r / oversFraction : 0.0;
              });

              return bowlerStats;
            }

            final bowlerStats = calculateInningsBowlers();

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'LIVE INFO',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 1.5),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70, size: 28),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white24, height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'SELECT INNINGS:',
                          style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            final provider = Provider.of<CricketProvider>(context, listen: false);
                            final available = provider.players.where((p) => !_selectedPlayers.any((sp) => sp.id == p.id)).toList();

                            showDialog(
                              context: context,
                              builder: (subCtx) => AlertDialog(
                                backgroundColor: const Color(0xFF1E293B),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                title: const Text('Add Player to Match', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                content: Container(
                                  width: double.maxFinite,
                                  child: available.isEmpty
                                      ? const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 20.0),
                                          child: Text('All roster players are already in the match.', style: TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                                        )
                                      : ListView.builder(
                                          shrinkWrap: true,
                                          itemCount: available.length,
                                          itemBuilder: (ctx2, idx) {
                                            final player = available[idx];
                                            return ListTile(
                                              leading: _buildPlayerAvatar(player, radius: 18),
                                              title: Text(player.name, style: const TextStyle(color: Colors.white)),
                                              onTap: () {
                                                _addPlayerToMatch(player);
                                                setStateDialog(() {});
                                                Navigator.pop(subCtx);
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('${player.name} added to the match.')),
                                                );
                                              },
                                            );
                                          },
                                        ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(subCtx);
                                      _showCreateNewPlayerDialog(context, (newPlayer) {
                                        _addPlayerToMatch(newPlayer);
                                        setStateDialog(() {});
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('${newPlayer.name} created and added to the match.')),
                                        );
                                      });
                                    },
                                    child: const Text('Create New', style: TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold)),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(subCtx),
                                    child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                                  )
                                ],
                              ),
                            );
                          },
                          icon: const Icon(Icons.person_add, color: Color(0xFFD4AF37), size: 16),
                          label: const Text('ADD PLAYER', style: TextStyle(color: Color(0xFFD4AF37), fontSize: 11, fontWeight: FontWeight.bold)),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(_battingOrder.length, (index) {
                          final playerId = _battingOrder[index];
                          final name = _getPlayerName(playerId);
                          final isSelected = selectedBatsmanIdx == index;
                          final labelText = '${_getOrdinal(index + 1)} ($name)';
                          
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(labelText),
                              selected: isSelected,
                              onSelected: (val) {
                                if (val) {
                                  setStateDialog(() {
                                    selectedBatsmanIdx = index;
                                  });
                                }
                              },
                              selectedColor: const Color(0xFFD4AF37),
                              backgroundColor: const Color(0xFF1E293B),
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.black : Colors.white70,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Scorecard'),
                          selected: isScorecard,
                          onSelected: (val) {
                            if (val) setStateDialog(() => selectedTab = 'scorecard');
                          },
                          selectedColor: Theme.of(context).primaryColor,
                          backgroundColor: const Color(0xFF1E293B),
                          labelStyle: TextStyle(
                            color: isScorecard ? Colors.black : Colors.white70,
                            fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ChoiceChip(
                        label: const Text('Commentary'),
                        selected: !isScorecard,
                        onSelected: (val) {
                          if (val) setStateDialog(() => selectedTab = 'commentary');
                        },
                        selectedColor: Theme.of(context).primaryColor,
                        backgroundColor: const Color(0xFF1E293B),
                        labelStyle: TextStyle(
                          color: !isScorecard ? Colors.black : Colors.white70,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: isScorecard
                        ? ListView(
                            children: [
                              const Text(
                                'Batting',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
                              ),
                              const SizedBox(height: 8),
                              _buildTableHeader(['Batsman', 'R', 'B', '4s', '6s', 'SR']),
                              const Divider(color: Colors.white24),
                              Builder(
                                builder: (context) {
                                  final stats = _playerStats[selectedBatsmanId] ?? {};
                                  final name = _getPlayerName(selectedBatsmanId);
                                  final isCurrent = selectedBatsmanId == _battingOrder[_currentBatsmanIndex];

                                  final r = stats['runs'] ?? 0;
                                  final b = stats['balls'] ?? 0;
                                  final fours = stats['4s'] ?? 0;
                                  final sixes = stats['6s'] ?? 0;
                                  final sr = b > 0 ? ((r / b) * 100).toStringAsFixed(1) : '0.0';
                                  final status = stats['status'] ?? 'Yet to bat';

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildTableRow(
                                          name + (isCurrent ? '*' : ''),
                                          '$r',
                                          '$b',
                                          '$fours',
                                          '$sixes',
                                          sr,
                                          isHighlight: isCurrent,
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(left: 8.0, top: 2.0),
                                          child: Text(
                                            status,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: isCurrent
                                                  ? const Color(0xFFD4AF37)
                                                  : (status == 'Out' ? Colors.redAccent : Colors.white38),
                                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'Bowling',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
                              ),
                              const SizedBox(height: 8),
                              _buildTableHeader(['Bowler', 'O', 'M', 'R', 'W', 'ER']),
                              const Divider(color: Colors.white24),
                              ..._selectedPlayers.map((player) {
                                final stats = bowlerStats[player.id] ?? {};
                                final double overs = stats['overs'] ?? 0.0;
                                final int runs = stats['runs'] ?? 0;
                                final int wickets = stats['wickets'] ?? 0;
                                final double economy = stats['economy'] ?? 0.0;
                                if ((stats['balls'] ?? 0) == 0) return const SizedBox.shrink();

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: _buildTableRow(
                                    player.name,
                                    overs.toStringAsFixed(1),
                                    '0',
                                    '$runs',
                                    '$wickets',
                                    economy.toStringAsFixed(2),
                                    isHighlight: player.id == _bowlerId,
                                  ),
                                );
                              }).toList(),
                            ],
                          )
                        : inningsBalls.isEmpty
                            ? const Center(
                                child: Text('No commentary available yet for this innings.', style: TextStyle(color: Colors.white38)),
                              )
                            : ListView(
                                children: inningsBalls.reversed.map((ball) {
                                  final over = ball['over'] ?? '0.0';
                                  final runs = ball['runs'] ?? 0;
                                  final isWide = ball['isWide'] ?? false;
                                  final isNoBall = ball['isNoBall'] ?? false;
                                  final isWicket = ball['isWicket'] ?? false;
                                  final description = ball['description'] ?? '';

                                  String badgeText = '$runs';
                                  Color badgeColor = Theme.of(context).primaryColor.withOpacity(0.15);
                                  Color textColor = Theme.of(context).primaryColor;

                                  if (isWicket) {
                                    badgeText = 'W';
                                    badgeColor = Colors.redAccent.withOpacity(0.2);
                                    textColor = Colors.redAccent;
                                  } else if (isWide) {
                                    badgeText = '${runs}wd';
                                    badgeColor = Colors.orangeAccent.withOpacity(0.2);
                                    textColor = Colors.orangeAccent;
                                  } else if (isNoBall) {
                                    badgeText = '${runs}nb';
                                    badgeColor = Colors.orangeAccent.withOpacity(0.2);
                                    textColor = Colors.orangeAccent;
                                  } else if (runs == 4) {
                                    badgeColor = Colors.green.withOpacity(0.2);
                                    textColor = Colors.green;
                                  } else if (runs == 6) {
                                    badgeColor = const Color(0xFFD4AF37).withOpacity(0.2);
                                    textColor = const Color(0xFFD4AF37);
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 44,
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.05),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            over,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor: badgeColor,
                                          child: Text(
                                            badgeText,
                                            style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            description,
                                            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

  Future<Map<String, dynamic>?> _showWicketDetailsFullScreen(BuildContext context, String batsmanOutId) async {
    String wicketType = 'Bowled';
    Player? fielder;
    List<Player> fielders = _selectedPlayers.where((p) => p.id != batsmanOutId).toList();

    return await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => Dialog.fullscreen(
          backgroundColor: Colors.black87,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: const Text('Wicket Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => Navigator.pop(ctx, null),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (['Caught', 'Run Out', 'Stumped'].contains(wicketType) && fielder == null) return;
                    Navigator.pop(ctx, {
                      'wicketType': wicketType,
                      'fielderId': fielder?.id,
                    });
                  },
                  child: const Text('DONE', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    dropdownColor: Theme.of(context).colorScheme.surface,
                    value: wicketType,
                    decoration: const InputDecoration(labelText: 'Wicket Type', labelStyle: TextStyle(color: Colors.white54)),
                    items: ['Bowled', 'Caught', 'LBW', 'Run Out', 'Stumped', 'Hit Wicket', 'Other']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white))))
                        .toList(),
                    onChanged: (val) {
                      setStateDialog(() {
                        wicketType = val!;
                        fielder = null;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Batsman Out: ${_getPlayerName(batsmanOutId)}', style: const TextStyle(color: Colors.white70, fontSize: 18)),
                  ),
                  const SizedBox(height: 20),
                  if (['Caught', 'Run Out', 'Stumped'].contains(wicketType)) ...[
                    DropdownButtonFormField<Player>(
                      dropdownColor: Theme.of(context).colorScheme.surface,
                      value: fielder,
                      decoration: InputDecoration(
                        labelText: wicketType == 'Caught' ? 'Caught By' : (wicketType == 'Stumped' ? 'Stumped By' : 'Fielder'),
                        labelStyle: const TextStyle(color: Colors.white54),
                      ),
                      items: fielders
                          .map((e) => DropdownMenuItem(value: e, child: Text(e.name, style: const TextStyle(color: Colors.white))))
                          .toList(),
                      onChanged: (val) => setStateDialog(() => fielder = val),
                    ),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showCustomRunsDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Enter Custom Runs',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Runs count',
            hintStyle: const TextStyle(color: Colors.white38),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Theme.of(context).primaryColor),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              final val = int.tryParse(controller.text);
              if (val != null && val >= 0) {
                Navigator.pop(context);
                _executeScore(val);
              }
            },
            child: Text(
              'Done',
              style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showBowlerSelectDialog() {
    final nonBatting = _selectedPlayers.where((p) => p.id != _battingOrder[_currentBatsmanIndex]).toList();
    if (nonBatting.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other players available to bowl.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Select Bowler', style: TextStyle(color: Colors.white)),
        children: nonBatting.map((player) {
          return SimpleDialogOption(
            onPressed: () {
              setState(() {
                _bowlerId = player.id;
              });
              Navigator.pop(context);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(player.name, style: const TextStyle(color: Colors.white70, fontSize: 16)),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _updateCumulativePlayerStats() {
    final provider = Provider.of<CricketProvider>(context, listen: false);
    List<Player> updatedPlayers = [];
    
    // 1. Calculate Bowling and Fielding stats from the timeline (_balls)
    Map<String, Map<String, dynamic>> bowlerStats = {};
    Map<String, Map<String, int>> fielderStats = {};
    
    for (var p in _selectedPlayers) {
      bowlerStats[p.id] = {
        'balls': 0, 'runs': 0, 'wickets': 0, 'maidens': 0,
      };
      fielderStats[p.id] = {
        'catches': 0, 'stumpings': 0, 'runOuts': 0,
      };
    }
    
    for (var ball in _balls) {
      String? bowlerId = ball['bowlerId'];
      bool isWicket = ball['isWicket'] ?? false;
      String? wicketType = ball['wicketType'];
      String? fielderId = ball['fielderId'];
      int runs = (ball['runs'] ?? 0) as int;
      bool isWide = ball['isWide'] ?? false;
      bool isNoBall = ball['isNoBall'] ?? false;
      bool isByes = ball['isByes'] ?? false;
      bool isLegByes = ball['isLegByes'] ?? false;
      int runsToAdd = (ball['runsToAdd'] ?? 0) as int;
      
      // Bowling Stats
      if (bowlerId != null) {
        if (!bowlerStats.containsKey(bowlerId)) {
          bowlerStats[bowlerId] = {'balls': 0, 'runs': 0, 'wickets': 0, 'maidens': 0};
        }
        final bStats = bowlerStats[bowlerId]!;
        if (!isWide && !isNoBall) bStats['balls'] = (bStats['balls'] as int) + 1;
        if (!isByes && !isLegByes) bStats['runs'] = (bStats['runs'] as int) + runsToAdd;
        if (isWicket && wicketType != 'Run Out') bStats['wickets'] = (bStats['wickets'] as int) + 1;
      }
      
      // Fielding Stats
      if (isWicket && fielderId != null) {
        if (!fielderStats.containsKey(fielderId)) {
          fielderStats[fielderId] = {'catches': 0, 'stumpings': 0, 'runOuts': 0};
        }
        if (wicketType == 'Caught') {
          fielderStats[fielderId]!['catches'] = (fielderStats[fielderId]!['catches'] ?? 0) + 1;
        } else if (wicketType == 'Stumped') {
          fielderStats[fielderId]!['stumpings'] = (fielderStats[fielderId]!['stumpings'] ?? 0) + 1;
        } else if (wicketType == 'Run Out') {
          fielderStats[fielderId]!['runOuts'] = (fielderStats[fielderId]!['runOuts'] ?? 0) + 1;
        }
      }
    }

    // 2. Iterate players and update their cumulative stats
    for (var player in _selectedPlayers) {
      final playerIndex = provider.players.indexWhere((p) => p.id == player.id);
      if (playerIndex == -1) continue;

      Player p = provider.players[playerIndex];
      
      int bMatches = p.getStat('Single', 'battingMatches') + 1;
      int bInnings = p.getStat('Single', 'battingInnings');
      int bRuns = p.getStat('Single', 'battingRuns');
      int bBalls = p.getStat('Single', 'battingBalls');
      int bFours = p.getStat('Single', 'battingFours');
      int bSixes = p.getStat('Single', 'battingSixes');
      int bBestScore = p.getStat('Single', 'battingBestScore');
      int bHundreds = p.getStat('Single', 'battingHundreds');
      int bFifties = p.getStat('Single', 'battingFifties');
      int bThirties = p.getStat('Single', 'battingThirties');
      int bDucks = p.getStat('Single', 'battingDucks');
      int bGoldenDucks = p.getStat('Single', 'battingGoldenDucks');
      int bNotOuts = p.getStat('Single', 'battingNotOuts');

      final stats = _playerStats[p.id];
      if (stats != null) {
        int runs = (stats['runs'] ?? 0) as int;
        int balls = (stats['balls'] ?? 0) as int;
        String status = (stats['status'] ?? '').toString();
        
        bInnings++;
        bRuns += runs;
        bBalls += balls;
        bFours += (stats['4s'] ?? 0) as int;
        bSixes += (stats['6s'] ?? 0) as int;
        
        if (runs > bBestScore) {
          bBestScore = runs;
        }
        if (runs >= 100) {
          bHundreds++;
        } else if (runs >= 50) {
          bFifties++;
        } else if (runs >= 30) {
          bThirties++;
        }
        if (runs == 0 && balls > 0) {
          bDucks++;
          if (balls == 1) {
            bGoldenDucks++;
          }
        }
        if (status != 'Out') {
          bNotOuts++;
        }
      }

      double bAverage = 0.0;
      int dismissals = bInnings - bNotOuts;
      if (dismissals > 0) {
        bAverage = bRuns / dismissals;
      } else {
        bAverage = bRuns.toDouble();
      }
      
      double bStrikeRate = 0.0;
      if (bBalls > 0) {
        bStrikeRate = (bRuns / bBalls) * 100;
      }

      // Parse derived bowling and fielding for this match
      final bStat = bowlerStats[p.id] ?? {'balls': 0, 'runs': 0, 'wickets': 0, 'maidens': 0};
      final fStat = fielderStats[p.id] ?? {'catches': 0, 'stumpings': 0, 'runOuts': 0};
      
      int matchBowls = bStat['balls'] as int;
      int matchRunsConc = bStat['runs'] as int;
      int matchWickets = bStat['wickets'] as int;
      int matchMaidens = bStat['maidens'] as int;
      double matchOvers = matchBowls ~/ 6 + (matchBowls % 6) / 10.0;
      
      // Update Bowling Cumulative
      int bwMatches = p.getStat('Single', 'bowlingMatches') + 1;
      int bwInnings = p.getStat('Single', 'bowlingInnings') + (matchBowls > 0 ? 1 : 0);
      int bwRunsConc = p.getStat('Single', 'bowlingRunsConceded') + matchRunsConc;
      int bwWickets = p.getStat('Single', 'bowlingWickets') + matchWickets;
      int bwMaidens = p.getStat('Single', 'bowlingMaidens') + matchMaidens;
      
      double currentOvers = p.getStat('Single', 'bowlingOvers').toDouble();
      int totalBalls = (currentOvers.toInt() * 6) + ((currentOvers - currentOvers.toInt()) * 10).round() + matchBowls;
      double bwOvers = totalBalls ~/ 6 + (totalBalls % 6) / 10.0;
      
      int bwBestWickets = p.getStat('Single', 'bowlingBestWickets');
      int bwBestRuns = p.getStat('Single', 'bowlingBestRuns');
      if (matchWickets > bwBestWickets || (matchWickets == bwBestWickets && matchRunsConc < bwBestRuns)) {
        bwBestWickets = matchWickets;
        bwBestRuns = matchRunsConc;
      }
      
      double bwEconomy = bwOvers > 0 ? bwRunsConc / bwOvers : 0.0;
      double bwAverage = bwWickets > 0 ? bwRunsConc / bwWickets : 0.0;
      double bwStrikeRate = bwWickets > 0 ? totalBalls / bwWickets : 0.0;
      
      int bw3W = p.getStat('Single', 'bowling3W') + (matchWickets >= 3 && matchWickets < 5 ? 1 : 0);
      int bw5W = p.getStat('Single', 'bowling5W') + (matchWickets >= 5 && matchWickets < 7 ? 1 : 0);
      int bw7W = p.getStat('Single', 'bowling7W') + (matchWickets >= 7 && matchWickets < 10 ? 1 : 0);
      int bw10W = p.getStat('Single', 'bowling10W') + (matchWickets >= 10 ? 1 : 0);
      
      // Update Fielding Cumulative
      int fMatches = p.getStat('Single', 'fieldingMatches') + 1;
      int fCatches = p.getStat('Single', 'fieldingCatches') + (fStat['catches'] as int);
      int fStumpings = p.getStat('Single', 'fieldingStumpings') + (fStat['stumpings'] as int);
      int fRunOuts = p.getStat('Single', 'fieldingRunOuts') + (fStat['runOuts'] as int);

      p.updateStatsForMode('Single', {
        'battingMatches': bMatches,
        'battingInnings': bInnings,
        'battingRuns': bRuns,
        'battingBalls': bBalls,
        'battingFours': bFours,
        'battingSixes': bSixes,
        'battingBestScore': bBestScore,
        'battingHundreds': bHundreds,
        'battingFifties': bFifties,
        'battingThirties': bThirties,
        'battingDucks': bDucks,
        'battingGoldenDucks': bGoldenDucks,
        'battingNotOuts': bNotOuts,
        'battingAverage': bAverage,
        'battingStrikeRate': bStrikeRate,
        
        'bowlingMatches': bwMatches,
        'bowlingInnings': bwInnings,
        'bowlingOvers': bwOvers,
        'bowlingWickets': bwWickets,
        'bowlingMaidens': bwMaidens,
        'bowlingRunsConceded': bwRunsConc,
        'bowlingBestWickets': bwBestWickets,
        'bowlingBestRuns': bwBestRuns,
        'bowlingEconomy': bwEconomy,
        'bowlingAverage': bwAverage,
        'bowlingStrikeRate': bwStrikeRate,
        'bowling3W': bw3W,
        'bowling5W': bw5W,
        'bowling7W': bw7W,
        'bowling10W': bw10W,
        
        'fieldingMatches': fMatches,
        'fieldingCatches': fCatches,
        'fieldingStumpings': fStumpings,
        'fieldingRunOuts': fRunOuts,
      });

      updatedPlayers.add(p);
    }

    if (updatedPlayers.isNotEmpty) {
      provider.updatePlayers(updatedPlayers);
    }
  }

  void _saveState() {
    final provider = Provider.of<CricketProvider>(context, listen: false);
    
    _matchId ??= DateTime.now().millisecondsSinceEpoch.toString();

    final matchData = {
      'type': 'single_mode',
      'step': _step,
      'overs': _overs,
      'wideRuns': _wideRuns,
      'noBallRuns': _noBallRuns,
      'reballWide': _reballWide,
      'reballNoBall': _reballNoBall,
      'selectedPlayers': _selectedPlayers.map((p) => p.id).toList(),
      'battingOrder': _battingOrder,
      'currentBatsmanIndex': _currentBatsmanIndex,
      'playerStats': _playerStats,
      'currentOverBalls': _currentOverBalls,
      'bowlerId': _bowlerId,
      'balls': _balls,
      'undoHistory': _undoHistory,
    };

    final match = MatchModel(
      id: _matchId!,
      team1Name: 'Single Mode',
      team2Name: 'Solo Practice',
      date: DateTime.now(),
      result: 'In Progress',
      isCompleted: _step == 4,
      overs: _overs,
      matchData: matchData,
    );

    provider.saveMatch(match);
  }

  Future<void> _saveMatchToDatabase({bool pop = true}) async {
    _updateCumulativePlayerStats();
    final provider = Provider.of<CricketProvider>(context, listen: false);
    _matchId ??= DateTime.now().millisecondsSinceEpoch.toString();
    final matchId = _matchId!;

    List<Player> sorted = List.from(_selectedPlayers);
    sorted.sort((a, b) {
      final aRuns = _playerStats[a.id]?['runs'] ?? 0;
      final bRuns = _playerStats[b.id]?['runs'] ?? 0;
      if (bRuns == aRuns) {
        final aIdx = _battingOrder.indexOf(a.id);
        final bIdx = _battingOrder.indexOf(b.id);
        return aIdx.compareTo(bIdx);
      }
      return bRuns.compareTo(aRuns);
    });
    final winnerName = sorted.isNotEmpty ? sorted.first.name : 'Unknown';
    final winnerRuns = sorted.isNotEmpty ? (_playerStats[sorted.first.id]?['runs'] ?? 0) : 0;

    final MatchModel match = MatchModel(
      id: matchId,
      team1Name: 'Single Mode',
      team2Name: 'Solo Practice',
      date: DateTime.now(),
      result: 'Winner: $winnerName ($winnerRuns runs)',
      isCompleted: true,
      overs: _overs,
      team1Score: winnerRuns,
      team1Wickets: 0,
      team1Overs: 0.0,
      team2Score: 0,
      team2Wickets: 0,
      team2Overs: 0.0,
      matchData: {
        'type': 'single_mode',
        'overs': _overs,
        'wideRuns': _wideRuns,
        'noBallRuns': _noBallRuns,
        'selectedPlayers': _selectedPlayers.map((p) => p.id).toList(),
        'battingOrder': _battingOrder,
        'playerStats': _playerStats,
        'balls': _balls,
      },
    );

    await provider.saveMatch(match);
    if (pop && mounted) {
      Navigator.pop(context);
    }
  }

  void _addPlayerToMatch(Player player) {
    setState(() {
      _selectedPlayers.add(player);
      if (!_battingOrder.contains(player.id)) {
        _battingOrder.add(player.id);
      }
      _playerStats[player.id] = <String, dynamic>{
        'runs': 0,
        'balls': 0,
        '4s': 0,
        '6s': 0,
        'status': 'Yet to bat',
      };
    });
  }

  void _showCreateNewPlayerDialog(BuildContext context, Function(Player) onPlayerCreated) {
    final controller = TextEditingController();
    Uint8List? pickedImageBytes;
    final ImagePicker picker = ImagePicker();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(
                  color: Color(0xFF3A3A3A),
                  width: 1.0,
                ),
              ),
              title: const Text(
                'Create New Player',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      final source = await showModalBottomSheet<ImageSource>(
                        context: context,
                        backgroundColor: const Color(0xFF1E293B),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        builder: (context) => Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text('Select Image Source', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                            ListTile(
                              leading: const Icon(Icons.camera_alt, color: Color(0xFFD4AF37)),
                              title: const Text('Camera', style: TextStyle(color: Colors.white)),
                              onTap: () => Navigator.pop(context, ImageSource.camera),
                            ),
                            ListTile(
                              leading: const Icon(Icons.photo_library, color: Color(0xFFD4AF37)),
                              title: const Text('Gallery', style: TextStyle(color: Colors.white)),
                              onTap: () => Navigator.pop(context, ImageSource.gallery),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      );

                      if (source != null) {
                        final image = await picker.pickImage(source: source, imageQuality: 50, maxWidth: 400);
                        if (image != null) {
                          final bytes = await image.readAsBytes();
                          setState(() {
                            pickedImageBytes = bytes;
                          });
                        }
                      }
                    },
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: const Color(0xFFD4AF37).withOpacity(0.2),
                      backgroundImage: pickedImageBytes != null ? MemoryImage(pickedImageBytes!) : null,
                      child: pickedImageBytes == null
                          ? const Icon(Icons.add_a_photo, color: Color(0xFFD4AF37), size: 30)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Player Name',
                      hintStyle: TextStyle(color: Colors.white38),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFD4AF37))),
                    ),
                    textCapitalization: TextCapitalization.words,
                    autofocus: true,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final name = controller.text.trim();
                          if (name.isNotEmpty) {
                            setState(() => isLoading = true);
                            String? base64Str;
                            if (pickedImageBytes != null) {
                              base64Str = base64Encode(pickedImageBytes!);
                            }
                            final provider = Provider.of<CricketProvider>(
                              context,
                              listen: false,
                            );
                            await provider.addPlayer(name, imageBase64: base64Str);
                            
                            // Find the new player added to provider.players
                            final newPlayer = provider.players.firstWhere(
                              (p) => p.name == name && !_selectedPlayers.any((sp) => sp.id == p.id),
                              orElse: () => provider.players.last,
                            );

                            onPlayerCreated(newPlayer);
                            
                            if (context.mounted) {
                              Navigator.pop(dialogCtx);
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: Colors.black,
                  ),
                  child: isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                      : const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddPlayerDuringSetupDialog() {
    final provider = Provider.of<CricketProvider>(context, listen: false);
    final available = provider.players.where((p) => !_selectedPlayers.any((sp) => sp.id == p.id)).toList();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Player to Match', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Container(
          width: double.maxFinite,
          child: available.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Text('All roster players are already in the match.', style: TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: available.length,
                  itemBuilder: (ctx, idx) {
                    final player = available[idx];
                    return ListTile(
                      leading: _buildPlayerAvatar(player, radius: 18),
                      title: Text(player.name, style: const TextStyle(color: Colors.white)),
                      onTap: () {
                        _addPlayerToMatch(player);
                        Navigator.pop(dialogCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${player.name} added to the end of the batting order.')),
                        );
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              _showCreateNewPlayerDialog(context, (newPlayer) {
                _addPlayerToMatch(newPlayer);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${newPlayer.name} created and added to the end of the batting order.')),
                );
              });
            },
            child: const Text('Create New', style: TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          )
        ],
      ),
    );
  }

  void _restartGameWithSortedOrder() {
    // Sort players by runs from highest to lowest
    _selectedPlayers.sort((a, b) {
      final aRuns = _playerStats[a.id]?['runs'] ?? 0;
      final bRuns = _playerStats[b.id]?['runs'] ?? 0;
      if (bRuns == aRuns) {
        final aIdx = _battingOrder.indexOf(a.id);
        final bIdx = _battingOrder.indexOf(b.id);
        return aIdx.compareTo(bIdx);
      }
      return bRuns.compareTo(aRuns);
    });

    _battingOrder = _selectedPlayers.map((p) => p.id).toList();

    // Reset scores
    _playerStats = {};
    for (var p in _selectedPlayers) {
      _playerStats[p.id] = <String, dynamic>{
        'runs': 0,
        'balls': 0,
        '4s': 0,
        '6s': 0,
        'status': 'Yet to bat',
      };
    }

    if (_battingOrder.isNotEmpty) {
      _playerStats[_battingOrder[0]]!['status'] = 'Batting';
    }

    setState(() {
      _currentBatsmanIndex = 0;
      _currentOverBalls.clear();
      _undoHistory.clear();
      _balls.clear();
      _isWide = false;
      _isNoBall = false;
      _isByes = false;
      _isLegByes = false;
      _isWicket = false;
      _bowlerId = null;
      _step = 1; // Jump to Batting Order Screen
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          SafeArea(
            child: _buildCurrentStepView(),
          ),
          if (_isDisplayingCelebration && _celebrationText != null && _celebrationSubtitle != null)
            _buildCelebrationOverlay(),
        ],
      ),
    );
  }

  Widget _buildCurrentStepView() {
    switch (_step) {
      case 0:
        return _buildPlayerSelectionStep();
      case 1:
        return _buildBattingOrderStep();
      case 2:
        return _buildSettingsStep();
      case 3:
        return _buildScoreboardStep();
      case 4:
        return _buildResultsStep();
      default:
        return Container();
    }
  }

  // --- WIZARD STEP 0: Player Selection ---
  Widget _buildPlayerSelectionStep() {
    final provider = Provider.of<CricketProvider>(context);
    final filtered = provider.players.where((p) {
      return p.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        _buildStepHeader("Select Players", "Select who will play in this match"),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search roster...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text("No roster players found", style: TextStyle(color: Colors.white38)))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, idx) {
                    final p = filtered[idx];
                    final isSel = _selectedPlayers.any((x) => x.id == p.id);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSel) {
                            _selectedPlayers.removeWhere((x) => x.id == p.id);
                          } else {
                            _selectedPlayers.add(p);
                          }
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSel ? Theme.of(context).primaryColor : Colors.white.withOpacity(0.05),
                            width: 2,
                          ),
                          boxShadow: isSel
                              ? [
                                  BoxShadow(
                                    color: Theme.of(context).primaryColor.withOpacity(0.15),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  )
                                ]
                              : null,
                        ),
                        child: Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircleAvatar(
                                    radius: 26,
                                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                                    backgroundImage: p.imageBase64 != null && p.imageBase64!.isNotEmpty
                                        ? MemoryImage(base64Decode(p.imageBase64!))
                                        : null,
                                    child: p.imageBase64 == null || p.imageBase64!.isEmpty
                                        ? Icon(Icons.person, color: Theme.of(context).primaryColor, size: 26)
                                        : null,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    p.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  const Divider(color: Colors.white10, height: 1),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          children: [
                                            const Text('M', style: TextStyle(fontSize: 9, color: Colors.white54)),
                                            const SizedBox(height: 2),
                                            Text('${p.battingMatches}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          children: [
                                            const Text('Runs', style: TextStyle(fontSize: 9, color: Colors.white54)),
                                            const SizedBox(height: 2),
                                            Text('${p.battingRuns}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          children: [
                                            const Text('SR', style: TextStyle(fontSize: 9, color: Colors.white54)),
                                            const SizedBox(height: 2),
                                            Text(
                                              p.battingStrikeRate.toStringAsFixed(1),
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (isSel)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.black,
                                    size: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        _buildBottomButton("NEXT", _selectedPlayers.isEmpty ? null : () {
          setState(() {
            _manualOrderTemp.clear();
            _battingOrder.clear();
            _orderMode = '';
            _step = 1;
          });
        }),
      ],
    );
  }

  // --- WIZARD STEP 1: Batting Order ---
  Widget _buildBattingOrderStep() {
    return Column(
      children: [
        _buildStepHeader("Batting Order", "Define the batting sequence"),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showAddPlayerDuringSetupDialog,
                  icon: const Icon(Icons.person_add, color: Colors.black, size: 20),
                  label: const Text("ADD PLAYER", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              Expanded(
                child: _buildOptionButton("RANDOM ORDER", Icons.shuffle, _orderMode == 'random', () {
                  setState(() {
                    _orderMode = 'random';
                    List<Player> shuffled = List.from(_selectedPlayers)..shuffle();
                    _battingOrder = shuffled.map((p) => p.id).toList();
                  });
                }),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOptionButton("MANUAL ORDER", Icons.touch_app, _orderMode == 'manual', () {
                  setState(() {
                    _orderMode = 'manual';
                    _battingOrder.clear();
                    _manualOrderTemp.clear();
                  });
                }),
              ),
            ],
          ),
        ),
        Expanded(
          child: (_orderMode.isEmpty && _battingOrder.isEmpty)
              ? const Center(child: Text("Select an ordering mode to continue", style: TextStyle(color: Colors.white38)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: _selectedPlayers.length,
                  itemBuilder: (ctx, idx) {
                    final player = _selectedPlayers[idx];
                    int positionIndex = _battingOrder.indexOf(player.id);
                    bool hasOrder = positionIndex != -1;

                    return Card(
                      color: hasOrder ? Theme.of(context).primaryColor.withOpacity(0.08) : const Color(0xFF1E293B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: hasOrder ? Theme.of(context).primaryColor : Colors.transparent),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 6.0),
                      child: ListTile(
                        onTap: _orderMode == 'manual'
                            ? () {
                                setState(() {
                                  if (hasOrder) {
                                    _battingOrder.remove(player.id);
                                  } else {
                                    _battingOrder.add(player.id);
                                  }
                                });
                              }
                            : null,
                        leading: _buildPlayerAvatar(player, radius: 20),
                        title: Text(player.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        trailing: CircleAvatar(
                          radius: 16,
                          backgroundColor: hasOrder ? Theme.of(context).primaryColor : const Color(0xFF334155),
                          child: Text(
                            hasOrder ? "${positionIndex + 1}" : "-",
                            style: TextStyle(
                              color: hasOrder ? Colors.black : Colors.white30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        _buildBottomButton("NEXT", _battingOrder.length == _selectedPlayers.length ? () {
          setState(() {
            // Set up player stats mapping
            _playerStats = {};
            for (var p in _selectedPlayers) {
              _playerStats[p.id] = <String, dynamic>{
                'runs': 0,
                'balls': 0,
                '4s': 0,
                '6s': 0,
                'status': 'Yet to bat',
              };
            }
            // First player bats
            _playerStats[_battingOrder[0]]!['status'] = 'Batting';
            _currentBatsmanIndex = 0;
            _step = 2;
          });
        } : null),
      ],
    );
  }

  // --- WIZARD STEP 2: Match Settings ---
  Widget _buildSettingsStep() {
    return Column(
      children: [
        _buildStepHeader("Match Setup", "Configure game rules"),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Overs per Batsman", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFD4AF37), size: 32),
                      onPressed: () {
                        if (_overs > 1) {
                          setState(() {
                            _overs--;
                            _oversCtrl.text = '$_overs';
                          });
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 80,
                      child: TextField(
                        controller: _oversCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          fillColor: const Color(0xFF1E293B),
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (val) {
                          final parsed = int.tryParse(val);
                          if (parsed != null && parsed > 0) {
                            setState(() {
                              _overs = parsed;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: Color(0xFFD4AF37), size: 32),
                      onPressed: () {
                        setState(() {
                          _overs++;
                          _oversCtrl.text = '$_overs';
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 36),
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: const Text('Advanced Settings', style: TextStyle(color: Colors.white70)),
                    collapsedBackgroundColor: const Color(0xFF1E293B),
                    backgroundColor: const Color(0xFF1E293B),
                    childrenPadding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _noBallRunsCtrl,
                              decoration: const InputDecoration(labelText: 'Runs per No Ball', labelStyle: TextStyle(color: Colors.white60)),
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white),
                              onChanged: (val) {
                                final parsed = int.tryParse(val);
                                if (parsed != null && parsed >= 0) {
                                  _noBallRuns = parsed;
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text('Reball?', style: TextStyle(color: Colors.white70)),
                          Switch(
                            value: _reballNoBall,
                            activeColor: Theme.of(context).primaryColor,
                            onChanged: (val) {
                              setState(() {
                                _reballNoBall = val;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _wideRunsCtrl,
                              decoration: const InputDecoration(labelText: 'Runs per Wide', labelStyle: TextStyle(color: Colors.white60)),
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white),
                              onChanged: (val) {
                                final parsed = int.tryParse(val);
                                if (parsed != null && parsed >= 0) {
                                  _wideRuns = parsed;
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text('Reball?', style: TextStyle(color: Colors.white70)),
                          Switch(
                            value: _reballWide,
                            activeColor: Theme.of(context).primaryColor,
                            onChanged: (val) {
                              setState(() {
                                _reballWide = val;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildBottomButton("LET'S PLAY", () {
          final nonBatting = _selectedPlayers.where((p) => p.id != _battingOrder[_currentBatsmanIndex]).toList();
          if (nonBatting.isEmpty) {
            setState(() {
              _step = 3;
            });
            _saveState();
            RewardedAdHelper.showAd();
            return;
          }
          
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => SimpleDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: const Text('Select Bowler to Begin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              children: nonBatting.map((player) {
                return SimpleDialogOption(
                  onPressed: () {
                    setState(() {
                      _bowlerId = player.id;
                      _step = 3;
                    });
                    _saveState();
                    RewardedAdHelper.showAd();
                    Navigator.pop(ctx);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(player.name, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  ),
                );
              }).toList(),
            ),
          );
        }),
      ],
    );
  }

  // --- PLAY STEP 3: Live Scoreboard ---
  Widget _buildScoreboardStep() {
    final currentStrikerId = _battingOrder[_currentBatsmanIndex];
    final currentStrikerStats = _playerStats[currentStrikerId] ?? {};
    final currentStrikerName = _getPlayerName(currentStrikerId);

    final runs = currentStrikerStats['runs'] ?? 0;
    final balls = currentStrikerStats['balls'] ?? 0;
    final fours = currentStrikerStats['4s'] ?? 0;
    final sixes = currentStrikerStats['6s'] ?? 0;
    final sr = balls > 0 ? ((runs / balls) * 100).toStringAsFixed(1) : '0.0';

    final crr = balls > 0 ? ((runs / balls) * 6).toStringAsFixed(2) : '0.00';
    final oversCount = "${balls ~/ 6}.${balls % 6}";

    // Target tracking for last batsman
    final isLastBatsman = _currentBatsmanIndex > 0 && _currentBatsmanIndex == _battingOrder.length - 1;
    int highestScore = 0;
    int target = 0;
    if (isLastBatsman) {
      for (int i = 0; i < _currentBatsmanIndex; i++) {
        final pid = _battingOrder[i];
        final prevRuns = _playerStats[pid]?['runs'] ?? 0;
        if (prevRuns > highestScore) {
          highestScore = prevRuns;
        }
      }
      target = highestScore + 1;
    }

    return Column(
      children: [
        // App Bar styled title
        AppBar(
          title: Text(
            '$currentStrikerName\'s Innings',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1E293B),
                  title: const Text('Exit Match?', style: TextStyle(color: Colors.white)),
                  content: const Text('Are you sure you want to exit the match? Progress will be lost.', style: TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                      },
                      child: const Text('Exit'),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.analytics_outlined, color: Color(0xFFD4AF37)),
              tooltip: 'View Live Scorecard',
              onPressed: _showLiveScorecardDialog,
            ),
          ],
        ),
        
        Builder(
          builder: (context) {
            Widget scoreboardContent = Column(
              children: [
                // Top Score Glass Card
                GlassContainer(
                  padding: const EdgeInsets.all(16),
                  borderRadius: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Individual Innings Score", style: TextStyle(color: Colors.white70)),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$runs',
                                style: const TextStyle(
                                  fontSize: 42,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Text(
                                  '($oversCount / $_overs)',
                                  style: const TextStyle(fontSize: 20, color: Colors.white54),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text("CRR", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Text(
                            crr,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn().slideY(begin: -0.1, end: 0),
                const SizedBox(height: 12),

                if (isLastBatsman) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFD4AF37).withOpacity(0.25),
                          Theme.of(context).primaryColor.withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.4), width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Highest Score to Beat", style: TextStyle(color: Colors.white70, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text(
                              "$highestScore Runs",
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text("TARGET", style: TextStyle(color: Color(0xFFD4AF37), fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1)),
                            const SizedBox(height: 4),
                            Text(
                              "$target",
                              style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 38, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ).animate().fadeIn().scale(delay: 50.ms),
                  const SizedBox(height: 12),
                ],

                // Striker/Bowler Stats Table
                GlassContainer(
                  padding: const EdgeInsets.all(16),
                  borderRadius: 16,
                  child: Column(
                    children: [
                      _buildTableHeader(['Player', 'R', 'B', '4s', '6s', 'SR']),
                      const Divider(color: Colors.white12),
                      _buildTableRow(
                        '$currentStrikerName*',
                        '$runs',
                        '$balls',
                        '$fours',
                        '$sixes',
                        sr,
                        isHighlight: true,
                      ),
                      const SizedBox(height: 16),
                      _buildTableHeader(['Bowler', 'O', 'M', 'R', 'W', 'ER']),
                      const Divider(color: Colors.white12),
                      GestureDetector(
                        onTap: _showBowlerSelectDialog,
                        child: _buildTableRow(
                          _bowlerId != null ? _getPlayerName(_bowlerId) : 'Select Bowler (Tap)',
                          '0.0', '0', '0', '0', '0.00',
                          isHighlight: true,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: 12),

                if (_currentBatsmanIndex > 0) ...[
                  GlassContainer(
                    padding: const EdgeInsets.all(16),
                    borderRadius: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Previous Innings Scores",
                          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                        ),
                        const SizedBox(height: 8),
                        const Divider(color: Colors.white12, height: 1),
                        const SizedBox(height: 8),
                        ...List.generate(_currentBatsmanIndex, (idx) {
                          final prevId = _battingOrder[idx];
                          final prevStats = _playerStats[prevId] ?? {};
                          final prevName = _getPlayerName(prevId);
                          final prevRuns = prevStats['runs'] ?? 0;
                          final prevBalls = prevStats['balls'] ?? 0;
                          final isHighest = isLastBatsman && prevRuns == highestScore;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    if (isHighest)
                                      const Padding(
                                        padding: EdgeInsets.only(right: 6.0),
                                        child: Icon(Icons.emoji_events, color: Color(0xFFD4AF37), size: 14),
                                      ),
                                    Text(
                                      prevName,
                                      style: TextStyle(
                                        color: isHighest ? const Color(0xFFD4AF37) : Colors.white,
                                        fontWeight: isHighest ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  "$prevRuns ($prevBalls balls)",
                                  style: TextStyle(
                                    color: isHighest ? const Color(0xFFD4AF37) : Colors.white70,
                                    fontWeight: isHighest ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ).animate().fadeIn(delay: 150.ms),
                  const SizedBox(height: 12),
                ],

                // Over Delivery Dots
                GlassContainer(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  borderRadius: 16,
                  child: Row(
                    children: [
                      const Text(
                        'This batsman: ',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _currentOverBalls.map((b) {
                            return CircleAvatar(
                              radius: 14,
                              backgroundColor: b == 'W'
                                  ? Colors.redAccent
                                  : (b.contains('wd') || b.contains('nb')
                                      ? Colors.orangeAccent
                                      : Theme.of(context).primaryColor.withOpacity(0.2)),
                              child: Text(
                                b,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: b == 'W' ? Colors.white : Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: 12),

                // Extras Switchers Card
                GlassContainer(
                  padding: const EdgeInsets.all(16),
                  borderRadius: 16,
                  child: Column(
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildCheckbox('Wd', _isWide, (v) => setState(() => _isWide = v!)),
                            const SizedBox(width: 12),
                            _buildCheckbox('Nb', _isNoBall, (v) => setState(() => _isNoBall = v!)),
                            const SizedBox(width: 12),
                            _buildCheckbox('Byes', _isByes, (v) => setState(() => _isByes = v!)),
                            const SizedBox(width: 12),
                            _buildCheckbox('Leg Byes', _isLegByes, (v) => setState(() => _isLegByes = v!)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildCheckbox('Wicket', _isWicket, (v) => setState(() => _isWicket = v!), color: Colors.redAccent),
                          ElevatedButton(
                            onPressed: () {
                              _saveUndoState();
                              _finishBatsmanInnings(currentStrikerId, out: false);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D32),
                              minimumSize: const Size(120, 36),
                            ),
                            child: const Text('Finish Innings', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0),
              ],
            );

            Widget controlsContent = Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildActionButton('Undo', _undoLastBall),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 5,
                    child: GlassContainer(
                      padding: const EdgeInsets.all(16),
                      borderRadius: 16,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildRunButton('0', () => _executeScore(0)),
                              _buildRunButton('1', () => _executeScore(1)),
                              _buildRunButton('2', () => _executeScore(2)),
                              _buildRunButton('3', () => _executeScore(3)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildRunButton('4', () => _executeScore(4)),
                              _buildRunButton('5', () => _executeScore(5)),
                              _buildRunButton('6', () => _executeScore(6)),
                              _buildRunButton('...', _showCustomRunsDialog),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().slideY(begin: 1, end: 0, curve: Curves.easeOutBack, duration: 600.ms);
        return Expanded(
          child: ResponsiveHelper.getValue(
            context,
            defaultVal: Column(
              children: [
                Expanded(child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: scoreboardContent,
                )),
                controlsContent,
              ],
            ),
            medium: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: scoreboardContent,
                )),
                Expanded(flex: 2, child: SingleChildScrollView(child: controlsContent)),
              ],
            ),
            large: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: scoreboardContent,
                )),
                Expanded(flex: 2, child: SingleChildScrollView(child: controlsContent)),
              ],
            ),
            extraLarge: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: scoreboardContent,
                )),
                Expanded(flex: 2, child: SingleChildScrollView(child: controlsContent)),
              ],
            ),
          ),
        );})
      ],
    );
  }

  // --- RESULTS STEP 4: Podium & Complete Scorecard ---
  Widget _buildResultsStep() {
    List<Player> sorted = List.from(_selectedPlayers);
    sorted.sort((a, b) {
      final aRuns = _playerStats[a.id]?['runs'] ?? 0;
      final bRuns = _playerStats[b.id]?['runs'] ?? 0;
      if (bRuns == aRuns) {
        final aIdx = _battingOrder.indexOf(a.id);
        final bIdx = _battingOrder.indexOf(b.id);
        return aIdx.compareTo(bIdx);
      }
      return bRuns.compareTo(aRuns);
    });

    return Column(
      children: [
        _buildStepHeader("Match Completed", "Podium and Scorecard details"),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Beautiful Podium View
              _buildPodiumView(sorted),
              const SizedBox(height: 24),
              const Text(
                'STANDINGS (HIGHEST TO LOWEST)',
                style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // Scorecard Table
              GlassContainer(
                padding: const EdgeInsets.all(16.0),
                borderRadius: 16,
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Rank & Batsman', style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('Score', style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(color: Colors.white12),
                    ...List.generate(sorted.length, (index) {
                      final p = sorted[index];
                      final stats = _playerStats[p.id] ?? {};
                      final runs = stats['runs'] ?? 0;
                      final balls = stats['balls'] ?? 0;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '#${index + 1} ',
                                  style: TextStyle(
                                    color: index == 0
                                        ? const Color(0xFFFBBF24)
                                        : index == 1
                                            ? const Color(0xFF94A3B8)
                                            : index == 2
                                                ? const Color(0xFFB45309)
                                                : Colors.white54,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildPlayerAvatar(p, radius: 16),
                                const SizedBox(width: 10),
                                Text(
                                  p.name,
                                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Text(
                              '$runs Runs ($balls balls)',
                              style: TextStyle(
                                color: index == 0
                                    ? const Color(0xFFFBBF24)
                                    : index == 1
                                        ? const Color(0xFF94A3B8)
                                        : index == 2
                                            ? const Color(0xFFB45309)
                                            : Colors.white70,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Action Buttons
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _restartGameWithSortedOrder,
                  icon: const Icon(Icons.refresh, color: Colors.cyanAccent),
                  label: const Text("LET'S PLAY AGAIN", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.cyanAccent, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    RewardedAdHelper.showAd();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.check, color: Colors.black),
                  label: const Text("FINISH", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- PODIUM VIEW BUILDER ---
  Widget _buildPodiumView(List<Player> sorted) {
    if (sorted.isEmpty) return Container();
    final first = sorted[0];
    final second = sorted.length > 1 ? sorted[1] : null;
    final third = sorted.length > 2 ? sorted[2] : null;

    final firstScore = _playerStats[first.id]?['runs'] ?? 0;
    final secondScore = second != null ? (_playerStats[second.id]?['runs'] ?? 0) : 0;
    final thirdScore = third != null ? (_playerStats[third.id]?['runs'] ?? 0) : 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd Place Column
          if (second != null)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPlayerAvatar(second, radius: 24),
                const SizedBox(height: 8),
                Text(second.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                Text("$secondScore Runs", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 8),
                Container(
                  width: 75,
                  height: 90,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFF94A3B8), Color(0xFF475569)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
                  ),
                  child: const Center(
                    child: Text("2nd", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ).animate().slideY(begin: 0.2, end: 0, duration: 400.ms, curve: Curves.easeOutQuad),
          const SizedBox(width: 8),

          // 1st Place Column
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 28),
              _buildPlayerAvatar(first, radius: 32),
              const SizedBox(height: 8),
              Text(first.name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              Text("$firstScore Runs", style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                width: 90,
                height: 125,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFFFBBF24), Color(0xFFD97706)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
                ),
                child: const Center(
                  child: Text("1st", style: TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ).animate().slideY(begin: 0.3, end: 0, duration: 500.ms, curve: Curves.easeOutBack),
          const SizedBox(width: 8),

          // 3rd Place Column
          if (third != null)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPlayerAvatar(third, radius: 22),
                const SizedBox(height: 8),
                Text(third.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                Text("$thirdScore Runs", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 8),
                Container(
                  width: 75,
                  height: 70,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFFB45309), Color(0xFF78350F)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
                  ),
                  child: const Center(
                    child: Text("3rd", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ).animate().slideY(begin: 0.2, end: 0, duration: 400.ms, curve: Curves.easeOutQuad),
        ],
      ),
    );
  }

  // --- GENERAL DESIGN UTILS ---
  Widget _buildStepHeader(String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_step > 0)
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white70),
                  onPressed: () => setState(() => _step--),
                ),
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: EdgeInsets.only(left: _step > 0 ? 48.0 : 0.0),
            child: Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton(String label, VoidCallback? onPressed) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          disabledBackgroundColor: Colors.white12,
          disabledForegroundColor: Colors.white24,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildOptionButton(String text, IconData icon, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: active ? Theme.of(context).primaryColor : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? Theme.of(context).primaryColor : Colors.white10),
        ),
        child: Column(
          children: [
            Icon(icon, color: active ? Colors.black : Colors.white70, size: 28),
            const SizedBox(height: 8),
            Text(text, style: TextStyle(color: active ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberConfigRow(String label, int value, Function(int) onChange) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 15)),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.white54),
              onPressed: value > 1 ? () => onChange(value - 1) : null,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(8)),
              child: Text("$value", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Colors.white54),
              onPressed: () => onChange(value + 1),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlayerAvatar(Player p, {double radius = 24}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
      backgroundImage: p.imageBase64 != null && p.imageBase64!.isNotEmpty
          ? MemoryImage(base64Decode(p.imageBase64!))
          : null,
      child: p.imageBase64 == null || p.imageBase64!.isEmpty
          ? Icon(Icons.person, color: Theme.of(context).primaryColor, size: radius * 0.9)
          : null,
    );
  }

  BoxDecoration _glassDecoration(BuildContext context) {
    return BoxDecoration(
      color: const Color(0xFF1E293B).withOpacity(0.85),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.08)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.4),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _buildTableHeader(List<String> columns) {
    return Row(
      children: [
        Expanded(flex: 3, child: Text(columns[0], style: const TextStyle(color: Colors.white38, fontSize: 12))),
        Expanded(flex: 1, child: Text(columns[1], textAlign: TextAlign.right, style: const TextStyle(color: Colors.white38, fontSize: 12))),
        Expanded(flex: 1, child: Text(columns[2], textAlign: TextAlign.right, style: const TextStyle(color: Colors.white38, fontSize: 12))),
        Expanded(flex: 1, child: Text(columns[3], textAlign: TextAlign.right, style: const TextStyle(color: Colors.white38, fontSize: 12))),
        Expanded(flex: 1, child: Text(columns[4], textAlign: TextAlign.right, style: const TextStyle(color: Colors.white38, fontSize: 12))),
        Expanded(flex: 2, child: Text(columns[5], textAlign: TextAlign.right, style: const TextStyle(color: Colors.white38, fontSize: 12))),
      ],
    );
  }

  Widget _buildTableRow(String name, String v1, String v2, String v3, String v4, String v5, {bool isHighlight = false}) {
    Color textColor = isHighlight ? Theme.of(context).primaryColor : Colors.white;
    return Row(
      children: [
        Expanded(flex: 3, child: Text(name, style: TextStyle(color: textColor, fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal, fontSize: 14), overflow: TextOverflow.ellipsis)),
        Expanded(flex: 1, child: Text(v1, textAlign: TextAlign.right, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14))),
        Expanded(flex: 1, child: Text(v2, textAlign: TextAlign.right, style: const TextStyle(color: Colors.white54, fontSize: 14))),
        Expanded(flex: 1, child: Text(v3, textAlign: TextAlign.right, style: const TextStyle(color: Colors.white54, fontSize: 14))),
        Expanded(flex: 1, child: Text(v4, textAlign: TextAlign.right, style: const TextStyle(color: Colors.white54, fontSize: 14))),
        Expanded(flex: 2, child: Text(v5, textAlign: TextAlign.right, style: const TextStyle(color: Colors.white54, fontSize: 14))),
      ],
    );
  }

  Widget _buildCheckbox(String label, bool value, Function(bool?) onChanged, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: color ?? Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(width: 4),
        Checkbox(
          value: value,
          onChanged: onChanged,
          activeColor: color ?? Theme.of(context).primaryColor,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1E293B),
        minimumSize: const Size(double.infinity, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: const BorderSide(color: Colors.white10),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildRunButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        radius: 26,
        backgroundColor: const Color(0xFF1E293B),
        child: Text(
          label,
          style: TextStyle(
            fontSize: label == '...' ? 16 : 20,
            color: Theme.of(context).primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildCelebrationOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _isDisplayingCelebration = false),
        child: Container(
          color: Colors.black87,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _celebrationText!,
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(color: Theme.of(context).primaryColor.withOpacity(0.6), blurRadius: 20),
                    ],
                  ),
                ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
                const SizedBox(height: 12),
                Text(
                  _celebrationSubtitle!,
                  style: const TextStyle(color: Colors.white70, fontSize: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- READ-ONLY SCORECARD VIEW FOR HISTORICAL SINGLE MODE MATCHES ---
class SingleModeScorecardScreen extends StatelessWidget {
  final MatchModel match;

  const SingleModeScorecardScreen({super.key, required this.match});

  String _getPlayerName(BuildContext context, String? id) {
    if (id == null || id.isEmpty) return 'Unknown';
    final provider = Provider.of<CricketProvider>(context, listen: false);
    final p = provider.players.firstWhere(
      (x) => x.id == id,
      orElse: () => Player(id: '', name: 'Unknown'),
    );
    return p.name;
  }

  Widget _buildPlayerAvatar(BuildContext context, Player p, {double radius = 24}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
      backgroundImage: p.imageBase64 != null && p.imageBase64!.isNotEmpty
          ? MemoryImage(base64Decode(p.imageBase64!))
          : null,
      child: p.imageBase64 == null || p.imageBase64!.isEmpty
          ? Icon(Icons.person, color: Theme.of(context).primaryColor, size: radius * 0.9)
          : null,
    );
  }

  BoxDecoration _glassDecoration(BuildContext context) {
    return BoxDecoration(
      color: const Color(0xFF1E293B).withOpacity(0.85),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.08)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.4),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _buildTableHeader(List<String> columns) {
    return Row(
      children: [
        Expanded(flex: 3, child: Text(columns[0], style: const TextStyle(color: Colors.white38, fontSize: 12))),
        Expanded(flex: 1, child: Text(columns[1], textAlign: TextAlign.right, style: const TextStyle(color: Colors.white38, fontSize: 12))),
        Expanded(flex: 1, child: Text(columns[2], textAlign: TextAlign.right, style: const TextStyle(color: Colors.white38, fontSize: 12))),
        Expanded(flex: 1, child: Text(columns[3], textAlign: TextAlign.right, style: const TextStyle(color: Colors.white38, fontSize: 12))),
        Expanded(flex: 1, child: Text(columns[4], textAlign: TextAlign.right, style: const TextStyle(color: Colors.white38, fontSize: 12))),
        Expanded(flex: 2, child: Text(columns[5], textAlign: TextAlign.right, style: const TextStyle(color: Colors.white38, fontSize: 12))),
      ],
    );
  }

  Widget _buildTableRow(BuildContext context, String name, String v1, String v2, String v3, String v4, String v5) {
    return Row(
      children: [
        Expanded(flex: 3, child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 14), overflow: TextOverflow.ellipsis)),
        Expanded(flex: 1, child: Text(v1, textAlign: TextAlign.right, style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 14))),
        Expanded(flex: 1, child: Text(v2, textAlign: TextAlign.right, style: const TextStyle(color: Colors.white54, fontSize: 14))),
        Expanded(flex: 1, child: Text(v3, textAlign: TextAlign.right, style: const TextStyle(color: Colors.white54, fontSize: 14))),
        Expanded(flex: 1, child: Text(v4, textAlign: TextAlign.right, style: const TextStyle(color: Colors.white54, fontSize: 14))),
        Expanded(flex: 2, child: Text(v5, textAlign: TextAlign.right, style: const TextStyle(color: Colors.white54, fontSize: 14))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CricketProvider>(context);
    final battingOrder = List<String>.from(match.matchData['battingOrder'] ?? []);
    final playerStats = Map<String, dynamic>.from(match.matchData['playerStats'] ?? {});

    List<Player> selectedPlayers = provider.players.where((p) => battingOrder.contains(p.id)).toList();
    selectedPlayers.sort((a, b) {
      final aRuns = playerStats[a.id]?['runs'] ?? 0;
      final bRuns = playerStats[b.id]?['runs'] ?? 0;
      if (bRuns == aRuns) {
        final aIdx = battingOrder.indexOf(a.id);
        final bIdx = battingOrder.indexOf(b.id);
        return aIdx.compareTo(bIdx);
      }
      return bRuns.compareTo(aRuns);
    });

    // Podium rankings
    final first = selectedPlayers.isNotEmpty ? selectedPlayers[0] : null;
    final second = selectedPlayers.length > 1 ? selectedPlayers[1] : null;
    final third = selectedPlayers.length > 2 ? selectedPlayers[2] : null;

    final firstScore = first != null ? (playerStats[first.id]?['runs'] ?? 0) : 0;
    final secondScore = second != null ? (playerStats[second.id]?['runs'] ?? 0) : 0;
    final thirdScore = third != null ? (playerStats[third.id]?['runs'] ?? 0) : 0;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Match Details', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Glowing trophied results title
            Center(
              child: Text(
                match.result,
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(color: Theme.of(context).primaryColor.withOpacity(0.5), blurRadius: 10),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),

            // Podium
            if (first != null)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (second != null)
                      Column(
                        children: [
                          _buildPlayerAvatar(context, second, radius: 24),
                          const SizedBox(height: 8),
                          Text(second.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                          Text("$secondScore Runs", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          const SizedBox(height: 8),
                          Container(
                            width: 75,
                            height: 90,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(colors: [Color(0xFF94A3B8), Color(0xFF475569)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                              borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
                            ),
                            child: const Center(
                              child: Text("2nd", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ).animate().slideY(begin: 0.2, end: 0, duration: 400.ms),
                    const SizedBox(width: 8),
                    Column(
                      children: [
                        const Icon(Icons.emoji_events, color: Colors.amber, size: 28),
                        _buildPlayerAvatar(context, first, radius: 32),
                        const SizedBox(height: 8),
                        Text(first.name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        Text("$firstScore Runs", style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Container(
                          width: 85,
                          height: 120,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [Color(0xFFFBBF24), Color(0xFFD97706)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                            borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
                          ),
                          child: const Center(
                            child: Text("1st", style: TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ).animate().slideY(begin: 0.3, end: 0, duration: 500.ms, curve: Curves.easeOutBack),
                    const SizedBox(width: 8),
                    if (third != null)
                      Column(
                        children: [
                          _buildPlayerAvatar(context, third, radius: 22),
                          const SizedBox(height: 8),
                          Text(third.name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          Text("$thirdScore Runs", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          const SizedBox(height: 8),
                          Container(
                            width: 75,
                            height: 70,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(colors: [Color(0xFFB45309), Color(0xFF78350F)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                              borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
                            ),
                            child: const Center(
                              child: Text("3rd", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ).animate().slideY(begin: 0.2, end: 0, duration: 400.ms),
                  ],
                ),
              ),

            const SizedBox(height: 24),
            const Text(
              'DETAILED SCORECARD',
              style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            GlassContainer(
              padding: const EdgeInsets.all(16.0),
              borderRadius: 16,
              child: Column(
                children: [
                  _buildTableHeader(['Batsman', 'R', 'B', '4s', '6s', 'SR']),
                  const Divider(color: Colors.white12),
                  ...battingOrder.map((pid) {
                    final p = provider.players.firstWhere((pl) => pl.id == pid, orElse: () => Player(id: pid, name: 'Unknown'));
                    final stats = playerStats[pid] ?? {};
                    final runs = stats['runs'] ?? 0;
                    final balls = stats['balls'] ?? 0;
                    final fours = stats['4s'] ?? 0;
                    final sixes = stats['6s'] ?? 0;
                    final sr = balls > 0 ? ((runs / balls) * 100).toStringAsFixed(1) : '0.0';

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: _buildTableRow(
                        context,
                        p.name,
                        '$runs',
                        '$balls',
                        '$fours',
                        '$sixes',
                        sr,
                      ),
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                final tempMatch = MatchModel(
                  id: match.id,
                  team1Name: 'Team 1',
                  team2Name: 'Team 2',
                  team1Score: match.team1Score,
                  team2Score: 0,
                  team1Wickets: match.team1Wickets,
                  team2Wickets: 0,
                  team1Overs: match.team1Overs,
                  team2Overs: 0.0,
                  date: match.date,
                  isCompleted: match.isCompleted,
                  result: match.result,
                  overs: match.overs,
                  matchData: {
                    ...match.matchData,
                    'team1Players': match.matchData['selectedPlayers'] ?? [],
                    'team2Players': [],
                  },
                );
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ScorecardScreen(match: tempMatch),
                  ),
                );
              },
              icon: const Icon(Icons.assessment, color: Colors.black),
              label: const Text("FULL SCORECARD", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 8,
                shadowColor: Theme.of(context).primaryColor.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
