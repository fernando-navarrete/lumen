import 'dart:collection';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GamesState {
  final HashMap<int, String> _selectedBuilds = HashMap<int, String>();

  String? getSelectedBuild(int gameId) {
    String? selectedBuild = _selectedBuilds[gameId];
    if (selectedBuild == null) {
      return null;
    }
    return selectedBuild;
  }

  void setSelectedBuild(int gameId, String buildId) {
    _selectedBuilds[gameId] = buildId;
    persist();
  }

  String toJson() {
    try {
      final stringKeyed = _selectedBuilds.map(
        (gameId, buildId) => MapEntry(gameId.toString(), buildId),
      );
      return jsonEncode(stringKeyed);
    } catch (e) {
      print(e);
      return '';
    }
  }

  void fromJson(String json) {
    try {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      _selectedBuilds.clear();
      _selectedBuilds.addAll(
        decoded.map(
          (gameId, buildId) => MapEntry(int.parse(gameId), buildId as String),
        ),
      );
    } catch (e) {
      print(e);
      _selectedBuilds.clear();
    }
  }

  void persist() {
    String json = toJson();
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('selectedBuilds', json);
    });
  }

  void load() {
    SharedPreferences.getInstance().then((prefs) {
      String? json = prefs.getString('selectedBuilds');
      if (json != null) {
        fromJson(json);
      }
    });
  }
}

final gamesStateProvider = Provider<GamesState>((ref) {
  final instance = GamesState();
  instance.load();
  return instance;
}, name: 'gamesStateProvider');
