import 'dart:convert';
import 'package:cricket/rewarded_ad_helper.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/player.dart';
import '../models/match.dart';
import '../providers/cricket_provider.dart';
import 'match_score_screen.dart';
import '../widgets/glass_container.dart';

class MatchSetupWizard extends StatefulWidget {
  final bool isRematch;
  final String? initialTeam1Name;
  final String? initialTeam2Name;
  final String? initialTeam1Image;
  final String? initialTeam2Image;
  final List<Player>? initialTeam1Players;
  final List<Player>? initialTeam2Players;
  final Player? initialTeam1Captain;
  final Player? initialTeam2Captain;

  const MatchSetupWizard({
    super.key,
    this.isRematch = false,
    this.initialTeam1Name,
    this.initialTeam2Name,
    this.initialTeam1Image,
    this.initialTeam2Image,
    this.initialTeam1Players,
    this.initialTeam2Players,
    this.initialTeam1Captain,
    this.initialTeam2Captain,
  });

  @override
  State<MatchSetupWizard> createState() => _MatchSetupWizardState();
}

class _MatchSetupWizardState extends State<MatchSetupWizard> {
  int _currentStep = 0;
  String _playerSearchQuery = '';

  List<Player> _selectedPlayers = [];
  final _team1NameCtrl = TextEditingController(text: 'Team 1');
  final _team2NameCtrl = TextEditingController(text: 'Team 2');
  Player? _team1Captain;
  Player? _team2Captain;
  List<Player> _team1Players = [];
  List<Player> _team2Players = [];
  bool _isTeam1TurnToPick = true;
  List<Player> _availableDraftPlayers = [];
  String _tossWonBy = 'Team 1';
  String _chooseTo = 'Bat';
  final _oversCtrl = TextEditingController(text: '20');

  bool _isAdvancedSettingsExpanded = false;
  final _noBallRunsCtrl = TextEditingController(text: '1');
  bool _reballOnNoBall = true;
  final _wideRunsCtrl = TextEditingController(text: '1');
  bool _reballOnWide = true;

  Player? _striker;
  Player? _nonStriker;
  Player? _bowler;

  String? _team1ImageBase64;
  String? _team2ImageBase64;

  @override
  void initState() {
    super.initState();
    if (widget.isRematch) {
      _currentStep = 5; // Settings step
      _team1NameCtrl.text = widget.initialTeam1Name ?? 'Team 1';
      _team2NameCtrl.text = widget.initialTeam2Name ?? 'Team 2';
      _team1ImageBase64 = widget.initialTeam1Image;
      _team2ImageBase64 = widget.initialTeam2Image;
      _team1Players = widget.initialTeam1Players ?? [];
      _team2Players = widget.initialTeam2Players ?? [];
      _team1Captain =
          widget.initialTeam1Captain ??
          (_team1Players.isNotEmpty ? _team1Players.first : null);
      _team2Captain =
          widget.initialTeam2Captain ??
          (_team2Players.isNotEmpty ? _team2Players.first : null);
    }
  }

