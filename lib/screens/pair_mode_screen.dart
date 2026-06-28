import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/match.dart';
import '../models/player.dart';
import '../providers/cricket_provider.dart';
import '../rewarded_ad_helper.dart';
import 'scorecard_screen.dart';
import '../widgets/glass_container.dart';
import '../responsive_helper.dart';

class PairModeScreen extends StatefulWidget {
  final MatchModel? match;
  const PairModeScreen({super.key, this.match});

  @override
  State<PairModeScreen> createState() => _PairModeScreenState();
}

class _PairModeScreenState extends State<PairModeScreen> {
  String? _matchId;
  int _step =
      0; // 0: Select Players, 1: Pairing & Batting Sequence, 2: Settings, 3: Play, 4: Results
  List<Player> _selectedPlayers = [];
  List<List<String>> _teams =
      []; // Teams of 2 players (each sublist is a pair of player IDs)
  String _orderMode = ''; // 'random' or 'manual'
  List<String> _manualPairsTemp =
      []; // Holds player IDs temporarily during manual pairing

  // Match State
  Map<String, Map<String, dynamic>> _playerStats = {};
  List<Map<String, dynamic>> _balls = [];
  List<String> _currentOverBalls = [];
  String? _bowlerId;

  // Settings
  int _overs = 2;
  int _noBallRuns = 1;
  int _wideRuns = 1;
  bool _reballNoBall = true;
  bool _reballWide = true;
  bool _lastBatsmanStanding = true;

  // Current Batting Team Info
  int _currentTeamIndex = 0;
  int _activeBatsmanIndex = 0; // 0 or 1 (index inside the current pair)

  // Undo Stack for state rolling back
  final List<Map<String, dynamic>> _undoStack = [];

  // Controllers
  late TextEditingController _oversCtrl;
  late TextEditingController _noBallRunsCtrl;
  late TextEditingController _wideRunsCtrl;

  // Ball event flags
  bool _isWide = false;
  bool _isNoBall = false;
  bool _isByes = false;
  bool _isLegByes = false;
  bool _isWicket = false;

  // Celebration flags
  bool _isDisplayingCelebration = false;
  String? _celebrationText;
  String? _celebrationSubtitle;

  final List<String> _fourPhrases = [
    "SMASHED FOR FOUR!",
    "SHOT! BEAUTIFUL BOUNDARY!",
    "CRACKING SHOT FOR FOUR!",
    "RACED AWAY TO THE FENCE!",
  ];

