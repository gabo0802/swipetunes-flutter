import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:swipetunes/models/song_track.dart';
import 'package:swipetunes/models/swipe_log_entry.dart';
import 'package:swipetunes/services/google_auth_service.dart';
import 'package:swipetunes/services/music_repository.dart';
import 'package:swipetunes/services/swipe_history_storage.dart';
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
  MusicSource activeSource = MusicSource.spotify;
  GoogleAuthSession? _googleAuthSession;

  final List<SongTrack> _queue = [];
  final List<SongTrack> _likedSongs = [];
  final List<SwipeLogEntry> _swipeLog = [];
  int _currentIndex = 0;

  List<SwipeLogEntry> get swipeLog => List.unmodifiable(_swipeLog);
  List<SongTrack> get likedSongs => List.unmodifiable(_likedSongs);
  bool get isAuthenticated => status == AppSessionStatus.signedIn;
  bool get hasTracks => _currentIndex < _queue.length;
  SongTrack? get currentTrack => hasTracks ? _queue[_currentIndex] : null;
  bool get isPlayingPreview => _player.playing;
  bool get isGoogleOAuthConfigured => _googleAuthService.isConfigured;
  bool get hasGoogleSession =>
      _googleAuthSession != null && !_googleAuthSession!.isExpired;
  String get googleSetupInstructions => _googleAuthService.setupInstructions;
  String get googleOAuthDiagnostics => _googleAuthService.diagnosticsSummary;
  bool get canSyncPlaylist =>
      activeSource == MusicSource.spotify &&
      !isDemoMode &&
      _spotifyAccessToken.isNotEmpty;

  Future<void> bootstrap() async {
    final persisted = await _historyStorage.loadHistory();
    _googleAuthSession = await _googleAuthStorage.loadSession();
    _swipeLog
      ..clear()
      ..addAll(persisted);
    notifyListeners();
  }

  Future<void> signInWithSpotify() async {
    activeSource = MusicSource.spotify;
    await _signInWithSource(MusicSource.spotify);
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
      } catch (error) {
        status = AppSessionStatus.error;
        errorMessage = 'Google sign-in failed. ${error.toString()}';
        notifyListeners();
        return;
      }
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
      final tracks = await _musicRepository.fetchRecommendations(
        source: source,
        accessToken: sourceAccessToken,
      );

      _queue
        ..clear()
        ..addAll(tracks);
      _likedSongs.clear();
      _currentIndex = 0;

      status = AppSessionStatus.signedIn;
      await _loadPreviewForCurrentTrack();
      notifyListeners();
    } catch (error) {
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

    if (!canSyncPlaylist) {
      if (activeSource == MusicSource.youtubeMusic) {
        return 'YouTube Music export is not implemented yet. Liked songs are still tracked.';
      }
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
    _googleAuthSession = null;
    await _googleAuthStorage.clearSession();
    status = AppSessionStatus.signedOut;
    errorMessage = null;
    notifyListeners();
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
