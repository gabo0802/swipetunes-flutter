import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:swipetunes/controllers/swipetunes_controller.dart';
import 'package:swipetunes/models/swipe_log_entry.dart';
import 'package:swipetunes/pages/discover_page.dart';
import 'package:swipetunes/pages/log_page.dart';
import 'package:swipetunes/pages/playlists_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SwipeTunesController>();
    final sourceLabel = controller.activeSource == MusicSource.youtubeMusic
        ? 'yt music'
        : 'provider';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'swipetunes',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: const Color(0xFF97B0FF),
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: Text(
                sourceLabel,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.black45,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: controller.logout,
            icon: const Icon(Icons.logout_rounded, color: Color(0xFF97B0FF)),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          DiscoverPage(),
          LogPage(),
          PlaylistsPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        height: 72,
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'Log',
          ),
          NavigationDestination(
            icon: Icon(Icons.queue_music_outlined),
            selectedIcon: Icon(Icons.queue_music_rounded),
            label: 'Playlists',
          ),
        ],
      ),
    );
  }
}
