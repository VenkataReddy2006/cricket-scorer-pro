import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/match.dart';
import '../models/player.dart';
import '../responsive_helper.dart';
import '../providers/cricket_provider.dart';
import 'scorecard_screen.dart';
import '../rewarded_ad_helper.dart';
import 'rematch_roster_screen.dart';
import '../widgets/glass_container.dart';

class MatchScoreScreen extends StatefulWidget {
  final MatchModel match;

  const MatchScoreScreen({super.key, required this.match});

  @override
  State<MatchScoreScreen> createState() => _MatchScoreScreenState();
}

class _MatchScoreScreenState extends State<MatchScoreScreen> {
  late MatchModel _match;

  Timer? _celebrationTimer;
  bool _promptBowlerPending = false;

  final List<String> _sixPhrases = const [
    "MASSIVE SIX!",
    "OUT OF THE PARK!",
    "MONSTER MAXIMUM!",
    "HUGE HIT!",
    "SHOT OF THE DAY!",
    "INTO THE CLOUDS!",
    "FLOWN INTO THE STANDS!",
    "CRACKING MAXIMUM!",
    "CRACKED FOR SIX!",
    "COMMANDING HIT!",
    "SPECTACULAR SIX!",
    "ABSOLUTELY GIGANTIC!",
    "A TOWERING SIX!",
    "OVER THE ROOF!",
    "CLEAN BLAZE!",
  ];

  final List<String> _fourPhrases = const [
    "CLASSY BOUNDARY!",
    "CRACKING FOUR!",
    "ELEGANT BOUNDARY!",
    "DELIGHTFUL SHOT!",
    "CRACKING 4!",
    "BEAUTIFUL FOUR!",
    "SMASHED FOR FOUR!",
    "SWEET BOUNDARY!",
    "DIRECT TO THE FENCE!",
    "GLORIOUS SHOT!",
    "CRISP BOUNDARY!",
    "BULLET TO THE BOUNDARY!",
    "TIMED TO PERFECTION!",
    "FOUR MORE ADDED!",
    "RACING AWAY!",
  ];

  final List<String> _wicketPhrases = const [
    "GONE! OUT!",
    "CRITICAL WICKET!",
    "BOWLED OVER!",
    "CLEANED UP!",
    "WHAT A DELIVERY!",
    "THE STUMPS ARE SHATTERED!",
    "BIG WICKET!",
    "BOWLED HIM!",
    "TRAPPED IN FRONT!",
    "WALK OF SHAME!",
    "A HUGE BLOW!",
    "CRACKING BALL, OUT!",
    "FINGER GOES UP!",
    "TIMBERRR!",
    "BACK TO THE PAVILION!",
  ];

  // Scoring State
  int _currentInnings = 1;
  int _battingTeam = 1;

  String? _strikerId;
  String? _nonStrikerId;
  String? _bowlerId;

  int _ballsInCurrentOver = 0;
  List<Map<String, dynamic>> _ballTimeline = [];
  List<String> _currentOverBalls = [];

  // Checkbox states
  bool _isWide = false;
  bool _isNoBall = false;
  bool _isByes = false;
  bool _isLegByes = false;
  bool _isWicket = false;

  Map<dynamic, dynamic> _playerStats = {};
  List<dynamic> _retiredPlayerIds = [];

  // Player Stats Overlay Queue
  final List<Map<String, dynamic>> _playerStatsQueue = [];
  bool _isDisplayingPlayerStats = false;
  Player? _currentPlayerForOverlay;
  bool _currentPlayerIsBatsman = false;
  final Set<String> _shownStatsPlayerIds = {};

  // Celebration Overlay
  String? _celebrationText;
  String? _celebrationSubtitle;
  bool _isDisplayingCelebration = false;

  // Consecutive counts (for hat-trick checking)
  final Map<String, int> _batsmanConsecutiveSixes = {};
  final Map<String, int> _batsmanConsecutiveFours = {};
  int _bowlerConsecutiveWickets = 0;

