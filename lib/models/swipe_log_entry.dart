import 'package:swipetunes/models/song_track.dart';

enum AppSessionStatus { signedOut, loading, signedIn, error }

enum SwipeAction { liked, dismissed }

enum MusicSource { spotify, youtubeMusic }

class SwipeLogEntry {
  const SwipeLogEntry({
    required this.track,
    required this.action,
    required this.timestamp,
  });

  final SongTrack track;
  final SwipeAction action;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
        'track': track.toJson(),
        'action': action.name,
        'timestamp': timestamp.toIso8601String(),
      };

  factory SwipeLogEntry.fromJson(Map<String, dynamic> json) {
    final actionName = json['action'] as String? ?? SwipeAction.dismissed.name;
    final action = SwipeAction.values.firstWhere(
      (value) => value.name == actionName,
      orElse: () => SwipeAction.dismissed,
    );

    return SwipeLogEntry(
      track: SongTrack.fromJson(json['track'] as Map<String, dynamic>? ?? {}),
      action: action,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
