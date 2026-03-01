import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:swipetunes/controllers/swipetunes_controller.dart';
import 'package:swipetunes/services/google_auth_service.dart';
import 'package:swipetunes/services/music_repository.dart';
import 'package:swipetunes/services/spotify_service.dart';
import 'package:swipetunes/services/swipe_history_storage.dart';
import 'package:swipetunes/services/youtube_data_service.dart';
import 'package:swipetunes/swipetunes_app.dart';

void main() {
  runApp(const SwipeTunesRoot());
}

class SwipeTunesRoot extends StatelessWidget {
  const SwipeTunesRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SwipeTunesController(
        MusicRepository(SpotifyService(), YouTubeDataService()),
        SwipeHistoryStorage(),
        GoogleAuthService(GoogleOAuthConfig.fromEnvironment()),
        GoogleAuthStorage(),
      )..bootstrap(),
      child: const SwipeTunesApp(),
    );
  }
}