  void _nextStep() {
    if (_currentStep == 0 && _selectedPlayers.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least 4 players')),
      );
      return;
    }
    if (_currentStep == 2 && (_team1Captain == null || _team2Captain == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select captains for both teams')),
      );
      return;
    }
    if (_currentStep == 2) {
      // After captains, go to Toss step
      setState(() => _currentStep++);
      return;
    }
    if (_currentStep == 3) {
      // After toss, set up the draft: toss winner picks first
      _availableDraftPlayers = List.from(_selectedPlayers)
        ..remove(_team1Captain)
        ..remove(_team2Captain);
      _team1Players = [_team1Captain!];
      _team2Players = [_team2Captain!];
      // Toss winner picks first
      _isTeam1TurnToPick = (_tossWonBy == 'Team 1');
      setState(() => _currentStep++);
      return;
    }
    if (_currentStep == 4 && _availableDraftPlayers.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Complete the draft first')));
      return;
    }
    if (_currentStep == 6) {
      if (_striker == null || _nonStriker == null || _bowler == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select openers and bowler')),
        );
        return;
      }
      if (_striker == _nonStriker) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Striker and non-striker must be different'),
          ),
        );
        return;
      }
      _startMatch();
      return;
    }

    // Check if Rematch flow skip backwards
    if (widget.isRematch && _currentStep == 5) {
      // Don't let them go backward to toss/draft if it's a rematch. They started at step 5.
    }

    setState(() => _currentStep++);
  }

  void _startMatch() {
    final matchId = const Uuid().v4();
    final match = MatchModel(
      id: matchId,
      team1Name: _team1NameCtrl.text,
      team2Name: _team2NameCtrl.text,
      date: DateTime.now(),
      overs: int.tryParse(_oversCtrl.text) ?? 20,
      matchData: {
        'tossWonBy': _tossWonBy == 'Team 1'
            ? _team1NameCtrl.text
            : _team2NameCtrl.text,
        'chooseTo': _chooseTo,
        'team1Players': _team1Players.map((e) => e.id).toList(),
        'team2Players': _team2Players.map((e) => e.id).toList(),
        'team1Captain':
            _team1Captain?.id ??
            (_team1Players.isNotEmpty ? _team1Players.first.id : ''),
        'team2Captain':
            _team2Captain?.id ??
            (_team2Players.isNotEmpty ? _team2Players.first.id : ''),
        'team1Image': _team1ImageBase64,
        'team2Image': _team2ImageBase64,
        'noBallRuns': int.tryParse(_noBallRunsCtrl.text) ?? 1,
        'reballOnNoBall': _reballOnNoBall,
        'wideRuns': int.tryParse(_wideRunsCtrl.text) ?? 1,
        'reballOnWide': _reballOnWide,
        'strikerId': _striker!.id,
        'nonStrikerId': _nonStriker!.id,
        'bowlerId': _bowler!.id,
        'currentInnings': 1,
        'battingTeam': _tossWonBy == 'Team 1'
            ? (_chooseTo == 'Bat' ? 1 : 2)
            : (_chooseTo == 'Bat' ? 2 : 1),
      },
    );

    Provider.of<CricketProvider>(context, listen: false).saveMatch(match);
    RewardedAdHelper.showAd();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => MatchScoreScreen(match: match)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MATCH SETUP',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [Color(0xFF131A2A), Color(0xFF0A0E17)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Theme(
                data: Theme.of(context).copyWith(
                  canvasColor: Theme.of(context).colorScheme.surface,
                  colorScheme: Theme.of(
                    context,
                  ).colorScheme.copyWith(primary: Theme.of(context).primaryColor),
                ),
                child: Stepper(
              type: StepperType.horizontal,
              currentStep: _currentStep,
              onStepContinue: _nextStep,
              onStepCancel: () {
                if (widget.isRematch && _currentStep == 5) {
                  Navigator.pop(context); // Go back to Rematch screen
                } else if (_currentStep > 0) {
                  setState(() => _currentStep--);
                }
              },
              controlsBuilder: (context, details) {
                return Padding(
                  padding: const EdgeInsets.only(top: 20.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: details.onStepContinue,
                          child: Text(
                            _currentStep == 6
                                ? 'START MATCH'
                                : (_currentStep == 0
                                      ? 'NEXT (${_selectedPlayers.length} SELECTED)'
                                      : 'NEXT'),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      if (_currentStep > 0 || widget.isRematch)
                        const SizedBox(width: 10),
                      if (_currentStep > 0 || widget.isRematch)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: details.onStepCancel,
                            child: const Text('BACK'),
                          ),
                        ),
                    ],
                  ),
                ).animate().fadeIn();
              },
              steps: [
                _buildStep1(),
                _buildStep2(),
                _buildStep3(),
                _buildStepToss(),
                _buildStep4(),
                _buildStep5(),
                _buildStep6(),
              ],
            ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Step _buildStep1() {
    final allPlayers = Provider.of<CricketProvider>(context).players;
    final filteredPlayers = allPlayers.where((p) {
      return p.name.toLowerCase().contains(_playerSearchQuery.toLowerCase());
    }).toList();

    return Step(
      title: _currentStep == 0
          ? const Text(
              'Players',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            )
          : const SizedBox.shrink(),
      content: allPlayers.isEmpty
          ? const Text(
              'Add players in the Players tab first.',
              style: TextStyle(color: Color(0x8A1B5E20)),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        _playerSearchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search roster players...',
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.white54,
                      ),
                      fillColor: Colors.white.withOpacity(0.05),
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Theme.of(context).primaryColor,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  height: MediaQuery.of(context).size.height * 0.52,
                  child: GlassContainer(
                    padding: EdgeInsets.zero,
                    borderRadius: 12,
                    child: filteredPlayers.isEmpty
                        ? const Center(
                            child: Text(
                              'No players match your search.',
                              style: TextStyle(color: Colors.white54),
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(8),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.85,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                            itemCount: filteredPlayers.length,
                            itemBuilder: (context, index) {
                              final p = filteredPlayers[index];
                              final isSelected = _selectedPlayers.contains(p);
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedPlayers.remove(p);
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
                                      color: isSelected
                                          ? Theme.of(context).primaryColor
                                          : Colors.white.withOpacity(0.05),
                                      width: 2,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: Theme.of(
                                                context,
                                              ).primaryColor.withOpacity(0.15),
                                              blurRadius: 8,
                                              spreadRadius: 1,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Stack(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            CircleAvatar(
                                              radius: 26,
                                              backgroundColor: Theme.of(
                                                context,
                                              ).primaryColor.withOpacity(0.2),
                                              backgroundImage:
                                                  p.imageBase64 != null &&
                                                      p.imageBase64!.isNotEmpty
                                                  ? MemoryImage(
                                                      base64Decode(
                                                        p.imageBase64!,
                                                      ),
                                                    )
                                                  : null,
                                              child:
                                                  p.imageBase64 == null ||
                                                      p.imageBase64!.isEmpty
                                                  ? Icon(
                                                      Icons.person,
                                                      color: Theme.of(
                                                        context,
                                                      ).primaryColor,
                                                      size: 26,
                                                    )
                                                  : null,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              p.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: Colors.white,
                                              ),
                                              textAlign: TextAlign.center,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 8),
                                            const Divider(
                                              color: Colors.white10,
                                              height: 1,
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceAround,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    children: [
                                                      const Text(
                                                        'M',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          color: Colors.white54,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        '${p.battingMatches}',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Column(
                                                    children: [
                                                      const Text(
                                                        'Runs',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          color: Colors.white54,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        '${p.battingRuns}',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Column(
                                                    children: [
                                                      const Text(
                                                        'SR',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          color: Colors.white54,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        p.battingStrikeRate
                                                            .toStringAsFixed(1),
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Theme.of(
                                                            context,
                                                          ).primaryColor,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Theme.of(
                                                context,
                                              ).primaryColor,
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
                ),
              ],
            ),
      isActive: _currentStep >= 0,
      state: _currentStep > 0 ? StepState.complete : StepState.indexed,
    );
  }

  Step _buildStep2() {
    return Step(
      title: _currentStep == 1
          ? const Text(
              'Teams',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            )
          : const SizedBox.shrink(),
      content: Column(
        children: [
          GlassContainer(
            padding: const EdgeInsets.all(16),
            borderRadius: 16,
            borderColor: Colors.cyanAccent,
            borderOpacity: 0.15,
            backgroundOpacity: 0.05,
            backgroundColor: Colors.cyan,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (picked != null) {
                      final bytes = await picked.readAsBytes();
                      setState(() => _team1ImageBase64 = base64Encode(bytes));
                    }
                  },
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.cyan.withOpacity(0.2),
                    backgroundImage: _team1ImageBase64 != null
                        ? MemoryImage(base64Decode(_team1ImageBase64!))
                        : null,
                    child: _team1ImageBase64 == null
                        ? const Icon(Icons.add_a_photo, color: Colors.cyan)
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _team1NameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Team 1 Name (Blue/Cyan)',
                      labelStyle: TextStyle(color: Colors.cyanAccent),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.cyanAccent),
                      ),
                    ),
                    style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassContainer(
            padding: const EdgeInsets.all(16),
            borderRadius: 16,
            borderColor: Colors.orangeAccent,
            borderOpacity: 0.15,
            backgroundOpacity: 0.05,
            backgroundColor: Colors.orange,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (picked != null) {
                      final bytes = await picked.readAsBytes();
                      setState(() => _team2ImageBase64 = base64Encode(bytes));
                    }
                  },
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.orange.withOpacity(0.2),
                    backgroundImage: _team2ImageBase64 != null
                        ? MemoryImage(base64Decode(_team2ImageBase64!))
                        : null,
                    child: _team2ImageBase64 == null
                        ? const Icon(Icons.add_a_photo, color: Colors.orange)
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _team2NameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Team 2 Name (Orange)',
                      labelStyle: TextStyle(color: Colors.orangeAccent),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.orangeAccent),
                      ),
                    ),
                    style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ).animate().slideX(begin: 0.1, end: 0).fadeIn(),
      isActive: _currentStep >= 1,
      state: _currentStep > 1 ? StepState.complete : StepState.indexed,
    );
  }

  Step _buildStep3() {
    return Step(
      title: _currentStep == 2
          ? const Text(
              'Captains',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            )
          : const SizedBox.shrink(),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tap a player to assign as captain',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.cyan.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.cyan.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _team1NameCtrl.text,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.cyanAccent,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _team1Captain?.name ?? "Not Selected",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _team2NameCtrl.text,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.orangeAccent,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _team2Captain?.name ?? "Not Selected",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.45,
            child: GlassContainer(
              padding: EdgeInsets.zero,
              borderRadius: 12,
              child: GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.78,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _selectedPlayers.length,
                itemBuilder: (context, index) {
                  final p = _selectedPlayers[index];
                  final isT1C = _team1Captain == p;
                  final isT2C = _team2Captain == p;
                  final double winPct = p.captaincyMatches > 0
                      ? (p.captaincyWon / p.captaincyMatches) * 100
                      : 0.0;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isT1C) {
                          _team1Captain = null;
                        } else if (isT2C) {
                          _team2Captain = null;
                        } else if (_team1Captain == null) {
                          _team1Captain = p;
                        } else if (_team2Captain == null) {
                          _team2Captain = p;
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Both captains already selected. Tap one to remove first.',
                              ),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isT1C
                              ? Colors.cyanAccent
                              : (isT2C
                                    ? Colors.orangeAccent
                                    : Colors.white.withOpacity(0.05)),
                          width: 2,
                        ),
                        boxShadow: isT1C || isT2C
                            ? [
                                BoxShadow(
                                  color: (isT1C ? Colors.cyan : Colors.orange)
                                      .withOpacity(0.15),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
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
                                  backgroundColor:
                                      (isT1C
                                              ? Colors.cyan
                                              : (isT2C
                                                    ? Colors.orange
                                                    : Theme.of(
                                                        context,
                                                      ).primaryColor))
                                          .withOpacity(0.2),
                                  backgroundImage:
                                      p.imageBase64 != null &&
                                          p.imageBase64!.isNotEmpty
                                      ? MemoryImage(
                                          base64Decode(p.imageBase64!),
                                        )
                                      : null,
                                  child:
                                      p.imageBase64 == null ||
                                          p.imageBase64!.isEmpty
                                      ? Icon(
                                          Icons.person,
                                          color: isT1C
                                              ? Colors.cyanAccent
                                              : (isT2C
                                                    ? Colors.orangeAccent
                                                    : Theme.of(
                                                        context,
                                                      ).primaryColor),
                                          size: 26,
                                        )
                                      : null,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  p.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                const Divider(color: Colors.white10, height: 1),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        children: [
                                          const Text(
                                            'M',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: Colors.white54,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${p.captaincyMatches}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        children: [
                                          const Text(
                                            'W',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: Colors.white54,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${p.captaincyWon}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.greenAccent,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        children: [
                                          const Text(
                                            'L',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: Colors.white54,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${p.captaincyLost}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.redAccent,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        children: [
                                          const Text(
                                            'Win%',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: Colors.white54,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${winPct.toStringAsFixed(0)}%',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.amberAccent,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (isT1C || isT2C)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: isT1C ? Colors.cyan : Colors.orange,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isT1C ? 'CAPT 1' : 'CAPT 2',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
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
          ),
        ],
      ).animate().slideX(begin: 0.1, end: 0).fadeIn(),
      isActive: _currentStep >= 2,
      state: _currentStep > 2 ? StepState.complete : StepState.indexed,
    );
  }

  Step _buildStepToss() {
    final team1Name = _team1NameCtrl.text;
    final team2Name = _team2NameCtrl.text;
    final captain1Name = _team1Captain?.name ?? team1Name;
    final captain2Name = _team2Captain?.name ?? team2Name;
    final tossWonByName = _tossWonBy == 'Team 1' ? team1Name : team2Name;
    final picksFirst = _tossWonBy == 'Team 1' ? captain1Name : captain2Name;

    return Step(
      title: _currentStep == 3
          ? const Text(
              'Toss',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            )
          : const SizedBox.shrink(),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Who won the toss?',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _tossWonBy = 'Team 1'),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _tossWonBy == 'Team 1'
                          ? Colors.cyan.withOpacity(0.2)
                          : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _tossWonBy == 'Team 1'
                            ? Colors.cyanAccent
                            : Colors.white12,
                        width: _tossWonBy == 'Team 1' ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.shield,
                          color: _tossWonBy == 'Team 1'
                              ? Colors.cyanAccent
                              : Colors.white38,
                          size: 36,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          team1Name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _tossWonBy == 'Team 1'
                                ? Colors.cyanAccent
                                : Colors.white60,
                            fontSize: 15,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'C: $captain1Name',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.0),
                child: Text(
                  'VS',
                  style: TextStyle(
                    color: Colors.white38,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _tossWonBy = 'Team 2'),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _tossWonBy == 'Team 2'
                          ? Colors.orange.withOpacity(0.2)
                          : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _tossWonBy == 'Team 2'
                            ? Colors.orangeAccent
                            : Colors.white12,
                        width: _tossWonBy == 'Team 2' ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.shield,
                          color: _tossWonBy == 'Team 2'
                              ? Colors.orangeAccent
                              : Colors.white38,
                          size: 36,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          team2Name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _tossWonBy == 'Team 2'
                                ? Colors.orangeAccent
                                : Colors.white60,
                            fontSize: 15,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'C: $captain2Name',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_tossWonBy.isNotEmpty) ...[
            GlassContainer(
              padding: const EdgeInsets.all(16),
              borderRadius: 14,
              borderColor: _tossWonBy == 'Team 1' ? Colors.cyanAccent : Colors.orangeAccent,
              borderOpacity: 0.25,
              backgroundOpacity: 0.05,
              backgroundColor: _tossWonBy == 'Team 1' ? Colors.cyan : Colors.orange,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.emoji_events,
                        color: _tossWonBy == 'Team 1'
                            ? Colors.cyanAccent
                            : Colors.orangeAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$tossWonByName won the toss!',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _tossWonBy == 'Team 1'
                              ? Colors.cyanAccent
                              : Colors.orangeAccent,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.people,
                          color: Colors.white54,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$picksFirst gets first pick in the player draft',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ).animate().slideX(begin: 0.1, end: 0).fadeIn(),
      isActive: _currentStep >= 3,
      state: _currentStep > 3 ? StepState.complete : StepState.indexed,
    );
  }

  Step _buildStep4() {
    return Step(
      title: _currentStep == 4
          ? const Text(
              'Draft',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            )
          : const SizedBox.shrink(),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_availableDraftPlayers.isNotEmpty) ...[
            GlassContainer(
              padding: const EdgeInsets.all(16),
              borderRadius: 16,
              borderColor: _isTeam1TurnToPick ? Colors.cyanAccent : Colors.orangeAccent,
              borderOpacity: 0.25,
              backgroundOpacity: 0.05,
              backgroundColor: _isTeam1TurnToPick ? Colors.cyan : Colors.orange,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.swap_horizontal_circle,
                        color: _isTeam1TurnToPick ? Colors.cyanAccent : Colors.orangeAccent,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_isTeam1TurnToPick ? _team1NameCtrl.text : _team2NameCtrl.text}\'s Turn to Pick',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _isTeam1TurnToPick ? Colors.cyanAccent : Colors.orangeAccent,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: _availableDraftPlayers.map((p) {
                      return ActionChip(
                        label: Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        backgroundColor: Colors.white.withOpacity(0.06),
                        side: BorderSide(color: Colors.white.withOpacity(0.1)),
                        onPressed: () {
                          setState(() {
                            if (_isTeam1TurnToPick)
                              _team1Players.add(p);
                            else
                              _team2Players.add(p);
                            _availableDraftPlayers.remove(p);
                            _isTeam1TurnToPick = !_isTeam1TurnToPick;
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GlassContainer(
                  padding: const EdgeInsets.all(12),
                  borderRadius: 16,
                  borderColor: Colors.cyanAccent,
                  borderOpacity: 0.15,
                  backgroundOpacity: 0.03,
                  backgroundColor: Colors.cyan,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _team1NameCtrl.text,
                        style: const TextStyle(
                          color: Colors.cyanAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._team1Players
                          .map(
                            (p) => Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4.0,
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_outline, size: 14, color: Colors.cyanAccent),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      p.name + (p == _team1Captain ? ' (C)' : ''),
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GlassContainer(
                  padding: const EdgeInsets.all(12),
                  borderRadius: 16,
                  borderColor: Colors.orangeAccent,
                  borderOpacity: 0.15,
                  backgroundOpacity: 0.03,
                  backgroundColor: Colors.orange,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _team2NameCtrl.text,
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._team2Players
                          .map(
                            (p) => Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4.0,
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_outline, size: 14, color: Colors.orangeAccent),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      p.name + (p == _team2Captain ? ' (C)' : ''),
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ).animate().slideX(begin: 0.1, end: 0).fadeIn(),
      isActive: _currentStep >= 4,
      state: _currentStep > 4 ? StepState.complete : StepState.indexed,
    );
  }

  Step _buildStep5() {
    return Step(
      title: _currentStep == 5
          ? const Text(
              'Settings',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            )
          : const SizedBox.shrink(),
      content: Column(
        children: [
          TextField(
            controller: _oversCtrl,
            decoration: InputDecoration(labelText: 'Overs per Innings'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
          // Toss Bat/Bowl choice
          // Toss winner + Bat/Bowl choice
          GlassContainer(
            padding: const EdgeInsets.all(16),
            borderRadius: 14,
            borderOpacity: 0.08,
            backgroundOpacity: 0.04,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Who won the toss?',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _tossWonBy = 'Team 1'),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _tossWonBy == 'Team 1'
                                ? Colors.cyan.withOpacity(0.2)
                                : Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _tossWonBy == 'Team 1'
                                  ? Colors.cyanAccent
                                  : Colors.white12,
                              width: _tossWonBy == 'Team 1' ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.shield,
                                color: _tossWonBy == 'Team 1'
                                    ? Colors.cyanAccent
                                    : Colors.white38,
                                size: 24,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _team1NameCtrl.text,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _tossWonBy == 'Team 1'
                                      ? Colors.cyanAccent
                                      : Colors.white60,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'VS',
                        style: TextStyle(
                          color: Colors.white38,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _tossWonBy = 'Team 2'),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _tossWonBy == 'Team 2'
                                ? Colors.orange.withOpacity(0.2)
                                : Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _tossWonBy == 'Team 2'
                                  ? Colors.orangeAccent
                                  : Colors.white12,
                              width: _tossWonBy == 'Team 2' ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.shield,
                                color: _tossWonBy == 'Team 2'
                                    ? Colors.orangeAccent
                                    : Colors.white38,
                                size: 24,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _team2NameCtrl.text,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _tossWonBy == 'Team 2'
                                      ? Colors.orangeAccent
                                      : Colors.white60,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.emoji_events,
                      color: _tossWonBy == 'Team 1'
                          ? Colors.cyanAccent
                          : Colors.orangeAccent,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${_tossWonBy == 'Team 1' ? _team1NameCtrl.text : _team2NameCtrl.text} won the toss — choose to bat or bowl',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _tossWonBy == 'Team 1'
                              ? Colors.cyanAccent
                              : Colors.orangeAccent,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _chooseTo = 'Bat'),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: _chooseTo == 'Bat'
                                ? Colors.green.withOpacity(0.2)
                                : Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _chooseTo == 'Bat'
                                  ? Colors.greenAccent
                                  : Colors.white12,
                              width: _chooseTo == 'Bat' ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.sports_cricket,
                                color: _chooseTo == 'Bat'
                                    ? Colors.greenAccent
                                    : Colors.white38,
                                size: 30,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'BAT',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: _chooseTo == 'Bat'
                                      ? Colors.greenAccent
                                      : Colors.white54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _chooseTo = 'Bowl'),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: _chooseTo == 'Bowl'
                                ? Colors.redAccent.withOpacity(0.2)
                                : Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _chooseTo == 'Bowl'
                                  ? Colors.redAccent
                                  : Colors.white12,
                              width: _chooseTo == 'Bowl' ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.sports_baseball,
                                color: _chooseTo == 'Bowl'
                                    ? Colors.redAccent
                                    : Colors.white38,
                                size: 30,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'BOWL',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: _chooseTo == 'Bowl'
                                      ? Colors.redAccent
                                      : Colors.white54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              title: const Text(
                'Advanced Settings',
                style: TextStyle(color: Colors.white70),
              ),
              collapsedBackgroundColor: Theme.of(context).colorScheme.surface,
              backgroundColor: Theme.of(context).colorScheme.surface,
              childrenPadding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _noBallRunsCtrl,
                        decoration: InputDecoration(
                          labelText: 'Runs per No Ball',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text('Reball?'),
                    Switch(
                      value: _reballOnNoBall,
                      activeColor: Theme.of(context).primaryColor,
                      onChanged: (val) => setState(() => _reballOnNoBall = val),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _wideRunsCtrl,
                        decoration: InputDecoration(labelText: 'Runs per Wide'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text('Reball?'),
                    Switch(
                      value: _reballOnWide,
                      activeColor: Theme.of(context).primaryColor,
                      onChanged: (val) => setState(() => _reballOnWide = val),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ).animate().slideX(begin: 0.1, end: 0).fadeIn(),
      isActive: _currentStep >= 5,
    );
  }

  Step _buildStep6() {
    bool isTeam1Batting =
        (_tossWonBy == 'Team 1' && _chooseTo == 'Bat') ||
        (_tossWonBy == 'Team 2' && _chooseTo == 'Bowl');
    List<Player> battingTeam = isTeam1Batting ? _team1Players : _team2Players;
    List<Player> bowlingTeam = isTeam1Batting ? _team2Players : _team1Players;

    return Step(
      title: _currentStep == 6
          ? const Text(
              'Openers',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            )
          : const SizedBox.shrink(),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassContainer(
            padding: const EdgeInsets.all(16),
            borderRadius: 16,
            borderColor: isTeam1Batting ? Colors.cyanAccent : Colors.orangeAccent,
            borderOpacity: 0.15,
            backgroundOpacity: 0.04,
            backgroundColor: isTeam1Batting ? Colors.cyan : Colors.orange,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isTeam1Batting ? _team1NameCtrl.text : _team2NameCtrl.text,
                  style: TextStyle(
                    color: isTeam1Batting ? Colors.cyanAccent : Colors.orangeAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Text(
                  'Select Opening Batsmen',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Player>(
                  value: _striker,
                  dropdownColor: const Color(0xFF131A2A),
                  hint: const Text('Striker', style: TextStyle(color: Colors.white38)),
                  items: battingTeam
                      .map((e) => DropdownMenuItem(value: e, child: Text(e.name, style: const TextStyle(color: Colors.white))))
                      .toList(),
                  onChanged: (val) => setState(() => _striker = val),
                  decoration: InputDecoration(
                    labelText: 'Striker',
                    labelStyle: TextStyle(color: isTeam1Batting ? Colors.cyanAccent : Colors.orangeAccent),
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: isTeam1Batting ? Colors.cyanAccent : Colors.orangeAccent)),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Player>(
                  value: _nonStriker,
                  dropdownColor: const Color(0xFF131A2A),
                  hint: const Text('Non-Striker', style: TextStyle(color: Colors.white38)),
                  items: battingTeam
                      .map((e) => DropdownMenuItem(value: e, child: Text(e.name, style: const TextStyle(color: Colors.white))))
                      .toList(),
                  onChanged: (val) => setState(() => _nonStriker = val),
                  decoration: InputDecoration(
                    labelText: 'Non-Striker',
                    labelStyle: TextStyle(color: isTeam1Batting ? Colors.cyanAccent : Colors.orangeAccent),
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: isTeam1Batting ? Colors.cyanAccent : Colors.orangeAccent)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GlassContainer(
            padding: const EdgeInsets.all(16),
            borderRadius: 16,
            borderColor: isTeam1Batting ? Colors.orangeAccent : Colors.cyanAccent,
            borderOpacity: 0.15,
            backgroundOpacity: 0.04,
            backgroundColor: isTeam1Batting ? Colors.orange : Colors.cyan,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isTeam1Batting ? _team2NameCtrl.text : _team1NameCtrl.text,
                  style: TextStyle(
                    color: isTeam1Batting ? Colors.orangeAccent : Colors.cyanAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Text(
                  'Select Opening Bowler',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Player>(
                  value: _bowler,
                  dropdownColor: const Color(0xFF131A2A),
                  hint: const Text('Bowler', style: TextStyle(color: Colors.white38)),
                  items: bowlingTeam
                      .map((e) => DropdownMenuItem(value: e, child: Text(e.name, style: const TextStyle(color: Colors.white))))
                      .toList(),
                  onChanged: (val) => setState(() => _bowler = val),
                  decoration: InputDecoration(
                    labelText: 'Bowler',
                    labelStyle: TextStyle(color: isTeam1Batting ? Colors.orangeAccent : Colors.cyanAccent),
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: isTeam1Batting ? Colors.orangeAccent : Colors.cyanAccent)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ).animate().slideX(begin: 0.1, end: 0).fadeIn(),
      isActive: _currentStep >= 6,
    );
  }
}
