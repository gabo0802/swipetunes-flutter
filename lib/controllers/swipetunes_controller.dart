import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:swipetunes/models/song_track.dart';
import 'package:swipetunes/models/swipe_log_entry.dart';
import 'package:swipetunes/models/youtube_playlist.dart';
import 'package:swipetunes/services/google_auth_service.dart';
import 'package:swipetunes/services/music_repository.dart';
import 'package:swipetunes/services/swipe_history_storage.dart';
import 'package:swipetunes/services/youtube_data_service.dart';
import 'package:swipetunes/utils/demo_tracks.dart';
import 'package:url_launcher/url_launcher.dart';

class SwipeTunesController extends ChangeNotifier {
  SwipeTunesController(
    this._musicRepository,
    this._historyStorage,
    this._googleAuthService,
    this._googleAuthStorage,
  );

  final MusicRepository _musicRepository;
  final SwipeHistoryStorage _historyStorage;
  final GoogleAuthService _googleAuthService;
  final GoogleAuthStorage _googleAuthStorage;
  final AudioPlayer _player = AudioPlayer();

  static const String _spotifyAccessToken =
      String.fromEnvironment('SPOTIFY_ACCESS_TOKEN');

  AppSessionStatus status = AppSessionStatus.signedOut;
  String? errorMessage;
  bool isDemoMode = true;
  MusicSource activeSource = MusicSource.youtubeMusic;
  GoogleAuthSession? _googleAuthSession;
  bool _hasActiveSession = false;
  int _recommendationRequestSalt = 0;
  bool _isLoadingYouTubePlaylists = false;
  String? _selectedYouTubePlaylistId;
  String? _youtubeDebugLine;
  bool _isUsingQuotaFallbackDemo = false;
  final Set<String> _servedYouTubeVideoIds = {};
  final List<YouTubePlaylist> _youTubePlaylists = [];

  final List<SongTrack> _queue = [];
  final List<SongTrack> _likedSongs = [];
  final List<SwipeLogEntry> _swipeLog = [];
  int _currentIndex = 0;

  List<SwipeLogEntry> get swipeLog => List.unmodifiable(_swipeLog);
  List<SongTrack> get likedSongs => List.unmodifiable(_likedSongs);
  bool get isAuthenticated => _hasActiveSession;
  bool get hasTracks => _currentIndex < _queue.length;
  SongTrack? get currentTrack => hasTracks ? _queue[_currentIndex] : null;
  bool get isPlayingPreview => _player.playing;
  bool get isGoogleOAuthConfigured => _googleAuthService.isConfigured;
  bool get hasGoogleSession =>
      _googleAuthSession != null && !_googleAuthSession!.isExpired;
  String get googleSetupInstructions => _googleAuthService.setupInstructions;
  String get googleOAuthDiagnostics => _googleAuthService.diagnosticsSummary;
  bool get isSpotifyDeprecated => true;
  bool get canSyncPlaylist =>
      activeSource == MusicSource.spotify &&
      !isDemoMode &&
      _spotifyAccessToken.isNotEmpty;
  bool get isLoadingYouTubePlaylists => _isLoadingYouTubePlaylists;
  String? get selectedYouTubePlaylistId => _selectedYouTubePlaylistId;
  String? get youtubeDebugLine => _youtubeDebugLine;
  bool get isUsingQuotaFallbackDemo => _isUsingQuotaFallbackDemo;
  List<YouTubePlaylist> get youTubePlaylists =>
      List.unmodifiable(_youTubePlaylists);
  String? get selectedYouTubePlaylistTitle {
    final selectedId = _selectedYouTubePlaylistId;
    if (selectedId == null || selectedId.isEmpty) {
      return null;
    }

    for (final playlist in _youTubePlaylists) {
      if (playlist.id == selectedId) {
        return playlist.title;
      }
    }
    return null;
  }

  Future<void> bootstrap() async {
    final persisted = await _historyStorage.loadHistory();
    _googleAuthSession = await _googleAuthStorage.loadSession();
    _swipeLog
      ..clear()
      ..addAll(persisted);
    notifyListeners();
  }

  Future<void> signInWithSpotify() async {
    status = AppSessionStatus.error;
    errorMessage =
        'Spotify support is temporarily deprecated. Use YT Music for now.';
    notifyListeners();
  }

  Future<void> signInWithYouTubeMusic() async {
    activeSource = MusicSource.youtubeMusic;

    if (!isGoogleOAuthConfigured) {
      status = AppSessionStatus.error;
      errorMessage = googleSetupInstructions;
      notifyListeners();
      return;
    }

    if (!hasGoogleSession) {
      status = AppSessionStatus.loading;
      errorMessage = null;
      notifyListeners();

      try {
        _googleAuthSession =
            await _googleAuthService.signInWithDesktopLoopback();
        await _googleAuthStorage.saveSession(_googleAuthSession!);
        _youtubeDebugLine = null;
        _isUsingQuotaFallbackDemo = false;
      } catch (error) {
        status = AppSessionStatus.error;
        errorMessage = 'Google sign-in failed. ${error.toString()}';
        notifyListeners();
        return;
      }
    }

    await loadYouTubePlaylists();

    if (_isUsingQuotaFallbackDemo) {
      return;
    }

    if (_selectedYouTubePlaylistId == null ||
        _selectedYouTubePlaylistId!.isEmpty) {
      _queue.clear();
      _likedSongs.clear();
      _currentIndex = 0;
      status = AppSessionStatus.signedIn;
      _hasActiveSession = true;
      errorMessage =
          'Select a playlist in the Playlists tab to generate recommendations.';
      notifyListeners();
      return;
    }

    await _signInWithSource(MusicSource.youtubeMusic);
  }

