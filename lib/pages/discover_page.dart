import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:swipetunes/controllers/swipetunes_controller.dart';
import 'package:swipetunes/models/swipe_log_entry.dart';

class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SwipeTunesController>();
    final track = controller.currentTrack;
    final hasPreview = (track?.previewUrl?.isNotEmpty ?? false);

    if (track == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'You reached the end of this stack.',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Liked songs: ${controller.likedSongs.length}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: controller.activeSource == MusicSource.spotify
                    ? controller.signInWithSpotify
                    : controller.signInWithYouTubeMusic,
                child: const Text('Load New Recommendations'),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            children: [
              GestureDetector(
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity > 180) {
                    controller.swipeCurrent(SwipeAction.liked);
                  } else if (velocity < -180) {
                    controller.swipeCurrent(SwipeAction.dismissed);
                  }
                },
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AspectRatio(
                          aspectRatio: 1,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.all(
                              Radius.circular(18),
                            ),
                            child: track.albumArtUrl.isEmpty
                                ? const ColoredBox(
                                    color: Color(0xFF232A34),
                                    child: Icon(
                                      Icons.music_note_rounded,
                                      size: 88,
                                    ),
                                  )
                                : Image.network(
                                    track.albumArtUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const ColoredBox(
                                      color: Color(0xFF232A34),
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        size: 72,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          track.name,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          track.artist,
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.white70,
                                  ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton.filledTonal(
                              tooltip: 'Dismiss (Swipe Left)',
                              onPressed: () => controller
                                  .swipeCurrent(SwipeAction.dismissed),
                              icon: const Icon(Icons.close_rounded),
                            ),
                            const SizedBox(width: 16),
                            IconButton.filled(
                              tooltip: hasPreview
                                  ? 'Play / Pause Preview'
                                  : 'Play full song externally',
                              onPressed: hasPreview
                                  ? controller.togglePreview
                                  : () async {
                                      final messenger =
                                          ScaffoldMessenger.of(context);
                                      final errorMessage = await controller
                                          .openCurrentTrackExternally();
                                      if (errorMessage != null) {
                                        messenger
                                          ..hideCurrentSnackBar()
                                          ..showSnackBar(
                                            SnackBar(
                                              content: Text(errorMessage),
                                            ),
                                          );
                                      }
                                    },
                              icon: Icon(
                                controller.isPlayingPreview
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                              ),
                            ),
                            const SizedBox(width: 16),
                            IconButton.filledTonal(
                              tooltip: 'Like (Swipe Right)',
                              onPressed: () =>
                                  controller.swipeCurrent(SwipeAction.liked),
                              icon: const Icon(Icons.favorite_rounded),
                            ),
                          ],
                        ),
                        if (!hasPreview) ...[
                          const SizedBox(height: 10),
                          Text(
                            controller.activeSource == MusicSource.youtubeMusic
                                ? 'Preview unavailable on this YT Music track yet. Play opens the full song externally.'
                                : 'Preview unavailable for this track. Play opens it externally.',
                            textAlign: TextAlign.center,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.white60,
                                    ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Swipe right to like • Swipe left to dismiss',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: controller.likedSongs.isEmpty
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final message =
                              await controller.exportLikedPlaylist();
                          messenger
                            ..hideCurrentSnackBar()
                            ..showSnackBar(SnackBar(content: Text(message)));
                        },
                  icon: const Icon(Icons.playlist_add_check_rounded),
                  label: Text(
                    controller.canSyncPlaylist
                        ? 'Save Liked Songs to Spotify'
                        : 'Save Playlist (Source Limited)',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
