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

extension NavBarItemLabel on NavBarItem {
  String get label => switch (this) {
    NavBarItem.library => 'Library',
    NavBarItem.downloads => 'Downloads',
    NavBarItem.settings => 'Settings',
  };
}

final navBarItemProvider = Provider<NavBarState>((ref) {
  final instance = NavBarState(NavBarItem.library);
  return instance;
}, name: 'navBarItemProvider');

/// Live text of the nav-bar search field; the library grid filters on it.
class LibrarySearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
}

final librarySearchProvider = NotifierProvider<LibrarySearchNotifier, String>(
  LibrarySearchNotifier.new,
  name: 'librarySearchProvider',
);
