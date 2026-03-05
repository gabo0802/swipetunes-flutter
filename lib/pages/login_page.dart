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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                children: [
                  const SizedBox(height: 30),
                  Text(
                    'swipetunes',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          color: const Color(0xFF97B0FF),
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.4,
                        ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Modern music discovery with playlist-seeded swiping.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 28),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: const BoxDecoration(
                              color: Color(0xFF8EDFC6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.graphic_eq_rounded,
                              size: 38,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Sign in with YT Music',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Pick a playlist seed, then swipe through recommendations.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
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
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Spotify is temporarily deprecated. Provider integrations remain extensible for future streaming apps.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    controller.isGoogleOAuthConfigured
                        ? 'Google OAuth ready for YT Music.'
                        : controller.googleSetupInstructions,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (controller.errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      controller.errorMessage!,
                      style: const TextStyle(color: Color(0xFFC44F64)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
