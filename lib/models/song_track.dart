class SongTrack {
  const SongTrack({
    required this.name,
    required this.artist,
    required this.albumArtUrl,
    required this.previewUrl,
    required this.spotifyUri,
    this.externalUrl,
  });

  final String name;
  final String artist;
  final String albumArtUrl;
  final String? previewUrl;
  final String spotifyUri;
  final String? externalUrl;

  Map<String, dynamic> toJson() => {
        'name': name,
        'artist': artist,
        'albumArtUrl': albumArtUrl,
        'previewUrl': previewUrl,
        'spotifyUri': spotifyUri,
        'externalUrl': externalUrl,
      };

  factory SongTrack.fromJson(Map<String, dynamic> json) {
    return SongTrack(
      name: json['name'] as String? ?? '',
      artist: json['artist'] as String? ?? 'Unknown Artist',
      albumArtUrl: json['albumArtUrl'] as String? ?? '',
      previewUrl: json['previewUrl'] as String?,
      spotifyUri: json['spotifyUri'] as String? ?? '',
      externalUrl: json['externalUrl'] as String?,
    );
  }
}
