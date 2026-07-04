import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GamesState {
  final HashMap<int, String> _selectedBuilds = HashMap<int, String>();
  final HashMap<int, String> _downloadedBuilds = HashMap<int, String>();

  String? getSelectedBuild(int gameId) {
    String? selectedBuild = _selectedBuilds[gameId];
    if (selectedBuild == null) {
      return null;
    }
    return selectedBuild;
  }

  void setSelectedBuild(int gameId, String buildName) {
    _selectedBuilds[gameId] = buildName;
    persist();
  }

  String _encodeMap(HashMap<int, String> map) {
    final stringKeyed = map.map(
      (gameId, buildId) => MapEntry(gameId.toString(), buildId),
    );
    return jsonEncode(stringKeyed);
  }

  void _decodeMap(String json, HashMap<int, String> target) {
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    target.clear();
    target.addAll(
      decoded.map(
        (gameId, buildId) => MapEntry(int.parse(gameId), buildId as String),
      ),
    );
  }

  String toJson() {
    try {
      return _encodeMap(_selectedBuilds);
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      return '';
    }
  }

  void fromJson(String json) {
    try {
      _decodeMap(json, _selectedBuilds);
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      _selectedBuilds.clear();
    }
  }

  void setDownloadedBuild(int gameId, String buildId) {
    _downloadedBuilds[gameId] = buildId;
    persist();
  }

  bool isDownloadedBuild(int gameId, String buildId) {
    return _downloadedBuilds[gameId] == buildId;
  }

  void persist() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('selectedBuilds', toJson());
      try {
        prefs.setString('downloadedBuilds', _encodeMap(_downloadedBuilds));
      } catch (e) {
        if (kDebugMode) {
          print(e);
        }
      }
    });
  }

  void load() {
    SharedPreferences.getInstance().then((prefs) {
      String? selectedJson = prefs.getString('selectedBuilds');
      if (selectedJson != null) {
        fromJson(selectedJson);
      }
      String? downloadedJson = prefs.getString('downloadedBuilds');
      if (downloadedJson != null) {
        try {
          _decodeMap(downloadedJson, _downloadedBuilds);
        } catch (e) {
          if (kDebugMode) {
            print(e);
          }
          _downloadedBuilds.clear();
        }
      }
    });
  }
}

final gamesStateProvider = Provider<GamesState>((ref) {
  final instance = GamesState();
  instance.load();
  return instance;
}, name: 'gamesStateProvider');
