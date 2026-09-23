import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NavBarItem { library, downloads, settings }

extension NavBarItemLabel on NavBarItem {
  String get label => switch (this) {
    NavBarItem.library => 'Library',
    NavBarItem.downloads => 'Downloads',
    NavBarItem.settings => 'Settings',
  };
}

/// The single source of truth for which top-level page is selected.
class NavBarNotifier extends Notifier<NavBarItem> {
  @override
  NavBarItem build() => NavBarItem.library;

  void select(NavBarItem item) => state = item;
}

final navBarItemProvider = NotifierProvider<NavBarNotifier, NavBarItem>(
  NavBarNotifier.new,
  name: 'navBarItemProvider',
);

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
