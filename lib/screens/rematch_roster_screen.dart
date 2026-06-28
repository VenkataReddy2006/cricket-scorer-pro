import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/player.dart';
import '../providers/cricket_provider.dart';
import 'match_setup_wizard.dart';

class RematchRosterScreen extends StatefulWidget {
  final String team1Name;
  final String team2Name;
  final String? team1Image;
  final String? team2Image;
  final List<Player> team1Players;
  final List<Player> team2Players;
  final Player? team1Captain;
  final Player? team2Captain;

  const RematchRosterScreen({
    super.key,
    required this.team1Name,
    required this.team2Name,
    this.team1Image,
    this.team2Image,
    required this.team1Players,
    required this.team2Players,
    this.team1Captain,
    this.team2Captain,
  });

  @override
  State<RematchRosterScreen> createState() => _RematchRosterScreenState();
}

class _RematchRosterScreenState extends State<RematchRosterScreen> {
  late List<Player> _team1Players;
  late List<Player> _team2Players;
  late Player? _team1Captain;
  late Player? _team2Captain;

  @override
  void initState() {
    super.initState();
    _team1Players = List.from(widget.team1Players);
    _team2Players = List.from(widget.team2Players);
    _team1Captain = widget.team1Captain;
    _team2Captain = widget.team2Captain;
  }

