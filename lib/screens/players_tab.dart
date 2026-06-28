import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/cricket_provider.dart';
import '../widgets/glass_container.dart';
import 'player_profile_screen.dart';
import '../rewarded_ad_helper.dart';

class PlayersTab extends StatelessWidget {
  const PlayersTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CricketProvider>(context);
    final players = provider.players;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ROSTER',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: InkWell(
                onTap: () => _showAddPlayerDialog(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.35),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded, size: 18, color: Colors.black),
                      const SizedBox(width: 4),
                      const Text(
                        'ADD',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ).animate().fadeIn(delay: 300.ms),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.4,
            colors: [
              Color(0xFF141A29),
              Color(0xFF07090F),
            ],
          ),
        ),
        child: SafeArea(
          child: players.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.group_off_outlined,
                        size: 80,
                        color: Colors.white24,
                      ).animate().fadeIn(),
                      const SizedBox(height: 20),
                      const Text(
                        'No players added yet.',
                        style: TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: players.length,
                  itemBuilder: (context, index) {
                    final player = players[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: GlassContainer(
                        borderRadius: 20,
                        blur: 16,
                        borderOpacity: 0.08,
                        backgroundOpacity: 0.04,
                        padding: EdgeInsets.zero,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          leading: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: primaryColor.withOpacity(0.2),
                                width: 2,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 26,
                              backgroundColor: primaryColor.withOpacity(0.08),
                              backgroundImage: player.imageBase64 != null && player.imageBase64!.isNotEmpty
                                  ? MemoryImage(base64Decode(player.imageBase64!))
                                  : null,
                              child: player.imageBase64 == null || player.imageBase64!.isEmpty
                                  ? Icon(
                                      Icons.person,
                                      color: primaryColor,
                                      size: 26,
                                    )
                                  : null,
                            ),
                          ),
                          title: Text(
                            player.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'Matches Played: ${player.getStat('Overall', 'battingMatches')}',
                              style: const TextStyle(color: Colors.white38, fontSize: 13),
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right_rounded,
                            color: primaryColor.withOpacity(0.8),
                          ),
                          onTap: () {
                            RewardedAdHelper.showAd(
                              onComplete: () {
                                Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (context, a, b) =>
                                        PlayerProfileScreen(player: player),
                                    transitionsBuilder: (context, a, b, child) =>
                                        FadeTransition(opacity: a, child: child),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    )
                    .animate()
                    .slideX(
                      begin: 0.15,
                      end: 0,
                      delay: (index * 50).ms,
                      curve: Curves.easeOutQuad,
                    )
                    .fadeIn();
                  },
                ),
        ),
      ),
    );
  }

  void _showAddPlayerDialog(BuildContext context) {
    final controller = TextEditingController();
    XFile? pickedImage;
    final ImagePicker picker = ImagePicker();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF161D29),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(
                  color: Color(0xFF3A3A3A),
                  width: 1.0,
                ),
              ),
              title: const Text(
                'Add Player',
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
                          setState(() {
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
                    decoration: InputDecoration(hintText: 'Player Name'),
                    textCapitalization: TextCapitalization.words,
                    autofocus: true,
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
                            setState(() => isLoading = true);
                            String? base64Str;
                            if (pickedImage != null) {
                              final bytes = await pickedImage!.readAsBytes();
                              base64Str = base64Encode(bytes);
                            }
                            if (context.mounted) {
                              await Provider.of<CricketProvider>(
                                context,
                                listen: false,
                              ).addPlayer(name, imageBase64: base64Str);
                              if (context.mounted) Navigator.pop(context);
                            }
                          }
                        },
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
}
