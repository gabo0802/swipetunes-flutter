import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:swipetunes/models/song_track.dart';
import 'package:swipetunes/models/youtube_playlist.dart';

class YouTubeApiException implements Exception {
  const YouTubeApiException({
    required this.statusCode,
    required this.message,
  });

  final int statusCode;
  final String message;

  @override
  String toString() => 'YouTube API error $statusCode: $message';
}

class YouTubeDataService {
  static const String _apiBase = 'https://www.googleapis.com/youtube/v3';

  Future<List<SongTrack>> fetchRecommendedTracks({
    required String accessToken,
    int maxResults = 20,
    String? seedPlaylistId,
    Set<String> excludedVideoIds = const {},
    int requestSalt = 0,
  }) async {
    final tracks = <SongTrack>[];
    final seenVideoIds = <String>{...excludedVideoIds};

    final hasSeedPlaylist = seedPlaylistId != null && seedPlaylistId.isNotEmpty;
    if (hasSeedPlaylist) {
      await _fetchRecommendationsFromPlaylist(
        accessToken: accessToken,
        seedPlaylistId: seedPlaylistId!,
        maxResults: maxResults,
        requestSalt: requestSalt,
        tracks: tracks,
        seenVideoIds: seenVideoIds,
      );

      return tracks;
    }

    return tracks;
  }

  Future<List<YouTubePlaylist>> fetchUserPlaylists({
    required String accessToken,
  }) async {
    final playlists = <YouTubePlaylist>[];
    String? pageToken;

    do {
      final uri = Uri.parse(
        '$_apiBase/playlists?part=snippet,contentDetails&mine=true&maxResults=25${pageToken == null ? '' : '&pageToken=$pageToken'}',
      );

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode != 200) {
        throw YouTubeApiException(
          statusCode: response.statusCode,
          message: _apiErrorMessage(response.body),
        );
      }

      final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
      final items = jsonBody['items'] as List<dynamic>? ?? const [];
      for (final rawItem in items) {
        final item = rawItem as Map<String, dynamic>;
        final id = item['id'] as String? ?? '';
        if (id.isEmpty) {
          continue;
        }

        final snippet = item['snippet'] as Map<String, dynamic>?;
        final contentDetails = item['contentDetails'] as Map<String, dynamic>?;
        final title = snippet?['title'] as String? ?? 'Untitled Playlist';
        final description = snippet?['description'] as String? ?? '';
        final thumbnails = snippet?['thumbnails'] as Map<String, dynamic>?;
        final itemCount = contentDetails?['itemCount'] as int? ?? 0;

        playlists.add(
          YouTubePlaylist(
            id: id,
            title: title,
            description: description,
            thumbnailUrl: _bestThumbnail(thumbnails),
            itemCount: itemCount,
          ),
        );
      }

      pageToken = jsonBody['nextPageToken'] as String?;
    } while (
        pageToken != null && pageToken.isNotEmpty && playlists.length < 75);