  final List<String> _sixPhrases = [
    "MONSTER SIX!",
    "CLEARED THE ROPE!",
    "INTO THE CROWD FOR SIX!",
    "OUT OF THE PARK!",
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
      _lastBatsmanStanding = data['lastBatsmanStanding'] ?? true;
      _currentTeamIndex = data['currentTeamIndex'] ?? 0;
      _activeBatsmanIndex = data['activeBatsmanIndex'] ?? 0;
      _orderMode = data['orderMode'] ?? '';
      
      if (data['teams'] != null) {
        _teams = List<List<String>>.from(
          (data['teams'] as List).map((t) => List<String>.from(t))
        );
      }
      
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
      
      if (data['undoStack'] != null) {
        _undoStack.addAll(List<Map<String, dynamic>>.from(
          (data['undoStack'] as List).map((e) => Map<String, dynamic>.from(e))
        ));
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
    super.dispose();
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

  int getTeamRuns(List<String> team) {
    int sum = 0;
    for (var id in team) {
      sum += (_playerStats[id]?['runs'] as int? ?? 0);
    }
    return sum;
  }

  int getTeamBalls(List<String> team) {
    int sum = 0;
    for (var id in team) {
      sum += (_playerStats[id]?['balls'] as int? ?? 0);
    }
    return sum;
  }

  bool _isPlayerOut(String? status) {
    if (status == null) return false;
    return status != 'Yet to bat' && 
           status != 'Batting' && 
           status != 'Target Completed' && 
           status != 'Overs Completed';
  }

  int getTeamWickets(List<String> team) {
    int count = 0;
    for (var id in team) {
      if (_isPlayerOut(_playerStats[id]?['status'])) {
        count++;
      }
    }
    return count;
  }

  // --- WIZARD METHODS ---
  void _addPlayerToMatch(Player p) {
    if (!_selectedPlayers.any((x) => x.id == p.id)) {
      setState(() {
        _selectedPlayers.add(p);
      });
    }
  }

  void _removePlayerFromMatch(Player p) {
    setState(() {
      _selectedPlayers.removeWhere((x) => x.id == p.id);
      _manualPairsTemp.remove(p.id);
      for (var team in _teams) {
        team.remove(p.id);
      }
      _teams.removeWhere((team) => team.isEmpty);
    });
  }

  void _setupRandomPairs() {
    setState(() {
      _orderMode = 'random';
      _teams.clear();
      _manualPairsTemp.clear();
      List<Player> shuffled = List.from(_selectedPlayers)..shuffle();
      for (int i = 0; i < shuffled.length; i += 2) {
        if (i + 1 < shuffled.length) {
          _teams.add([shuffled[i].id, shuffled[i + 1].id]);
        }
      }
    });
  }

  void _setupManualPairs() {
    setState(() {
      _orderMode = 'manual';
      _teams.clear();
      _manualPairsTemp.clear();
    });
  }

  void _handleManualPairTap(String playerId) {
    setState(() {
      // Check if player is already assigned in a completed team
      bool isAssigned = _teams.any((team) => team.contains(playerId));
      if (isAssigned) {
        // Remove team containing player
        _teams.removeWhere((team) => team.contains(playerId));
        return;
      }

      if (_manualPairsTemp.contains(playerId)) {
        _manualPairsTemp.remove(playerId);
      } else {
        _manualPairsTemp.add(playerId);
        if (_manualPairsTemp.length == 2) {
          _teams.add(List.from(_manualPairsTemp));
          _manualPairsTemp.clear();
        }
      }
    });
  }

  void _addPairDuringSetup(Player p1, Player p2) {
    setState(() {
      if (!_selectedPlayers.any((x) => x.id == p1.id)) _selectedPlayers.add(p1);
      if (!_selectedPlayers.any((x) => x.id == p2.id)) _selectedPlayers.add(p2);
      _teams.add([p1.id, p2.id]);
    });
  }

  void _showCreateNewPlayerDialog(
    BuildContext context,
    Function(Player) onPlayerCreated,
  ) {
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
                side: const BorderSide(color: Color(0xFF3A3A3A), width: 1.0),
              ),
              title: const Text(
                'Create New Player',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
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
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        builder: (context) => Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text(
                                'Select Image Source',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            ListTile(
                              leading: const Icon(
                                Icons.camera_alt,
                                color: Color(0xFFF355DA),
                              ),
                              title: const Text(
                                'Camera',
                                style: TextStyle(color: Colors.white),
                              ),
                              onTap: () =>
                                  Navigator.pop(context, ImageSource.camera),
                            ),
                            ListTile(
                              leading: const Icon(
                                Icons.photo_library,
                                color: Color(0xFFF355DA),
                              ),
                              title: const Text(
                                'Gallery',
                                style: TextStyle(color: Colors.white),
                              ),
                              onTap: () =>
                                  Navigator.pop(context, ImageSource.gallery),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      );

                      if (source != null) {
                        final image = await picker.pickImage(
                          source: source,
                          imageQuality: 50,
                          maxWidth: 400,
                        );
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
                      backgroundColor: const Color(0xFFF355DA).withOpacity(0.2),
                      backgroundImage: pickedImageBytes != null
                          ? MemoryImage(pickedImageBytes!)
                          : null,
                      child: pickedImageBytes == null
                          ? const Icon(
                              Icons.add_a_photo,
                              color: Color(0xFFF355DA),
                              size: 30,
                            )
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
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFF355DA)),
                      ),
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
                            await provider.addPlayer(
                              name,
                              imageBase64: base64Str,
                            );

                            // Find the new player added to provider.players
                            final newPlayer = provider.players.firstWhere(
                              (p) =>
                                  p.name == name &&
                                  !_selectedPlayers.any((sp) => sp.id == p.id),
                              orElse: () => provider.players.last,
                            );

                            onPlayerCreated(newPlayer);

                            if (context.mounted) {
                              Navigator.pop(dialogCtx);
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF355DA),
                    foregroundColor: Colors.black,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddPairDialog(Function(Player, Player) onAdded) {
    List<Player> tempSelected = [];
    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setSubState) {
          final provider = Provider.of<CricketProvider>(context);
          final available = provider.players
              .where((p) => !_selectedPlayers.any((sp) => sp.id == p.id))
              .toList();

          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Select 2 Players for a Pair',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Container(
              width: double.maxFinite,
              child: available.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20.0),
                      child: Text(
                        'No available roster players. Please create new ones.',
                        style: TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: available.length,
                      itemBuilder: (ctx, idx) {
                        final player = available[idx];
                        final isChecked = tempSelected.any(
                          (x) => x.id == player.id,
                        );
                        return CheckboxListTile(
                          activeColor: const Color(0xFFF355DA),
                          secondary: _buildPlayerAvatar(player, radius: 18),
                          title: Text(
                            player.name,
                            style: const TextStyle(color: Colors.white),
                          ),
                          value: isChecked,
                          onChanged: (val) {
                            setSubState(() {
                              if (val == true) {
                                if (tempSelected.length < 2) {
                                  tempSelected.add(player);
                                }
                              } else {
                                tempSelected.removeWhere(
                                  (x) => x.id == player.id,
                                );
                              }
                            });
                          },
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _showCreateNewPlayerDialog(context, (newPlayer) {
                    setSubState(() {
                      if (tempSelected.length < 2) {
                        tempSelected.add(newPlayer);
                      }
                    });
                  });
                },
                child: const Text(
                  'Create New',
                  style: TextStyle(
                    color: Color(0xFFF355DA),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              ElevatedButton(
                onPressed: tempSelected.length == 2
                    ? () {
                        onAdded(tempSelected[0], tempSelected[1]);
                        Navigator.pop(dialogCtx);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF355DA),
                ),
                child: const Text(
                  'Add Pair',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _triggerCelebration(String title, String subtitle) {
    setState(() {
      _celebrationText = title;
      _celebrationSubtitle = subtitle;
      _isDisplayingCelebration = true;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isDisplayingCelebration = false;
        });
      }
    });
  }

  // --- STATE PERSISTENCE UNDO ---
  void _saveUndoState() {
    _undoStack.add({
      'step': _step,
      'currentTeamIndex': _currentTeamIndex,
      'activeBatsmanIndex': _activeBatsmanIndex,
      'playerStats': jsonDecode(jsonEncode(_playerStats)),
      'currentOverBalls': List<String>.from(_currentOverBalls),
      'balls': List<Map<String, dynamic>>.from(_balls),
      'bowlerId': _bowlerId,
      'isWide': _isWide,
      'isNoBall': _isNoBall,
      'isByes': _isByes,
      'isLegByes': _isLegByes,
      'isWicket': _isWicket,
    });
    if (_undoStack.length > 30) {
      _undoStack.removeAt(0);
    }
  }

  void _undoLastBall() {
    if (_undoStack.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nothing to undo.')));
      return;
    }
    final last = _undoStack.removeLast();
    setState(() {
      _step = last['step'];
      _currentTeamIndex = last['currentTeamIndex'];
      _activeBatsmanIndex = last['activeBatsmanIndex'];
      _playerStats = Map<String, Map<String, dynamic>>.from(
        (last['playerStats'] as Map).map(
          (k, v) => MapEntry(k as String, Map<String, dynamic>.from(v)),
        ),
      );
      _currentOverBalls = List<String>.from(last['currentOverBalls']);
      _balls = List<Map<String, dynamic>>.from(last['balls']);
      _bowlerId = last['bowlerId'];
      _isWide = last['isWide'];
      _isNoBall = last['isNoBall'];
      _isByes = last['isByes'];
      _isLegByes = last['isLegByes'];
      _isWicket = last['isWicket'];
    });
    _saveState();
  }

  void _swapBatsmen() {
    setState(() {
      _activeBatsmanIndex = _activeBatsmanIndex == 0 ? 1 : 0;
    });
    _saveState();
  }

  Future<void> _executeScore(int runs) async {
    if (_teams.isEmpty) return;
    _saveUndoState();

    final currentTeam = _teams[_currentTeamIndex];
    final currentBatsmanId = currentTeam[_activeBatsmanIndex];
    final stats = _playerStats[currentBatsmanId]!;

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
      // Wide adding to batsman runs if it's wide and we reball
      stats['runs'] = (stats['runs'] ?? 0) + runsToAdd;
    }

    if (_isNoBall) {
      if (!_isWide && !_isByes && !_isLegByes) {
        // Runs from bat already counted
      }
      if (!_isWide) {
        stats['runs'] = (stats['runs'] ?? 0) + _noBallRuns;
      }
    }

    // Boundaries Trigger
    if (runs == 4 && !_isWide && !_isByes && !_isLegByes) {
      final phrase = _fourPhrases[math.Random().nextInt(_fourPhrases.length)];
      _triggerCelebration(phrase, "by ${_getPlayerName(currentBatsmanId)}");
    } else if (runs == 6 && !_isWide && !_isByes && !_isLegByes) {
      final phrase = _sixPhrases[math.Random().nextInt(_sixPhrases.length)];
      _triggerCelebration(phrase, "by ${_getPlayerName(currentBatsmanId)}");
    }

    // Wicket checking
    if (_isWicket) {
      String strikerId = currentBatsmanId;
      String nonStrikerId = currentTeam[_activeBatsmanIndex == 0 ? 1 : 0];
      
      Map<String, dynamic>? wicketDetails = await _showWicketDetailsFullScreen(context, strikerId, nonStrikerId);
      if (wicketDetails == null) {
        _undoLastBall();
        return;
      }

      String wicketType = wicketDetails['wicketType'];
      String? fielderId = wicketDetails['fielderId'];
      String batsmanOutId = wicketDetails['batsmanOutId'];
      
      final batsmanBalls = stats['balls'] ?? 0;
      final bOversStr = "${batsmanBalls ~/ 6}.${batsmanBalls % 6}";
      String bowlerName = _bowlerId != null ? _getPlayerName(_bowlerId) : 'Bowler';
      String outBatsmanName = _getPlayerName(batsmanOutId);
      String fielderName = fielderId != null ? _getPlayerName(fielderId) : '';
      
      String statusString = 'out';
      if (wicketType == 'Bowled') {
        statusString = 'b $bowlerName';
      } else if (wicketType == 'Caught') {
        statusString = 'c $fielderName b $bowlerName';
      } else if (wicketType == 'LBW') {
        statusString = 'lbw b $bowlerName';
      } else if (wicketType == 'Striker Runout' || wicketType == 'Non-Striker Runout' || wicketType == 'Run Out') {
        statusString = 'run out ($fielderName)';
      } else if (wicketType == 'Stumped') {
        statusString = 'st $fielderName b $bowlerName';
      } else if (wicketType == 'Hit Wicket') {
        statusString = 'hit wicket b $bowlerName';
      }

      _playerStats[batsmanOutId]!['status'] = statusString;
      _currentOverBalls.add('W');

      String description = 'OUT! $outBatsmanName is out $wicketType';
      if (fielderName.isNotEmpty) description += ' by $fielderName';
      description += ' off the bowling of $bowlerName.';

      _balls.add({
        'over': bOversStr,
        'teamIndex': _currentTeamIndex,
        'strikerId': currentBatsmanId,
        'batsmanOutId': batsmanOutId,
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
      _finishBatsmanOrTeamInnings(batsmanOutId, out: true);
      return;
    }

    // Timeline labels
    String ballLabel = runs.toString();
    if (_isWide)
      ballLabel = '${runs}wd';
    else if (_isNoBall)
      ballLabel = '${runs}nb';
    else if (_isByes)
      ballLabel = '${runs}b';
    else if (_isLegByes)
      ballLabel = '${runs}lb';
    _currentOverBalls.add(ballLabel);

    // Append ball record
    final batsmanBalls = stats['balls'] ?? 0;
    final bOversStr = "${batsmanBalls ~/ 6}.${batsmanBalls % 6}";
    String bowlerName = _bowlerId != null
        ? _getPlayerName(_bowlerId)
        : 'Bowler';
    String strikerName = _getPlayerName(currentBatsmanId);

    String description = '';
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

    _balls.add({
      'over': bOversStr,
      'teamIndex': _currentTeamIndex,
      'strikerId': currentBatsmanId,
      'bowlerId': _bowlerId,
      'runs': runs,
      'runsToAdd': runsToAdd,
      'isByes': _isByes,
      'isLegByes': _isLegByes,
      'isWicket': _isWicket,
      'wicketType': null,
      'fielderId': null,
      'description': description,
    });

    _resetChecks();

    // Strike rotation on odd runs (1 or 3) off the bat
    if ((runs == 1 || runs == 3) && !_isWide) {
      final wickets = getTeamWickets(currentTeam);
      if (wickets == 0) {
        _swapBatsmen();
      }
    }

    // Check target chasing logic for last pair
    final isLastTeam =
        _currentTeamIndex > 0 && _currentTeamIndex == _teams.length - 1;
    if (isLastTeam) {
      int highestScore = 0;
      for (int i = 0; i < _currentTeamIndex; i++) {
        final score = getTeamRuns(_teams[i]);
        if (score > highestScore) {
          highestScore = score;
        }
      }
      final target = highestScore + 1;
      final currentTeamScore = getTeamRuns(currentTeam);
      if (currentTeamScore >= target) {
        stats['status'] = 'Target Completed';
        _finishBatsmanOrTeamInnings(
          currentBatsmanId,
          out: false,
          forceTeamComplete: true,
        );
        return;
      }
    }

    // Check over complete legal count
    int legalBalls = _currentOverBalls.where((b) {
      final isWd = b.contains('wd');
      final isNb = b.contains('nb');
      if (isWd && _reballWide) return false;
      if (isNb && _reballNoBall) return false;
      return true;
    }).length;

    int totalTeamBalls = getTeamBalls(currentTeam);
    if (totalTeamBalls >= _overs * 6) {
      stats['status'] = 'Overs Completed';
      _finishBatsmanOrTeamInnings(
        currentBatsmanId,
        out: false,
        forceTeamComplete: true,
      );
    } else {
      if (legalBalls >= 6) {
        final wickets = getTeamWickets(currentTeam);
        if (wickets == 0) {
          _swapBatsmen();
        }
        _currentOverBalls.clear();
        final nonBatting = _selectedPlayers
            .where((p) => !currentTeam.contains(p.id) && p.id != _bowlerId)
            .toList();
        final finalNonBatting = nonBatting.isNotEmpty
            ? nonBatting
            : _selectedPlayers
                  .where((p) => !currentTeam.contains(p.id))
                  .toList();

        if (finalNonBatting.isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => SimpleDialog(
                  backgroundColor: const Color(0xFF1E293B),
                  title: const Text(
                    'Over Completed! Select Next Bowler',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
                        child: Text(
                          player.name,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            }
          });
        }
      }
    }
    _saveState();
    setState(() {});
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

  void _finishBatsmanOrTeamInnings(
    String batsmanId, {
    required bool out,
    bool forceTeamComplete = false,
  }) {
    final name = _getPlayerName(batsmanId);
    final runs = _playerStats[batsmanId]?['runs'] ?? 0;
    final balls = _playerStats[batsmanId]?['balls'] ?? 0;
    final currentTeam = _teams[_currentTeamIndex];

    bool needPartnerToBat = false;
    int partnerIndex = -1;
    if (out && !forceTeamComplete) {
      if (_lastBatsmanStanding) {
        final wickets = getTeamWickets(currentTeam);
        if (wickets == 1) {
          needPartnerToBat = true;
          partnerIndex = currentTeam.indexWhere(
            (id) => !_isPlayerOut(_playerStats[id]?['status']),
          );
        }
      }
    }

    if (needPartnerToBat && partnerIndex != -1) {
      final partnerId = currentTeam[partnerIndex];
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
                    color: Color(0xFFF355DA),
                    size: 80,
                  ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
                  const SizedBox(height: 24),
                  Text(
                    "$name is OUT!",
                    style: const TextStyle(
                      color: Colors.redAccent,
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
                    "PARTNER CONTINUES TO BAT:",
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 14,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getPlayerName(partnerId),
                    style: const TextStyle(
                      color: Color(0xFFF355DA),
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 48),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _activeBatsmanIndex = partnerIndex;
                        _playerStats[partnerId]!['status'] = 'Batting';
                      });
                      _saveState();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF355DA),
                      minimumSize: const Size(200, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Start Innings',
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
      // Innings of the entire team/pair is completed
      final teamRuns = getTeamRuns(currentTeam);
      final teamBalls = getTeamBalls(currentTeam);
      final teamWickets = getTeamWickets(currentTeam);

      if (_currentTeamIndex + 1 < _teams.length) {
        final nextTeam = _teams[_currentTeamIndex + 1];
        final nextTeamNames =
            "${_getPlayerName(nextTeam[0])} & ${_getPlayerName(nextTeam[1])}";

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
                      Icons.groups_rounded,
                      color: Colors.greenAccent,
                      size: 80,
                    ).animate().scale(
                      duration: 400.ms,
                      curve: Curves.elasticOut,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "Innings Completed!",
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Team scored $teamRuns/$teamWickets off ${teamBalls ~/ 6}.${teamBalls % 6} overs",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 48),
                    const Text(
                      "NEXT BATTING PAIR:",
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 14,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      nextTeamNames,
                      style: const TextStyle(
                        color: Color(0xFFF355DA),
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _currentTeamIndex++;
                          _activeBatsmanIndex = 0;
                          _currentOverBalls.clear();
                          _playerStats[_teams[_currentTeamIndex][0]]!['status'] =
                              'Batting';
                        });

                        final nextTeamMembers = _teams[_currentTeamIndex];
                        final nonBatting = _selectedPlayers
                            .where((p) => !nextTeamMembers.contains(p.id))
                            .toList();
                        if (nonBatting.isNotEmpty) {
                          Future.delayed(const Duration(milliseconds: 100), () {
                            if (mounted) {
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (ctx2) => SimpleDialog(
                                  backgroundColor: const Color(0xFF1E293B),
                                  title: const Text(
                                    'Select Bowler for Next Team',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  children: nonBatting.map((player) {
                                    return SimpleDialogOption(
                                      onPressed: () {
                                        setState(() {
                                          _bowlerId = player.id;
                                        });
                                        _saveState();
                                        Navigator.pop(ctx2);
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8.0,
                                        ),
                                        child: Text(
                                          player.name,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 16,
                                          ),
                                        ),
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
                        backgroundColor: const Color(0xFFF355DA),
                        minimumSize: const Size(200, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Start Innings',
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
        // End of match!
        setState(() {
          _step = 4;
        });
        _saveState();
        RewardedAdHelper.showAd();
        _saveMatchToDatabase();
      }
    }
  }

  void _updateCumulativePlayerStats() {
    final provider = Provider.of<CricketProvider>(context, listen: false);
    List<Player> updatedPlayers = [];

    // 1. Calculate Bowling and Fielding stats from the timeline (_balls)
    Map<String, Map<String, dynamic>> bowlerStats = {};
    Map<String, Map<String, int>> fielderStats = {};

    for (var p in _selectedPlayers) {
      bowlerStats[p.id] = {'balls': 0, 'runs': 0, 'wickets': 0, 'maidens': 0};
      fielderStats[p.id] = {'catches': 0, 'stumpings': 0, 'runOuts': 0};
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
          bowlerStats[bowlerId] = {
            'balls': 0,
            'runs': 0,
            'wickets': 0,
            'maidens': 0,
          };
        }
        final bStats = bowlerStats[bowlerId]!;
        if (!isWide && !isNoBall)
          bStats['balls'] = (bStats['balls'] as int) + 1;
        if (!isByes && !isLegByes)
          bStats['runs'] = (bStats['runs'] as int) + runsToAdd;
        if (isWicket && wicketType != 'Run Out')
          bStats['wickets'] = (bStats['wickets'] as int) + 1;
      }

      // Fielding Stats
      if (isWicket && fielderId != null) {
        if (!fielderStats.containsKey(fielderId)) {
          fielderStats[fielderId] = {
            'catches': 0,
            'stumpings': 0,
            'runOuts': 0,
          };
        }
        if (wicketType == 'Caught') {
          fielderStats[fielderId]!['catches'] =
              (fielderStats[fielderId]!['catches'] ?? 0) + 1;
        } else if (wicketType == 'Stumped') {
          fielderStats[fielderId]!['stumpings'] =
              (fielderStats[fielderId]!['stumpings'] ?? 0) + 1;
        } else if (wicketType == 'Run Out') {
          fielderStats[fielderId]!['runOuts'] =
              (fielderStats[fielderId]!['runOuts'] ?? 0) + 1;
        }
      }
    }

    // 2. Iterate players and update their cumulative stats
    for (var player in _selectedPlayers) {
      final playerIndex = provider.players.indexWhere((p) => p.id == player.id);
      if (playerIndex == -1) continue;

      Player p = provider.players[playerIndex];

      int bMatches = p.getStat('Pair', 'battingMatches') + 1;
      int bInnings = p.getStat('Pair', 'battingInnings');
      int bRuns = p.getStat('Pair', 'battingRuns');
      int bBalls = p.getStat('Pair', 'battingBalls');
      int bFours = p.getStat('Pair', 'battingFours');
      int bSixes = p.getStat('Pair', 'battingSixes');
      int bBestScore = p.getStat('Pair', 'battingBestScore');
      int bHundreds = p.getStat('Pair', 'battingHundreds');
      int bFifties = p.getStat('Pair', 'battingFifties');
      int bThirties = p.getStat('Pair', 'battingThirties');
      int bDucks = p.getStat('Pair', 'battingDucks');
      int bGoldenDucks = p.getStat('Pair', 'battingGoldenDucks');
      int bNotOuts = p.getStat('Pair', 'battingNotOuts');

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
        if (!_isPlayerOut(status)) {
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

      Map<String, dynamic> updates = {
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
      };

      // Parse derived bowling and fielding for this match
      final bStat =
          bowlerStats[p.id] ??
          {'balls': 0, 'runs': 0, 'wickets': 0, 'maidens': 0};
      final fStat =
          fielderStats[p.id] ?? {'catches': 0, 'stumpings': 0, 'runOuts': 0};

      int matchBowls = bStat['balls'] as int;
      int matchRunsConc = bStat['runs'] as int;
      int matchWickets = bStat['wickets'] as int;
      int matchMaidens = bStat['maidens'] as int;
      double matchOvers = matchBowls ~/ 6 + (matchBowls % 6) / 10.0;

      // Update Bowling Cumulative
      int bwMatches = p.getStat('Pair', 'bowlingMatches') + 1;
      int bwInnings =
          p.getStat('Pair', 'bowlingInnings') + (matchBowls > 0 ? 1 : 0);
      int bwRunsConc = p.getStat('Pair', 'bowlingRunsConceded') + matchRunsConc;
      int bwWickets = p.getStat('Pair', 'bowlingWickets') + matchWickets;
      int bwMaidens = p.getStat('Pair', 'bowlingMaidens') + matchMaidens;

      double currentOvers = p.getStat('Pair', 'bowlingOvers').toDouble();
      int totalBalls =
          (currentOvers.toInt() * 6) +
          ((currentOvers - currentOvers.toInt()) * 10).round() +
          matchBowls;
      double bwOvers = totalBalls ~/ 6 + (totalBalls % 6) / 10.0;

      int bwBestWickets = p.getStat('Pair', 'bowlingBestWickets');
      int bwBestRuns = p.getStat('Pair', 'bowlingBestRuns');
      if (matchWickets > bwBestWickets ||
          (matchWickets == bwBestWickets && matchRunsConc < bwBestRuns)) {
        bwBestWickets = matchWickets;
        bwBestRuns = matchRunsConc;
      }

      double bwEconomy = bwOvers > 0 ? bwRunsConc / bwOvers : 0.0;
      double bwAverage = bwWickets > 0 ? bwRunsConc / bwWickets : 0.0;
      double bwStrikeRate = bwWickets > 0 ? totalBalls / bwWickets : 0.0;

      int bw3W =
          p.getStat('Pair', 'bowling3W') +
          (matchWickets >= 3 && matchWickets < 5 ? 1 : 0);
      int bw5W =
          p.getStat('Pair', 'bowling5W') +
          (matchWickets >= 5 && matchWickets < 7 ? 1 : 0);
      int bw7W =
          p.getStat('Pair', 'bowling7W') +
          (matchWickets >= 7 && matchWickets < 10 ? 1 : 0);
      int bw10W =
          p.getStat('Pair', 'bowling10W') + (matchWickets >= 10 ? 1 : 0);

      // Update Fielding Cumulative
      int fMatches = p.getStat('Pair', 'fieldingMatches') + 1;
      int fCatches =
          p.getStat('Pair', 'fieldingCatches') + (fStat['catches'] as int);
      int fStumpings =
          p.getStat('Pair', 'fieldingStumpings') + (fStat['stumpings'] as int);
      int fRunOuts =
          p.getStat('Pair', 'fieldingRunOuts') + (fStat['runOuts'] as int);

      updates.addAll({
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

      p.updateStatsForMode('Pair', updates);

      updatedPlayers.add(p);
    }

    if (updatedPlayers.isNotEmpty) {
      provider.updatePlayers(updatedPlayers);
    }
  }

  Future<void> _saveMatchToDatabase() async {
    _updateCumulativePlayerStats();
    List<List<String>> sortedTeams = List.from(_teams);
    sortedTeams.sort((a, b) {
      final aRuns = getTeamRuns(a);
      final bRuns = getTeamRuns(b);
      if (bRuns == aRuns) {
        final aIdx = _teams.indexOf(a);
        final bIdx = _teams.indexOf(b);
        return aIdx.compareTo(bIdx);
      }
      return bRuns.compareTo(aRuns);
    });

    final winnerNames =
        "${_getPlayerName(sortedTeams[0][0])} & ${_getPlayerName(sortedTeams[0][1])}";
    final resultText =
        "$winnerNames won the Pair match with ${getTeamRuns(sortedTeams[0])} runs!";

    final newMatch = MatchModel(
      id: _matchId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      team1Name: 'Pair Mode Match',
      team2Name: '',
      team1Score: getTeamRuns(sortedTeams[0]),
      team2Score: 0,
      team1Overs: 0.0,
      team2Overs: 0.0,
      team1Wickets: getTeamWickets(sortedTeams[0]),
      team2Wickets: 0,
      date: DateTime.now(),
      isCompleted: true,
      result: resultText,
      overs: _overs,
      matchData: {
        'type': 'pair_mode',
        'teams': _teams,
        'playerStats': _playerStats,
        'balls': _balls,
        'overs': _overs,
        'wideRuns': _wideRuns,
        'noBallRuns': _noBallRuns,
        'reballWide': _reballWide,
        'reballNoBall': _reballNoBall,
        'lastBatsmanStanding': _lastBatsmanStanding,
      },
    );

    final provider = Provider.of<CricketProvider>(context, listen: false);
    await provider.saveMatch(newMatch);
  }

  void _saveState() {
    final provider = Provider.of<CricketProvider>(context, listen: false);
    
    _matchId ??= DateTime.now().millisecondsSinceEpoch.toString();

    final matchData = {
      'type': 'pair_mode',
      'step': _step,
      'overs': _overs,
      'wideRuns': _wideRuns,
      'noBallRuns': _noBallRuns,
      'reballWide': _reballWide,
      'reballNoBall': _reballNoBall,
      'lastBatsmanStanding': _lastBatsmanStanding,
      'currentTeamIndex': _currentTeamIndex,
      'activeBatsmanIndex': _activeBatsmanIndex,
      'orderMode': _orderMode,
      'selectedPlayers': _selectedPlayers.map((p) => p.id).toList(),
      'teams': _teams,
      'playerStats': _playerStats,
      'currentOverBalls': _currentOverBalls,
      'bowlerId': _bowlerId,
      'balls': _balls,
      'undoStack': _undoStack,
    };

    final match = MatchModel(
      id: _matchId!,
      team1Name: 'Pair Mode',
      team2Name: 'Match',
      date: DateTime.now(),
      result: 'In Progress',
      isCompleted: _step == 4,
      overs: _overs,
      matchData: matchData,
    );

    provider.saveMatch(match);
  }

  void _restartGameWithSortedOrder() {
    setState(() {
      // Sort teams by final runs (highest to lowest)
      _teams.sort((a, b) {
        final aRuns = getTeamRuns(a);
        final bRuns = getTeamRuns(b);
        if (bRuns == aRuns) {
          final aIdx = _teams.indexOf(a);
          final bIdx = _teams.indexOf(b);
          return aIdx.compareTo(bIdx);
        }
        return bRuns.compareTo(aRuns);
      });

      // Clear match scoring states
      _balls.clear();
      _currentOverBalls.clear();
      _bowlerId = null;
      _currentTeamIndex = 0;
      _activeBatsmanIndex = 0;
      _undoStack.clear();

      // Go back to Wizard Step 1 (Batting Order / Pairing sequence list)
      _step = 1;
      _saveState();
    });
  }

  // --- FULL SCREEN LIVE SCORECARD MODAL ---
  void _showLiveScorecardDialog() {
    String selectedTab = 'scorecard'; // 'scorecard' or 'commentary'
    int selectedTeamIdx = _currentTeamIndex;

    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: const Color(0xFF0F172A),
        child: StatefulBuilder(
          builder: (context, setStateDialog) {
            final isScorecard = selectedTab == 'scorecard';
            final selectedTeam = _teams[selectedTeamIdx];
            final teamBalls = _balls
                .where((ball) => ball['teamIndex'] == selectedTeamIdx)
                .toList();

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

              for (var ball in teamBalls) {
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

                final bool countsAsBallFaced = (!isW) || (isW && !_reballWide);
                if (countsAsBallFaced) {
                  stats['balls'] = (stats['balls'] as int) + 1;
                }

                int conceded = 0;
                if (!isB && !isLb) {
                  conceded = runsToAddVal;
                } else {
                  if (isW)
                    conceded = runsToAddVal;
                  else if (isNb)
                    conceded = _noBallRuns;
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
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            letterSpacing: 1.5,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white70,
                            size: 28,
                          ),
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
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            _showAddPairDialog((p1, p2) {
                              _addPairDuringSetup(p1, p2);
                              // Initialize states for newly added pair
                              _playerStats[p1.id] = <String, dynamic>{
                                'runs': 0,
                                'balls': 0,
                                '4s': 0,
                                '6s': 0,
                                'status': 'Yet to bat',
                              };
                              _playerStats[p2.id] = <String, dynamic>{
                                'runs': 0,
                                'balls': 0,
                                '4s': 0,
                                '6s': 0,
                                'status': 'Yet to bat',
                              };
                              setStateDialog(() {});
                              setState(() {});
                              _saveState();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Pair ${p1.name} & ${p2.name} added to the match.',
                                  ),
                                ),
                              );
                            });
                          },
                          icon: const Icon(
                            Icons.person_add,
                            color: Color(0xFFF355DA),
                            size: 16,
                          ),
                          label: const Text(
                            'ADD PAIR',
                            style: TextStyle(
                              color: Color(0xFFF355DA),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(_teams.length, (index) {
                          final team = _teams[index];
                          final names =
                              "${_getPlayerName(team[0])} & ${_getPlayerName(team[1])}";
                          final isSelected = selectedTeamIdx == index;
                          final labelText =
                              '${_getOrdinal(index + 1)} ($names)';

                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(labelText),
                              selected: isSelected,
                              onSelected: (selected) {
                                setStateDialog(() {
                                  selectedTeamIdx = index;
                                });
                              },
                              selectedColor: const Color(0xFFF355DA),
                              backgroundColor: const Color(0xFF1E293B),
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? Colors.black
                                    : Colors.white70,
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
                            if (val)
                              setStateDialog(() => selectedTab = 'scorecard');
                          },
                          selectedColor: const Color(0xFFF355DA),
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
                            if (val)
                              setStateDialog(() => selectedTab = 'commentary');
                          },
                          selectedColor: const Color(0xFFF355DA),
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
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Batting',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    Text(
                                      'Total: ${getTeamRuns(selectedTeam)}/${getTeamWickets(selectedTeam)}',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFF355DA),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _buildTableHeader([
                                  'Batsman',
                                  'R',
                                  'B',
                                  '4s',
                                  '6s',
                                  'SR',
                                ]),
                                const Divider(color: Colors.white24),
                                ...selectedTeam.map((pid) {
                                  final stats = _playerStats[pid] ?? {};
                                  final name = _getPlayerName(pid);
                                  final isCurrent =
                                      (selectedTeamIdx == _currentTeamIndex) &&
                                      (pid ==
                                          _teams[_currentTeamIndex][_activeBatsmanIndex]);

                                  final r = stats['runs'] ?? 0;
                                  final b = stats['balls'] ?? 0;
                                  final fours = stats['4s'] ?? 0;
                                  final sixes = stats['6s'] ?? 0;
                                  final sr = b > 0
                                      ? ((r / b) * 100).toStringAsFixed(1)
                                      : '0.0';
                                  final status =
                                      stats['status'] ?? 'Yet to bat';

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4.0,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                          padding: const EdgeInsets.only(
                                            left: 8.0,
                                            top: 2.0,
                                          ),
                                          child: Text(
                                            status,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: isCurrent
                                                  ? const Color(0xFFF355DA)
                                                  : (status == 'Out'
                                                        ? Colors.redAccent
                                                        : Colors.white38),
                                              fontWeight: isCurrent
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                const SizedBox(height: 24),
                                const Text(
                                  'Bowling',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildTableHeader([
                                  'Bowler',
                                  'O',
                                  'M',
                                  'R',
                                  'W',
                                  'ER',
                                ]),
                                const Divider(color: Colors.white24),
                                ..._selectedPlayers.map((player) {
                                  if (selectedTeam.contains(player.id))
                                    return const SizedBox.shrink();
                                  final stats = bowlerStats[player.id] ?? {};
                                  final double overs = stats['overs'] ?? 0.0;
                                  final int runs = stats['runs'] ?? 0;
                                  final int wickets = stats['wickets'] ?? 0;
                                  final double economy =
                                      stats['economy'] ?? 0.0;
                                  if ((stats['balls'] ?? 0) == 0)
                                    return const SizedBox.shrink();

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4.0,
                                    ),
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
                          : teamBalls.isEmpty
                          ? const Center(
                              child: Text(
                                'No commentary available yet for this innings.',
                                style: TextStyle(color: Colors.white38),
                              ),
                            )
                          : ListView(
                              children: teamBalls.reversed.map((ball) {
                                final over = ball['over'] ?? '0.0';
                                final runs = ball['runs'] ?? 0;
                                final isWide = ball['isWide'] ?? false;
                                final isNoBall = ball['isNoBall'] ?? false;
                                final isWicket = ball['isWicket'] ?? false;
                                final description = ball['description'] ?? '';

                                String badgeText = '$runs';
                                Color badgeColor = const Color(
                                  0xFFF355DA,
                                ).withOpacity(0.15);
                                Color textColor = const Color(0xFFF355DA);

                                if (isWicket) {
                                  badgeText = 'W';
                                  badgeColor = Colors.redAccent.withOpacity(
                                    0.2,
                                  );
                                  textColor = Colors.redAccent;
                                } else if (isWide) {
                                  badgeText = '${runs}wd';
                                  badgeColor = Colors.orangeAccent.withOpacity(
                                    0.2,
                                  );
                                  textColor = Colors.orangeAccent;
                                } else if (isNoBall) {
                                  badgeText = '${runs}nb';
                                  badgeColor = Colors.orangeAccent.withOpacity(
                                    0.2,
                                  );
                                  textColor = Colors.orangeAccent;
                                } else if (runs == 4) {
                                  badgeColor = Colors.green.withOpacity(0.2);
                                  textColor = Colors.green;
                                } else if (runs == 6) {
                                  badgeColor = const Color(
                                    0xFFFFDF7A,
                                  ).withOpacity(0.2);
                                  textColor = const Color(0xFFFFDF7A);
                                }

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 44,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.05),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          over,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: badgeColor,
                                        child: Text(
                                          badgeText,
                                          style: TextStyle(
                                            color: textColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          description,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13,
                                            height: 1.4,
                                          ),
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

  String _getOrdinal(int num) {
    if (num % 100 >= 11 && num % 100 <= 13) return '${num}th';
    switch (num % 10) {
      case 1:
        return '${num}st';
      case 2:
        return '${num}nd';
      case 3:
        return '${num}rd';
      default:
        return '${num}th';
    }
  }

  Future<Map<String, dynamic>?> _showWicketDetailsFullScreen(BuildContext context, String strikerId, String nonStrikerId) async {
    String wicketType = 'Bowled';
    String batsmanOutId = strikerId;
    Player? fielder;
    
    List<String> battingPair = _teams[_currentTeamIndex];
    List<Player> fielders = _selectedPlayers
        .where((p) => !battingPair.contains(p.id))
        .toList();

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
                    if (['Caught', 'Striker Runout', 'Non-Striker Runout', 'Stumped'].contains(wicketType) && fielder == null) return;
                    Navigator.pop(ctx, {
                      'wicketType': wicketType,
                      'fielderId': fielder?.id,
                      'batsmanOutId': batsmanOutId,
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
                    items: ['Bowled', 'Caught', 'LBW', 'Striker Runout', 'Non-Striker Runout', 'Stumped', 'Hit Wicket', 'Other']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white))))
                        .toList(),
                    onChanged: (val) {
                      setStateDialog(() {
                        wicketType = val!;
                        if (wicketType == 'Non-Striker Runout') {
                          batsmanOutId = nonStrikerId;
                        } else {
                          batsmanOutId = strikerId;
                        }
                        fielder = null;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    dropdownColor: Theme.of(context).colorScheme.surface,
                    value: batsmanOutId,
                    decoration: const InputDecoration(labelText: 'Batsman Out', labelStyle: TextStyle(color: Colors.white54)),
                    items: [
                      DropdownMenuItem(value: strikerId, child: Text('${_getPlayerName(strikerId)} (Striker)', style: const TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: nonStrikerId, child: Text('${_getPlayerName(nonStrikerId)} (Non-Striker)', style: const TextStyle(color: Colors.white))),
                    ],
                    onChanged: (wicketType == 'Non-Striker Runout' || wicketType == 'Striker Runout') ? (val) {
                      setStateDialog(() => batsmanOutId = val!);
                    } : null,
                  ),
                  const SizedBox(height: 20),
                  if (['Caught', 'Striker Runout', 'Non-Striker Runout', 'Stumped'].contains(wicketType)) ...[
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
    int runsVal = 0;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Custom Runs',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: StatefulBuilder(
          builder: (ctx2, setStateSub) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.remove,
                    color: Colors.white70,
                    size: 28,
                  ),
                  onPressed: () {
                    if (runsVal > 0) setStateSub(() => runsVal--);
                  },
                ),
                Text(
                  '$runsVal',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.white70, size: 28),
                  onPressed: () => setStateSub(() => runsVal++),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _executeScore(runsVal);
            },
            child: const Text(
              'Submit',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- UI BUILDING CHUNKS ---
  Widget _buildStepHeader(String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF355DA), Color(0xFF6E0DF2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    if (_step > 0) {
                      setState(() {
                        _step--;
                      });
                    } else {
                      Navigator.pop(context);
                    }
                  },
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 56.0, top: 4.0),
              child: Text(
                subtitle,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButton(String text, VoidCallback? onPressed) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      width: double.infinity,
      color: const Color(0xFF0F172A),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF355DA),
          disabledBackgroundColor: Colors.white12,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          shadowColor: const Color(0xFFF355DA).withOpacity(0.3),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: onPressed != null ? Colors.black : Colors.white30,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ),
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

  Widget _buildPlayerAvatar(Player p, {double radius = 24}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFF355DA).withOpacity(0.2),
      backgroundImage: p.imageBase64 != null && p.imageBase64!.isNotEmpty
          ? MemoryImage(base64Decode(p.imageBase64!))
          : null,
      child: p.imageBase64 == null || p.imageBase64!.isEmpty
          ? const Icon(Icons.person, color: Color(0xFFF355DA))
          : null,
    );
  }

  Widget _buildTableHeader(List<String> columns) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            columns[0],
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            columns[1],
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            columns[2],
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            columns[3],
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            columns[4],
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            columns[5],
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
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
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            name,
            style: TextStyle(
              color: isHighlight ? const Color(0xFFF355DA) : Colors.white,
              fontSize: 13,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            v1,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: isHighlight ? const Color(0xFFF355DA) : Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            v2,
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            v3,
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            v4,
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            v5,
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ),
      ],
    );
  }

  // --- STEP VIEWS ---

  // --- STEP 0: Player Selection ---
  Widget _buildPlayerSelectionStep() {
    final provider = Provider.of<CricketProvider>(context);
    final players = provider.players;

    return Column(
      children: [
        _buildStepHeader(
          "Select Players",
          "Pair Mode requires even count of players (min 4)",
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _showCreateNewPlayerDialog(context, (newPlayer) {
                      setState(() {
                        if (!_selectedPlayers.any(
                          (x) => x.id == newPlayer.id,
                        )) {
                          _selectedPlayers.add(newPlayer);
                        }
                      });
                    });
                  },
                  icon: const Icon(
                    Icons.person_add,
                    color: Colors.black,
                    size: 20,
                  ),
                  label: const Text(
                    "ADD PLAYER",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF355DA),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: players.isEmpty
              ? const Center(
                  child: Text(
                    "No players found in roster. Please add some.",
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16.0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: players.length,
                  itemBuilder: (ctx, idx) {
                    final player = players[idx];
                    final isSelected = _selectedPlayers.any(
                      (x) => x.id == player.id,
                    );

                    return Card(
                      color: isSelected
                          ? const Color(0xFF6E0DF2).withOpacity(0.2)
                          : const Color(0xFF1E293B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isSelected
                              ? const Color(0xFFF355DA)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          if (isSelected) {
                            _removePlayerFromMatch(player);
                          } else {
                            _addPlayerToMatch(player);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildPlayerAvatar(player, radius: 28),
                              const SizedBox(height: 8),
                              Text(
                                player.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Matches: ${player.battingMatches}",
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                "Runs: ${player.battingRuns} (SR: ${player.battingStrikeRate.toStringAsFixed(1)})",
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        _buildBottomButton(
          "NEXT (${_selectedPlayers.length} SELECTED)",
          (_selectedPlayers.length >= 4 && _selectedPlayers.length % 2 == 0)
              ? () {
                  setState(() {
                    _step = 1;
                    _orderMode = '';
                    _teams.clear();
                    _manualPairsTemp.clear();
                  });
                }
              : null,
        ),
      ],
    );
  }

  // --- STEP 1: Pairing & Batting Order ---
  Widget _buildPairingStep() {
    return Column(
      children: [
        _buildStepHeader("Batting Pairs", "Group players into teams of 2"),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _showAddPairDialog((p1, p2) {
                      _addPairDuringSetup(p1, p2);
                    });
                  },
                  icon: const Icon(
                    Icons.person_add,
                    color: Colors.black,
                    size: 20,
                  ),
                  label: const Text(
                    "ADD PAIR",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF355DA),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: _buildOptionButton(
                  "RANDOM PAIRS",
                  Icons.shuffle,
                  _orderMode == 'random',
                  _setupRandomPairs,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOptionButton(
                  "MANUAL PAIRS",
                  Icons.touch_app,
                  _orderMode == 'manual',
                  _setupManualPairs,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _orderMode.isEmpty
              ? const Center(
                  child: Text(
                    "Select a pairing mode to continue",
                    style: TextStyle(color: Colors.white38),
                  ),
                )
              : Column(
                  children: [
                    if (_orderMode == 'manual') ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 4.0,
                        ),
                        child: Text(
                          _manualPairsTemp.isEmpty
                              ? "Tap first player of the pair"
                              : "Tap second player for: ${_getPlayerName(_manualPairsTemp[0])}",
                          style: const TextStyle(
                            color: Color(0xFFF355DA),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        itemCount: _selectedPlayers.length,
                        itemBuilder: (ctx, idx) {
                          final player = _selectedPlayers[idx];
                          final int teamIdx = _teams.indexWhere(
                            (t) => t.contains(player.id),
                          );
                          final bool isAssigned = teamIdx != -1;
                          final bool isPending = _manualPairsTemp.contains(
                            player.id,
                          );

                          final List<Color> pairColors = [
                            const Color(0xFFF355DA), // Pink
                            const Color(0xFF3B82F6), // Blue
                            const Color(0xFF10B981), // Green
                            const Color(0xFFF59E0B), // Orange/Amber
                            const Color(0xFF8B5CF6), // Purple
                            const Color(0xFFEC4899), // Deep Pink
                            const Color(0xFF06B6D4), // Cyan
                            const Color(0xFF14B8A6), // Teal
                          ];

                          Color cardColor = const Color(0xFF1E293B);
                          Color borderColor = Colors.transparent;
                          Color badgeColor = const Color(0xFF334155);
                          if (isAssigned) {
                            final pColor =
                                pairColors[teamIdx % pairColors.length];
                            cardColor = pColor.withOpacity(0.08);
                            borderColor = pColor.withOpacity(0.6);
                            badgeColor = pColor;
                          } else if (isPending) {
                            cardColor = const Color(
                              0xFFF355DA,
                            ).withOpacity(0.12);
                            borderColor = const Color(0xFFF355DA);
                            badgeColor = const Color(0xFFF355DA);
                          }

                          return Card(
                            color: cardColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: borderColor),
                            ),
                            margin: const EdgeInsets.symmetric(vertical: 6.0),
                            child: ListTile(
                              onTap: _orderMode == 'manual'
                                  ? () => _handleManualPairTap(player.id)
                                  : null,
                              leading: _buildPlayerAvatar(player, radius: 20),
                              title: Text(
                                player.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              trailing: CircleAvatar(
                                radius: 16,
                                backgroundColor: badgeColor,
                                child: Text(
                                  isAssigned
                                      ? "${teamIdx + 1}"
                                      : (isPending ? "?" : "-"),
                                  style: TextStyle(
                                    color: isAssigned
                                        ? Colors.black
                                        : Colors.white30,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
        _buildBottomButton(
          "NEXT",
          (_teams.length * 2 == _selectedPlayers.length && _teams.isNotEmpty)
              ? () {
                  setState(() {
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
                    // First pair striker starts
                    _playerStats[_teams[0][0]]!['status'] = 'Batting';
                    _currentTeamIndex = 0;
                    _activeBatsmanIndex = 0;
                    _step = 2;
                    _saveState();
                  });
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildOptionButton(
    String text,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(
        icon,
        color: isSelected ? Colors.black : Colors.white54,
        size: 18,
      ),
      label: Text(
        text,
        style: TextStyle(
          color: isSelected ? Colors.black : Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected
            ? const Color(0xFFF355DA)
            : const Color(0xFF1E293B),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // --- STEP 2: Match Settings ---
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
                const Text(
                  "Overs per Pair",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: Color(0xFFF355DA),
                        size: 32,
                      ),
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          fillColor: const Color(0xFF1E293B),
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
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
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: Color(0xFFF355DA),
                        size: 32,
                      ),
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
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: const Text(
                      'Advanced Settings',
                      style: TextStyle(color: Colors.white70),
                    ),
                    collapsedBackgroundColor: const Color(0xFF1E293B),
                    backgroundColor: const Color(0xFF1E293B),
                    childrenPadding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _noBallRunsCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Runs per No Ball',
                                labelStyle: TextStyle(color: Colors.white60),
                              ),
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
                          const Text(
                            'Reball?',
                            style: TextStyle(color: Colors.white70),
                          ),
                          Switch(
                            value: _reballNoBall,
                            activeColor: const Color(0xFFF355DA),
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
                              decoration: const InputDecoration(
                                labelText: 'Runs per Wide',
                                labelStyle: TextStyle(color: Colors.white60),
                              ),
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
                          const Text(
                            'Reball?',
                            style: TextStyle(color: Colors.white70),
                          ),
                          Switch(
                            value: _reballWide,
                            activeColor: const Color(0xFFF355DA),
                            onChanged: (val) {
                              setState(() {
                                _reballWide = val;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Last Batsman Standing',
                            style: TextStyle(color: Colors.white70),
                          ),
                          Switch(
                            value: _lastBatsmanStanding,
                            activeColor: const Color(0xFFF355DA),
                            onChanged: (val) {
                              setState(() {
                                _lastBatsmanStanding = val;
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
          final currentTeam = _teams[_currentTeamIndex];
          final nonBatting = _selectedPlayers
              .where((p) => !currentTeam.contains(p.id))
              .toList();
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
              title: const Text(
                'Select Bowler to Begin',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
                    child: Text(
                      player.name,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }),
      ],
    );
  }

  Map<String, dynamic> _getBowlerLiveStats(String bowlerId) {
    int bowledBalls = 0;
    int runsConceded = 0;
    int wickets = 0;
    int maidens = 0;

    for (var ball in _balls) {
      if (ball['bowlerId'] == bowlerId &&
          ball['teamIndex'] == _currentTeamIndex) {
        final bool isW = ball['isWide'] ?? false;
        final bool isNb = ball['isNoBall'] ?? false;
        final bool isWicket = ball['isWicket'] ?? false;
        final int runsVal = ball['runs'] ?? 0;
        final int runsToAddVal = ball['runsToAdd'] ?? 0;
        final bool isB = ball['isByes'] ?? false;
        final bool isLb = ball['isLegByes'] ?? false;

        final bool countsAsBallFaced = (!isW) || (isW && !_reballWide);
        if (countsAsBallFaced) {
          bowledBalls++;
        }

        int conceded = 0;
        if (!isB && !isLb) {
          conceded = runsToAddVal;
        } else {
          if (isW)
            conceded = runsToAddVal;
          else if (isNb)
            conceded = _noBallRuns;
        }
        runsConceded += conceded;

        if (isWicket) {
          wickets++;
        }
      }
    }

    final oversStr = "${bowledBalls ~/ 6}.${bowledBalls % 6}";
    double oversFraction = bowledBalls / 6.0;
    final erStr = oversFraction > 0
        ? (runsConceded / oversFraction).toStringAsFixed(2)
        : '0.00';

    return {
      'overs': oversStr,
      'maidens': maidens,
      'runsConceded': runsConceded,
      'wickets': wickets,
      'economy': erStr,
    };
  }

  // --- STEP 3: Live Scoreboard ---
  Widget _buildScoreboardStep() {
    final currentTeam = _teams[_currentTeamIndex];
    final strikerId = currentTeam[_activeBatsmanIndex];
    final strikerStats = _playerStats[strikerId] ?? {};
    final strikerName = _getPlayerName(strikerId);
    final strikerRuns = strikerStats['runs'] ?? 0;
    final strikerBalls = strikerStats['balls'] ?? 0;
    final strikerFours = strikerStats['4s'] ?? 0;
    final strikerSixes = strikerStats['6s'] ?? 0;
    final strikerSR = strikerBalls > 0
        ? ((strikerRuns / strikerBalls) * 100).toStringAsFixed(1)
        : '0.0';

    final nonStrikerIndex = _activeBatsmanIndex == 0 ? 1 : 0;
    final nonStrikerId = currentTeam[nonStrikerIndex];
    final nonStrikerStats = _playerStats[nonStrikerId] ?? {};
    final nonStrikerName = _getPlayerName(nonStrikerId);
    final nonStrikerRuns = nonStrikerStats['runs'] ?? 0;
    final nonStrikerBalls = nonStrikerStats['balls'] ?? 0;
    final nonStrikerFours = nonStrikerStats['4s'] ?? 0;
    final nonStrikerSixes = nonStrikerStats['6s'] ?? 0;
    final nonStrikerSR = nonStrikerBalls > 0
        ? ((nonStrikerRuns / nonStrikerBalls) * 100).toStringAsFixed(1)
        : '0.0';

    final teamRuns = getTeamRuns(currentTeam);
    final teamBalls = getTeamBalls(currentTeam);
    final teamWickets = getTeamWickets(currentTeam);

    // Target Chasing info
    final isLastTeam =
        _currentTeamIndex > 0 && _currentTeamIndex == _teams.length - 1;
    int highestScore = 0;
    if (isLastTeam) {
      for (int i = 0; i < _currentTeamIndex; i++) {
        final score = getTeamRuns(_teams[i]);
        if (score > highestScore) highestScore = score;
      }
    }
    final target = highestScore + 1;

    return Column(
      children: [
        // Custom Play Header with Scorecard button
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          color: const Color(0xFF0F172A),
          child: SafeArea(
            bottom: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PAIR INNINGS - ${_getOrdinal(_currentTeamIndex + 1)}',
                      style: const TextStyle(
                        color: Color(0xFFF355DA),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${_getPlayerName(currentTeam[0])} & ${_getPlayerName(currentTeam[1])}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(
                    Icons.assessment,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: _showLiveScorecardDialog,
                ),
              ],
            ),
          ),
        ),
        const Divider(color: Colors.white12, height: 1),
        Builder(
          builder: (context) {
            Widget scoreboardContent = ListView(
              padding: const EdgeInsets.only(top: 16.0),
              children: [
                // Previous scores list
                if (_currentTeamIndex > 0) ...[
                  const Text(
                    'PREVIOUS TEAM SCORES',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GlassContainer(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    borderRadius: 16,
                    child: Column(
                      children: List.generate(_currentTeamIndex, (idx) {
                        final prevTeam = _teams[idx];
                        final names =
                            "${_getPlayerName(prevTeam[0])} & ${_getPlayerName(prevTeam[1])}";
                        final score = getTeamRuns(prevTeam);
                        final wkts = getTeamWickets(prevTeam);
                        final ballsFaced = getTeamBalls(prevTeam);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${_getOrdinal(idx + 1)}: $names',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '$score/$wkts (${ballsFaced ~/ 6}.${ballsFaced % 6} ov)',
                                style: const TextStyle(
                                  color: Color(0xFFF355DA),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Last team target card
                if (isLastTeam) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFBBF24), Color(0xFFB45309)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'TARGET TO BEAT',
                          style: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$target Runs',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Highest prev score: $highestScore runs',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ).animate().scale(duration: 400.ms),
                  const SizedBox(height: 20),
                ],

                // Giant Score Board
                GlassContainer(
                  padding: const EdgeInsets.all(24.0),
                  borderRadius: 16,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'TOTAL SCORE',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '$teamRuns',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 44,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    '/$teamWickets',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'OVERS',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${teamBalls ~/ 6}.${teamBalls % 6} / $_overs.0',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white12, height: 32),
                      _buildTableHeader([
                        'Batsman',
                        'R',
                        'B',
                        '4s',
                        '6s',
                        'SR',
                      ]),
                      const Divider(color: Colors.white10),
                      _buildTableRow(
                        '$strikerName*',
                        '$strikerRuns',
                        '$strikerBalls',
                        '$strikerFours',
                        '$strikerSixes',
                        strikerSR,
                        isHighlight: true,
                      ),
                      const SizedBox(height: 8),
                      _buildTableRow(
                        _isPlayerOut(_playerStats[nonStrikerId]?['status'])
                            ? '$nonStrikerName (Out)'
                            : nonStrikerName,
                        '$nonStrikerRuns',
                        '$nonStrikerBalls',
                        '$nonStrikerFours',
                        '$nonStrikerSixes',
                        nonStrikerSR,
                      ),
                      if (_bowlerId != null) ...[
                        const SizedBox(height: 16),
                        _buildTableHeader(['Bowler', 'O', 'M', 'R', 'W', 'ER']),
                        const Divider(color: Colors.white10),
                        Builder(
                          builder: (context) {
                            final bLiveStats = _getBowlerLiveStats(_bowlerId!);
                            return _buildTableRow(
                              _getPlayerName(_bowlerId),
                              bLiveStats['overs'].toString(),
                              bLiveStats['maidens'].toString(),
                              bLiveStats['runsConceded'].toString(),
                              bLiveStats['wickets'].toString(),
                              bLiveStats['economy'].toString(),
                              isHighlight: true,
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Timeline Over balls
                GlassContainer(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  borderRadius: 16,
                  child: Row(
                    children: [
                      const Text(
                        'THIS OVER: ',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _currentOverBalls.map((ball) {
                              bool isW = ball == 'W';
                              bool isExtra =
                                  ball.contains('wd') || ball.contains('nb');
                              Color color = isW
                                  ? Colors.redAccent
                                  : (isExtra
                                        ? Colors.orangeAccent
                                        : const Color(0xFFF355DA));
                              return Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: color.withOpacity(0.4),
                                  ),
                                ),
                                child: Text(
                                  ball,
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Extras Switches Row
                GlassContainer(
                  padding: const EdgeInsets.all(12),
                  borderRadius: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      FilterChip(
                        label: const Text('Wide'),
                        selected: _isWide,
                        onSelected: (val) => setState(() => _isWide = val),
                        selectedColor: Colors.orangeAccent.withOpacity(0.25),
                        checkmarkColor: Colors.orangeAccent,
                        labelStyle: TextStyle(
                          color: _isWide ? Colors.orangeAccent : Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      FilterChip(
                        label: const Text('No Ball'),
                        selected: _isNoBall,
                        onSelected: (val) => setState(() => _isNoBall = val),
                        selectedColor: Colors.orangeAccent.withOpacity(0.25),
                        checkmarkColor: Colors.orangeAccent,
                        labelStyle: TextStyle(
                          color: _isNoBall
                              ? Colors.orangeAccent
                              : Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      FilterChip(
                        label: const Text('Byes'),
                        selected: _isByes,
                        onSelected: (val) => setState(() => _isByes = val),
                        selectedColor: Colors.blueAccent.withOpacity(0.25),
                        checkmarkColor: Colors.blueAccent,
                        labelStyle: TextStyle(
                          color: _isByes ? Colors.blueAccent : Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      FilterChip(
                        label: const Text('Leg Byes'),
                        selected: _isLegByes,
                        onSelected: (val) => setState(() => _isLegByes = val),
                        selectedColor: Colors.blueAccent.withOpacity(0.25),
                        checkmarkColor: Colors.blueAccent,
                        labelStyle: TextStyle(
                          color: _isLegByes
                              ? Colors.blueAccent
                              : Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Wicket & Finish Buttons
                GlassContainer(
                  padding: const EdgeInsets.all(16),
                  borderRadius: 16,
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              setState(() => _isWicket = !_isWicket),
                          icon: const Icon(Icons.gavel, size: 18),
                          label: const Text(
                            'WICKET',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _isWicket
                                ? Colors.redAccent
                                : Colors.white70,
                            side: BorderSide(
                              color: _isWicket
                                  ? Colors.redAccent
                                  : Colors.white24,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: getTeamWickets(currentTeam) > 0
                            ? null
                            : _swapBatsmen,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Swap Batsman',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          _saveUndoState();
                          _finishBatsmanOrTeamInnings(
                            strikerId,
                            out: false,
                            forceTeamComplete: true,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC2185B),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Finish Innings',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 300.ms),
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
                      children: [_buildActionButton('Undo', _undoLastBall)],
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
                    Expanded(child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: scoreboardContent,
                    )),
                    controlsContent,
                  ],
                ),
                medium: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: scoreboardContent,
                    )),
                    Expanded(flex: 2, child: SingleChildScrollView(child: controlsContent)),
                  ],
                ),
                large: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: scoreboardContent,
                    )),
                    Expanded(flex: 2, child: SingleChildScrollView(child: controlsContent)),
                  ],
                ),
                extraLarge: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: scoreboardContent,
                    )),
                    Expanded(flex: 2, child: SingleChildScrollView(child: controlsContent)),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1E293B),
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white10),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRunButton(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF334155), Color(0xFF1E293B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 18,
              color: Color(0xFFF355DA),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // --- RESULTS STEP 4: Podium & Stable Leaderboard ---
  Widget _buildResultsStep() {
    List<List<String>> sortedTeams = List.from(_teams);
    sortedTeams.sort((a, b) {
      final aRuns = getTeamRuns(a);
      final bRuns = getTeamRuns(b);
      if (bRuns == aRuns) {
        final aIdx = _teams.indexOf(a);
        final bIdx = _teams.indexOf(b);
        return aIdx.compareTo(bIdx);
      }
      return bRuns.compareTo(aRuns);
    });

    final provider = Provider.of<CricketProvider>(context, listen: false);

    // Extract podium players representing teams
    final firstPair = sortedTeams.isNotEmpty ? sortedTeams[0] : null;
    final secondPair = sortedTeams.length > 1 ? sortedTeams[1] : null;
    final thirdPair = sortedTeams.length > 2 ? sortedTeams[2] : null;

    final firstScore = firstPair != null ? getTeamRuns(firstPair) : 0;
    final secondScore = secondPair != null ? getTeamRuns(secondPair) : 0;
    final thirdScore = thirdPair != null ? getTeamRuns(thirdPair) : 0;

    Player _getPlayerModel(String id) {
      return provider.players.firstWhere(
        (p) => p.id == id,
        orElse: () => Player(id: id, name: 'Unknown'),
      );
    }

    return Column(
      children: [
        _buildStepHeader("Match Completed", "Podium and Scorecard details"),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Beautiful Podium View for Pairs
              if (firstPair != null)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // 2nd Place Team
                      if (secondPair != null)
                        Column(
                          children: [
                            Row(
                              children: [
                                _buildPlayerAvatar(
                                  _getPlayerModel(secondPair[0]),
                                  radius: 20,
                                ),
                                const SizedBox(width: 4),
                                _buildPlayerAvatar(
                                  _getPlayerModel(secondPair[1]),
                                  radius: 20,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "${_getPlayerName(secondPair[0]).split(' ')[0]} & ${_getPlayerName(secondPair[1]).split(' ')[0]}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "$secondScore Runs",
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: 90,
                              height: 90,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF94A3B8),
                                    Color(0xFF475569),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(8),
                                  topRight: Radius.circular(8),
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  "2nd",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ).animate().slideY(
                          begin: 0.2,
                          end: 0,
                          duration: 400.ms,
                        ),
                      const SizedBox(width: 10),
                      // 1st Place Team
                      Column(
                        children: [
                          const Icon(
                            Icons.emoji_events,
                            color: Colors.amber,
                            size: 28,
                          ),
                          Row(
                            children: [
                              _buildPlayerAvatar(
                                _getPlayerModel(firstPair[0]),
                                radius: 24,
                              ),
                              const SizedBox(width: 4),
                              _buildPlayerAvatar(
                                _getPlayerModel(firstPair[1]),
                                radius: 24,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "${_getPlayerName(firstPair[0]).split(' ')[0]} & ${_getPlayerName(firstPair[1]).split(' ')[0]}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "$firstScore Runs",
                            style: const TextStyle(
                              color: Color(0xFFF355DA),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 100,
                            height: 120,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(8),
                                topRight: Radius.circular(8),
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                "1st",
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ).animate().slideY(
                        begin: 0.3,
                        end: 0,
                        duration: 500.ms,
                        curve: Curves.easeOutBack,
                      ),
                      const SizedBox(width: 10),
                      // 3rd Place Team
                      if (thirdPair != null)
                        Column(
                          children: [
                            Row(
                              children: [
                                _buildPlayerAvatar(
                                  _getPlayerModel(thirdPair[0]),
                                  radius: 18,
                                ),
                                const SizedBox(width: 4),
                                _buildPlayerAvatar(
                                  _getPlayerModel(thirdPair[1]),
                                  radius: 18,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "${_getPlayerName(thirdPair[0]).split(' ')[0]} & ${_getPlayerName(thirdPair[1]).split(' ')[0]}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "$thirdScore Runs",
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: 90,
                              height: 70,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFFB45309),
                                    Color(0xFF78350F),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(8),
                                  topRight: Radius.circular(8),
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  "3rd",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ).animate().slideY(
                          begin: 0.2,
                          end: 0,
                          duration: 400.ms,
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              const Text(
                'STANDINGS (HIGHEST TO LOWEST)',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // Leaderboard Container
              GlassContainer(
                padding: const EdgeInsets.all(16.0),
                borderRadius: 16,
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Rank & Pair Team',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Score',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white12),
                    ...List.generate(sortedTeams.length, (index) {
                      final team = sortedTeams[index];
                      final names =
                          "${_getPlayerName(team[0])} & ${_getPlayerName(team[1])}";
                      final score = getTeamRuns(team);
                      final ballsFaced = getTeamBalls(team);
                      final wkts = getTeamWickets(team);

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
                                _buildPlayerAvatar(
                                  _getPlayerModel(team[0]),
                                  radius: 14,
                                ),
                                const SizedBox(width: 4),
                                _buildPlayerAvatar(
                                  _getPlayerModel(team[1]),
                                  radius: 14,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  names,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '$score/$wkts (${ballsFaced ~/ 6}.${ballsFaced % 6} ov)',
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
                  icon: const Icon(Icons.refresh, color: Colors.white70),
                  label: const Text(
                    'LET\'S PLAY AGAIN',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.home, color: Colors.black),
                  label: const Text(
                    'EXIT TO HOME',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF355DA),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // Step Rendering
          if (_step == 0) _buildPlayerSelectionStep(),
          if (_step == 1) _buildPairingStep(),
          if (_step == 2) _buildSettingsStep(),
          if (_step == 3) _buildScoreboardStep(),
          if (_step == 4) _buildResultsStep(),

          // Overlay Boundary Celebration
          if (_isDisplayingCelebration) _buildCelebrationOverlay(),
        ],
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
                    color: const Color(0xFFF355DA),
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(
                        color: const Color(0xFFF355DA).withOpacity(0.6),
                        blurRadius: 20,
                      ),
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

// --- READ-ONLY SCORECARD VIEW FOR HISTORICAL PAIR MODE MATCHES ---
class PairModeScorecardScreen extends StatelessWidget {
  final MatchModel match;

  const PairModeScorecardScreen({super.key, required this.match});

  String _getPlayerName(BuildContext context, String? id) {
    if (id == null || id.isEmpty) return 'Unknown';
    final provider = Provider.of<CricketProvider>(context, listen: false);
    final p = provider.players.firstWhere(
      (x) => x.id == id,
      orElse: () => Player(id: '', name: 'Unknown'),
    );
    return p.name;
  }

  Widget _buildPlayerAvatar(
    BuildContext context,
    Player p, {
    double radius = 18,
  }) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFF355DA).withOpacity(0.2),
      backgroundImage: p.imageBase64 != null && p.imageBase64!.isNotEmpty
          ? MemoryImage(base64Decode(p.imageBase64!))
          : null,
      child: p.imageBase64 == null || p.imageBase64!.isEmpty
          ? const Icon(Icons.person, color: Color(0xFFF355DA), size: 16)
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

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CricketProvider>(context);
    final teamsData = List<dynamic>.from(match.matchData['teams'] ?? []);
    final playerStats = Map<String, dynamic>.from(
      match.matchData['playerStats'] ?? {},
    );

    List<List<String>> teams = teamsData
        .map((t) => List<String>.from(t))
        .toList();

    int getTeamRuns(List<String> team) {
      int sum = 0;
      for (var id in team) {
        sum += (playerStats[id]?['runs'] as int? ?? 0);
      }
      return sum;
    }

    int getTeamBalls(List<String> team) {
      int sum = 0;
      for (var id in team) {
        sum += (playerStats[id]?['balls'] as int? ?? 0);
      }
      return sum;
    }

    bool isPlayerOut(String? status) {
      if (status == null) return false;
      return status != 'Yet to bat' && 
             status != 'Batting' && 
             status != 'Target Completed' && 
             status != 'Overs Completed';
    }

    int getTeamWickets(List<String> team) {
      int count = 0;
      for (var id in team) {
        if (isPlayerOut(playerStats[id]?['status'])) {
          count++;
        }
      }
      return count;
    }

    // Sort teams for podium
    List<List<String>> sortedTeams = List.from(teams);
    sortedTeams.sort((a, b) {
      final aRuns = getTeamRuns(a);
      final bRuns = getTeamRuns(b);
      if (bRuns == aRuns) {
        final aIdx = teams.indexOf(a);
        final bIdx = teams.indexOf(b);
        return aIdx.compareTo(bIdx);
      }
      return bRuns.compareTo(aRuns);
    });

    final firstPair = sortedTeams.isNotEmpty ? sortedTeams[0] : null;
    final secondPair = sortedTeams.length > 1 ? sortedTeams[1] : null;
    final thirdPair = sortedTeams.length > 2 ? sortedTeams[2] : null;

    final firstScore = firstPair != null ? getTeamRuns(firstPair) : 0;
    final secondScore = secondPair != null ? getTeamRuns(secondPair) : 0;
    final thirdScore = thirdPair != null ? getTeamRuns(thirdPair) : 0;

    Player _getPlayerModel(String id) {
      return provider.players.firstWhere(
        (p) => p.id == id,
        orElse: () => Player(id: id, name: 'Unknown'),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          'Match Details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Center(
              child: Text(
                match.result,
                style: const TextStyle(
                  color: Color(0xFFF355DA),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),

            // Podium
            if (firstPair != null)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (secondPair != null)
                      Column(
                        children: [
                          Row(
                            children: [
                              _buildPlayerAvatar(
                                context,
                                _getPlayerModel(secondPair[0]),
                              ),
                              const SizedBox(width: 4),
                              _buildPlayerAvatar(
                                context,
                                _getPlayerModel(secondPair[1]),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "${_getPlayerName(context, secondPair[0]).split(' ')[0]} & ${_getPlayerName(context, secondPair[1]).split(' ')[0]}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "$secondScore Runs",
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 80,
                            height: 90,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF94A3B8), Color(0xFF475569)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(8),
                                topRight: Radius.circular(8),
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                "2nd",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ).animate().slideY(begin: 0.2, end: 0, duration: 400.ms),
                    const SizedBox(width: 8),
                    Column(
                      children: [
                        const Icon(
                          Icons.emoji_events,
                          color: Colors.amber,
                          size: 28,
                        ),
                        Row(
                          children: [
                            _buildPlayerAvatar(
                              context,
                              _getPlayerModel(firstPair[0]),
                              radius: 22,
                            ),
                            const SizedBox(width: 4),
                            _buildPlayerAvatar(
                              context,
                              _getPlayerModel(firstPair[1]),
                              radius: 22,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "${_getPlayerName(context, firstPair[0]).split(' ')[0]} & ${_getPlayerName(context, firstPair[1]).split(' ')[0]}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "$firstScore Runs",
                          style: const TextStyle(
                            color: Color(0xFFF355DA),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 90,
                          height: 120,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(8),
                              topRight: Radius.circular(8),
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              "1st",
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ).animate().slideY(
                      begin: 0.3,
                      end: 0,
                      duration: 500.ms,
                      curve: Curves.easeOutBack,
                    ),
                    const SizedBox(width: 8),
                    if (thirdPair != null)
                      Column(
                        children: [
                          Row(
                            children: [
                              _buildPlayerAvatar(
                                context,
                                _getPlayerModel(thirdPair[0]),
                              ),
                              const SizedBox(width: 4),
                              _buildPlayerAvatar(
                                context,
                                _getPlayerModel(thirdPair[1]),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "${_getPlayerName(context, thirdPair[0]).split(' ')[0]} & ${_getPlayerName(context, thirdPair[1]).split(' ')[0]}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "$thirdScore Runs",
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 80,
                            height: 70,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFB45309), Color(0xFF78350F)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(8),
                                topRight: Radius.circular(8),
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                "3rd",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ).animate().slideY(begin: 0.2, end: 0, duration: 400.ms),
                  ],
                ),
              ),

            const SizedBox(height: 24),
            const Text(
              'STANDINGS (HIGHEST TO LOWEST)',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            GlassContainer(
              padding: const EdgeInsets.all(16.0),
              borderRadius: 16,
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Rank & Pair Team',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Score',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12),
                  ...List.generate(sortedTeams.length, (index) {
                    final team = sortedTeams[index];
                    final names =
                        "${_getPlayerName(context, team[0])} & ${_getPlayerName(context, team[1])}";
                    final score = getTeamRuns(team);
                    final ballsFaced = getTeamBalls(team);
                    final wkts = getTeamWickets(team);

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
                              _buildPlayerAvatar(
                                context,
                                _getPlayerModel(team[0]),
                              ),
                              const SizedBox(width: 4),
                              _buildPlayerAvatar(
                                context,
                                _getPlayerModel(team[1]),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                names,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '$score/$wkts (${ballsFaced ~/ 6}.${ballsFaced % 6} ov)',
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
                    'team1Players': (match.matchData['teams'] as List?)?.expand((t) => List<String>.from(t)).toList() ?? [],
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
                backgroundColor: const Color(0xFFF355DA),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 8,
                shadowColor: const Color(0xFFF355DA).withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
