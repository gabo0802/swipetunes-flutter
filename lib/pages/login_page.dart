import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:swipetunes/controllers/swipetunes_controller.dart';
import 'package:swipetunes/models/swipe_log_entry.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SwipeTunesController>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'SwipeTunes',
                        style:
                            Theme.of(context).textTheme.displaySmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF65DFA3),
                                ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Choose your music source, then swipe right to like and left to skip.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed:
                              controller.status == AppSessionStatus.loading
                                  ? null
                                  : controller.signInWithSpotify,
                          icon: const Icon(Icons.music_note_rounded),
                          label: Text(
                            controller.status == AppSessionStatus.loading &&
                                    controller.activeSource ==
                                        MusicSource.spotify
                                ? 'Loading Spotify...'
                                : 'Continue with Spotify',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed:
                              controller.status == AppSessionStatus.loading
                                  ? null
                                  : controller.signInWithYouTubeMusic,
                          icon: const Icon(Icons.ondemand_video_rounded),
                          label: Text(
                            controller.status == AppSessionStatus.loading &&
                                    controller.activeSource ==
                                        MusicSource.youtubeMusic
                                ? 'Loading YT Music...'
                                : 'Continue with YT Music',
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        controller.isGoogleOAuthConfigured
                            ? 'Google OAuth is configured for YT Music sign-in. Recommendations still use demo data for now.'
                            : controller.googleSetupInstructions,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (controller.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          controller.errorMessage!,
                          style: const TextStyle(color: Colors.redAccent),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