    return playlists;
  }

  Future<YouTubePlaylist?> createPlaylist({
    required String accessToken,
    required String title,
    String description = '',
  }) async {
    final uri = Uri.parse('$_apiBase/playlists?part=snippet,status');
    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'snippet': {
          'title': title,
          'description': description,
        },
        'status': {'privacyStatus': 'private'},
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw YouTubeApiException(
        statusCode: response.statusCode,
        message: _apiErrorMessage(response.body),
      );
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final id = payload['id'] as String?;
    if (id == null || id.isEmpty) {
      return null;
    }

    final snippet = payload['snippet'] as Map<String, dynamic>?;
    final thumbnails = snippet?['thumbnails'] as Map<String, dynamic>?;

    return YouTubePlaylist(
      id: id,
      title: snippet?['title'] as String? ?? title,
      description: snippet?['description'] as String? ?? description,
      thumbnailUrl: _bestThumbnail(thumbnails),
      itemCount: 0,
    );
  }

  Future<void> _fetchRecommendationsFromQueries({
    required String accessToken,
    required int maxResults,
    required int requestSalt,
    required List<SongTrack> tracks,
    required Set<String> seenVideoIds,
  }) async {
    final seedQueries = <String>[
      'indie pop mix',
      'rnb essentials',
      'alt rock hits',
      'chill playlist',
      'new music friday',
      'afrobeats mix',
      'latin pop hits',
    ];

    final rotatedQueries = _rotate(seedQueries, requestSalt);
    final orders = <String>['relevance', 'date', 'viewCount'];
    final order = orders[requestSalt % orders.length];

    for (final query in rotatedQueries) {
      if (tracks.length >= maxResults) {
        break;
      }

      final uri = Uri.parse(
        '$_apiBase/search?part=snippet&type=video&videoCategoryId=10&maxResults=10&order=$order&q=${Uri.encodeQueryComponent(query)}',
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
      _appendTrackResults(
        items: items,
        tracks: tracks,
        seenVideoIds: seenVideoIds,
        maxResults: maxResults,
      );
    }
  }

  Future<void> _fetchRecommendationsFromPlaylist({
    required String accessToken,
    required String seedPlaylistId,
    required int maxResults,
    required int requestSalt,
    required List<SongTrack> tracks,
    required Set<String> seenVideoIds,
  }) async {
    final playlistSeeds = await _fetchPlaylistVideoSeeds(
      accessToken: accessToken,
      playlistId: seedPlaylistId,
    );

    if (playlistSeeds.isEmpty) {
      return;
    }

    final seedVideoIds = playlistSeeds
        .map((seed) => seed.videoId)
        .where((id) => id.isNotEmpty)
        .toList();

    seenVideoIds.addAll(seedVideoIds);

    YouTubeApiException? lastSearchError;
    var hadSuccessfulSearchResponse = false;

    final relatedSeeds = _rotate(seedVideoIds, requestSalt).take(4).toList();
    for (final seedVideoId in relatedSeeds) {
      if (tracks.length >= maxResults) {
        break;
      }

      final uri = Uri.parse(
        '$_apiBase/search?part=snippet&type=video&relatedToVideoId=$seedVideoId&maxResults=8',
      );

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 403) {
        throw YouTubeApiException(
          statusCode: response.statusCode,
          message: _apiErrorMessage(response.body),
        );
      }

      if (response.statusCode != 200) {
        if (response.statusCode >= 400) {
          lastSearchError = YouTubeApiException(
            statusCode: response.statusCode,
            message: _apiErrorMessage(response.body),
          );
        }
        continue;
      }

      hadSuccessfulSearchResponse = true;

      final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
      final items = jsonBody['items'] as List<dynamic>? ?? const [];
      _appendTrackResults(
        items: items,
        tracks: tracks,
        seenVideoIds: seenVideoIds,
        maxResults: maxResults,
      );
    }

    if (tracks.length >= maxResults) {
      return;
    }

    final seedQueries = _buildSeedQueries(playlistSeeds);
    final rotatedQueries = _rotate(seedQueries, requestSalt).take(6).toList();
    for (final query in rotatedQueries) {
      if (tracks.length >= maxResults) {
        break;
      }

      final uri = Uri.parse(
        '$_apiBase/search?part=snippet&type=video&maxResults=8&q=${Uri.encodeQueryComponent(query)}',
      );

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 403) {
        throw YouTubeApiException(
          statusCode: response.statusCode,
          message: _apiErrorMessage(response.body),
        );
      }

      if (response.statusCode != 200) {
        if (response.statusCode >= 400) {
          lastSearchError = YouTubeApiException(
            statusCode: response.statusCode,
            message: _apiErrorMessage(response.body),
          );
        }
        continue;
      }

      hadSuccessfulSearchResponse = true;

      final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
      final items = jsonBody['items'] as List<dynamic>? ?? const [];
      _appendTrackResults(
        items: items,
        tracks: tracks,
        seenVideoIds: seenVideoIds,
        maxResults: maxResults,
      );
    }

    if (tracks.isNotEmpty) {
      return;
    }

    if (!hadSuccessfulSearchResponse && lastSearchError != null) {
      throw lastSearchError;
    }

    _appendSeedTracksFallback(
      seeds: _rotate(playlistSeeds, requestSalt),
      tracks: tracks,
      maxResults: maxResults,
    );
  }

  void _appendSeedTracksFallback({
    required List<_PlaylistSeed> seeds,
    required List<SongTrack> tracks,
    required int maxResults,
  }) {
    for (final seed in seeds) {
      if (tracks.length >= maxResults) {
        break;
      }

      final videoId = seed.videoId;
      if (videoId.isEmpty) {
        continue;
      }

      final cleanedTitle = _cleanTitle(seed.title);
      if (cleanedTitle.isEmpty) {
        continue;
      }

      tracks.add(
        SongTrack(
          name: cleanedTitle,
          artist:
              seed.channelTitle.isEmpty ? 'Unknown Artist' : seed.channelTitle,
          albumArtUrl: _stableVideoThumbnail(videoId, null),
          previewUrl: null,
          spotifyUri: 'yt:$videoId',
          externalUrl: 'https://music.youtube.com/watch?v=$videoId',
        ),
      );
    }
  }

  List<String> _buildSeedQueries(List<_PlaylistSeed> seeds) {
    final queries = <String>[];
    final seen = <String>{};

    for (final seed in seeds) {
      final cleanedTitle = _cleanTitle(seed.title);
      if (cleanedTitle.isEmpty) {
        continue;
      }

      final query = seed.channelTitle.isEmpty
          ? cleanedTitle
          : '$cleanedTitle ${seed.channelTitle}';
      final normalized = query.toLowerCase().trim();
      if (normalized.isNotEmpty && seen.add(normalized)) {
        queries.add(query);
      }
    }

    return queries;
  }

  void _appendTrackResults({
    required List<dynamic> items,
    required List<SongTrack> tracks,
    required Set<String> seenVideoIds,
    required int maxResults,
  }) {
    for (final rawItem in items) {
      if (tracks.length >= maxResults) {
        break;
      }

      final item = rawItem as Map<String, dynamic>;
      final videoId = _extractVideoId(item);
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
      final thumbUrl = _stableVideoThumbnail(videoId, thumbnails);

      tracks.add(
        SongTrack(
          name: _cleanTitle(title),
          artist: channelTitle,
          albumArtUrl: thumbUrl,
          previewUrl: null,
          spotifyUri: 'yt:$videoId',
          externalUrl: 'https://music.youtube.com/watch?v=$videoId',
        ),
      );
      seenVideoIds.add(videoId);
    }
  }

  Future<List<_PlaylistSeed>> _fetchPlaylistVideoSeeds({
    required String accessToken,
    required String playlistId,
  }) async {
    final seeds = <_PlaylistSeed>[];
    String? pageToken;

    do {
      final uri = Uri.parse(
        '$_apiBase/playlistItems?part=snippet&playlistId=$playlistId&maxResults=25${pageToken == null ? '' : '&pageToken=$pageToken'}',
      );

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode != 200) {
        throw YouTubeApiException(
          statusCode: response.statusCode,
          message: _apiErrorMessage(response.body),
        );
      }

      final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
      final items = jsonBody['items'] as List<dynamic>? ?? const [];
      for (final rawItem in items) {
        final item = rawItem as Map<String, dynamic>;
        final snippet = item['snippet'] as Map<String, dynamic>?;
        final resourceId = snippet?['resourceId'] as Map<String, dynamic>?;
        final videoId = resourceId?['videoId'] as String?;
        if (videoId != null && videoId.isNotEmpty) {
          final title = (snippet?['title'] as String? ?? '').trim();
          final channel = (snippet?['videoOwnerChannelTitle'] as String? ??
                  snippet?['channelTitle'] as String? ??
                  '')
              .trim();

          if (!_isDeletedOrPrivateTitle(title)) {
            seeds.add(
              _PlaylistSeed(
                videoId: videoId,
                title: title,
                channelTitle: channel,
              ),
            );
          }
        }
      }

      pageToken = jsonBody['nextPageToken'] as String?;
    } while (pageToken != null && pageToken.isNotEmpty && seeds.length < 60);

    return seeds;
  }

  bool _isDeletedOrPrivateTitle(String title) {
    final normalized = title.trim().toLowerCase();
    return normalized == 'deleted video' || normalized == 'private video';
  }

  String? _extractVideoId(Map<String, dynamic> item) {
    final directId = item['id'] as String?;
    if (directId != null && directId.isNotEmpty) {
      return directId;
    }

    final idMap = item['id'] as Map<String, dynamic>?;
    return idMap?['videoId'] as String?;
  }

  List<T> _rotate<T>(List<T> input, int salt) {
    if (input.isEmpty) {
      return input;
    }

    final offset = salt % input.length;
    if (offset == 0) {
      return List<T>.from(input);
    }
    return [...input.skip(offset), ...input.take(offset)];
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
        if (url.startsWith('http://')) {
          return url.replaceFirst('http://', 'https://');
        }
        return url;
      }
    }
    return '';
  }

  String _stableVideoThumbnail(
      String videoId, Map<String, dynamic>? thumbnails) {
    if (videoId.isNotEmpty) {
      return 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
    }
    return _bestThumbnail(thumbnails);
  }

  String _cleanTitle(String input) {
    return input
        .replaceAll(RegExp(r'\s*\(Official[^)]*\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\[Official[^\]]*\]', caseSensitive: false), '')
        .trim();
  }

  String _apiErrorMessage(String responseBody) {
    try {
      final jsonBody = jsonDecode(responseBody) as Map<String, dynamic>;
      final error = jsonBody['error'];
      if (error is Map<String, dynamic>) {
        final message = error['message'] as String?;
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
    } catch (_) {}

    if (responseBody.isEmpty) {
      return 'Unknown error';
    }
    final compact = responseBody.replaceAll(RegExp(r'\s+'), ' ').trim();
    return compact.length > 220 ? '${compact.substring(0, 220)}…' : compact;
  }
}

class _PlaylistSeed {
  const _PlaylistSeed({
    required this.videoId,
    required this.title,
    required this.channelTitle,
  });

  final String videoId;
  final String title;
  final String channelTitle;
}
