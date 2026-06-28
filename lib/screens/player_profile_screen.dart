import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';
import '../providers/cricket_provider.dart';

class PlayerProfileScreen extends StatefulWidget {
  final Player player;

  const PlayerProfileScreen({super.key, required this.player});

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  Player get player => widget.player;
  String _selectedMode = 'Overall'; // 'Overall', 'Single', 'Pair', 'Team'

  void _showEditPlayerDialog() {
    final controller = TextEditingController(text: player.name);
    String? currentImageBase64 = player.imageBase64;
    XFile? pickedImage;
    final ImagePicker picker = ImagePicker();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF161D29),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(
                  color: Color(0xFF2E3440),
                  width: 1.0,
                ),
              ),
              title: const Text(
                'Edit Player',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      final source = await showModalBottomSheet<ImageSource>(
                        context: context,
                        backgroundColor: const Color(0xFF161D29),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                                ),
                              ),
                            ),
                            ListTile(
                              leading: Icon(
                                Icons.camera_alt,
                                color: Theme.of(context).primaryColor,
                              ),
                              title: const Text('Camera'),
                              onTap: () => Navigator.pop(context, ImageSource.camera),
                            ),
                            ListTile(
                              leading: Icon(
                                Icons.photo_library,
                                color: Theme.of(context).primaryColor,
                              ),
                              title: const Text('Gallery'),
                              onTap: () => Navigator.pop(context, ImageSource.gallery),
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
                          setStateDialog(() {
                            pickedImage = image;
                            currentImageBase64 = null; // Override old image
                          });
                        }
                      }
                    },
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                      backgroundImage: pickedImage != null
                          ? FileImage(File(pickedImage!.path))
                          : (currentImageBase64 != null && currentImageBase64!.isNotEmpty
                              ? MemoryImage(base64Decode(currentImageBase64!))
                              : null) as ImageProvider<Object>?,
                      child: pickedImage == null && (currentImageBase64 == null || currentImageBase64!.isEmpty)
                          ? Icon(Icons.add_a_photo, color: Theme.of(context).primaryColor, size: 30)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(hintText: 'Player Name'),
                    textCapitalization: TextCapitalization.words,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
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
                            setStateDialog(() => isLoading = true);
                            String? base64Str = player.imageBase64;
                            if (pickedImage != null) {
                              final bytes = await pickedImage!.readAsBytes();
                              base64Str = base64Encode(bytes);
                            }
                            
                            player.name = name;
                            player.imageBase64 = base64Str;
                            
                            if (context.mounted) {
                              await Provider.of<CricketProvider>(
                                context,
                                listen: false,
                              ).updatePlayer(player);
                              
                              setState(() {});
                              
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Player details updated.')),
                                );
                              }
                            }
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161D29),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(
              color: Color(0xFF2E3440),
              width: 1.0,
            ),
          ),
          title: const Text(
            'Delete Player',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
          ),
          content: Text(
            'Are you sure you want to delete ${player.name}? This will permanently delete their stats and records.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final provider = Provider.of<CricketProvider>(context, listen: false);
                await provider.deletePlayer(player.id);
                if (context.mounted) {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back to Roster
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${player.name} deleted successfully.')),
                  );
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Map<String, dynamic> _getBattingStats() {
    return {
      'matches': player.getStat(_selectedMode, 'battingMatches'),
      'innings': player.getStat(_selectedMode, 'battingInnings'),
      'runs': player.getStat(_selectedMode, 'battingRuns'),
      'notOuts': player.getStat(_selectedMode, 'battingNotOuts'),
      'bestScore': player.getStat(_selectedMode, 'battingBestScore'),
      'average': (player.getStat(_selectedMode, 'battingAverage', defaultValue: 0.0) as num).toDouble(),
      'strikeRate': (player.getStat(_selectedMode, 'battingStrikeRate', defaultValue: 0.0) as num).toDouble(),
      'fours': player.getStat(_selectedMode, 'battingFours'),
      'sixes': player.getStat(_selectedMode, 'battingSixes'),
      'thirties': player.getStat(_selectedMode, 'battingThirties'),
      'fifties': player.getStat(_selectedMode, 'battingFifties'),
      'hundreds': player.getStat(_selectedMode, 'battingHundreds'),
      'ballsFaced': player.getStat(_selectedMode, 'battingBalls'),
      'ducks': player.getStat(_selectedMode, 'battingDucks'),
      'goldenDucks': player.getStat(_selectedMode, 'battingGoldenDucks'),
    };
  }

  Map<String, dynamic> _getBowlingStats() {
    return {
      'matches': player.getStat(_selectedMode, 'bowlingMatches'),
      'innings': player.getStat(_selectedMode, 'bowlingInnings'),
      'overs': (player.getStat(_selectedMode, 'bowlingOvers', defaultValue: 0.0) as num).toDouble(),
      'wickets': player.getStat(_selectedMode, 'bowlingWickets'),
      'bestWickets': player.getStat(_selectedMode, 'bowlingBestWickets'),
      'bestRuns': player.getStat(_selectedMode, 'bowlingBestRuns'),
      'economy': (player.getStat(_selectedMode, 'bowlingEconomy', defaultValue: 0.0) as num).toDouble(),
      'average': (player.getStat(_selectedMode, 'bowlingAverage', defaultValue: 0.0) as num).toDouble(),
      'threeWickets': player.getStat(_selectedMode, 'bowling3W'),
      'fiveWickets': player.getStat(_selectedMode, 'bowling5W'),
    };
  }

  Map<String, dynamic> _getFieldingStats() {
    return {
      'matches': player.getStat(_selectedMode, 'fieldingMatches'),
      'catches': player.getStat(_selectedMode, 'fieldingCatches'),
      'stumpings': player.getStat(_selectedMode, 'fieldingStumpings'),
      'runOuts': player.getStat(_selectedMode, 'fieldingRunOuts'),
    };
  }

  Map<String, dynamic> _getCaptaincyStats() {
    return {
      'matches': player.getStat(_selectedMode, 'captaincyMatches'),
      'won': player.getStat(_selectedMode, 'captaincyWon'),
      'lost': player.getStat(_selectedMode, 'captaincyLost'),
    };
  }

  Widget _buildModeSelector() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 8.0),
      padding: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: const Color(0xFF161D29),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2E3440)),
      ),
      child: Row(
        children: [
          Expanded(child: _buildModeSelectorOption('Overall', 'Overall')),
          Expanded(child: _buildModeSelectorOption('Single', 'Single')),
          Expanded(child: _buildModeSelectorOption('Pair', 'Pair')),
          Expanded(child: _buildModeSelectorOption('Team', 'Team')),
        ],
      ),
    );
  }

  Widget _buildModeSelectorOption(String label, String value) {
    final isSelected = _selectedMode == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMode = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD4AF37) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            player.name,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white70),
              onPressed: _showEditPlayerDialog,
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white60),
              onPressed: _showDeleteConfirmationDialog,
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            labelColor: const Color(0xFFD4AF37),
            unselectedLabelColor: const Color(0xFF8B8B8B),
            indicatorColor: const Color(0xFFD4AF37),
            indicatorWeight: 1.5,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: 'Batting'),
              Tab(text: 'Bowling'),
              Tab(text: 'Fielding'),
              Tab(text: 'Captaincy'),
            ],
          ),
        ),
        extendBodyBehindAppBar: true,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0B0B0B), Color(0xFF151515)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildModeSelector(),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildBattingStats(context),
                      _buildBowlingStats(context),
                      _buildFieldingStats(context),
                      _buildCaptaincyStats(context),
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

  Widget _buildStatRow(
    BuildContext context,
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
      decoration: BoxDecoration(
        color: const Color(0xFF161D29),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlight
              ? const Color(0xFFC9A227)
              : const Color(0xFF2E3440),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16, color: Colors.white70),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isHighlight
                  ? const Color(0xFFD4AF37)
                  : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBattingStats(BuildContext context) {
    final stats = _getBattingStats();
    return ListView(
      padding: const EdgeInsets.all(20.0),
      children:
          [
                _buildStatRow(context, 'Matches', '${stats['matches']}'),
                _buildStatRow(context, 'Innings', '${stats['innings']}'),
                _buildStatRow(
                  context,
                  'Runs',
                  '${stats['runs']}',
                  isHighlight: true,
                ),
                _buildStatRow(context, 'Not Outs', '${stats['notOuts']}'),
                _buildStatRow(context, 'Balls Faced', '${stats['ballsFaced']}'),
                _buildStatRow(
                  context,
                  'Best Score',
                  '${stats['bestScore']}',
                  isHighlight: true,
                ),
                _buildStatRow(
                  context,
                  'Average',
                  (stats['average'] as double).toStringAsFixed(2),
                ),
                _buildStatRow(
                  context,
                  'Strike Rate',
                  (stats['strikeRate'] as double).toStringAsFixed(2),
                  isHighlight: true,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(color: Colors.white54),
                ),
                _buildStatRow(context, 'Fours (4s)', '${stats['fours']}'),
                _buildStatRow(context, 'Sixes (6s)', '${stats['sixes']}'),
                _buildStatRow(
                  context,
                  'Thirties (30s)',
                  '${stats['thirties']}',
                  isHighlight: true,
                ),
                _buildStatRow(
                  context,
                  'Fifties (50s)',
                  '${stats['fifties']}',
                  isHighlight: true,
                ),
                _buildStatRow(
                  context,
                  'Hundreds (100s)',
                  '${stats['hundreds']}',
                  isHighlight: true,
                ),
                _buildStatRow(context, 'Duckouts', '${stats['ducks']}'),
                _buildStatRow(context, 'Golden Duckouts', '${stats['goldenDucks']}'),
              ]
              .animate(interval: 50.ms)
              .slideY(begin: 0.1, end: 0, curve: Curves.easeOut)
              .fadeIn(),
    );
  }

  Widget _buildBowlingStats(BuildContext context) {
    final stats = _getBowlingStats();
    return ListView(
      padding: const EdgeInsets.all(20.0),
      children:
          [
                _buildStatRow(context, 'Matches', '${stats['matches']}'),
                _buildStatRow(context, 'Innings', '${stats['innings']}'),
                _buildStatRow(
                  context,
                  'Overs',
                  (stats['overs'] as double).toStringAsFixed(1),
                ),
                _buildStatRow(
                  context,
                  'Wickets',
                  '${stats['wickets']}',
                  isHighlight: true,
                ),
                _buildStatRow(
                  context,
                  'Best Bowling',
                  '${stats['bestWickets']}/${stats['bestRuns']}',
                  isHighlight: true,
                ),
                _buildStatRow(
                  context,
                  'Economy',
                  (stats['economy'] as double).toStringAsFixed(2),
                ),
                _buildStatRow(
                  context,
                  'Average',
                  (stats['average'] as double).toStringAsFixed(2),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(color: Colors.white54),
                ),
                _buildStatRow(context, '3 Wickets', '${stats['threeWickets']}'),
                _buildStatRow(
                  context,
                  '5 Wickets',
                  '${stats['fiveWickets']}',
                  isHighlight: true,
                ),
              ]
              .animate(interval: 50.ms)
              .slideY(begin: 0.1, end: 0, curve: Curves.easeOut)
              .fadeIn(),
    );
  }

  Widget _buildFieldingStats(BuildContext context) {
    final stats = _getFieldingStats();
    return ListView(
      padding: const EdgeInsets.all(20.0),
      children:
          [
                _buildStatRow(context, 'Matches', '${stats['matches']}'),
                _buildStatRow(
                  context,
                  'Catches',
                  '${stats['catches']}',
                  isHighlight: true,
                ),
                _buildStatRow(
                  context,
                  'Stumpings',
                  '${stats['stumpings']}',
                ),
                _buildStatRow(context, 'Run Outs', '${stats['runOuts']}'),
              ]
              .animate(interval: 50.ms)
              .slideY(begin: 0.1, end: 0, curve: Curves.easeOut)
              .fadeIn(),
    );
  }

  Widget _buildCaptaincyStats(BuildContext context) {
    final stats = _getCaptaincyStats();
    final matchesCount = stats['matches'] as int;
    final wonCount = stats['won'] as int;
    final lostCount = stats['lost'] as int;
    final winPercentage = matchesCount > 0 ? (wonCount / matchesCount * 100) : 0.0;

    return ListView(
      padding: const EdgeInsets.all(20.0),
      children:
          [
                _buildStatRow(
                  context,
                  'Matches as Captain',
                  '$matchesCount',
                ),
                _buildStatRow(
                  context,
                  'Won',
                  '$wonCount',
                  isHighlight: true,
                ),
                _buildStatRow(context, 'Lost', '$lostCount'),
                _buildStatRow(
                  context,
                  'Win Percentage',
                  '${winPercentage.toStringAsFixed(2)}%',
                  isHighlight: true,
                ),
              ]
              .animate(interval: 50.ms)
              .slideY(begin: 0.1, end: 0, curve: Curves.easeOut)
              .fadeIn(),
    );
  }
}