  void _showAddPlayerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return _AddPlayerDialog(
          currentTeam1Players: _team1Players,
          currentTeam2Players: _team2Players,
          onPlayerAdded: (player, team) {
            setState(() {
              if (team == 1) {
                if (!_team1Players.any((p) => p.id == player.id)) {
                  _team1Players.add(player);
                }
              } else {
                if (!_team2Players.any((p) => p.id == player.id)) {
                  _team2Players.add(player);
                }
              }
            });
          },
        );
      },
    );
  }

  void _continue() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MatchSetupWizard(
          isRematch: true,
          initialTeam1Name: widget.team1Name,
          initialTeam2Name: widget.team2Name,
          initialTeam1Image: widget.team1Image,
          initialTeam2Image: widget.team2Image,
          initialTeam1Players: _team1Players,
          initialTeam2Players: _team2Players,
          initialTeam1Captain: _team1Captain,
          initialTeam2Captain: _team2Captain,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('REMATCH ROSTERS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => _showAddPlayerDialog(context),
            tooltip: 'Add Player',
          )
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Theme.of(context).colorScheme.surface, Theme.of(context).scaffoldBackgroundColor],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTeamList(
                        teamName: widget.team1Name,
                        teamImage: widget.team1Image,
                        players: _team1Players,
                        captain: _team1Captain,
                        color: Colors.cyan,
                      ),
                    ),
                    const VerticalDivider(color: Colors.white24, width: 1),
                    Expanded(
                      child: _buildTeamList(
                        teamName: widget.team2Name,
                        teamImage: widget.team2Image,
                        players: _team2Players,
                        captain: _team2Captain,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: _continue,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('CONTINUE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamList({
    required String teamName,
    required String? teamImage,
    required List<Player> players,
    required Player? captain,
    required Color color,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: color.withOpacity(0.2),
                backgroundImage: teamImage != null && teamImage.isNotEmpty ? MemoryImage(base64Decode(teamImage)) : null,
                child: teamImage == null || teamImage.isEmpty ? Icon(Icons.shield, color: color) : null,
              ),
              const SizedBox(height: 8),
              Text(teamName, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
              Text('${players.length} Players', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ),
        const Divider(color: Colors.white12),
        Expanded(
          child: ListView.builder(
            itemCount: players.length,
            itemBuilder: (context, index) {
              final p = players[index];
              return ListTile(
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: color.withOpacity(0.1),
                  backgroundImage: p.imageBase64 != null && p.imageBase64!.isNotEmpty ? MemoryImage(base64Decode(p.imageBase64!)) : null,
                  child: p.imageBase64 == null || p.imageBase64!.isEmpty ? Icon(Icons.person, color: color, size: 16) : null,
                ),
                title: Text(p.name, style: const TextStyle(fontSize: 13, color: Colors.white)),
                trailing: p.id == captain?.id
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                        child: Text('C', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                      )
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AddPlayerDialog extends StatefulWidget {
  final List<Player> currentTeam1Players;
  final List<Player> currentTeam2Players;
  final Function(Player, int) onPlayerAdded;

  const _AddPlayerDialog({
    required this.currentTeam1Players,
    required this.currentTeam2Players,
    required this.onPlayerAdded,
  });

  @override
  State<_AddPlayerDialog> createState() => _AddPlayerDialogState();
}

class _AddPlayerDialogState extends State<_AddPlayerDialog> {
  String _searchQuery = '';
  
  void _createNewPlayer(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return _CreateNewPlayerDialog(
          onPlayerCreated: (player) {
            Navigator.pop(ctx); 
            setState(() {
              _searchQuery = '';
            });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CricketProvider>(context);
    final allPlayers = provider.players;
    
    final availablePlayers = allPlayers.where((p) {
      bool inT1 = widget.currentTeam1Players.any((tp) => tp.id == p.id);
      bool inT2 = widget.currentTeam2Players.any((tp) => tp.id == p.id);
      bool matchesSearch = p.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return !inT1 && !inT2 && matchesSearch;
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Add Player', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search available players...',
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _createNewPlayer(context),
              icon: const Icon(Icons.add),
              label: const Text('Create New Player'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                foregroundColor: Theme.of(context).primaryColor,
                minimumSize: const Size(double.infinity, 40),
                elevation: 0,
              ),
            ),
            const Divider(color: Colors.white12, height: 24),
            Expanded(
              child: availablePlayers.isEmpty
                  ? const Center(child: Text('No players available', style: TextStyle(color: Colors.white54)))
                  : ListView.builder(
                      itemCount: availablePlayers.length,
                      itemBuilder: (context, index) {
                        final p = availablePlayers[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundImage: p.imageBase64 != null && p.imageBase64!.isNotEmpty ? MemoryImage(base64Decode(p.imageBase64!)) : null,
                            child: p.imageBase64 == null || p.imageBase64!.isEmpty ? const Icon(Icons.person) : null,
                          ),
                          title: Text(p.name, style: const TextStyle(color: Colors.white)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () {
                                  widget.onPlayerAdded(p, 1);
                                  Navigator.pop(context);
                                },
                                child: const Text('T1', style: TextStyle(color: Colors.cyanAccent)),
                              ),
                              TextButton(
                                onPressed: () {
                                  widget.onPlayerAdded(p, 2);
                                  Navigator.pop(context);
                                },
                                child: const Text('T2', style: TextStyle(color: Colors.orangeAccent)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateNewPlayerDialog extends StatefulWidget {
  final Function(Player) onPlayerCreated;
  
  const _CreateNewPlayerDialog({required this.onPlayerCreated});

  @override
  State<_CreateNewPlayerDialog> createState() => _CreateNewPlayerDialogState();
}

class _CreateNewPlayerDialogState extends State<_CreateNewPlayerDialog> {
  final _nameCtrl = TextEditingController();
  String? _imageBase64;
  
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _imageBase64 = base64Encode(bytes);
      });
    }
  }

  void _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    
    final name = _nameCtrl.text.trim();
    final provider = Provider.of<CricketProvider>(context, listen: false);
    
    await provider.addPlayer(name, imageBase64: _imageBase64);
    
    // The player is now in the provider's list. Let's find it.
    final newPlayer = provider.players.lastWhere((p) => p.name == name && p.imageBase64 == _imageBase64);
    widget.onPlayerCreated(newPlayer);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('New Player', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white.withOpacity(0.1),
                backgroundImage: _imageBase64 != null ? MemoryImage(base64Decode(_imageBase64!)) : null,
                child: _imageBase64 == null ? const Icon(Icons.add_a_photo, size: 30) : null,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Player Name'),
              autofocus: true,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _save, child: const Text('Save')),
              ],
            )
          ],
        ),
      ),
    );
  }
}
