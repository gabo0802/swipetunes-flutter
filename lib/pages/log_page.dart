import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:swipetunes/controllers/swipetunes_controller.dart';
import 'package:swipetunes/models/swipe_log_entry.dart';

class LogPage extends StatelessWidget {
  const LogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SwipeTunesController>();
    final log = controller.swipeLog;
    final formatter = DateFormat('MMM d • h:mm a');

    if (log.isEmpty) {
      return Center(
        child: Text(
          'No swipes yet. Start discovering songs.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: controller.clearPersistedHistory,
              icon: const Icon(Icons.delete_sweep_rounded),
              label: const Text('Clear History'),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemBuilder: (context, index) {
              final entry = log[index];
              final isLiked = entry.action == SwipeAction.liked;

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isLiked
                        ? const Color(0xFF65DFA3)
                        : const Color(0xFFEE8F8F),
                    child: Icon(
                      isLiked ? Icons.favorite_rounded : Icons.close_rounded,
                      color: Colors.black,
                    ),
                  ),
                  title: Text(entry.track.name),
                  subtitle: Text(
                    '${entry.track.artist} • ${formatter.format(entry.timestamp)}',
                  ),
                  trailing: Text(isLiked ? 'Liked' : 'Skipped'),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemCount: log.length,
          ),
        ),
      ],
    );
  }
}
