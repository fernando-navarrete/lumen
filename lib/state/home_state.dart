import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen/state/library_state.dart';

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

enum SelectedTab { overview, builds, settings, dlc, saves }

extension SelectedTabLabel on SelectedTab {
  String get label => switch (this) {
    SelectedTab.overview => 'Overview',
    SelectedTab.builds => 'Builds',
    SelectedTab.dlc => 'DLC',
    SelectedTab.saves => 'Saves',
    SelectedTab.settings => 'Settings',
  };
}

/// The game open in the library and which of its details tabs is showing.
typedef LibrarySelection = ({int gameId, SelectedTab tab});

/// The single source of truth for the library's selected game, so it
/// survives switching nav tabs. Null means the grid is showing.
class LibrarySelectionNotifier extends Notifier<LibrarySelection?> {
  @override
  LibrarySelection? build() {
    // A refreshed owned list that no longer has the selected game (refunded)
    // falls back to the grid. Loading and errors keep the selection: a failed
    // refresh keeps the previous list.
    ref.listen(ownedGamesProvider, (_, next) {
      final owned = next.value;
      final selected = state;
      if (next.isLoading || owned == null || selected == null) return;
      if (!owned.contains(selected.gameId)) state = null;
    });
    return null;
  }

  void select(int gameId) =>
      state = (gameId: gameId, tab: SelectedTab.overview);

  void selectTab(SelectedTab tab) {
    final selected = state;
    if (selected == null) return;
    state = (gameId: selected.gameId, tab: tab);
  }

  void clear() => state = null;
}

final librarySelectionProvider =
    NotifierProvider<LibrarySelectionNotifier, LibrarySelection?>(
      LibrarySelectionNotifier.new,
      name: 'librarySelectionProvider',
    );
