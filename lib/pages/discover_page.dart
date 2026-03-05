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
    final selectedSeedLabel = controller.selectedYouTubePlaylistTitle;

    if (track == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.queue_music_rounded,
                      size: 48, color: Color(0xFF97B0FF)),
                  const SizedBox(height: 10),
                  Text(
                    'You reached the end of this stack',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Liked songs: ${controller.likedSongs.length}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: controller.signInWithYouTubeMusic,
                    child: const Text('Load New Recommendations'),
                  ),
                ],
              ),
            ),
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
                              Radius.circular(16),
                            ),
                            child: track.albumArtUrl.isEmpty
                                ? const ColoredBox(
                                    color: Color(0xFFDCEFD7),
                                    child: Icon(
                                      Icons.music_note_rounded,
                                      size: 88,
                                      color: Colors.black45,
                                    ),
                                  )
                                : Image.network(
                                    track.albumArtUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const ColoredBox(
                                      color: Color(0xFFDCEFD7),
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        size: 72,
                                        color: Colors.black45,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          track.name,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          track.artist,
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.black54,
                                  ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _ActionChipButton(
                              tooltip: 'Dismiss (Swipe Left)',
                              background: const Color(0xFFF3A4B0),
                              icon: Icons.stop_rounded,
                              onTap: () => controller
                                  .swipeCurrent(SwipeAction.dismissed),
                            ),
                            const SizedBox(width: 14),
                            _ActionChipButton(
                              tooltip: hasPreview
                                  ? 'Play / Pause Preview'
                                  : 'Play full song externally',
                              background: const Color(0xFF8EDFC6),
                              icon: controller.isPlayingPreview
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              onTap: hasPreview
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
                            ),
                            const SizedBox(width: 14),
                            _ActionChipButton(
                              tooltip: 'Like (Swipe Right)',
                              background: const Color(0xFF8EDFC6),
                              icon: Icons.favorite_rounded,
                              onTap: () =>
                                  controller.swipeCurrent(SwipeAction.liked),
                            ),
                          ],
                        ),
                        if (!hasPreview) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Preview unavailable on this YT Music track yet. Play opens the full song externally.',
                            textAlign: TextAlign.center,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.black54,
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
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.black54),
              ),
              const SizedBox(height: 12),
              if (controller.activeSource == MusicSource.youtubeMusic)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF6EF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    selectedSeedLabel == null
                        ? 'Seed playlist: Not selected yet'
                        : 'Seed playlist: $selectedSeedLabel',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.black54),
                  ),
                ),
              if (controller.activeSource == MusicSource.youtubeMusic)
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
                  label: const Text('Export Liked Songs (Coming Soon)'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionChipButton extends StatelessWidget {
  const _ActionChipButton({
    required this.tooltip,
    required this.background,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final Color background;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 72,
            height: 72,
            child: Icon(icon, size: 38, color: Colors.black87),
          ),
        ),
      ),
    );
  }
}
