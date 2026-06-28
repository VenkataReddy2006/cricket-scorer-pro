import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/player.dart';
import '../models/match.dart';
import '../services/api_service.dart';

class CricketProvider with ChangeNotifier {
  Box<Player>? _playersBox;
  Box<MatchModel>? _matchesBox;

  List<Player> get players => _playersBox?.values.toList() ?? [];
  List<MatchModel> get matches => _matchesBox?.values.toList() ?? [];

  bool isInitialized = false;

  CricketProvider() {
    _init();
  }

  Future<void> _init() async {
    _playersBox = Hive.box<Player>('players');
    _matchesBox = Hive.box<MatchModel>('matches');
    isInitialized = true;
    notifyListeners();
    // Auto-sync with backend on startup
    syncWithBackend();
  }

  Future<void> syncWithBackend() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token == 'guest' || token.startsWith('google_offline_')) {
        return; // Skip synchronization for guests and offline sessions
      }

      // Sync players

      final remotePlayers = await ApiService.getPlayers();
      for (var rp in remotePlayers) {
        if (!_playersBox!.values.any((lp) => lp.id == rp.id)) {
          await _playersBox!.add(rp);
        }
      }
      if (_playersBox!.isNotEmpty) {
        await ApiService.syncPlayers(_playersBox!.values.toList());
      }

      // Sync matches
      final remoteMatches = await ApiService.getMatches();
      for (var rm in remoteMatches) {
        if (!_matchesBox!.values.any((lm) => lm.id == rm.id)) {
          await _matchesBox!.put(rm.id, rm);
        }
      }
      if (_matchesBox!.isNotEmpty) {
        await ApiService.syncMatches(_matchesBox!.values.toList());
      }

      notifyListeners();
    } catch (e) {
      print('Sync failed: $e');
    }
  }

  Future<void> addPlayer(String name, {String? imageBase64}) async {
    final player = Player(
      id: const Uuid().v4(),
      name: name,
      imageBase64: imageBase64,
    );
    await _playersBox?.add(player);
    notifyListeners();
    syncWithBackend();
  }

  Future<void> updatePlayer(Player player) async {
    if (player.isInBox) {
      await player.save();
    } else {
      final index = _playersBox?.values.toList().indexWhere((p) => p.id == player.id) ?? -1;
      if (index != -1) {
        await _playersBox!.putAt(index, player);
      }
    }
    notifyListeners();
    ApiService.updatePlayer(player);
  }

  Future<void> deletePlayer(String playerId) async {
    if (_playersBox != null) {
      final index = _playersBox!.values.toList().indexWhere((p) => p.id == playerId);
      if (index != -1) {
        await _playersBox!.deleteAt(index);
      }
    }
    notifyListeners();
    ApiService.deletePlayer(playerId);
  }

  Future<void> updatePlayers(List<Player> updatedPlayers) async {
    for (var player in updatedPlayers) {
      player.recalculateOverallStats();
      await player.save();
    }
    notifyListeners();
    syncWithBackend();
  }

  Future<void> saveMatch(MatchModel match) async {
    if (_matchesBox != null) {
      await _matchesBox!.put(match.id, match); // Save locally in Hive
    }
    notifyListeners();
    // Upsert to MongoDB (creates if new, updates if exists)
    ApiService.updateMatch(match);
  }

  Future<void> deleteMatch(String matchId) async {
    if (_matchesBox != null) {
      await _matchesBox!.delete(matchId);
    }
    notifyListeners();
    ApiService.deleteMatch(matchId);
  }

  Future<void> clearData() async {
    if (_playersBox != null) await _playersBox!.clear();
    if (_matchesBox != null) await _matchesBox!.clear();
    notifyListeners();
  }
}
