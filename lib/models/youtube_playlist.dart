class YouTubePlaylist {
  const YouTubePlaylist({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.itemCount,
  });

  final String id;
  final String title;
  final String description;
  final String thumbnailUrl;
  final int itemCount;
}
