import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:swipetunes/controllers/swipetunes_controller.dart';
import 'package:swipetunes/models/swipe_log_entry.dart';

class PlaylistsPage extends StatelessWidget {
  const PlaylistsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SwipeTunesController>();

    if (controller.activeSource != MusicSource.youtubeMusic) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Playlist-based recommendations are available for YT Music.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      );
    }

    if (controller.isLoadingYouTubePlaylists) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: controller.loadYouTubePlaylists,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh Playlists'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _showCreatePlaylistDialog(context),
                  icon: const Icon(Icons.playlist_add_rounded),
                  label: const Text('Create Playlist'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (kDebugMode && controller.youtubeDebugLine != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'DEBUG: ${controller.youtubeDebugLine}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.amberAccent,
                    ),
              ),
            ),
          if (controller.youTubePlaylists.isEmpty)
            Expanded(
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Text(
                      'No playlists found. Create one to use as your recommendation seed.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: controller.youTubePlaylists.length,
                itemBuilder: (context, index) {
                  final playlist = controller.youTubePlaylists[index];
                  final isSelected =
                      playlist.id == controller.selectedYouTubePlaylistId;

                  return Card(
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: playlist.thumbnailUrl.isEmpty
                            ? const SizedBox(
                                width: 52,
                                height: 52,
                                child: ColoredBox(
                                  color: Color(0xFFEAF6EF),
                                  child: Icon(
                                    Icons.queue_music_rounded,
                                    color: Colors.black54,
                                  ),
                                ),
                              )
                            : Image.network(
                                playlist.thumbnailUrl,
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const SizedBox(
                                  width: 52,
                                  height: 52,
                                  child: ColoredBox(
                                    color: Color(0xFFEAF6EF),
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                      title: Text(playlist.title),
                      subtitle: Text('${playlist.itemCount} tracks'),
                      trailing: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF8EDFC6)
                              : const Color(0xFFECE7CA),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isSelected
                              ? Icons.check_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 18,
                          color: Colors.black87,
                        ),
                      ),
                      onTap: () =>
                          controller.selectYouTubePlaylist(playlist.id),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showCreatePlaylistDialog(BuildContext context) async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final controller = context.read<SwipeTunesController>();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create YouTube Playlist'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Playlist name',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final title = titleController.text.trim();
              if (title.isEmpty) {
                return;
              }

              final message = await controller.createYouTubePlaylist(
                title: title,
                description: descriptionController.text.trim(),
              );

              if (!context.mounted) {
                return;
              }

              Navigator.of(context).pop();
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(message)));
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    titleController.dispose();
    descriptionController.dispose();
  }
}
