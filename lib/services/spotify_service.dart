import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:swipetunes/models/song_track.dart';
import 'package:swipetunes/utils/demo_tracks.dart';

class SpotifyService {
  static const String _spotifyApiBase = 'https://api.spotify.com/v1';

  Future<List<SongTrack>> fetchRecommendedTracks({String? accessToken}) async {
    if (accessToken == null || accessToken.isEmpty) {
      return spotifyDemoTracks;
    }

    try {
      final topTracksResponse = await http.get(
        Uri.parse('$_spotifyApiBase/me/top/tracks?limit=5&offset=0'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (topTracksResponse.statusCode != 200) {
        return spotifyDemoTracks;
      }

      final topTracksJson =
          jsonDecode(topTracksResponse.body) as Map<String, dynamic>;
      final topTracksItems =
          (topTracksJson['items'] as List<dynamic>? ?? const []);
      final topTrackIds = topTracksItems
          .map((item) => (item as Map<String, dynamic>)['id'] as String?)
          .whereType<String>()
          .take(5)
          .toList();

      if (topTrackIds.isEmpty) {
        return spotifyDemoTracks;
      }

      final recommendationsResponse = await http.get(
        Uri.parse(
          '$_spotifyApiBase/recommendations?seed_tracks=${topTrackIds.join(',')}',
        ),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (recommendationsResponse.statusCode != 200) {
        return spotifyDemoTracks;
      }

      final recommendationsJson =
          jsonDecode(recommendationsResponse.body) as Map<String, dynamic>;
      final tracks =
          (recommendationsJson['tracks'] as List<dynamic>? ?? const [])
              .map((raw) => _songTrackFromJson(raw as Map<String, dynamic>))
              .whereType<SongTrack>()
              .toList();

      return tracks.isEmpty ? spotifyDemoTracks : tracks;
    } catch (_) {
      return spotifyDemoTracks;
    }
  }

  Future<bool> createPlaylistWithTracks({
    required String accessToken,
    required List<SongTrack> tracks,
    required String playlistName,
  }) async {
    try {
      final meResponse = await http.get(
        Uri.parse('$_spotifyApiBase/me'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (meResponse.statusCode != 200) {
        return false;
      }

      final meJson = jsonDecode(meResponse.body) as Map<String, dynamic>;
      final userId = meJson['id'] as String?;
      if (userId == null || userId.isEmpty) {
        return false;
      }

      final createPlaylistResponse = await http.post(
        Uri.parse('$_spotifyApiBase/users/$userId/playlists'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'name': playlistName, 'public': false}),
      );

      if (createPlaylistResponse.statusCode != 201) {
        return false;
      }

      final playlistJson =
          jsonDecode(createPlaylistResponse.body) as Map<String, dynamic>;
      final playlistId = playlistJson['id'] as String?;
      if (playlistId == null || playlistId.isEmpty) {
        return false;
      }

      final uris = tracks
          .map((song) => song.spotifyUri)
          .where((uri) => uri.isNotEmpty)
          .toList();
      final addTracksResponse = await http.post(
        Uri.parse('$_spotifyApiBase/playlists/$playlistId/tracks'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'uris': uris}),
      );

      return addTracksResponse.statusCode == 201 ||
          addTracksResponse.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  SongTrack? _songTrackFromJson(Map<String, dynamic> raw) {
    final name = raw['name'] as String?;
    final uri = raw['uri'] as String?;
    final artistsRaw = raw['artists'] as List<dynamic>?;
    final albumRaw = raw['album'] as Map<String, dynamic>?;
    final imagesRaw = albumRaw?['images'] as List<dynamic>?;

    if (name == null || uri == null) {
      return null;
    }

    final artists = (artistsRaw ?? const [])
        .map((artist) => (artist as Map<String, dynamic>)['name'] as String?)
        .whereType<String>()
        .join(', ');

    final albumArt = imagesRaw != null && imagesRaw.isNotEmpty
        ? (imagesRaw.first as Map<String, dynamic>)['url'] as String? ?? ''
        : '';

    return SongTrack(
      name: name,
      artist: artists.isEmpty ? 'Unknown Artist' : artists,
      albumArtUrl: albumArt,
      previewUrl: raw['preview_url'] as String?,
      spotifyUri: uri,
    );
  }
}
