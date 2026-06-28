import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/player.dart';
import '../models/match.dart';

class ApiService {
  // Use local backend IP so physical devices on the same Wi-Fi can connect, avoiding infinite hangs.
  // static const String baseUrl = kIsWeb ? 'http://localhost:5000/api' : 'http://192.168.1.33:5000/api';
  static const String baseUrl = 'https://cricket-8zkw.onrender.com/api';

  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<bool> _isGuest() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') == 'guest';
  }

  // --- Auth Methods ---


  static Future<Map<String, dynamic>> googleLogin(String email, String name) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/google-login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'name': name}),
      ).timeout(const Duration(seconds: 5));
      return {'statusCode': response.statusCode, 'body': json.decode(response.body)};
    } catch (e) {
      return {'statusCode': 500, 'body': {'message': 'Connection error'}};
    }
  }


  // --- Player Methods ---
  static Future<List<Player>> getPlayers() async {
    if (await _isGuest()) return [];
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('$baseUrl/players'), headers: headers);
      if (response.statusCode == 200) {
        Iterable l = json.decode(response.body);
        return List<Player>.from(l.map((model) => Player.fromJson(model)));
      }
      return [];
    } catch (e) {
      print('Error getting players: $e');
      return [];
    }
  }

  static Future<bool> syncPlayers(List<Player> players) async {
    if (await _isGuest()) return true;
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/players/sync'),
        headers: headers,
        body: json.encode({
          'players': players.map((p) => p.toJson()).toList(),
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error syncing players: $e');
      return false;
    }
  }

  static Future<bool> updatePlayer(Player player) async {
    if (await _isGuest()) return true;
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/players/${player.id}'),
        headers: headers,
        body: json.encode(player.toJson()),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating player: $e');
      return false;
    }
  }

  static Future<bool> deletePlayer(String id) async {
    if (await _isGuest()) return true;
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/players/$id'),
        headers: headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting player: $e');
      return false;
    }
  }

  // --- Match Methods ---
  static Future<List<MatchModel>> getMatches() async {
    if (await _isGuest()) return [];
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('$baseUrl/matches'), headers: headers);
      if (response.statusCode == 200) {
        Iterable l = json.decode(response.body);
        return List<MatchModel>.from(l.map((model) => MatchModel.fromJson(model)));
      }
      return [];
    } catch (e) {
      print('Error getting matches: $e');
      return [];
    }
  }

  static Future<bool> createMatch(MatchModel match) async {
    if (await _isGuest()) return true;
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/matches'),
        headers: headers,
        body: json.encode(match.toJson()),
      );
      return response.statusCode == 201;
    } catch (e) {
      print('Error creating match: $e');
      return false;
    }
  }

  static Future<bool> updateMatch(MatchModel match) async {
    if (await _isGuest()) return true;
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/matches/${match.id}'),
        headers: headers,
        body: json.encode(match.toJson()),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating match: $e');
      return false;
    }
  }

  static Future<bool> syncMatches(List<MatchModel> matches) async {
    if (await _isGuest()) return true;
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/matches/sync'),
        headers: headers,
        body: json.encode({
          'matches': matches.map((m) => m.toJson()).toList(),
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error syncing matches: $e');
      return false;
    }
  }

  static Future<bool> deleteMatch(String id) async {
    if (await _isGuest()) return true;
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/matches/$id'),
        headers: headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting match: $e');
      return false;
    }
  }
}