  Future<void> _signInWithSource(MusicSource source) async {
    status = AppSessionStatus.loading;
    errorMessage = null;
    notifyListeners();

    try {
      final sourceAccessToken = source == MusicSource.spotify
          ? _spotifyAccessToken
          : _googleAuthSession?.accessToken;

      isDemoMode = sourceAccessToken == null || sourceAccessToken.isEmpty;
      List<SongTrack> tracks;
      if (source == MusicSource.youtubeMusic) {
        _youtubeDebugLine = null;
        _isUsingQuotaFallbackDemo = false;
        _recommendationRequestSalt += 1;
        tracks = await _musicRepository.fetchRecommendations(
          source: source,
          accessToken: sourceAccessToken,
          seedPlaylistId: _selectedYouTubePlaylistId,
          excludedTrackIds: _servedYouTubeVideoIds,
          requestSalt: _recommendationRequestSalt,
        );

        if (tracks.isEmpty && _servedYouTubeVideoIds.isNotEmpty) {
          _servedYouTubeVideoIds.clear();
          _recommendationRequestSalt += 1;
          tracks = await _musicRepository.fetchRecommendations(
            source: source,
            accessToken: sourceAccessToken,
            seedPlaylistId: _selectedYouTubePlaylistId,
            requestSalt: _recommendationRequestSalt,
          );
        }

        if (tracks.isEmpty &&
            _selectedYouTubePlaylistId != null &&
            _selectedYouTubePlaylistId!.isNotEmpty) {
          errorMessage =
              'No recommendation candidates were found from the selected playlist. Try another playlist or check YouTube Data API access/scopes.';
        }
      } else {
        tracks = await _musicRepository.fetchRecommendations(
          source: source,
          accessToken: sourceAccessToken,
        );
      }

      _queue
        ..clear()
        ..addAll(tracks);
      _likedSongs.clear();
      _currentIndex = 0;

      if (source == MusicSource.youtubeMusic) {
        for (final track in tracks) {
          final videoId = _extractYouTubeVideoId(track);
          if (videoId != null && videoId.isNotEmpty) {
            _servedYouTubeVideoIds.add(videoId);
          }
        }
      }

      status = AppSessionStatus.signedIn;
      _hasActiveSession = true;
      await _loadPreviewForCurrentTrack();
      notifyListeners();
    } catch (error) {
      if (error is YouTubeApiException) {
        _youtubeDebugLine = 'YT API ${error.statusCode}: ${error.message}';
        if (_isQuotaExceededError(error)) {
          _activateYouTubeQuotaFallback();
          return;
        }
      }

      status = AppSessionStatus.error;
      errorMessage = 'Could not load recommendations. ${error.toString()}';
      notifyListeners();
    }
  }

  Future<void> swipeCurrent(SwipeAction action) async {
    final track = currentTrack;
    if (track == null) {
      return;
    }

    if (action == SwipeAction.liked) {
      _likedSongs.add(track);
    }

    _swipeLog.insert(
      0,
      SwipeLogEntry(track: track, action: action, timestamp: DateTime.now()),
    );
    if (_swipeLog.length > SwipeHistoryStorage.maxEntries) {
      _swipeLog.removeRange(SwipeHistoryStorage.maxEntries, _swipeLog.length);
    }
    await _historyStorage.saveHistory(_swipeLog);

    _currentIndex += 1;
    await _loadPreviewForCurrentTrack();
    notifyListeners();
  }

  Future<void> togglePreview() async {
    final track = currentTrack;
    if (track == null || track.previewUrl == null) {
      return;
    }

    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
    notifyListeners();
  }

  Future<String?> openCurrentTrackExternally() async {
    final track = currentTrack;
    if (track == null) {
      return 'No active track to open.';
    }

    final query = Uri.encodeQueryComponent('${track.name} ${track.artist}');
    final url = track.externalUrl != null && track.externalUrl!.isNotEmpty
        ? Uri.parse(track.externalUrl!)
        : (activeSource == MusicSource.youtubeMusic
            ? Uri.parse('https://music.youtube.com/search?q=$query')
            : Uri.parse('https://open.spotify.com/search/$query'));

    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened) {
      return 'Could not open external player link.';
    }

