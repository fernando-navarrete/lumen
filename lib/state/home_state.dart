import 'package:flutter_riverpod/flutter_riverpod.dart';

class NavBarState {
  NavBarItem _item;
  NavBarState(this._item);

  NavBarItem get item => _item;

  void setItem(NavBarItem item) {
    _item = item;
  }
}

enum NavBarItem { library, downloads, settings }

final navBarItemProvider = Provider<NavBarState>((ref) {
  final instance = NavBarState(NavBarItem.library);
  return instance;
}, name: 'navBarItemProvider');