  @override
  void initState() {
    super.initState();
    _match = widget.match;
    _currentInnings = _match.matchData['currentInnings'] ?? 1;
    _battingTeam = _match.matchData['battingTeam'] ?? 1;
    _strikerId = _match.matchData['strikerId'];
    _nonStrikerId = _match.matchData['nonStrikerId'];
    _bowlerId = _match.matchData['bowlerId'];
    _ballsInCurrentOver = _match.matchData['ballsInCurrentOver'] ?? 0;
    _currentOverBalls = List<String>.from(
      _match.matchData['currentOverBalls'] ?? [],
    );
    _retiredPlayerIds = List<dynamic>.from(
      _match.matchData['retiredPlayerIds'] ?? [],
    );
    if (_match.matchData['playerStats'] != null) {
      _playerStats = Map<dynamic, dynamic>.from(
        _match.matchData['playerStats'],
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_strikerId != null) _enqueuePlayerStats(_strikerId, true);
      if (_nonStrikerId != null) _enqueuePlayerStats(_nonStrikerId, true);
      if (_bowlerId != null) _enqueuePlayerStats(_bowlerId, false);
    });
  }

  @override
  void dispose() {
    _celebrationTimer?.cancel();
    super.dispose();
  }

  Map<dynamic, dynamic> _getStats(String? playerId) {
    if (playerId == null) return {};
    if (!_playerStats.containsKey(playerId) ||
        _playerStats[playerId] == null ||
        _playerStats[playerId] is! Map) {
      _playerStats[playerId] = <String, dynamic>{
        'runs': 0,
        'balls': 0,
        '4s': 0,
        '6s': 0,
        'bowledBalls': 0,
        'maidens': 0,
        'runsConceded': 0,
        'wickets': 0,
      };
    }
    return _playerStats[playerId];
  }

  void _enqueuePlayerStats(String? playerId, bool isBatsman) {
    if (playerId == null || playerId.isEmpty) return;

    final allPlayers = Provider.of<CricketProvider>(
      context,
      listen: false,
    ).players;
    final player = allPlayers.firstWhere(
      (p) => p.id == playerId,
      orElse: () => Player(id: '', name: 'Unknown'),
    );
    if (player.id.isEmpty) return;

    final key = '${playerId}_${isBatsman ? "bat" : "bowl"}';
    if (_shownStatsPlayerIds.contains(key)) {
      return;
    }
    _shownStatsPlayerIds.add(key);

    _playerStatsQueue.add({'player': player, 'isBatsman': isBatsman});

    _processPlayerStatsQueue();
  }

  void _processPlayerStatsQueue() {
    if (_isDisplayingCelebration) return; // Wait for celebration to end
    if (_isDisplayingPlayerStats || _playerStatsQueue.isEmpty) return;

    final nextItem = _playerStatsQueue.removeAt(0);
    setState(() {
      _currentPlayerForOverlay = nextItem['player'];
      _currentPlayerIsBatsman = nextItem['isBatsman'];
      _isDisplayingPlayerStats = true;
    });

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _isDisplayingPlayerStats) {
        _dismissPlayerStatsOverlay();
      }
    });
  }

  void _dismissPlayerStatsOverlay() {
    setState(() {
      _isDisplayingPlayerStats = false;
      _currentPlayerForOverlay = null;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _processPlayerStatsQueue();

        // If the queue is empty, and we aren't showing stats/celebrations, and bowler prompt is pending, trigger it
        if (!_isDisplayingCelebration &&
            !_isDisplayingPlayerStats &&
            _playerStatsQueue.isEmpty &&
            _promptBowlerPending) {
          _promptBowlerPending = false;
          _promptNextBowler();
        }
      }
    });
  }

  void _dismissCelebration() {
    if (!mounted) return;
    setState(() {
      _isDisplayingCelebration = false;
      _celebrationText = null;
      _celebrationSubtitle = null;
    });

    // Check if there are queued player stats first
    if (_playerStatsQueue.isNotEmpty) {
      _processPlayerStatsQueue();
    } else if (_promptBowlerPending) {
      _promptBowlerPending = false;
      _promptNextBowler();
    }
  }

  void _saveState() {
    _checkAndInitPartnership();
    _match.matchData['currentInnings'] = _currentInnings;
    _match.matchData['battingTeam'] = _battingTeam;
    _match.matchData['strikerId'] = _strikerId;
    _match.matchData['nonStrikerId'] = _nonStrikerId;
    _match.matchData['bowlerId'] = _bowlerId;
    _match.matchData['ballsInCurrentOver'] = _ballsInCurrentOver;
    _match.matchData['currentOverBalls'] = _currentOverBalls;
    _match.matchData['retiredPlayerIds'] = _retiredPlayerIds;
    _match.matchData['playerStats'] = _playerStats;
    Provider.of<CricketProvider>(context, listen: false).saveMatch(_match);
  }

  void _handleScoreButton(int runs) {
    if (_isWicket) {
      _promptWicketDetails(runs);
    } else {
      _executeScore(runs);
    }
  }

  void _promptWicketDetails(int runs) {
    final provider = Provider.of<CricketProvider>(context, listen: false);

    List<dynamic> battingTeamIds = _battingTeam == 1
        ? _match.matchData['team1Players']
        : _match.matchData['team2Players'];
    List<Player> battingTeam = provider.players
        .where((p) => battingTeamIds.contains(p.id))
        .toList();

    List<Player> availableNextBatsmen = battingTeam.where((p) {
      if (p.id == _strikerId || p.id == _nonStrikerId) return false;
      final stats = _getStats(p.id);
      final hasNotBatted =
          (stats['balls'] ?? 0) == 0 && (stats['runs'] ?? 0) == 0;
      final isRetired = _retiredPlayerIds.contains(p.id);
      return hasNotBatted || isRetired;
    }).toList();
    List<dynamic> fieldingTeamIds = _battingTeam == 1
        ? _match.matchData['team2Players']
        : _match.matchData['team1Players'];
    List<Player> fieldingTeam = provider.players
        .where((p) => fieldingTeamIds.contains(p.id))
        .toList();

    String wicketType = 'Bowled';
    String batsmanOutId = _strikerId ?? '';
    Player? nextBatsman;
    Player? fielder;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => Dialog.fullscreen(
          backgroundColor: Colors.black87,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: const Text(
                'Wicket Details',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() => _isWicket = false);
                },
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (availableNextBatsmen.isNotEmpty && nextBatsman == null)
                      return;
                    if ([
                          'Caught',
                          'Striker Runout',
                          'Non-Striker Runout',
                          'Stumped',
                        ].contains(wicketType) &&
                        fielder == null)
                      return;
                    Navigator.pop(ctx);
                    _executeScore(
                      runs,
                      isRunOut: wicketType.contains('Runout'),
                      batsmanOutId: batsmanOutId,
                      nextBatsmanId: nextBatsman?.id,
                      wicketType: wicketType,
                      fielderId: fielder?.id,
                    );
                  },
                  child: const Text(
                    'DONE',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
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
                    decoration: InputDecoration(
                      labelText: 'Wicket Type',
                      labelStyle: TextStyle(color: Colors.white54),
                    ),
                    items:
                        [
                              'Bowled',
                              'Caught',
                              'LBW',
                              'Striker Runout',
                              'Non-Striker Runout',
                              'Stumped',
                              'Hit Wicket',
                            ]
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text(
                                  e,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: (val) {
                      setStateDialog(() {
                        wicketType = val!;
                        if (wicketType == 'Striker Runout')
                          batsmanOutId = _strikerId ?? '';
                        else if (wicketType == 'Non-Striker Runout')
                          batsmanOutId = _nonStrikerId ?? '';
                        else
                          batsmanOutId = _strikerId ?? '';
                        fielder = null;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  if (wicketType.contains('Runout'))
                    DropdownButtonFormField<String>(
                      dropdownColor: Theme.of(context).colorScheme.surface,
                      value: batsmanOutId,
                      decoration: InputDecoration(
                        labelText: 'Batsman Out',
                        labelStyle: TextStyle(color: Colors.white54),
                      ),
                      items: [
                        if (_strikerId != null)
                          DropdownMenuItem(
                            value: _strikerId!,
                            child: Text(
                              _getPlayerName(_strikerId),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        if (_nonStrikerId != null)
                          DropdownMenuItem(
                            value: _nonStrikerId!,
                            child: Text(
                              _getPlayerName(_nonStrikerId),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                      ],
                      onChanged: (val) =>
                          setStateDialog(() => batsmanOutId = val!),
                    )
                  else
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Batsman Out: ${_getPlayerName(batsmanOutId)}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  if ([
                    'Caught',
                    'Striker Runout',
                    'Non-Striker Runout',
                    'Stumped',
                  ].contains(wicketType)) ...[
                    DropdownButtonFormField<Player>(
                      dropdownColor: Theme.of(context).colorScheme.surface,
                      value: fielder,
                      decoration: InputDecoration(
                        labelText: wicketType == 'Caught'
                            ? 'Caught By'
                            : (wicketType == 'Stumped'
                                  ? 'Stumped By'
                                  : 'Fielder'),
                        labelStyle: const TextStyle(color: Colors.white54),
                      ),
                      items: fieldingTeam
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(
                                e.name,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) => setStateDialog(() => fielder = val),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (availableNextBatsmen.isNotEmpty)
                    DropdownButtonFormField<Player>(
                      dropdownColor: Theme.of(context).colorScheme.surface,
                      decoration: InputDecoration(
                        labelText: 'Next Batsman',
                        labelStyle: TextStyle(color: Colors.white54),
                      ),
                      items: availableNextBatsmen
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(
                                _retiredPlayerIds.contains(e.id)
                                    ? '${e.name} (Retired)'
                                    : e.name,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setStateDialog(() => nextBatsman = val),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(top: 16.0),
                      child: Text(
                        'All Out! No batsmen remaining.',
                        style: TextStyle(color: Colors.redAccent, fontSize: 18),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _executeScore(
    int runs, {
    bool isRunOut = false,
    String? batsmanOutId,
    String? nextBatsmanId,
    String? wicketType,
    String? fielderId,
  }) {
    final String currentStriker = _strikerId ?? '';
    final String currentNonStriker = _nonStrikerId ?? '';
    final String currentBowler = _bowlerId ?? '';

    // Capture current state strings synchronously (fast)
    final String matchJsonStr = jsonEncode(_match.toJson());
    final String statsJsonStr = jsonEncode(_playerStats);
    final String? capStriker = _strikerId;
    final String? capNonStriker = _nonStrikerId;
    final String? capBowler = _bowlerId;
    final int capBallsInOver = _ballsInCurrentOver;
    final List<String> capOverBalls = List.from(_currentOverBalls);

    // Perform heavy decoding off the main UI rendering path
    Future.delayed(Duration.zero, () {
      if (!mounted) return;
      _ballTimeline.add({
        'matchState': jsonDecode(matchJsonStr),
        'strikerId': capStriker,
        'nonStrikerId': capNonStriker,
        'bowlerId': capBowler,
        'ballsInCurrentOver': capBallsInOver,
        'currentOverBalls': capOverBalls,
        'playerStats': jsonDecode(statsJsonStr),
      });
    });

    bool overCompletedOnThisBall = false;

    setState(() {
      int oversFloor =
          (_battingTeam == 1 ? _match.team1Overs : _match.team2Overs).floor();
      String overStr = '$oversFloor.${_ballsInCurrentOver + 1}';

      int runsToAdd = runs;
      if (_isWide) runsToAdd += (_match.matchData['wideRuns'] ?? 1) as int;
      if (_isNoBall) runsToAdd += (_match.matchData['noBallRuns'] ?? 1) as int;

      final strikerStats = _getStats(_strikerId);
      final bowlerStats = _getStats(_bowlerId);

      // Update striker
      if (!_isWide) {
        strikerStats['balls'] = (strikerStats['balls'] ?? 0) + 1;
        if (!_isByes && !_isLegByes) {
          strikerStats['runs'] = (strikerStats['runs'] ?? 0) + runs;
          if (runs == 4) strikerStats['4s'] = (strikerStats['4s'] ?? 0) + 1;
          if (runs == 6) strikerStats['6s'] = (strikerStats['6s'] ?? 0) + 1;
        }
      }

      // Update bowler
      int bowlerRuns = runsToAdd;
      if (_isByes || _isLegByes)
        bowlerRuns -= runs; // Byes/LegByes aren't charged to bowler
      bowlerStats['runsConceded'] =
          (bowlerStats['runsConceded'] ?? 0) + bowlerRuns;

      if (!_isWide && !_isNoBall)
        bowlerStats['bowledBalls'] = (bowlerStats['bowledBalls'] ?? 0) + 1;
      if (_isWicket && !isRunOut)
        bowlerStats['wickets'] = (bowlerStats['wickets'] ?? 0) + 1;

      if (_battingTeam == 1) {
        _match.team1Score += runsToAdd;
        if (_isWicket) _match.team1Wickets++;
      } else {
        _match.team2Score += runsToAdd;
        if (_isWicket) _match.team2Wickets++;
      }

      bool isLegalDelivery = !_isWide && !_isNoBall;
      if (isLegalDelivery) {
        _ballsInCurrentOver++;
      }

      // Update oversData for graphs
      List<dynamic> oversData = List.from(
        _match.matchData['oversData_$_currentInnings'] ?? [0],
      );
      if (oversData.isEmpty) oversData.add(0);
      oversData[oversData.length - 1] =
          (oversData[oversData.length - 1] as int) + runsToAdd;

      // Append ball to string tracker
      String ballLabel = runs.toString();
      if (_isWicket)
        ballLabel = 'W';
      else if (_isWide)
        ballLabel = '${runs}wd';
      else if (_isNoBall)
        ballLabel = '${runs}nb';
      else if (_isByes)
        ballLabel = '${runs}b';
      else if (_isLegByes)
        ballLabel = '${runs}lb';
      _currentOverBalls.add(ballLabel);

      if (_ballsInCurrentOver >= 6) {
        overCompletedOnThisBall = isLegalDelivery;
        if (_battingTeam == 1)
          _match.team1Overs = _match.team1Overs.floor() + 1.0;
        else
          _match.team2Overs = _match.team2Overs.floor() + 1.0;
        _swapBatsmen();
        _ballsInCurrentOver = 0;
        _currentOverBalls.clear();
        oversData.add(0); // Prepare for next over
      } else {
        if (_battingTeam == 1)
          _match.team1Overs =
              _match.team1Overs.floor() + (_ballsInCurrentOver / 10);
        else
          _match.team2Overs =
              _match.team2Overs.floor() + (_ballsInCurrentOver / 10);
      }
      _match.matchData['oversData_$_currentInnings'] = oversData;

      if (_isWicket && batsmanOutId != null) {
        String bowlerName = currentBowler.isNotEmpty
            ? _getPlayerName(currentBowler)
            : 'Bowler';
        String fielderName = fielderId != null ? _getPlayerName(fielderId) : '';
        String statusString = 'out';

        if (wicketType == 'Bowled') {
          statusString = 'b $bowlerName';
        } else if (wicketType == 'Caught') {
          statusString = 'c $fielderName b $bowlerName';
        } else if (wicketType == 'LBW') {
          statusString = 'lbw b $bowlerName';
        } else if (wicketType == 'Run Out' ||
            wicketType == 'Striker Runout' ||
            wicketType == 'Non-Striker Runout') {
          statusString = 'run out ($fielderName)';
        } else if (wicketType == 'Stumped') {
          statusString = 'st $fielderName b $bowlerName';
        } else if (wicketType == 'Hit Wicket') {
          statusString = 'hit wicket b $bowlerName';
        }

        _playerStats[batsmanOutId]!['status'] = statusString;
        if (batsmanOutId == _strikerId) {
          _strikerId = nextBatsmanId;
        } else if (batsmanOutId == _nonStrikerId) {
          _nonStrikerId = nextBatsmanId;
        }
        if (nextBatsmanId != null) {
          _retiredPlayerIds.remove(nextBatsmanId);
          _enqueuePlayerStats(nextBatsmanId, true);
        }
      }

      if (runs % 2 != 0 && !_isWide) _swapBatsmen();

      // Create ball object for commentary/fall of wickets/partnerships
      String bowlerName = _getPlayerName(currentBowler);
      String strikerName = _getPlayerName(currentStriker);
      String nonStrikerName = _getPlayerName(currentNonStriker);
      String batsmanOutName = batsmanOutId != null
          ? _getPlayerName(batsmanOutId)
          : '';
      String fielderName = fielderId != null ? _getPlayerName(fielderId) : '';

      String description = '';
      if (_isWicket) {
        if (wicketType == 'Bowled') {
          description = 'Bowled! $strikerName is clean bowled by $bowlerName.';
        } else if (wicketType == 'Caught') {
          description =
              'OUT! $strikerName is caught by $fielderName off the bowling of $bowlerName.';
        } else if (wicketType == 'LBW') {
          description = 'LBW! $strikerName is trapped in front by $bowlerName.';
        } else if (wicketType == 'Stumped') {
          description =
              'OUT! Stumped! $strikerName steps out and is stumped by $fielderName off the bowling of $bowlerName.';
        } else if (wicketType == 'Striker Runout') {
          description =
              'OUT! Run Out! $strikerName is run out by $fielderName.';
        } else if (wicketType == 'Non-Striker Runout') {
          description =
              'OUT! Run Out! $nonStrikerName is run out by $fielderName.';
        } else if (wicketType == 'Hit Wicket') {
          description =
              'OUT! Hit Wicket! $strikerName hits their own stumps off $bowlerName.';
        } else {
          description =
              'OUT! $batsmanOutName is out off the bowling of $bowlerName.';
        }
      } else {
        String extrasText = '';
        if (_isWide)
          extrasText = ' (Wide)';
        else if (_isNoBall)
          extrasText = ' (No Ball)';
        else if (_isByes)
          extrasText = ' (Byes)';
        else if (_isLegByes)
          extrasText = ' (Leg Byes)';

        if (runs == 0) {
          description = '$bowlerName to $strikerName, no run$extrasText.';
        } else if (runs == 4) {
          description =
              'FOUR! $bowlerName to $strikerName, driven away for a boundary$extrasText!';
        } else if (runs == 6) {
          description =
              'SIX! $bowlerName to $strikerName, launched over the ropes for a maximum$extrasText!';
        } else {
          description =
              '$bowlerName to $strikerName, $runs run${runs > 1 ? 's' : ''}$extrasText.';
        }
      }

      final ballRecord = {
        'over': overStr,
        'strikerId': currentStriker,
        'nonStrikerId': currentNonStriker,
        'bowlerId': currentBowler,
        'runs': runs,
        'isWide': _isWide,
        'isNoBall': _isNoBall,
        'isByes': _isByes,
        'isLegByes': _isLegByes,
        'isWicket': _isWicket,
        'wicketType': wicketType,
        'fielderId': fielderId,
        'batsmanOutId': batsmanOutId,
        'runsToAdd': runsToAdd,
        'label': ballLabel,
        'description': description,
        'teamScore': _battingTeam == 1 ? _match.team1Score : _match.team2Score,
        'teamWickets': _battingTeam == 1
            ? _match.team1Wickets
            : _match.team2Wickets,
      };

      List<dynamic> ballsList = List.from(
        _match.matchData['balls_$_currentInnings'] ?? [],
      );
      ballsList.add(ballRecord);
      _match.matchData['balls_$_currentInnings'] = ballsList;

      // --- Consecutive tracking & Celebration triggering ---
      final String batsmanId = currentStriker;
      final String bowlerId = currentBowler;

      bool triggerCelebration = false;
      String celebrationMainText = "";
      String celebrationSub = "";

      if (!_isWide && !_isNoBall) {
        if (runs == 6 && !_isByes && !_isLegByes) {
          _batsmanConsecutiveSixes[batsmanId] =
              (_batsmanConsecutiveSixes[batsmanId] ?? 0) + 1;
          _batsmanConsecutiveFours[batsmanId] = 0;
          _bowlerConsecutiveWickets = 0;

          final batsmanName = _getPlayerName(batsmanId);
          if (_batsmanConsecutiveSixes[batsmanId] == 3) {
            triggerCelebration = true;
            celebrationMainText = "HAT-TRICK OF SIXES!";
            celebrationSub =
                "3 consecutive maximums by $batsmanName! Unbelievable hitting!";
          } else {
            triggerCelebration = true;
            final phrase =
                _sixPhrases[math.Random().nextInt(_sixPhrases.length)];
            celebrationMainText = phrase;
            celebrationSub = "by $batsmanName";
          }
        } else if (runs == 4 && !_isByes && !_isLegByes) {
          _batsmanConsecutiveFours[batsmanId] =
              (_batsmanConsecutiveFours[batsmanId] ?? 0) + 1;
          _batsmanConsecutiveSixes[batsmanId] = 0;
          _bowlerConsecutiveWickets = 0;

          final batsmanName = _getPlayerName(batsmanId);
          if (_batsmanConsecutiveFours[batsmanId] == 3) {
            triggerCelebration = true;
            celebrationMainText = "HAT-TRICK OF FOURS!";
            celebrationSub =
                "3 consecutive boundaries by $batsmanName! Pure elegance!";
          } else {
            triggerCelebration = true;
            final phrase =
                _fourPhrases[math.Random().nextInt(_fourPhrases.length)];
            celebrationMainText = phrase;
            celebrationSub = "by $batsmanName";
          }
        } else {
          _batsmanConsecutiveSixes[batsmanId] = 0;
          _batsmanConsecutiveFours[batsmanId] = 0;

          if (_isWicket && !isRunOut) {
            _bowlerConsecutiveWickets++;
            final bowlerName = _getPlayerName(bowlerId);
            if (_bowlerConsecutiveWickets == 3) {
              triggerCelebration = true;
              celebrationMainText = "HAT-TRICK OF WICKETS!!!";
              celebrationSub =
                  "3 wickets in 3 balls for $bowlerName! Sensational bowling!";
            } else {
              triggerCelebration = true;
              final phrase =
                  _wicketPhrases[math.Random().nextInt(_wicketPhrases.length)];
              celebrationMainText = phrase;
              celebrationSub = "by $bowlerName";
            }
          } else {
            _bowlerConsecutiveWickets = 0;
          }
        }
      } else {
        _batsmanConsecutiveSixes[batsmanId] = 0;
        _batsmanConsecutiveFours[batsmanId] = 0;
        _bowlerConsecutiveWickets = 0;
      }

      if (triggerCelebration) {
        _celebrationText = celebrationMainText;
        _celebrationSubtitle = celebrationSub;
        _isDisplayingCelebration = true;

        _celebrationTimer?.cancel();
        _celebrationTimer = Timer(const Duration(milliseconds: 2500), () {
          if (mounted) {
            _dismissCelebration();
          }
        });
      }

      // Reset checkboxes
      _isWide = false;
      _isNoBall = false;
      _isByes = false;
      _isLegByes = false;
      _isWicket = false;
    });

    Future.delayed(Duration.zero, () {
      if (mounted) _saveState();
    });

    _checkMatchStatus(overJustCompleted: overCompletedOnThisBall);
  }

  void _checkMatchStatus({bool overJustCompleted = false}) {
    bool inningsOver = false;
    bool matchOver = false;

    int currentScore = _battingTeam == 1
        ? _match.team1Score
        : _match.team2Score;
    int currentWickets = _battingTeam == 1
        ? _match.team1Wickets
        : _match.team2Wickets;
    double currentOvers = _battingTeam == 1
        ? _match.team1Overs
        : _match.team2Overs;

    // Check target passed
    if (_currentInnings == 2) {
      int targetScore =
          (_battingTeam == 2 ? _match.team1Score : _match.team2Score) + 1;
      if (currentScore >= targetScore) {
        inningsOver = true;
        matchOver = true;
      }
    }

    // Check wickets or overs dynamically based on team size
    List teamPlayers = _battingTeam == 1
        ? (_match.matchData['team1Players'] ?? [])
        : (_match.matchData['team2Players'] ?? []);
    int maxWickets = teamPlayers.isNotEmpty ? (teamPlayers.length - 1) : 10;
    if (maxWickets < 1) maxWickets = 10;

    if (currentWickets >= maxWickets ||
        currentOvers >= _maxOversForCurrentInnings) {
      inningsOver = true;
      if (_currentInnings == 2) matchOver = true;
    }

    final provider = Provider.of<CricketProvider>(context, listen: false);
    List<dynamic> battingTeamIds = _battingTeam == 1
        ? _match.matchData['team1Players']
        : _match.matchData['team2Players'];
    List<Player> battingTeam = provider.players
        .where((p) => battingTeamIds.contains(p.id))
        .toList();

    bool noActiveBatsmenPair = _strikerId == null || _nonStrikerId == null;
    if (noActiveBatsmenPair && !inningsOver) {
      List<Player> available = battingTeam.where((p) {
        if (p.id == _strikerId || p.id == _nonStrikerId) return false;
        final stats = _getStats(p.id);
        final hasNotBatted =
            (stats['balls'] ?? 0) == 0 && (stats['runs'] ?? 0) == 0;
        final isRetired = _retiredPlayerIds.contains(p.id);
        return hasNotBatted || isRetired;
      }).toList();
      if (available.isEmpty) {
        inningsOver = true;
        if (_currentInnings == 2) matchOver = true;
      }
    }

    if (matchOver) {
      _endMatch();
    } else if (inningsOver) {
      _endInnings();
    } else if (overJustCompleted && currentOvers < _maxOversForCurrentInnings) {
      if (_isDisplayingCelebration ||
          _isDisplayingPlayerStats ||
          _playerStatsQueue.isNotEmpty) {
        _promptBowlerPending = true;
      } else {
        _promptNextBowler();
      }
    } else if (_isWicket) {
      // Future feature: prompt next batsman
    }
  }

  void _promptNextBowler() {
    List<dynamic> bowlingTeamIds = _battingTeam == 1
        ? _match.matchData['team2Players']
        : _match.matchData['team1Players'];
    final allPlayers = Provider.of<CricketProvider>(
      context,
      listen: false,
    ).players;
    List<Player> bowlingTeam = allPlayers
        .where((p) => bowlingTeamIds.contains(p.id) && p.id != _bowlerId)
        .toList();

    Player? selected;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text(
              'Select Next Bowler',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white54),
              onPressed: () => Navigator.pop(ctx),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (selected == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select a bowler.')),
                    );
                    return;
                  }
                  setState(() {
                    _bowlerId = selected!.id;
                    _saveState();
                  });
                  _enqueuePlayerStats(selected!.id, false);
                  Navigator.pop(ctx);
                },
                child: const Text(
                  'DONE',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(24.0),
            child: DropdownButtonFormField<Player>(
              dropdownColor: Theme.of(context).colorScheme.surface,
              hint: const Text(
                'Bowler',
                style: TextStyle(color: Colors.white54),
              ),
              items: bowlingTeam
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(
                        e.name,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (val) => selected = val,
            ),
          ),
        ),
      ),
    );
  }

  void _endInnings() {
    int target =
        (_battingTeam == 1 ? _match.team1Score : _match.team2Score) + 1;
    double maxOvers2ndInnings = _match.matchData['dls_target_overs'] != null
        ? (_match.matchData['dls_target_overs'] as num).toDouble()
        : _match.overs.toDouble();
    int balls = _overDecimalToBalls(maxOvers2ndInnings);
    String oversText = _match.matchData['dls_target_overs'] != null
        ? '${maxOvers2ndInnings.toStringAsFixed(1)} overs'
        : '${_match.overs} overs';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text(
              'Innings Break',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false, // Must select to continue
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'First innings is over.\nTarget: $target runs in $balls balls ($oversText).',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 22,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _currentInnings = 2;
                        _battingTeam = _battingTeam == 1 ? 2 : 1;
                        _strikerId = null;
                        _nonStrikerId = null;
                        _bowlerId = null;
                        _ballsInCurrentOver = 0;
                        _currentOverBalls.clear();
                        _saveState();
                      });
                      RewardedAdHelper.showAd();
                      _promptNewInningsOpeners();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text(
                      'START 2ND INNINGS',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _promptNewInningsOpeners() {
    List<dynamic> battingTeamIds = _battingTeam == 1
        ? _match.matchData['team1Players']
        : _match.matchData['team2Players'];
    List<dynamic> bowlingTeamIds = _battingTeam == 1
        ? _match.matchData['team2Players']
        : _match.matchData['team1Players'];
    final allPlayers = Provider.of<CricketProvider>(
      context,
      listen: false,
    ).players;
    List<Player> battingTeam = allPlayers
        .where((p) => battingTeamIds.contains(p.id))
        .toList();
    List<Player> bowlingTeam = allPlayers
        .where((p) => bowlingTeamIds.contains(p.id))
        .toList();

    Player? st;
    Player? nst;
    Player? bw;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => Dialog.fullscreen(
          backgroundColor: Colors.black87,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: const Text(
                '2nd Innings Openers',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              automaticallyImplyLeading: false, // Must select to continue
              actions: [
                TextButton(
                  onPressed: () {
                    if (st == null || nst == null || bw == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select all players.'),
                        ),
                      );
                      return;
                    }
                    if (st == nst) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Striker and Non-Striker must be different.',
                          ),
                        ),
                      );
                      return;
                    }

                    setState(() {
                      _strikerId = st!.id;
                      _nonStrikerId = nst!.id;
                      _bowlerId = bw!.id;
                      _saveState();
                    });
                    _enqueuePlayerStats(st!.id, true);
                    _enqueuePlayerStats(nst!.id, true);
                    _enqueuePlayerStats(bw!.id, false);
                    Navigator.pop(ctx);
                  },
                  child: const Text(
                    'START',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Player>(
                    dropdownColor: Theme.of(context).colorScheme.surface,
                    hint: const Text(
                      'Striker',
                      style: TextStyle(color: Colors.white54),
                    ),
                    items: battingTeam
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(
                              e.name,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setStateDialog(() => st = val),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<Player>(
                    dropdownColor: Theme.of(context).colorScheme.surface,
                    hint: const Text(
                      'Non-Striker',
                      style: TextStyle(color: Colors.white54),
                    ),
                    items: battingTeam
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(
                              e.name,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setStateDialog(() => nst = val),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<Player>(
                    dropdownColor: Theme.of(context).colorScheme.surface,
                    hint: const Text(
                      'Bowler',
                      style: TextStyle(color: Colors.white54),
                    ),
                    items: bowlingTeam
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(
                              e.name,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setStateDialog(() => bw = val),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _updateCumulativePlayerStats() {
    final provider = Provider.of<CricketProvider>(context, listen: false);
    List<Player> updatedPlayers = [];

    List<dynamic> allMatchPlayerIds = [];
    allMatchPlayerIds.addAll(_match.matchData['team1Players'] ?? []);
    allMatchPlayerIds.addAll(_match.matchData['team2Players'] ?? []);

    String? team1Captain = _match.matchData['team1Captain'];
    String? team2Captain = _match.matchData['team2Captain'];

    int winningTeam = 0;
    if (_match.team1Score > _match.team2Score)
      winningTeam = 1;
    else if (_match.team2Score > _match.team1Score)
      winningTeam = 2;

    Map<String, Map<String, int>> fielderStats = {};
    for (var playerId in allMatchPlayerIds) {
      fielderStats[playerId] = {'catches': 0, 'stumpings': 0, 'runOuts': 0};
    }
    for (int innings = 1; innings <= 2; innings++) {
      List<dynamic> ballsList = _match.matchData['balls_$innings'] ?? [];
      for (var ball in ballsList) {
        bool isWicket = ball['isWicket'] ?? false;
        String? wicketType = ball['wicketType'];
        String? fielderId = ball['fielderId'];
        if (isWicket &&
            fielderId != null &&
            fielderStats.containsKey(fielderId)) {
          if (wicketType == 'Caught') {
            fielderStats[fielderId]!['catches'] =
                (fielderStats[fielderId]!['catches'] ?? 0) + 1;
          } else if (wicketType == 'Stumped') {
            fielderStats[fielderId]!['stumpings'] =
                (fielderStats[fielderId]!['stumpings'] ?? 0) + 1;
          } else if (wicketType == 'Striker Runout' ||
              wicketType == 'Non-Striker Runout') {
            fielderStats[fielderId]!['runOuts'] =
                (fielderStats[fielderId]!['runOuts'] ?? 0) + 1;
          }
        }
      }
    }

    for (var playerId in allMatchPlayerIds) {
      final playerIndex = provider.players.indexWhere((p) => p.id == playerId);
      if (playerIndex == -1) continue;

      Player player = provider.players[playerIndex];
      bool isModified = false;

      player.battingMatches++;
      player.bowlingMatches++;
      player.fieldingMatches++;
      isModified = true;

      final fStats = fielderStats[player.id];
      if (fStats != null) {
        player.fieldingCatches += fStats['catches'] ?? 0;
        player.fieldingStumpings += fStats['stumpings'] ?? 0;
        player.fieldingRunOuts += fStats['runOuts'] ?? 0;
      }

      if (player.id == team1Captain) {
        player.captaincyMatches++;
        if (winningTeam == 1)
          player.captaincyWon++;
        else if (winningTeam == 2)
          player.captaincyLost++;
      } else if (player.id == team2Captain) {
        player.captaincyMatches++;
        if (winningTeam == 2)
          player.captaincyWon++;
        else if (winningTeam == 1)
          player.captaincyLost++;
      }

      final stats = _playerStats[player.id];
      if (stats != null && stats is Map) {
        int balls = stats['balls'] ?? 0;
        int runs = stats['runs'] ?? 0;

        if (balls > 0 || runs > 0) {
          player.battingInnings++;
          player.battingRuns += runs;
          player.battingBalls += balls;
          player.battingFours += (stats['4s'] ?? 0) as int;
          player.battingSixes += (stats['6s'] ?? 0) as int;

          if (runs > player.battingBestScore) player.battingBestScore = runs;
          if (runs >= 100)
            player.battingHundreds++;
          else if (runs >= 50)
            player.battingFifties++;
          else if (runs >= 30)
            player.battingThirties++;

          if (runs == 0 && balls > 0) {
            player.battingDucks++;
            if (balls == 1) player.battingGoldenDucks++;
          }

          int dismissals = player.battingInnings - player.battingNotOuts;
          if (dismissals > 0)
            player.battingAverage = player.battingRuns / dismissals;
          else
            player.battingAverage = player.battingRuns.toDouble();

          if (player.battingBalls > 0) {
            player.battingStrikeRate =
                (player.battingRuns / player.battingBalls) * 100;
          } else {
            player.battingStrikeRate = 0.0;
          }
        }

        int bowledBalls = stats['bowledBalls'] ?? 0;
        if (bowledBalls > 0) {
          player.bowlingInnings++;
          int runsConceded = (stats['runsConceded'] ?? 0) as int;
          player.bowlingRunsConceded += runsConceded;
          int matchWickets = (stats['wickets'] ?? 0) as int;
          player.bowlingWickets += matchWickets;
          player.bowlingMaidens += (stats['maidens'] ?? 0) as int;

          if (matchWickets > player.bowlingBestWickets ||
              (matchWickets == player.bowlingBestWickets &&
                  runsConceded < player.bowlingBestRuns) ||
              (player.bowlingBestWickets == 0 && matchWickets > 0)) {
            player.bowlingBestWickets = matchWickets;
            player.bowlingBestRuns = runsConceded;
          }

          if (matchWickets >= 10)
            player.bowling10W++;
          else if (matchWickets >= 7)
            player.bowling7W++;
          else if (matchWickets >= 5)
            player.bowling5W++;
          else if (matchWickets >= 3)
            player.bowling3W++;

          int totalBalls =
              (player.bowlingOvers.floor() * 6) +
              ((player.bowlingOvers - player.bowlingOvers.floor()) * 10)
                  .round();
          totalBalls += bowledBalls;
          player.bowlingOvers = (totalBalls ~/ 6) + ((totalBalls % 6) / 10.0);

          if (player.bowlingOvers > 0) {
            player.bowlingEconomy =
                player.bowlingRunsConceded / player.bowlingOvers;
          }

          if (player.bowlingWickets > 0) {
            player.bowlingAverage =
                player.bowlingRunsConceded / player.bowlingWickets;
            player.bowlingStrikeRate = totalBalls / player.bowlingWickets;
          } else {
            player.bowlingAverage = 0.0;
            player.bowlingStrikeRate = 0.0;
          }
        }
      }

      if (isModified) {
        updatedPlayers.add(player);
      }
    }

    if (updatedPlayers.isNotEmpty) {
      provider.updatePlayers(updatedPlayers);
    }
  }

  void _endMatch() {
    if (!_match.isCompleted) {
      _updateCumulativePlayerStats();
    }
    setState(() {
      _match.isCompleted = true;

      // Determine batting order
      int firstBattingTeam = _battingTeam == 1 ? 2 : 1;
      int secondBattingTeam = _battingTeam;

      int firstBatScore = firstBattingTeam == 1
          ? _match.team1Score
          : _match.team2Score;
      int secondBatScore = secondBattingTeam == 1
          ? _match.team1Score
          : _match.team2Score;

      int secondBatWickets = secondBattingTeam == 1
          ? _match.team1Wickets
          : _match.team2Wickets;

      String firstBatName = firstBattingTeam == 1
          ? _match.team1Name
          : _match.team2Name;
      String secondBatName = secondBattingTeam == 1
          ? _match.team1Name
          : _match.team2Name;

      List teamPlayers = secondBattingTeam == 1
          ? (_match.matchData['team1Players'] ?? [])
          : (_match.matchData['team2Players'] ?? []);
      int maxWickets = teamPlayers.isNotEmpty ? (teamPlayers.length - 1) : 10;
      if (maxWickets < 1) maxWickets = 10;
      int wicketsRemaining = maxWickets - secondBatWickets;
      if (wicketsRemaining < 0) wicketsRemaining = 0;

      if (firstBatScore > secondBatScore) {
        _match.result =
            '$firstBatName won by ${firstBatScore - secondBatScore} runs';
      } else if (secondBatScore > firstBatScore) {
        _match.result = '$secondBatName won by $wicketsRemaining wickets';
      } else {
        _match.result = 'Match Tied';
      }

      _saveState();
    });

    RewardedAdHelper.showAd();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text(
              'MATCH COMPLETED',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
          ),
          body: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const SizedBox(height: 10),
                // Glowing Trophy or Medal icon
                const Icon(
                  Icons.emoji_events,
                  color: Colors.amber,
                  size: 64,
                ).animate().scale(
                  delay: 200.ms,
                  duration: 400.ms,
                  curve: Curves.elasticOut,
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    _match.result,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(
                          color: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.5),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
                const SizedBox(height: 20),

                // Scorecard title
                const Text(
                  'MATCH SCORECARD',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),

                TabBar(
                  indicatorColor: Theme.of(context).primaryColor,
                  labelColor: Theme.of(context).primaryColor,
                  unselectedLabelColor: Colors.white54,
                  tabs: [
                    Tab(text: '${_match.team1Name} Innings'),
                    Tab(text: '${_match.team2Name} Innings'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      ScorecardInningsView(
                        match: _match,
                        teamName: _match.team1Name,
                        score: _match.team1Score,
                        wickets: _match.team1Wickets,
                        overs: _match.team1Overs,
                        battingTeamIds: _match.matchData['team1Players'] ?? [],
                        bowlingTeamIds: _match.matchData['team2Players'] ?? [],
                      ),
                      ScorecardInningsView(
                        match: _match,
                        teamName: _match.team2Name,
                        score: _match.team2Score,
                        wickets: _match.team2Wickets,
                        overs: _match.team2Overs,
                        battingTeamIds: _match.matchData['team2Players'] ?? [],
                        bowlingTeamIds: _match.matchData['team1Players'] ?? [],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 16.0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            RewardedAdHelper.showAd();
                            Navigator.pop(ctx);
                            Navigator.pop(context);

                            final provider = Provider.of<CricketProvider>(
                              context,
                              listen: false,
                            );
                            final t1Ids = List<String>.from(
                              _match.matchData['team1Players'] ?? [],
                            );
                            final t2Ids = List<String>.from(
                              _match.matchData['team2Players'] ?? [],
                            );
                            final t1Players = t1Ids
                                .map(
                                  (id) => provider.players.firstWhere(
                                    (p) => p.id == id,
                                    orElse: () => Player(id: '', name: ''),
                                  ),
                                )
                                .where((p) => p.id.isNotEmpty)
                                .toList();
                            final t2Players = t2Ids
                                .map(
                                  (id) => provider.players.firstWhere(
                                    (p) => p.id == id,
                                    orElse: () => Player(id: '', name: ''),
                                  ),
                                )
                                .where((p) => p.id.isNotEmpty)
                                .toList();

                            Player? t1Cap;
                            Player? t2Cap;
                            if (_match.matchData['team1Captain'] != null) {
                              t1Cap = provider.players.firstWhere(
                                (p) => p.id == _match.matchData['team1Captain'],
                                orElse: () => Player(id: '', name: ''),
                              );
                              if (t1Cap.id.isEmpty) t1Cap = null;
                            }
                            if (_match.matchData['team2Captain'] != null) {
                              t2Cap = provider.players.firstWhere(
                                (p) => p.id == _match.matchData['team2Captain'],
                                orElse: () => Player(id: '', name: ''),
                              );
                              if (t2Cap.id.isEmpty) t2Cap = null;
                            }

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RematchRosterScreen(
                                  team1Name: _match.team1Name,
                                  team2Name: _match.team2Name,
                                  team1Image: _match.matchData['team1Image'],
                                  team2Image: _match.matchData['team2Image'],
                                  team1Players: t1Players,
                                  team2Players: t2Players,
                                  team1Captain: t1Cap,
                                  team2Captain: t2Cap,
                                ),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: Colors.cyanAccent,
                              width: 1.5,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            "LET'S PLAY AGAIN",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.cyanAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            RewardedAdHelper.showAd();
                            Navigator.pop(ctx);
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 8,
                            shadowColor: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.4),
                          ),
                          child: const Text(
                            'FINISH',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _checkAndInitPartnership() {
    final currentStriker = _strikerId;
    final currentNonStriker = _nonStrikerId;
    if (currentStriker == null || currentNonStriker == null) return;

    final savedStriker = _match.matchData['partnership_strikerId'];
    final savedNonStriker = _match.matchData['partnership_nonStrikerId'];

    bool isSamePair =
        (currentStriker == savedStriker &&
            currentNonStriker == savedNonStriker) ||
        (currentStriker == savedNonStriker &&
            currentNonStriker == savedStriker);

    if (!isSamePair) {
      final sStats = _getStats(currentStriker);
      final nsStats = _getStats(currentNonStriker);
      int teamScore = _battingTeam == 1 ? _match.team1Score : _match.team2Score;
      int teamWickets = _battingTeam == 1
          ? _match.team1Wickets
          : _match.team2Wickets;
      double teamOvers = _battingTeam == 1
          ? _match.team1Overs
          : _match.team2Overs;

      _match.matchData['partnership_strikerId'] = currentStriker;
      _match.matchData['partnership_nonStrikerId'] = currentNonStriker;
      _match.matchData['partnership_strikerRunsAtStart'] = sStats['runs'] ?? 0;
      _match.matchData['partnership_strikerBallsAtStart'] =
          sStats['balls'] ?? 0;
      _match.matchData['partnership_nonStrikerRunsAtStart'] =
          nsStats['runs'] ?? 0;
      _match.matchData['partnership_nonStrikerBallsAtStart'] =
          nsStats['balls'] ?? 0;
      _match.matchData['partnership_teamScoreAtStart'] = teamScore;
      _match.matchData['partnership_teamWicketsAtStart'] = teamWickets;
      _match.matchData['partnership_teamOversAtStart'] = teamOvers;
    }
  }

  void _handleDlsClick() {
    if (_currentInnings != 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('DLS can only be applied during the 1st innings.'),
        ),
      );
      return;
    }

    final double currentOvers = _battingTeam == 1
        ? _match.team1Overs
        : _match.team2Overs;
    final int currentScore = _battingTeam == 1
        ? _match.team1Score
        : _match.team2Score;

    if (currentOvers == 0.0 && currentScore == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No balls have been bowled yet in the 1st innings.'),
        ),
      );
      return;
    }

    final int targetScore = currentScore + 1;
    final int targetBalls = _overDecimalToBalls(currentOvers);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Apply DLS',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(color: Colors.white10),
              const SizedBox(height: 16),
              const Text(
                'Are you sure you want to apply DLS and end the 1st innings now?',
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '1st Innings: $currentScore runs in ${currentOvers.toStringAsFixed(1)} overs',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '2nd Innings Target: $targetScore runs in ${currentOvers.toStringAsFixed(1)} overs ($targetBalls balls)',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _match.matchData['dls_target_overs'] = currentOvers;
                      });
                      _endInnings();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                    ),
                    child: const Text(
                      'Confirm',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPartnershipDialog() {
    final striker = _strikerId;
    final nonStriker = _nonStrikerId;
    if (striker == null || nonStriker == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No active partnership.')));
      return;
    }

    final sStats = _getStats(striker);
    final nsStats = _getStats(nonStriker);

    int teamScore = _battingTeam == 1 ? _match.team1Score : _match.team2Score;
    double teamOvers = _battingTeam == 1
        ? _match.team1Overs
        : _match.team2Overs;

    String? pStrikerId = _match.matchData['partnership_strikerId'];
    int sRunsAtStart = _match.matchData['partnership_strikerRunsAtStart'] ?? 0;
    int sBallsAtStart =
        _match.matchData['partnership_strikerBallsAtStart'] ?? 0;
    int nsRunsAtStart =
        _match.matchData['partnership_nonStrikerRunsAtStart'] ?? 0;
    int nsBallsAtStart =
        _match.matchData['partnership_nonStrikerBallsAtStart'] ?? 0;
    int teamScoreAtStart =
        _match.matchData['partnership_teamScoreAtStart'] ?? 0;
    double teamOversAtStart =
        _match.matchData['partnership_teamOversAtStart'] ?? 0.0;

    int strikerContribRuns = 0;
    int strikerContribBalls = 0;
    int nonStrikerContribRuns = 0;
    int nonStrikerContribBalls = 0;

    if (striker == pStrikerId) {
      strikerContribRuns = (sStats['runs'] ?? 0) - sRunsAtStart;
      strikerContribBalls = (sStats['balls'] ?? 0) - sBallsAtStart;
      nonStrikerContribRuns = (nsStats['runs'] ?? 0) - nsRunsAtStart;
      nonStrikerContribBalls = (nsStats['balls'] ?? 0) - nsBallsAtStart;
    } else {
      strikerContribRuns = (sStats['runs'] ?? 0) - nsRunsAtStart;
      strikerContribBalls = (sStats['balls'] ?? 0) - nsBallsAtStart;
      nonStrikerContribRuns = (nsStats['runs'] ?? 0) - sRunsAtStart;
      nonStrikerContribBalls = (nsStats['balls'] ?? 0) - sBallsAtStart;
    }

    int totalRuns = teamScore - teamScoreAtStart;
    int totalBalls = strikerContribBalls + nonStrikerContribBalls;

    int extrasContrib =
        totalRuns - (strikerContribRuns + nonStrikerContribRuns);
    if (extrasContrib < 0) extrasContrib = 0;

    double strikerPct = totalRuns > 0
        ? (strikerContribRuns / totalRuns) * 100
        : 0.0;
    double nonStrikerPct = totalRuns > 0
        ? (nonStrikerContribRuns / totalRuns) * 100
        : 0.0;
    double extrasPct = totalRuns > 0 ? (extrasContrib / totalRuns) * 100 : 0.0;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Current Partnership',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(color: Colors.white10),
              const SizedBox(height: 16),
              Text(
                '$totalRuns Runs',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'off $totalBalls balls',
                style: const TextStyle(fontSize: 16, color: Colors.white54),
              ),
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 14,
                  width: double.infinity,
                  color: Colors.white10,
                  child: Row(
                    children: [
                      if (strikerContribRuns > 0)
                        Expanded(
                          flex: strikerContribRuns,
                          child: Container(
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      if (nonStrikerContribRuns > 0)
                        Expanded(
                          flex: nonStrikerContribRuns,
                          child: Container(color: Colors.tealAccent),
                        ),
                      if (extrasContrib > 0)
                        Expanded(
                          flex: extrasContrib,
                          child: Container(color: Colors.orangeAccent),
                        ),
                      if (totalRuns == 0)
                        Expanded(child: Container(color: Colors.white24)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildPartnershipRow(
                context,
                '${_getPlayerName(striker)} *',
                strikerContribRuns,
                strikerContribBalls,
                strikerPct,
                Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 12),
              _buildPartnershipRow(
                context,
                _getPlayerName(nonStriker),
                nonStrikerContribRuns,
                nonStrikerContribBalls,
                nonStrikerPct,
                Colors.tealAccent,
              ),
              const SizedBox(height: 12),
              _buildPartnershipRow(
                context,
                'Extras',
                extrasContrib,
                null,
                extrasPct,
                Colors.orangeAccent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPartnershipRow(
    BuildContext context,
    String name,
    int runs,
    int? balls,
    double percent,
    Color dotColor,
  ) {
    final ballsText = balls != null ? ' ($balls b)' : '';
    final pctText = percent.toStringAsFixed(0);
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '$runs$ballsText',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 40,
          child: Text(
            '$pctText%',
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ),
      ],
    );
  }

  void _promptRetire() {
    if (_strikerId == null && _nonStrikerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active batsmen to retire.')),
      );
      return;
    }

    final provider = Provider.of<CricketProvider>(context, listen: false);
    List<dynamic> battingTeamIds = _battingTeam == 1
        ? _match.matchData['team1Players']
        : _match.matchData['team2Players'];
    List<Player> battingTeam = provider.players
        .where((p) => battingTeamIds.contains(p.id))
        .toList();

    List<Player> availableNextBatsmen = battingTeam.where((p) {
      if (p.id == _strikerId || p.id == _nonStrikerId) return false;
      final stats = _getStats(p.id);
      final hasNotBatted =
          (stats['balls'] ?? 0) == 0 && (stats['runs'] ?? 0) == 0;
      final isRetired = _retiredPlayerIds.contains(p.id);
      return hasNotBatted || isRetired;
    }).toList();

    if (availableNextBatsmen.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text(
            'Retire Batsman',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'No other batsmen are available to replace the retiring batsman.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'OK',
                style: TextStyle(color: Colors.tealAccent),
              ),
            ),
          ],
        ),
      );
      return;
    }

    String? retiringBatsmanId;
    Player? nextBatsman;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => Dialog.fullscreen(
          backgroundColor: Colors.black87,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: const Text(
                'Retire Batsman',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => Navigator.pop(ctx),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (retiringBatsmanId == null || nextBatsman == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select both fields.'),
                        ),
                      );
                      return;
                    }

                    final prevMatchState = jsonDecode(
                      jsonEncode(_match.toJson()),
                    );
                    _ballTimeline.add({
                      'matchState': prevMatchState,
                      'strikerId': _strikerId,
                      'nonStrikerId': _nonStrikerId,
                      'bowlerId': _bowlerId,
                      'ballsInCurrentOver': _ballsInCurrentOver,
                      'currentOverBalls': List.from(_currentOverBalls),
                      'playerStats': jsonDecode(jsonEncode(_playerStats)),
                    });

                    setState(() {
                      if (!_retiredPlayerIds.contains(retiringBatsmanId)) {
                        _retiredPlayerIds.add(retiringBatsmanId);
                      }

                      _retiredPlayerIds.remove(nextBatsman!.id);

                      // Add a special retire record to the balls list
                      String retiringName = _getPlayerName(retiringBatsmanId);
                      String nextName = nextBatsman!.name;
                      int oversFloor =
                          (_battingTeam == 1
                                  ? _match.team1Overs
                                  : _match.team2Overs)
                              .floor();
                      String overStr = '$oversFloor.$_ballsInCurrentOver';

                      final retireRecord = {
                        'over': overStr,
                        'strikerId': _strikerId,
                        'nonStrikerId': _nonStrikerId,
                        'bowlerId': _bowlerId,
                        'runs': 0,
                        'isWide': false,
                        'isNoBall': false,
                        'isByes': false,
                        'isLegByes': false,
                        'isWicket': false,
                        'isRetirement': true,
                        'retiringBatsmanId': retiringBatsmanId,
                        'nextBatsmanId': nextBatsman!.id,
                        'label': 'Ret',
                        'description':
                            '$retiringName retired. $nextName came to the crease.',
                        'teamScore': _battingTeam == 1
                            ? _match.team1Score
                            : _match.team2Score,
                        'teamWickets': _battingTeam == 1
                            ? _match.team1Wickets
                            : _match.team2Wickets,
                      };

                      List<dynamic> ballsList = List.from(
                        _match.matchData['balls_$_currentInnings'] ?? [],
                      );
                      ballsList.add(retireRecord);
                      _match.matchData['balls_$_currentInnings'] = ballsList;

                      if (retiringBatsmanId == _strikerId) {
                        _strikerId = nextBatsman!.id;
                      } else {
                        _nonStrikerId = nextBatsman!.id;
                      }

                      _saveState();
                    });
                    _enqueuePlayerStats(nextBatsman!.id, true);

                    Navigator.pop(ctx);
                  },
                  child: const Text(
                    'DONE',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    dropdownColor: Theme.of(context).colorScheme.surface,
                    value: retiringBatsmanId,
                    decoration: const InputDecoration(
                      labelText: 'Batsman to Retire',
                      labelStyle: TextStyle(color: Colors.white54),
                    ),
                    items: [
                      if (_strikerId != null)
                        DropdownMenuItem(
                          value: _strikerId,
                          child: Text(
                            '${_getPlayerName(_strikerId)} (Striker)',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      if (_nonStrikerId != null)
                        DropdownMenuItem(
                          value: _nonStrikerId,
                          child: Text(
                            '${_getPlayerName(_nonStrikerId)} (Non-Striker)',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                    ],
                    onChanged: (val) =>
                        setStateDialog(() => retiringBatsmanId = val),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<Player>(
                    dropdownColor: Theme.of(context).colorScheme.surface,
                    value: nextBatsman,
                    decoration: const InputDecoration(
                      labelText: 'Select New Batsman',
                      labelStyle: TextStyle(color: Colors.white54),
                    ),
                    items: availableNextBatsmen
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(
                              _retiredPlayerIds.contains(e.id)
                                  ? '${e.name} (Retired)'
                                  : e.name,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setStateDialog(() => nextBatsman = val),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _swapBatsmen() {
    setState(() {
      final temp = _strikerId;
      _strikerId = _nonStrikerId;
      _nonStrikerId = temp;
    });
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
            hintText: 'Enter number of runs',
            hintStyle: const TextStyle(color: Colors.white38),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white30),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Theme.of(context).primaryColor),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () {
              final val = int.tryParse(controller.text);
              if (val != null && val >= 0) {
                Navigator.pop(context);
                _handleScoreButton(val);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid number of runs'),
                  ),
                );
              }
            },
            child: Text(
              'Done',
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _undoLastBall() {
    if (_ballTimeline.isEmpty) return;
    final lastState = _ballTimeline.removeLast();
    setState(() {
      _match = MatchModel.fromJson(lastState['matchState']);
      _currentInnings = _match.matchData['currentInnings'] ?? 1;
      _battingTeam = _match.matchData['battingTeam'] ?? 1;
      _strikerId = lastState['strikerId'];
      _nonStrikerId = lastState['nonStrikerId'];
      _bowlerId = lastState['bowlerId'];
      _ballsInCurrentOver = lastState['ballsInCurrentOver'];
      _currentOverBalls = List<String>.from(
        lastState['currentOverBalls'] ?? [],
      );
      _playerStats = Map<dynamic, dynamic>.from(lastState['playerStats']);
      _retiredPlayerIds = List<dynamic>.from(
        _match.matchData['retiredPlayerIds'] ?? [],
      );
      _saveState();
    });
  }

  String _getPlayerName(String? id) {
    if (id == null) return '-';
    final p = Provider.of<CricketProvider>(context, listen: false).players
        .firstWhere(
          (p) => p.id == id,
          orElse: () => Player(id: '', name: 'Unknown'),
        );
    return p.name;
  }

  bool _isRunOut() {
    // Basic logic stub for run out Checkbox, since runout is not currently distinguished in extras, we assume Wicket checkbox is Bowled/Caught etc.
    // To be fully accurate, we'd need a specific runout checkbox. For now, Wicket counts to bowler.
    return false;
  }

  String _getBatsmanSR(Map<dynamic, dynamic> stats) {
    int runs = stats['runs'] ?? 0;
    int balls = stats['balls'] ?? 0;
    if (balls == 0) return '0.00';
    return ((runs / balls) * 100).toStringAsFixed(2);
  }

  String _getBowlerER(Map<dynamic, dynamic> stats) {
    int runs = stats['runsConceded'] ?? 0;
    int balls = stats['bowledBalls'] ?? 0;
    if (balls == 0) return '0.00';
    return (runs / (balls / 6)).toStringAsFixed(2);
  }

  String _getBowlerOvers(Map<dynamic, dynamic> stats) {
    int balls = stats['bowledBalls'] ?? 0;
    return '${balls ~/ 6}.${balls % 6}';
  }

  int _overDecimalToBalls(double overs) {
    int whole = overs.floor();
    int part = ((overs - whole) * 10).round();
    return (whole * 6) + part;
  }

  double get _maxOversForCurrentInnings {
    if (_currentInnings == 2 && _match.matchData['dls_target_overs'] != null) {
      return (_match.matchData['dls_target_overs'] as num).toDouble();
    }
    return _match.overs.toDouble();
  }

  double _getCRR() {
    double overs = _battingTeam == 1 ? _match.team1Overs : _match.team2Overs;
    int score = _battingTeam == 1 ? _match.team1Score : _match.team2Score;
    int balls = (overs.floor() * 6) + ((overs - overs.floor()) * 10).round();
    if (balls == 0) return 0.0;
    return (score / balls) * 6;
  }

  Map<String, int> _getFirstInningsScoreAtBalls(int targetLegalBalls) {
    final List<dynamic> balls = _match.matchData['balls_1'] ?? [];
    int score = 0;
    int wickets = 0;
    int legalBallsCount = 0;

    for (var ball in balls) {
      bool isWide = ball['isWide'] ?? false;
      bool isNoBall = ball['isNoBall'] ?? false;
      if (!isWide && !isNoBall) {
        legalBallsCount++;
      }
      if (legalBallsCount <= targetLegalBalls) {
        score = ball['teamScore'] ?? 0;
        wickets = ball['teamWickets'] ?? 0;
      } else {
        break;
      }
    }

    if (targetLegalBalls == 0) {
      return {'score': 0, 'wickets': 0};
    }

    if (legalBallsCount < targetLegalBalls && balls.isNotEmpty) {
      final lastBall = balls.last;
      return {
        'score': lastBall['teamScore'] ?? 0,
        'wickets': lastBall['teamWickets'] ?? 0,
      };
    }

    if (balls.isEmpty) {
      final firstInningsScore = _battingTeam == 2
          ? _match.team1Score
          : _match.team2Score;
      final firstInningsWickets = _battingTeam == 2
          ? _match.team1Wickets
          : _match.team2Wickets;
      return {'score': firstInningsScore, 'wickets': firstInningsWickets};
    }

    return {'score': score, 'wickets': wickets};
  }

  @override
  Widget build(BuildContext context) {
    int currentScore = _battingTeam == 1
        ? _match.team1Score
        : _match.team2Score;
    int currentWickets = _battingTeam == 1
        ? _match.team1Wickets
        : _match.team2Wickets;
    double currentOvers = _battingTeam == 1
        ? _match.team1Overs
        : _match.team2Overs;
    String battingTeamName = _battingTeam == 1
        ? _match.team1Name
        : _match.team2Name;

    int targetScore = 0;
    int runsNeeded = 0;
    int ballsRemaining = 0;
    double rrr = 0.0;
    double maxOvers = _maxOversForCurrentInnings;

    if (_currentInnings == 2) {
      int firstInningsScore = _battingTeam == 2
          ? _match.team1Score
          : _match.team2Score;
      targetScore = firstInningsScore + 1;
      runsNeeded = targetScore - currentScore;
      if (runsNeeded < 0) runsNeeded = 0;

      int totalBalls = _overDecimalToBalls(maxOvers);
      int ballsBowled = _overDecimalToBalls(currentOvers);
      ballsRemaining = totalBalls - ballsBowled;
      if (ballsRemaining < 0) ballsRemaining = 0;

      if (ballsRemaining > 0) {
        rrr = (runsNeeded / ballsRemaining) * 6;
      } else {
        rrr = runsNeeded > 0 ? double.infinity : 0.0;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${_match.team1Name} v/s ${_match.team2Name}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ScorecardScreen(match: _match),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).primaryColor.withOpacity(0.5),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Text(
                    '1:3',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.surface,
                  Theme.of(context).scaffoldBackgroundColor,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Builder(
                    builder: (context) {
                      Widget scoreboardContent = SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            // Top Score Card
                            GlassContainer(
                              padding: const EdgeInsets.all(16),
                              borderRadius: 16,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$battingTeamName, ${_currentInnings == 1 ? "1st" : "2nd"} inning',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '$currentScore - $currentWickets',
                                              style: const TextStyle(
                                                fontSize: 42,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 8.0,
                                              ),
                                              child: Text(
                                                '(${currentOvers.toStringAsFixed(1)})',
                                                style: const TextStyle(
                                                  fontSize: 20,
                                                  color: Colors.white54,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (_currentInnings == 2 &&
                                            !_match.isCompleted) ...[
                                          const SizedBox(height: 8),
                                          Builder(
                                            builder: (context) {
                                              final needText = runsNeeded > 0
                                                  ? 'Need $runsNeeded runs off $ballsRemaining balls'
                                                  : 'Target achieved!';
                                              return Text(
                                                needText,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Theme.of(
                                                    context,
                                                  ).primaryColor,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              );
                                            },
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  if (_currentInnings == 1)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            const Text(
                                              'Proj. Score',
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              (_getCRR() * _match.overs)
                                                  .round()
                                                  .toString(),
                                              style: const TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 20),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            const Text(
                                              'CRR',
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              _getCRR().toStringAsFixed(2),
                                              style: const TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    )
                                  else
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                const Text(
                                                  'CRR',
                                                  style: TextStyle(
                                                    color: Colors.white70,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 10),
                                                Text(
                                                  _getCRR().toStringAsFixed(2),
                                                  style: const TextStyle(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(width: 20),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                const Text(
                                                  'RRR',
                                                  style: TextStyle(
                                                    color: Colors.white70,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 10),
                                                Text(
                                                  rrr.isInfinite
                                                      ? 'N/A'
                                                      : rrr.toStringAsFixed(2),
                                                  style: const TextStyle(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        if (!_match.isCompleted) ...[
                                          const SizedBox(height: 8),
                                          Builder(
                                            builder: (context) {
                                              final targetLegalBalls =
                                                  (currentOvers.floor() * 6) +
                                                  _ballsInCurrentOver;
                                              final firstInnData =
                                                  _getFirstInningsScoreAtBalls(
                                                    targetLegalBalls,
                                                  );
                                              final firstInnScore =
                                                  firstInnData['score'];
                                              final firstInnWickets =
                                                  firstInnData['wickets'];
                                              return Text(
                                                '1st Inn: $firstInnScore-$firstInnWickets',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Theme.of(
                                                    context,
                                                  ).primaryColor,
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ],
                                    ),
                                ],
                              ),
                            ).animate().fadeIn().slideY(begin: -0.1, end: 0),

                            const SizedBox(height: 12),

                            // Batsman / Bowler Table
                            GlassContainer(
                                  padding: const EdgeInsets.all(16),
                                  borderRadius: 16,
                                  child: Column(
                                    children: [
                                      _buildTableHeader([
                                        'Batsman',
                                        'R',
                                        'B',
                                        '4s',
                                        '6s',
                                        'SR',
                                      ]),
                                      const Divider(color: Color(0x3D1B5E20)),
                                      Builder(
                                        builder: (context) {
                                          final sStats = _getStats(_strikerId);
                                          final nsStats = _getStats(
                                            _nonStrikerId,
                                          );
                                          final bStats = _getStats(_bowlerId);
                                          return Column(
                                            children: [
                                              _buildTableRow(
                                                _getPlayerName(_strikerId) +
                                                    '*',
                                                '${sStats['runs']}',
                                                '${sStats['balls']}',
                                                '${sStats['4s']}',
                                                '${sStats['6s']}',
                                                _getBatsmanSR(sStats),
                                                isHighlight: true,
                                              ),
                                              const SizedBox(height: 8),
                                              _buildTableRow(
                                                _getPlayerName(_nonStrikerId),
                                                '${nsStats['runs']}',
                                                '${nsStats['balls']}',
                                                '${nsStats['4s']}',
                                                '${nsStats['6s']}',
                                                _getBatsmanSR(nsStats),
                                              ),
                                              const SizedBox(height: 16),
                                              _buildTableHeader([
                                                'Bowler',
                                                'O',
                                                'M',
                                                'R',
                                                'W',
                                                'ER',
                                              ]),
                                              const Divider(
                                                color: Color(0x3D1B5E20),
                                              ),
                                              _buildTableRow(
                                                _getPlayerName(_bowlerId),
                                                _getBowlerOvers(bStats),
                                                '${bStats['maidens']}',
                                                '${bStats['runsConceded']}',
                                                '${bStats['wickets']}',
                                                _getBowlerER(bStats),
                                                isHighlight: true,
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                )
                                .animate()
                                .fadeIn(delay: 100.ms)
                                .slideY(begin: 0.1, end: 0),

                            const SizedBox(height: 12),

                            // This Over tracking
                            GlassContainer(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  borderRadius: 16,
                                  child: Row(
                                    children: [
                                      const Text(
                                        'This over: ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white70,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: _currentOverBalls
                                              .map(
                                                (b) => CircleAvatar(
                                                  radius: 14,
                                                  backgroundColor: b == 'W'
                                                      ? Colors.redAccent
                                                      : (b.contains('wd') ||
                                                                b.contains('nb')
                                                            ? Colors
                                                                  .orangeAccent
                                                            : Theme.of(context)
                                                                  .primaryColor
                                                                  .withOpacity(
                                                                    0.2,
                                                                  )),
                                                  child: Text(
                                                    b,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: b == 'W'
                                                          ? Colors.white
                                                          : Theme.of(
                                                              context,
                                                            ).primaryColor,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                .animate()
                                .fadeIn(delay: 200.ms)
                                .slideY(begin: 0.1, end: 0),

                            const SizedBox(height: 12),

                            // Extras and Actions Card
                            GlassContainer(
                                  padding: const EdgeInsets.all(16),
                                  borderRadius: 16,
                                  child: Column(
                                    children: [
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            _buildCheckbox(
                                              'Wd',
                                              _isWide,
                                              (v) =>
                                                  setState(() => _isWide = v!),
                                            ),
                                            const SizedBox(width: 12),
                                            _buildCheckbox(
                                              'Nb',
                                              _isNoBall,
                                              (v) => setState(
                                                () => _isNoBall = v!,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            _buildCheckbox(
                                              'Byes',
                                              _isByes,
                                              (v) =>
                                                  setState(() => _isByes = v!),
                                            ),
                                            const SizedBox(width: 12),
                                            _buildCheckbox(
                                              'Leg Byes',
                                              _isLegByes,
                                              (v) => setState(
                                                () => _isLegByes = v!,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          _buildCheckbox(
                                            'Wicket',
                                            _isWicket,
                                            (v) =>
                                                setState(() => _isWicket = v!),
                                            color: Colors.redAccent,
                                          ),
                                          Row(
                                            children: [
                                              ElevatedButton(
                                                onPressed: _promptRetire,
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(
                                                    0xFF2E7D32,
                                                  ),
                                                  minimumSize: const Size(
                                                    60,
                                                    36,
                                                  ),
                                                ),
                                                child: const Text(
                                                  'Retire',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              ElevatedButton(
                                                onPressed: _swapBatsmen,
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(
                                                    0xFF2E7D32,
                                                  ),
                                                  minimumSize: const Size(
                                                    100,
                                                    36,
                                                  ),
                                                ),
                                                child: const Text(
                                                  'Swap Batsman',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                )
                                .animate()
                                .fadeIn(delay: 300.ms)
                                .slideY(begin: 0.1, end: 0),
                          ],
                        ),
                      );

                      Widget controlsContent =
                          Container(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                // Left action buttons
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildActionButton('Undo', _undoLastBall),
                                      const SizedBox(height: 8),
                                      _buildActionButton(
                                        'DLS',
                                        _currentInnings == 1
                                            ? _handleDlsClick
                                            : () {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'DLS can only be applied during the 1st innings.',
                                                    ),
                                                  ),
                                                );
                                              },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Right circular keypad
                                Expanded(
                                  flex: 5,
                                  child: GlassContainer(
                                    padding: const EdgeInsets.all(16),
                                    borderRadius: 16,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceEvenly,
                                          children: [
                                            _buildRunButton(
                                              '0',
                                              () => _handleScoreButton(0),
                                            ),
                                            _buildRunButton(
                                              '1',
                                              () => _handleScoreButton(1),
                                            ),
                                            _buildRunButton(
                                              '2',
                                              () => _handleScoreButton(2),
                                            ),
                                            _buildRunButton(
                                              '3',
                                              () => _handleScoreButton(3),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceEvenly,
                                          children: [
                                            _buildRunButton(
                                              '4',
                                              () => _handleScoreButton(4),
                                            ),
                                            _buildRunButton(
                                              '5',
                                              () => _handleScoreButton(5),
                                            ),
                                            _buildRunButton(
                                              '6',
                                              () => _handleScoreButton(6),
                                            ),
                                            _buildRunButton(
                                              '...',
                                              _showCustomRunsDialog,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ).animate().slideY(
                            begin: 1,
                            end: 0,
                            curve: Curves.easeOutBack,
                            duration: 600.ms,
                          );

                      return Expanded(
                        child: ResponsiveHelper.getValue(
                          context,
                          defaultVal: Column(
                            children: [
                              Expanded(child: scoreboardContent),
                              controlsContent,
                            ],
                          ),
                          medium: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: scoreboardContent),
                              Expanded(
                                flex: 2,
                                child: SingleChildScrollView(
                                  child: controlsContent,
                                ),
                              ),
                            ],
                          ),
                          large: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: scoreboardContent),
                              Expanded(
                                flex: 2,
                                child: SingleChildScrollView(
                                  child: controlsContent,
                                ),
                              ),
                            ],
                          ),
                          extraLarge: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: scoreboardContent),
                              Expanded(
                                flex: 2,
                                child: SingleChildScrollView(
                                  child: controlsContent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          if (_isDisplayingCelebration &&
              _celebrationText != null &&
              _celebrationSubtitle != null)
            CelebrationOverlay(
              mainText: _celebrationText!,
              subtitle: _celebrationSubtitle!,
              onTap: () {
                _celebrationTimer?.cancel();
                _dismissCelebration();
              },
            ),
          if (_isDisplayingPlayerStats && _currentPlayerForOverlay != null)
            PlayerStatsOverlay(
              player: _currentPlayerForOverlay!,
              isBatsman: _currentPlayerIsBatsman,
              onTap: _dismissPlayerStatsOverlay,
            ),
        ],
      ),
    );
  }

  BoxDecoration _glassDecoration(BuildContext context) {
    return BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.1)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.4),
          blurRadius: 10,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  Widget _buildTableHeader(List<String> columns) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            columns[0],
            style: const TextStyle(color: Colors.white54),
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            columns[1],
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white54),
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            columns[2],
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white54),
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            columns[3],
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white54),
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            columns[4],
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white54),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            columns[5],
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white54),
          ),
        ),
      ],
    );
  }

  Widget _buildTableRow(
    String name,
    String v1,
    String v2,
    String v3,
    String v4,
    String v5, {
    bool isHighlight = false,
  }) {
    Color textColor = isHighlight
        ? Theme.of(context).primaryColor
        : Colors.white;
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            name,
            style: TextStyle(
              color: textColor,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            v1,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            v2,
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white54),
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            v3,
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white54),
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            v4,
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white54),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            v5,
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white54),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckbox(
    String title,
    bool value,
    ValueChanged<bool?> onChanged, {
    Color? color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: color ?? Theme.of(context).primaryColor,
            checkColor: Colors.black,
            side: const BorderSide(color: Colors.white54, width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(color: Colors.white)),
      ],
    );
  }

  Widget _buildActionButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2E7D32),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 5,
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildRunButton(String label, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Theme.of(context).primaryColor, width: 2),
          color: Colors.transparent,
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Theme.of(context).primaryColor.withOpacity(0.5),
                blurRadius: 5,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ConfettiRibbon {
  double x;
  double y;
  double speed;
  double size;
  double angle;
  double rotationSpeed;
  Color color;
  double swaySpeed;
  double swayWidth;

  ConfettiRibbon({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.angle,
    required this.rotationSpeed,
    required this.color,
    required this.swaySpeed,
    required this.swayWidth,
  });
}

class ConfettiPainter extends CustomPainter {
  final List<ConfettiRibbon> ribbons;
  final double animationValue;

  ConfettiPainter({required this.ribbons, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (var ribbon in ribbons) {
      paint.color = ribbon.color;

      canvas.save();
      double sway =
          math.sin(animationValue * ribbon.swaySpeed) * ribbon.swayWidth;
      canvas.translate(ribbon.x + sway, ribbon.y);
      canvas.rotate(ribbon.angle);

      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: ribbon.size,
        height: ribbon.size * 0.3,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class CelebrationOverlay extends StatefulWidget {
  final String mainText;
  final String subtitle;
  final VoidCallback onTap;

  const CelebrationOverlay({
    super.key,
    required this.mainText,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<ConfettiRibbon> _ribbons = [];
  final math.Random _random = math.Random();

  final List<Color> _colors = const [
    Colors.redAccent,
    Colors.blueAccent,
    Colors.greenAccent,
    Colors.yellowAccent,
    Colors.orangeAccent,
    Colors.purpleAccent,
    Colors.pinkAccent,
    Colors.tealAccent,
  ];

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
          ..addListener(() {
            _updateRibbons();
          });
    _controller.repeat();

    for (int i = 0; i < 60; i++) {
      _ribbons.add(_createRibbon(initialY: true));
    }
  }

  ConfettiRibbon _createRibbon({bool initialY = false}) {
    return ConfettiRibbon(
      x: _random.nextDouble() * 500,
      y: initialY ? (_random.nextDouble() * 800) : -20,
      speed: 2.0 + _random.nextDouble() * 4.0,
      size: 8.0 + _random.nextDouble() * 14.0,
      angle: _random.nextDouble() * math.pi * 2,
      rotationSpeed: 0.02 + _random.nextDouble() * 0.05,
      color: _colors[_random.nextInt(_colors.length)],
      swaySpeed: 1.0 + _random.nextDouble() * 3.0,
      swayWidth: 5.0 + _random.nextDouble() * 15.0,
    );
  }

  void _updateRibbons() {
    setState(() {
      for (var ribbon in _ribbons) {
        ribbon.y += ribbon.speed;
        ribbon.angle += ribbon.rotationSpeed;

        if (ribbon.y > 900) {
          ribbon.y = -20;
          ribbon.x = _random.nextDouble() * 500;
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        color: Colors.black.withOpacity(0.85),
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: ConfettiPainter(
                  ribbons: _ribbons,
                  animationValue: _controller.value * 2 * math.pi,
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                          widget.mainText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 2,
                            shadows: [
                              Shadow(color: Colors.tealAccent, blurRadius: 15),
                              Shadow(color: Colors.greenAccent, blurRadius: 30),
                            ],
                          ),
                        )
                        .animate()
                        .scale(duration: 400.ms, curve: Curves.elasticOut)
                        .then()
                        .shake(duration: 800.ms, hz: 4),
                    const SizedBox(height: 16),
                    Text(
                          widget.subtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.tealAccent,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 5),
                            ],
                          ),
                        )
                        .animate()
                        .fadeIn(delay: 300.ms, duration: 400.ms)
                        .slideY(begin: 0.2, end: 0),
                    const SizedBox(height: 40),
                    const Text(
                          'TAP TO DISMISS',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white38,
                            letterSpacing: 3,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                        .animate(
                          onPlay: (controller) =>
                              controller.repeat(reverse: true),
                        )
                        .fadeIn(duration: 800.ms),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PlayerStatsOverlay extends StatelessWidget {
  final Player player;
  final bool isBatsman;
  final VoidCallback onTap;

  const PlayerStatsOverlay({
    super.key,
    required this.player,
    required this.isBatsman,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;
    if (player.imageBase64 != null && player.imageBase64!.isNotEmpty) {
      try {
        final decodedBytes = base64Decode(player.imageBase64!);
        imageWidget = ClipRRect(
          borderRadius: BorderRadius.circular(50),
          child: Image.memory(
            decodedBytes,
            width: 100,
            height: 100,
            fit: BoxFit.cover,
          ),
        );
      } catch (e) {
        imageWidget = _buildPlaceholderAvatar();
      }
    } else {
      imageWidget = _buildPlaceholderAvatar();
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.black87,
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.center,
        child: SingleChildScrollView(
          child:
              Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.tealAccent.withOpacity(0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.tealAccent.withOpacity(0.15),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.tealAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.tealAccent.withOpacity(0.5),
                            ),
                          ),
                          child: Text(
                            isBatsman ? "BATSMAN INTRO" : "BOWLER INTRO",
                            style: const TextStyle(
                              color: Colors.tealAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        Hero(
                          tag: 'player_intro_${player.id}',
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: imageWidget,
                          ),
                        ),
                        const SizedBox(height: 16),

                        Text(
                          player.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 24),

                        const Divider(color: Colors.white10),
                        const SizedBox(height: 16),

                        isBatsman ? _buildBattingStats() : _buildBowlingStats(),

                        const SizedBox(height: 24),
                        const Text(
                          'TAP ANYWHERE TO SKIP',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white30,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                  .animate()
                  .scale(duration: 350.ms, curve: Curves.easeOutBack)
                  .fadeIn(duration: 200.ms),
        ),
      ),
    );
  }

  Widget _buildPlaceholderAvatar() {
    final initials = player.name.isNotEmpty
        ? player.name
              .trim()
              .split(' ')
              .map((l) => l[0])
              .take(2)
              .join()
              .toUpperCase()
        : 'P';
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Colors.teal.shade700, Colors.teal.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w900,
          color: Colors.white70,
        ),
      ),
    );
  }

  Widget _buildBattingStats() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatItem("Matches", "${player.battingMatches}"),
            _buildStatItem("Innings", "${player.battingInnings}"),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatItem("Runs", "${player.battingRuns}"),
            _buildStatItem(
              "Strike Rate",
              player.battingStrikeRate.toStringAsFixed(2),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatItem("50s", "${player.battingFifties}"),
            _buildStatItem("Best Score", "${player.battingBestScore}"),
          ],
        ),
      ],
    );
  }

  Widget _buildBowlingStats() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatItem("Matches", "${player.bowlingMatches}"),
            _buildStatItem("Innings", "${player.bowlingInnings}"),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatItem("Wickets", "${player.bowlingWickets}"),
            _buildStatItem("Economy", player.bowlingEconomy.toStringAsFixed(2)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatItem("Overs", player.bowlingOvers.toStringAsFixed(1)),
            _buildStatItem(
              "Best Bowl",
              "${player.bowlingBestWickets}/${player.bowlingBestRuns}",
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white54,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