    return null;
  }

  Future<String> exportLikedPlaylist() async {
    if (_likedSongs.isEmpty) {
      return 'No liked songs to export yet.';
    }

    if (activeSource == MusicSource.youtubeMusic) {
      return 'Playlist export is temporarily disabled while provider integrations are being refreshed.';
    }

    if (!canSyncPlaylist) {
      return 'Running in demo mode. Add SPOTIFY_ACCESS_TOKEN to enable Spotify playlist sync.';
    }

    final ok = await _musicRepository.createPlaylist(
      source: activeSource,
      accessToken: _spotifyAccessToken,
      tracks: _likedSongs,
      playlistName: 'SwipeTunes Picks',
    );

    if (!ok) {
      return 'Failed to save playlist.';
    }

    return 'Playlist created with ${_likedSongs.length} tracks.';
  }

  Future<void> logout() async {
    await _player.stop();
    _queue.clear();
    _likedSongs.clear();
    _currentIndex = 0;
    _servedYouTubeVideoIds.clear();
    _youTubePlaylists.clear();
    _selectedYouTubePlaylistId = null;
    _isLoadingYouTubePlaylists = false;
    _youtubeDebugLine = null;
    _isUsingQuotaFallbackDemo = false;
    _googleAuthSession = null;
    _hasActiveSession = false;
    await _googleAuthStorage.clearSession();
    status = AppSessionStatus.signedOut;
    errorMessage = null;
    notifyListeners();
  }

  Future<void> loadYouTubePlaylists() async {
    if (activeSource != MusicSource.youtubeMusic || !hasGoogleSession) {
      return;
    }

    _isLoadingYouTubePlaylists = true;
    _youtubeDebugLine = null;
    notifyListeners();

    try {
      final playlists = await _musicRepository.fetchYouTubePlaylists(
        accessToken: _googleAuthSession!.accessToken,
      );

      _isUsingQuotaFallbackDemo = false;

      _youTubePlaylists
        ..clear()
        ..addAll(playlists);

      if (_youTubePlaylists.isNotEmpty) {
        final selectedStillExists = _youTubePlaylists
            .any((playlist) => playlist.id == _selectedYouTubePlaylistId);
        if (!selectedStillExists) {
          _selectedYouTubePlaylistId = _youTubePlaylists.first.id;
        }
      } else {
        _selectedYouTubePlaylistId = null;
      }
    } catch (error) {
      if (error is YouTubeApiException) {
        _youtubeDebugLine = 'YT API ${error.statusCode}: ${error.message}';
        if (_isQuotaExceededError(error)) {
          _activateYouTubeQuotaFallback();
          return;
        }
      } else {
        _youtubeDebugLine = error.toString();
      }
      errorMessage = 'Could not load your YouTube playlists.';
    } finally {
      _isLoadingYouTubePlaylists = false;
      notifyListeners();
    }
  }

  Future<void> selectYouTubePlaylist(String? playlistId) async {
    _selectedYouTubePlaylistId = playlistId;
    _servedYouTubeVideoIds.clear();
    _recommendationRequestSalt = 0;
    notifyListeners();

    if (activeSource == MusicSource.youtubeMusic && hasGoogleSession) {
      await _signInWithSource(MusicSource.youtubeMusic);
    }
  }

  bool _isQuotaExceededError(YouTubeApiException error) {
    if (error.statusCode != 403) {
      return false;
    }

    final lower = error.message.toLowerCase();
    return lower.contains('quota') ||
        lower.contains('quotaexceeded') ||
        lower.contains('exceeded your') ||
        lower.contains('daily limit');
  }

  void _activateYouTubeQuotaFallback() {
    _isUsingQuotaFallbackDemo = true;
    isDemoMode = true;
    _selectedYouTubePlaylistId = null;
    _youTubePlaylists.clear();
    _servedYouTubeVideoIds.clear();

    _queue
      ..clear()
      ..addAll(youtubeMusicDemoTracks);
    _likedSongs.clear();
    _currentIndex = 0;

    status = AppSessionStatus.signedIn;
    _hasActiveSession = true;
    errorMessage =
        'YouTube API quota is exhausted, so SwipeTunes loaded a local demo playlist for now.';
    notifyListeners();
  }

  Future<String> createYouTubePlaylist({
    required String title,
    String description = '',
  }) async {
    if (!hasGoogleSession) {
      return 'Sign in with YouTube Music first.';
    }

    final created = await _musicRepository.createYouTubePlaylist(
      accessToken: _googleAuthSession!.accessToken,
      title: title,
      description: description,
    );

    if (created == null) {
      return 'Could not create playlist.';
    }

    _youTubePlaylists.insert(0, created);
    await selectYouTubePlaylist(created.id);
    return 'Playlist created.';
  }

  String? _extractYouTubeVideoId(SongTrack track) {
    if (track.spotifyUri.startsWith('yt:')) {
      final id = track.spotifyUri.substring(3);
      return id.isEmpty ? null : id;
    }

    final external = track.externalUrl;
    if (external == null || external.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(external);
    return uri?.queryParameters['v'];
  }

  Future<void> clearPersistedHistory() async {
    _swipeLog.clear();
    await _historyStorage.clearHistory();
    notifyListeners();
  }

  Future<void> _loadPreviewForCurrentTrack() async {
    await _player.stop();
    final preview = currentTrack?.previewUrl;
    if (preview == null) {
      notifyListeners();
      return;
    }

    try {
      await _player.setUrl(preview);
    } catch (_) {}
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
