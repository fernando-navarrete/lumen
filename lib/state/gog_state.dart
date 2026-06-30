import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gogdl2_flutter_bridge/gogdl2_flutter_bridge.dart';

class GogState {
  final Gog _gog;

  GogState(this._gog);

  String getLoginUrl() {
    return _gog.getLoginUrl();
  }
}

final gogStateProvider = Provider<GogState>((ref) {
  final instance = GogState(Gog());
  ref.onDispose(() => instance._gog.dispose());
  return instance;
}, name: 'gogStateProvider');
