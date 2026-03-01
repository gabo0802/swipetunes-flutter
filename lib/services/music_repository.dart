import 'package:swipetunes/models/song_track.dart';
import 'package:swipetunes/models/swipe_log_entry.dart';
import 'package:swipetunes/services/spotify_service.dart';
import 'package:swipetunes/services/youtube_data_service.dart';
import 'package:swipetunes/utils/demo_tracks.dart';

class MusicRepository {
  MusicRepository(this._spotifyService, this._youTubeDataService);

  final SpotifyService _spotifyService;
  final YouTubeDataService _youTubeDataService;

  Future<List<SongTrack>> fetchRecommendations({
    required MusicSource source,
    String? accessToken,
  }) async {
    switch (source) {
      case MusicSource.spotify:
        return _spotifyService.fetchRecommendedTracks(accessToken: accessToken);
      case MusicSource.youtubeMusic:
        if (accessToken == null || accessToken.isEmpty) {
          return youtubeMusicDemoTracks;
        }

        try {
          final tracks = await _youTubeDataService.fetchRecommendedTracks(
            accessToken: accessToken,
          );
          if (tracks.isEmpty) {
            return youtubeMusicDemoTracks;
          }
          return tracks;
        } catch (_) {
          return youtubeMusicDemoTracks;
        }
    }
  }

  Future<bool> createPlaylist({
    required MusicSource source,
    required String accessToken,
    required List<SongTrack> tracks,
    required String playlistName,
  }) async {
    switch (source) {
      case MusicSource.spotify:
        return _spotifyService.createPlaylistWithTracks(
          accessToken: accessToken,
          tracks: tracks,
          playlistName: playlistName,
        );
      case MusicSource.youtubeMusic:
        return false;
    }
  }
}
