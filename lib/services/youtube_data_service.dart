import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:swipetunes/models/song_track.dart';

class YouTubeDataService {
  static const String _apiBase = 'https://www.googleapis.com/youtube/v3';

  Future<List<SongTrack>> fetchRecommendedTracks({
    required String accessToken,
    int maxResults = 20,
  }) async {
    final seedQueries = <String>[
      'indie pop mix',
      'rnb essentials',
      'alt rock hits',
      'chill playlist',
      'new music friday',
    ];

    final tracks = <SongTrack>[];
    final seenVideoIds = <String>{};

    for (final query in seedQueries) {
      if (tracks.length >= maxResults) {
        break;
      }

      final uri = Uri.parse(
        '$_apiBase/search?part=snippet&type=video&videoCategoryId=10&maxResults=10&q=${Uri.encodeQueryComponent(query)}',
      );

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode != 200) {
        continue;
      }

      final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
      final items = jsonBody['items'] as List<dynamic>? ?? const [];

      for (final rawItem in items) {
        if (tracks.length >= maxResults) {
          break;
        }

        final item = rawItem as Map<String, dynamic>;
        final idMap = item['id'] as Map<String, dynamic>?;
        final videoId = idMap?['videoId'] as String?;
        if (videoId == null ||
            videoId.isEmpty ||
            seenVideoIds.contains(videoId)) {
          continue;
        }

        final snippet = item['snippet'] as Map<String, dynamic>?;
        if (snippet == null) {
          continue;
        }

        final title = snippet['title'] as String? ?? 'Unknown Title';
        final channelTitle =
            snippet['channelTitle'] as String? ?? 'Unknown Artist';
        final thumbnails = snippet['thumbnails'] as Map<String, dynamic>?;
        final thumbUrl = _bestThumbnail(thumbnails);

        tracks.add(
          SongTrack(
            name: _cleanTitle(title),
            artist: channelTitle,
            albumArtUrl: thumbUrl,
            previewUrl: null,
            spotifyUri: '',
            externalUrl: 'https://music.youtube.com/watch?v=$videoId',
          ),
        );
        seenVideoIds.add(videoId);
      }
    }

    return tracks;
  }

  String _bestThumbnail(Map<String, dynamic>? thumbnails) {
    if (thumbnails == null) {
      return '';
    }

    const preferenceOrder = ['maxres', 'standard', 'high', 'medium', 'default'];
    for (final key in preferenceOrder) {
      final entry = thumbnails[key] as Map<String, dynamic>?;
      final url = entry?['url'] as String?;
      if (url != null && url.isNotEmpty) {
        return url;
      }
    }
    return '';
  }

  String _cleanTitle(String input) {
    return input
        .replaceAll(RegExp(r'\s*\(Official[^)]*\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\[Official[^\]]*\]', caseSensitive: false), '')
        .trim();
  }
}
