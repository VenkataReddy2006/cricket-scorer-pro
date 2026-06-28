import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:image_picker/image_picker.dart';
import '../models/match.dart';
import '../models/player.dart';
import '../providers/cricket_provider.dart';
import 'pdf_preview_screen.dart';
import '../widgets/glass_container.dart';

class ScorecardScreen extends StatefulWidget {
  final MatchModel match;

  const ScorecardScreen({super.key, required this.match});

  @override
  State<ScorecardScreen> createState() => _ScorecardScreenState();
}

class _ScorecardScreenState extends State<ScorecardScreen> {
  late MatchModel _match;

  @override
  void initState() {
    super.initState();
    _match = widget.match;
  }

  void _showAddPlayersDialog(BuildContext context) {
    final provider = Provider.of<CricketProvider>(context, listen: false);
    
    // Mapping of player id to target team: 'none', 'team1', 'team2'
    Map<String, String> selectedTeams = {};
    String searchQuery = '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            // Get existing match players (re-read each build to exclude them)
            final List<dynamic> team1PlayersList = _match.matchData['team1Players'] ?? [];
            final List<dynamic> team2PlayersList = _match.matchData['team2Players'] ?? [];
            
            final Set<String> existingPlayerIds = {
              ...team1PlayersList.map((e) => e.toString()),
              ...team2PlayersList.map((e) => e.toString()),
            };

            // Re-fetch list to include newly added players inline
            final currentAllPlayers = provider.players;
            final remainingPlayers = currentAllPlayers.where((p) {
              final isNotAlreadyInMatch = !existingPlayerIds.contains(p.id);
              final matchesSearch = p.name.toLowerCase().contains(searchQuery.toLowerCase());
              return isNotAlreadyInMatch && matchesSearch;
            }).toList();

            return AlertDialog(
              backgroundColor: const Color(0xFF151A28),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: Theme.of(context).primaryColor.withOpacity(0.3),
                ),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add Players',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      // Inline player creation sub-dialog
                      await _showInlineCreatePlayerDialog(context, provider, setStateDialog);
                    },
                    icon: Icon(Icons.add, color: Theme.of(context).primaryColor, size: 18),
                    label: Text(
                      'New Player',
                      style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.5,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Search box
                    TextField(
                      onChanged: (value) {
                        setStateDialog(() {
                          searchQuery = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search roster players...',
                        prefixIcon: const Icon(Icons.search, color: Colors.white54),
                        fillColor: Colors.white.withOpacity(0.05),
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (remainingPlayers.isEmpty)
                      const Expanded(
                        child: Center(
                          child: Text(
                            'No remaining players found.',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          itemCount: remainingPlayers.length,
                          itemBuilder: (context, index) {
                            final player = remainingPlayers[index];
                            final target = selectedTeams[player.id] ?? 'none';
                            
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                                        backgroundImage: player.imageBase64 != null && player.imageBase64!.isNotEmpty
                                            ? MemoryImage(base64Decode(player.imageBase64!))
                                            : null,
                                        child: player.imageBase64 == null || player.imageBase64!.isEmpty
                                            ? Icon(Icons.person, color: Theme.of(context).primaryColor, size: 18)
                                            : null,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          player.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 4,
                                    children: [
                                      ChoiceChip(
                                        label: const Text('None', style: TextStyle(fontSize: 11)),
                                        selected: target == 'none',
                                        onSelected: (selected) {
                                          if (selected) {
                                            setStateDialog(() {
                                              selectedTeams[player.id] = 'none';
                                            });
                                          }
                                        },
                                        selectedColor: Colors.grey.withOpacity(0.3),
                                        backgroundColor: Colors.transparent,
                                        labelStyle: TextStyle(color: target == 'none' ? Colors.white : Colors.white54),
                                      ),
                                      ChoiceChip(
                                        label: Text(_match.team1Name, style: const TextStyle(fontSize: 11)),
                                        selected: target == 'team1',
                                        onSelected: (selected) {
                                          if (selected) {
                                            setStateDialog(() {
                                              selectedTeams[player.id] = 'team1';
                                            });
                                          }
                                        },
                                        selectedColor: Colors.cyan.withOpacity(0.3),
                                        backgroundColor: Colors.transparent,
                                        labelStyle: TextStyle(color: target == 'team1' ? Colors.cyanAccent : Colors.white54),
                                      ),
                                      ChoiceChip(
                                        label: Text(_match.team2Name, style: const TextStyle(fontSize: 11)),
                                        selected: target == 'team2',
                                        onSelected: (selected) {
                                          if (selected) {
                                            setStateDialog(() {
                                              selectedTeams[player.id] = 'team2';
                                            });
                                          }
                                        },
                                        selectedColor: Colors.orange.withOpacity(0.3),
                                        backgroundColor: Colors.transparent,
                                        labelStyle: TextStyle(color: target == 'team2' ? Colors.orangeAccent : Colors.white54),
                                      ),
                                    ],
                                  ),
                                  const Divider(color: Colors.white10),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final List<dynamic> t1Updated = List.from(_match.matchData['team1Players'] ?? []);
                    final List<dynamic> t2Updated = List.from(_match.matchData['team2Players'] ?? []);
                    
                    selectedTeams.forEach((playerId, team) {
                      if (team == 'team1') {
                        if (!t1Updated.contains(playerId)) t1Updated.add(playerId);
                      } else if (team == 'team2') {
                        if (!t2Updated.contains(playerId)) t2Updated.add(playerId);
                      }
                    });

                    setState(() {
                      _match.matchData['team1Players'] = t1Updated;
                      _match.matchData['team2Players'] = t2Updated;
                    });

                    await provider.saveMatch(_match);

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Players added successfully!')),
                      );
                    }
                  },
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showInlineCreatePlayerDialog(
    BuildContext context,
    CricketProvider provider,
    StateSetter setStateDialog,
  ) async {
    final controller = TextEditingController();
    XFile? pickedImage;
    final ImagePicker picker = ImagePicker();
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateInline) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1C2237),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: Theme.of(context).primaryColor.withOpacity(0.3),
                ),
              ),
              title: const Text('Create New Player', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      final source = await showModalBottomSheet<ImageSource>(
                        context: context,
                        backgroundColor: const Color(0xFF151A28),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        builder: (context) => Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text('Select Image Source', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ),
                            ListTile(
                              leading: Icon(Icons.camera_alt, color: Theme.of(context).primaryColor),
                              title: const Text('Camera'),
                              onTap: () => Navigator.pop(context, ImageSource.camera),
                            ),
                            ListTile(
                              leading: Icon(Icons.photo_library, color: Theme.of(context).primaryColor),
                              title: const Text('Gallery'),
                              onTap: () => Navigator.pop(context, ImageSource.gallery),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      );

                      if (source != null) {
                        final image = await picker.pickImage(source: source, imageQuality: 50, maxWidth: 400);
                        if (image != null) {
                          setStateInline(() {
                            pickedImage = image;
                          });
                        }
                      }
                    },
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                      backgroundImage: pickedImage != null ? FileImage(File(pickedImage!.path)) : null,
                      child: pickedImage == null
                          ? Icon(Icons.add_a_photo, color: Theme.of(context).primaryColor, size: 30)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(hintText: 'Player Name'),
                    textCapitalization: TextCapitalization.words,
                    autofocus: true,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = controller.text.trim();
                          if (name.isNotEmpty) {
                            setStateInline(() => isSaving = true);
                            String? base64Str;
                            if (pickedImage != null) {
                              final bytes = await pickedImage!.readAsBytes();
                              base64Str = base64Encode(bytes);
                            }
                            await provider.addPlayer(name, imageBase64: base64Str);
                            if (context.mounted) {
                              Navigator.pop(context);
                              // Trigger rebuild of the parent dialog
                              setStateDialog(() {});
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                        )
                      : const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _getPlayerName(String? id) {
    final provider = Provider.of<CricketProvider>(context, listen: false);
    if (id == null || id.isEmpty) return 'Unknown';
    final p = provider.players.firstWhere(
      (element) => element.id == id,
      orElse: () => Player(id: '', name: 'Unknown'),
    );
    return p.name;
  }

  Widget _buildMainContent(BuildContext context) {
    String type = _match.matchData['type'] ?? 'team_mode';
    if (type == 'single_mode' || type == 'pair_mode') {
      List<dynamic> tabsData = type == 'single_mode'
          ? (_match.matchData['team1Players'] ?? [])
          : (_match.matchData['teams'] ?? []);

      if (tabsData.isEmpty) {
        return const Center(child: Text('No data found.', style: TextStyle(color: Colors.white)));
      }

      return DefaultTabController(
        length: tabsData.length,
        child: Column(
          children: [
            TabBar(
              isScrollable: tabsData.length > 2,
              indicatorColor: Theme.of(context).primaryColor,
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.white54,
              tabs: tabsData.map((data) {
                if (type == 'single_mode') {
                  return Tab(text: _getPlayerName(data.toString()));
                } else {
                  List<String> pair = List<String>.from(data);
                  String p1 = pair.isNotEmpty ? _getPlayerName(pair[0]) : '';
                  String p2 = pair.length > 1 ? _getPlayerName(pair[1]) : '';
                  return Tab(text: '$p1 & $p2');
                }
              }).toList(),
            ),
            Expanded(
              child: TabBarView(
                children: tabsData.map((data) {
                  List<String> targetIds = type == 'single_mode'
                      ? [data.toString()]
                      : List<String>.from(data);
                      
                  String tabName = '';
                  if (type == 'single_mode') {
                    tabName = _getPlayerName(targetIds[0]);
                  } else {
                    String p1 = targetIds.isNotEmpty ? _getPlayerName(targetIds[0]) : '';
                    String p2 = targetIds.length > 1 ? _getPlayerName(targetIds[1]) : '';
                    tabName = '$p1 & $p2';
                  }

                  int tabScore = 0;
                  int tabWickets = 0;
                  final pStats = _match.matchData['playerStats'] ?? {};
                  for (String id in targetIds) {
                    tabScore += pStats[id]?['runs'] as int? ?? 0;
                    String status = pStats[id]?['status'] ?? '';
                    if (status != 'Yet to bat' && status != 'Batting' && status != 'Target Completed' && status != 'Overs Completed' && status != 'Not Out' && status.isNotEmpty) {
                      tabWickets++;
                    }
                  }

                  int totalLegalBalls = 0;
                  List<dynamic> allBalls = _match.matchData['balls'] ?? _match.matchData['balls_1'] ?? [];
                  for (var b in allBalls) {
                    String s = b['strikerId'] ?? '';
                    String ns = b['nonStrikerId'] ?? '';
                    if (targetIds.contains(s) || targetIds.contains(ns)) {
                      bool isW = b['isWide'] ?? false;
                      bool isNb = b['isNoBall'] ?? false;
                      if (!isW && !isNb) {
                        totalLegalBalls++;
                      }
                    }
                  }
                  double tabOvers = totalLegalBalls ~/ 6 + (totalLegalBalls % 6) / 10.0;

                  return ScorecardInningsView(
                    match: _match,
                    teamName: tabName,
                    score: tabScore,
                    wickets: tabWickets,
                    overs: tabOvers,
                    battingTeamIds: _match.matchData['team1Players'] ?? [],
                    bowlingTeamIds: _match.matchData['team1Players'] ?? [],
                    isDynamic: true,
                    dynamicTargetIds: targetIds,
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            indicatorColor: Theme.of(context).primaryColor,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: '${_match.team1Name} Innings'),
              Tab(text: '${_match.team2Name} Innings'),
            ],
          ),
          if (!_match.isCompleted)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).primaryColor.withOpacity(0.15),
                      Colors.teal.withOpacity(0.05)
                    ],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Theme.of(context).primaryColor.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showAddPlayersDialog(context),
                    borderRadius: BorderRadius.circular(30),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 20.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_add_alt_1,
                            color: Theme.of(context).primaryColor,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'ADD PLAYERS TO TEAMS',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Scorecard',
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export PDF & Share',
            onPressed: () async {
              final provider = Provider.of<CricketProvider>(context, listen: false);
              
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(
                    color: Colors.tealAccent,
                  ),
                ),
              );

              try {
                final pdfBytes = await PdfPreviewScreen.generatePdf(
                  PdfPageFormat.a4,
                  _match,
                  provider.players,
                );
                
                if (context.mounted) Navigator.pop(context);

                await Printing.sharePdf(
                  bytes: pdfBytes,
                  filename: 'Match_${_match.team1Name}_vs_${_match.team2Name}_Scorecard.pdf',
                );
              } catch (e) {
                if (context.mounted) Navigator.pop(context);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to generate PDF: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF020617)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: _buildMainContent(context),
            ),
          ),
        ),
      ),
    );
  }
}

class ScorecardInningsView extends StatefulWidget {
  final MatchModel match;
  final String teamName;
  final int score;
  final int wickets;
  final double overs;
  final List<dynamic> battingTeamIds;
  final List<dynamic> bowlingTeamIds;
  final bool isDynamic;
  final List<String>? dynamicTargetIds;

  const ScorecardInningsView({
    super.key,
    required this.match,
    required this.teamName,
    required this.score,
    required this.wickets,
    required this.overs,
    required this.battingTeamIds,
    required this.bowlingTeamIds,
    this.isDynamic = false,
    this.dynamicTargetIds,
  });

  @override
  State<ScorecardInningsView> createState() => _ScorecardInningsViewState();
}

class _ScorecardInningsViewState extends State<ScorecardInningsView> {
  int _selectedSection = 0; // 0: Scorecard, 1: Partnerships, 2: Fall of Wickets, 3: Commentary

  String _getPlayerName(String? id, List<Player> players) {
    if (id == null || id.isEmpty) return 'Unknown';
    final p = players.firstWhere(
      (element) => element.id == id,
      orElse: () => Player(id: '', name: 'Unknown'),
    );
    return p.name;
  }

  List<Map<String, dynamic>> _calculatePartnerships(List<dynamic> balls, List<Player> players) {
    List<Map<String, dynamic>> list = [];
    if (balls.isEmpty) return list;

    String? currentPStrikerId;
    String? currentPNonStrikerId;
    int runs = 0;
    int totalBalls = 0;
    int strikerRuns = 0;
    int strikerBalls = 0;
    int nonStrikerRuns = 0;
    int nonStrikerBalls = 0;
    int extras = 0;

    for (var ball in balls) {
      String strikerId = ball['strikerId'] ?? '';
      String nonStrikerId = ball['nonStrikerId'] ?? '';

      if (currentPStrikerId == null || currentPNonStrikerId == null) {
        currentPStrikerId = strikerId;
        currentPNonStrikerId = nonStrikerId;
      }

      bool isSamePair = (strikerId == currentPStrikerId && nonStrikerId == currentPNonStrikerId) ||
                        (strikerId == currentPNonStrikerId && nonStrikerId == currentPStrikerId);

      if (!isSamePair) {
        // Save ended partnership
        list.add({
          'strikerId': currentPStrikerId,
          'nonStrikerId': currentPNonStrikerId,
          'runs': runs,
          'balls': totalBalls,
          'strikerRuns': strikerRuns,
          'strikerBalls': strikerBalls,
          'nonStrikerRuns': nonStrikerRuns,
          'nonStrikerBalls': nonStrikerBalls,
          'extras': extras,
          'wicketNumber': list.length + 1,
        });

        // Reset for next partnership
        currentPStrikerId = strikerId;
        currentPNonStrikerId = nonStrikerId;
        runs = 0;
        totalBalls = 0;
        strikerRuns = 0;
        strikerBalls = 0;
        nonStrikerRuns = 0;
        nonStrikerBalls = 0;
        extras = 0;
      }

      // Check if this was a retirement record
      bool isRetirement = ball['isRetirement'] ?? false;
      if (isRetirement) {
        list.add({
          'strikerId': currentPStrikerId,
          'nonStrikerId': currentPNonStrikerId,
          'runs': runs,
          'balls': totalBalls,
          'strikerRuns': strikerRuns,
          'strikerBalls': strikerBalls,
          'nonStrikerRuns': nonStrikerRuns,
          'nonStrikerBalls': nonStrikerBalls,
          'extras': extras,
          'wicketNumber': list.length + 1,
          'isRetired': true,
        });

        // Reset using the new batsman from the retirement record
        String retiringId = ball['retiringBatsmanId'] ?? '';
        String nextId = ball['nextBatsmanId'] ?? '';
        if (currentPStrikerId == retiringId) {
          currentPStrikerId = nextId;
        } else {
          currentPNonStrikerId = nextId;
        }
        runs = 0;
        totalBalls = 0;
        strikerRuns = 0;
        strikerBalls = 0;
        nonStrikerRuns = 0;
        nonStrikerBalls = 0;
        extras = 0;
        continue;
      }

      int ballRuns = ball['runs'] ?? 0;
      bool isWide = ball['isWide'] ?? false;
      bool isByes = ball['isByes'] ?? false;
      bool isLegByes = ball['isLegByes'] ?? false;
      int runsToAdd = ball['runsToAdd'] ?? ballRuns;

      runs += runsToAdd;
      if (!isWide) {
        totalBalls++;
      }

      if (strikerId == currentPStrikerId) {
        if (!isWide) {
          strikerBalls++;
          if (!isByes && !isLegByes) {
            strikerRuns += ballRuns;
          }
        }
      } else {
        if (!isWide) {
          nonStrikerBalls++;
          if (!isByes && !isLegByes) {
            nonStrikerRuns += ballRuns;
          }
        }
      }

      int batRuns = 0;
      if (!isWide && !isByes && !isLegByes) {
        batRuns = ballRuns;
      }
      int ballExtras = runsToAdd - batRuns;
      if (ballExtras > 0) {
        extras += ballExtras;
      }
    }

    if (currentPStrikerId != null && currentPNonStrikerId != null) {
      list.add({
        'strikerId': currentPStrikerId,
        'nonStrikerId': currentPNonStrikerId,
        'runs': runs,
        'balls': totalBalls,
        'strikerRuns': strikerRuns,
        'strikerBalls': strikerBalls,
        'nonStrikerRuns': nonStrikerRuns,
        'nonStrikerBalls': nonStrikerBalls,
        'extras': extras,
        'wicketNumber': list.length + 1,
        'isActive': true,
      });
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CricketProvider>(context, listen: false);
    final allPlayers = provider.players;

    Map<dynamic, dynamic> playerStats = widget.match.matchData['playerStats'] != null
        ? Map<dynamic, dynamic>.from(widget.match.matchData['playerStats'])
        : {};

    List<Player> batsmen = allPlayers
        .where((p) => widget.battingTeamIds.contains(p.id))
        .toList();
    List<Player> bowlers = allPlayers
        .where((p) => widget.bowlingTeamIds.contains(p.id))
        .toList();

    String? strikerId = widget.match.matchData['strikerId'];
    String? team1Captain = widget.match.matchData['team1Captain'];
    String? team2Captain = widget.match.matchData['team2Captain'];

    List<dynamic> retiredPlayerIds = widget.match.matchData['retiredPlayerIds'] ?? [];

    Map<dynamic, dynamic> getPlayerStats(String id) {
      return playerStats[id] ?? {};
    }

    int inningsNum = widget.teamName == widget.match.team1Name ? 1 : 2;
    List<dynamic> allBalls = widget.match.matchData['balls_$inningsNum'] ?? widget.match.matchData['balls'] ?? [];
    List<dynamic> balls = allBalls;

    if (widget.isDynamic && widget.dynamicTargetIds != null) {
      balls = allBalls.where((b) {
        String s = b['strikerId'] ?? '';
        String ns = b['nonStrikerId'] ?? '';
        return widget.dynamicTargetIds!.contains(s) || widget.dynamicTargetIds!.contains(ns);
      }).toList();
    }

    Map<String, Map<String, int>> dynamicBowlerStats = {};
    if (widget.isDynamic) {
      for (var ball in balls) {
        String bowlerId = ball['bowlerId'] ?? '';
        if (bowlerId.isEmpty) continue;
        
        dynamicBowlerStats.putIfAbsent(bowlerId, () => {'runsConceded': 0, 'bowledBalls': 0, 'wickets': 0, 'maidens': 0});
        
        bool isW = ball['isWide'] ?? false;
        bool isNb = ball['isNoBall'] ?? false;
        bool isB = ball['isByes'] ?? false;
        bool isLb = ball['isLegByes'] ?? false;
        int runsToAdd = ball['runsToAdd'] ?? (ball['runs'] ?? 0);
        bool isWicket = ball['isWicket'] ?? false;

        if (!isW && !isNb) {
          dynamicBowlerStats[bowlerId]!['bowledBalls'] = dynamicBowlerStats[bowlerId]!['bowledBalls']! + 1;
        }
        
        if (!isB && !isLb) {
          dynamicBowlerStats[bowlerId]!['runsConceded'] = dynamicBowlerStats[bowlerId]!['runsConceded']! + runsToAdd;
        }

        if (isWicket) {
            String dismissalType = ball['dismissalType'] ?? '';
            if (dismissalType != 'Run Out' && dismissalType != 'Retired' && dismissalType != 'Retired Hurt') {
               dynamicBowlerStats[bowlerId]!['wickets'] = dynamicBowlerStats[bowlerId]!['wickets']! + 1;
            }
        }
      }
    }

    var activeBatsmen = widget.isDynamic
        ? batsmen.where((p) => widget.dynamicTargetIds!.contains(p.id)).toList()
        : batsmen.where((p) {
            final stats = getPlayerStats(p.id);
            return (stats['balls'] ?? 0) > 0 ||
                p.id == strikerId ||
                retiredPlayerIds.contains(p.id);
          }).toList();

    var activeBowlers = widget.isDynamic
        ? bowlers.where((p) => dynamicBowlerStats.containsKey(p.id)).toList()
        : bowlers.where((p) {
            final stats = getPlayerStats(p.id);
            return (stats['bowledBalls'] ?? 0) > 0;
          }).toList();

    var yetToBat = widget.isDynamic ? <Player>[] : batsmen.where((p) => !activeBatsmen.contains(p)).toList();

    List<Map<String, dynamic>> partnerships = widget.isDynamic ? [] : _calculatePartnerships(balls, allPlayers);

    int widesCount = 0;
    int noBallsCount = 0;
    int byesCount = 0;
    int legByesCount = 0;
    int totalLegalBalls = 0;

    for (var ball in balls) {
      bool isW = ball['isWide'] ?? false;
      bool isNb = ball['isNoBall'] ?? false;
      bool isB = ball['isByes'] ?? false;
      bool isLb = ball['isLegByes'] ?? false;
      int ballRuns = ball['runs'] ?? 0;
      int runsToAdd = ball['runsToAdd'] ?? ballRuns;

      if (isW) {
        widesCount += runsToAdd;
      } else if (isNb) {
        noBallsCount += (runsToAdd - ballRuns);
      } else if (isB) {
        byesCount += runsToAdd;
      } else if (isLb) {
        legByesCount += runsToAdd;
      }

      if (!isW && !isNb) {
        totalLegalBalls++;
      }
    }

    int totalExtras = widesCount + noBallsCount + byesCount + legByesCount;
    double crr = totalLegalBalls > 0 ? (widget.score / totalLegalBalls) * 6 : 0.0;

    final sections = widget.isDynamic 
      ? ['Scorecard', 'Fall of Wickets', 'Commentary']
      : ['Scorecard', 'Partnerships', 'Fall of Wickets', 'Commentary'];

    final isTeam1 = widget.teamName == widget.match.team1Name;
    final teamColor = isTeam1 ? Colors.cyanAccent : Colors.orangeAccent;
    final teamBaseColor = isTeam1 ? Colors.cyan : Colors.orange;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Score Summary Card
        GlassContainer(
          padding: const EdgeInsets.all(20),
          borderRadius: 16,
          borderColor: teamColor,
          borderOpacity: 0.25,
          backgroundOpacity: 0.05,
          backgroundColor: teamBaseColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.teamName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${widget.score}-${widget.wickets}',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: teamColor,
                    ),
                  ),
                  Text(
                    '(${widget.overs.toStringAsFixed(1)} Overs)',
                    style: const TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Section Selector Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(sections.length, (index) {
              final isSelected = _selectedSection == index;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(sections[index]),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedSection = index);
                    }
                  },
                  selectedColor: teamColor,
                  backgroundColor: const Color(0xFF1E293B).withOpacity(0.4),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected ? Colors.transparent : Colors.white10,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 20),

        // Subsections views
        if (_selectedSection == 0) ...[
          if (activeBatsmen.isNotEmpty) ...[
            const Text(
              'Batting',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            GlassContainer(
              padding: const EdgeInsets.all(16),
              borderRadius: 16,
              borderColor: teamColor.withOpacity(0.5),
              borderOpacity: 0.15,
              backgroundOpacity: 0.03,
              backgroundColor: teamBaseColor,
              child: Column(
                children: [
                  _buildTableHeader(['Batsman', 'R', 'B', '4s', '6s', 'SR']),
                  const Divider(color: Colors.white24),
                  ...activeBatsmen.map((p) {
                    final stats = getPlayerStats(p.id);
                    int runs = stats['runs'] ?? 0;
                    int ballsCount = stats['balls'] ?? 0;
                    String sr = ballsCount == 0
                        ? '0.00'
                        : ((runs / ballsCount) * 100).toStringAsFixed(2);
                    String displayName = p.name;
                    if (p.id == team1Captain || p.id == team2Captain) displayName += ' (C)';
                    if (p.id == strikerId) displayName += '*';
                    if (retiredPlayerIds.contains(p.id)) displayName += ' (retired)';
                    
                    return Column(
                      children: [
                        _buildTableRow(
                          displayName,
                          '$runs',
                          '$ballsCount',
                          '${stats['4s'] ?? 0}',
                          '${stats['6s'] ?? 0}',
                          sr,
                          subtitle: stats['status'] == 'Yet to bat' || stats['status'] == null ? (retiredPlayerIds.contains(p.id) ? 'retired' : (p.id == strikerId || p.id == widget.match.matchData['nonStrikerId'] ? 'batting' : 'yet to bat')) : stats['status'],
                        ),
                        const SizedBox(height: 8),
                      ],
                    );
                  }),
                  const Divider(color: Colors.white24),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        const Expanded(
                          flex: 3,
                          child: Text(
                            'Extras',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Center(
                            child: Text(
                              '$totalExtras',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 5,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              '${byesCount} B, ${legByesCount} LB, ${widesCount} WD, ${noBallsCount} NB, 0 P',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white24),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        const Expanded(
                          flex: 3,
                          child: Text(
                            'Total',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${widget.score}-${widget.wickets} (${widget.overs.toStringAsFixed(1)} Ov)',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              crr.toStringAsFixed(2),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
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
          ],
          const SizedBox(height: 20),
          if (activeBowlers.isNotEmpty) ...[
            const Text(
              'Bowling',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            GlassContainer(
              padding: const EdgeInsets.all(16),
              borderRadius: 16,
              borderColor: (isTeam1 ? Colors.orangeAccent : Colors.cyanAccent).withOpacity(0.5),
              borderOpacity: 0.15,
              backgroundOpacity: 0.03,
              backgroundColor: isTeam1 ? Colors.orange : Colors.cyan,
              child: Column(
                children: [
                  _buildTableHeader(['Bowler', 'O', 'M', 'R', 'W', 'ER']),
                  const Divider(color: Colors.white24),
                  ...activeBowlers.map((p) {
                    final stats = getPlayerStats(p.id);
                    int runs = widget.isDynamic ? (dynamicBowlerStats[p.id]?['runsConceded'] ?? 0) : (stats['runsConceded'] ?? 0);
                    int ballsCount = widget.isDynamic ? (dynamicBowlerStats[p.id]?['bowledBalls'] ?? 0) : (stats['bowledBalls'] ?? 0);
                    int wickets = widget.isDynamic ? (dynamicBowlerStats[p.id]?['wickets'] ?? 0) : (stats['wickets'] ?? 0);
                    int maidens = widget.isDynamic ? (dynamicBowlerStats[p.id]?['maidens'] ?? 0) : (stats['maidens'] ?? 0);
                    
                    String oversStr = '${ballsCount ~/ 6}.${ballsCount % 6}';
                    String er = ballsCount == 0
                        ? '0.00'
                        : (runs / (ballsCount / 6)).toStringAsFixed(2);
                    String displayName = p.name;
                    if (p.id == team1Captain || p.id == team2Captain) displayName += ' (C)';
                    
                    return Column(
                      children: [
                        _buildTableRow(
                          displayName,
                          oversStr,
                          '$maidens',
                          '$runs',
                          '$wickets',
                          er,
                        ),
                        const SizedBox(height: 8),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ],
          if (yetToBat.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Yet to bat',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            GlassContainer(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              borderRadius: 16,
              borderColor: teamColor.withOpacity(0.3),
              borderOpacity: 0.1,
              backgroundOpacity: 0.02,
              backgroundColor: teamBaseColor,
              child: Text(
                yetToBat.map((p) => (p.id == team1Captain || p.id == team2Captain) ? '${p.name} (C)' : p.name).join(', '),
                style: const TextStyle(color: Colors.white70, height: 1.5),
              ),
            ),
          ],
        ],

        if (_selectedSection == 1) ...[
          if (partnerships.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40.0),
              child: Center(
                child: Text(
                  'No partnerships recorded yet.',
                  style: TextStyle(color: Colors.white54, fontSize: 16),
                ),
              ),
            )
          else
            ...partnerships.map((p) {
              String sName = _getPlayerName(p['strikerId'], allPlayers);
              String nsName = _getPlayerName(p['nonStrikerId'], allPlayers);
              int pRuns = p['runs'] ?? 0;
              int pBalls = p['balls'] ?? 0;
              int sRuns = p['strikerRuns'] ?? 0;
              int sBalls = p['strikerBalls'] ?? 0;
              int nsRuns = p['nonStrikerRuns'] ?? 0;
              int nsBalls = p['nonStrikerBalls'] ?? 0;
              int pExtras = p['extras'] ?? 0;
              bool isActive = p['isActive'] ?? false;
              bool isRetired = p['isRetired'] ?? false;

              return GlassContainer(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                borderRadius: 16,
                borderColor: teamColor.withOpacity(0.3),
                borderOpacity: 0.15,
                backgroundOpacity: 0.03,
                backgroundColor: teamBaseColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isActive
                              ? 'Active Partnership'
                              : (isRetired ? 'Wicket #${p['wicketNumber']} (Retirement)' : 'Wicket #${p['wicketNumber']}'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isActive ? teamColor : Colors.white70,
                          ),
                        ),
                        Text(
                          '$pRuns runs ($pBalls b)',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Progress Split Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        height: 8,
                        width: double.infinity,
                        color: Colors.white10,
                        child: Row(
                          children: [
                            if (sRuns > 0)
                              Expanded(
                                flex: sRuns,
                                child: Container(color: teamColor),
                              ),
                            if (nsRuns > 0)
                              Expanded(
                                flex: nsRuns,
                                child: Container(color: Colors.tealAccent),
                              ),
                            if (pExtras > 0)
                              Expanded(
                                flex: pExtras,
                                child: Container(color: Colors.orangeAccent),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Names and values
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '$sName: $sRuns ($sBalls b)',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '$nsName: $nsRuns ($nsBalls b)',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          'Extras: $pExtras',
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],

        if (_selectedSection == 2) ...[
          if (balls.where((b) => b['isWicket'] == true).isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40.0),
              child: Center(
                child: Text(
                  'No wickets fallen yet.',
                  style: TextStyle(color: Colors.white54, fontSize: 16),
                ),
              ),
            )
          else
            GlassContainer(
              padding: const EdgeInsets.all(16),
              borderRadius: 16,
              borderColor: Colors.redAccent.withOpacity(0.3),
              borderOpacity: 0.15,
              backgroundOpacity: 0.03,
              backgroundColor: Colors.redAccent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Fall of Wickets',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Divider(color: Colors.white24, height: 24),
                  ...balls.where((b) => b['isWicket'] == true).toList().asMap().entries.map((entry) {
                    int idx = entry.key;
                    var w = entry.value;
                    int wNum = idx + 1;
                    int scoreAtW = w['teamScore'] ?? 0;
                    int wicketsAtW = w['teamWickets'] ?? 0;
                    String batsmanName = _getPlayerName(w['batsmanOutId'] ?? w['strikerId'], allPlayers);
                    String overStr = w['over'] ?? '0.0';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '$wNum',
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$scoreAtW-$wicketsAtW ($batsmanName)',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Over: $overStr',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
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

        if (_selectedSection == 3) ...[
          if (balls.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40.0),
              child: Center(
                child: Text(
                  'No deliveries bowled yet.',
                  style: TextStyle(color: Colors.white54, fontSize: 16),
                ),
              ),
            )
          else
            ...balls.reversed.map((b) {
              bool isW = b['isWicket'] ?? false;
              bool isRet = b['isRetirement'] ?? false;
              bool isExtra = (b['isWide'] ?? false) || (b['isNoBall'] ?? false);
              int runs = b['runs'] ?? 0;
              String over = b['over'] ?? '0.0';
              String label = b['label'] ?? '';
              String desc = b['description'] ?? '';

              Color badgeColor = Colors.white10;
              Color textColor = Colors.white;
              if (isW) {
                badgeColor = Colors.redAccent;
                textColor = Colors.white;
              } else if (isRet) {
                badgeColor = Colors.grey;
                textColor = Colors.white;
              } else if (runs == 4) {
                badgeColor = Colors.blueAccent;
                textColor = Colors.white;
              } else if (runs == 6) {
                badgeColor = Colors.purpleAccent;
                textColor = Colors.white;
              } else if (isExtra) {
                badgeColor = Colors.orangeAccent.withOpacity(0.2);
                textColor = Colors.orangeAccent;
              }

              return GlassContainer(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                borderRadius: 12,
                borderColor: badgeColor.withOpacity(0.3),
                borderOpacity: 0.15,
                backgroundOpacity: 0.03,
                backgroundColor: badgeColor,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Text(
                          over,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: badgeColor,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              label,
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            desc,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Score: ${b['teamScore']}-${b['teamWickets']}',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
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
            style: const TextStyle(
              color: Colors.white54,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Center(
            child: Text(
              columns[1],
              style: const TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Center(
            child: Text(
              columns[2],
              style: const TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Center(
            child: Text(
              columns[3],
              style: const TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Center(
            child: Text(
              columns[4],
              style: const TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              columns[5],
              style: const TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableRow(
    String col1,
    String col2,
    String col3,
    String col4,
    String col5,
    String col6, {
    String? subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                col1,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null && subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        Expanded(
          flex: 1,
          child: Center(
            child: Text(
              col2,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Center(
            child: Text(col3, style: const TextStyle(color: Colors.white70)),
          ),
        ),
        Expanded(
          flex: 1,
          child: Center(
            child: Text(col4, style: const TextStyle(color: Colors.white70)),
          ),
        ),
        Expanded(
          flex: 1,
          child: Center(
            child: Text(col5, style: const TextStyle(color: Colors.white70)),
          ),
        ),
        Expanded(
          flex: 2,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(col6, style: const TextStyle(color: Colors.white70)),
          ),
        ),
      ],
    );
  }
}
