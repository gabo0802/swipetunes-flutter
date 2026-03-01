import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:swipetunes/controllers/swipetunes_controller.dart';
import 'package:swipetunes/pages/home_shell.dart';
import 'package:swipetunes/pages/login_page.dart';

class SwipeTunesApp extends StatelessWidget {
  const SwipeTunesApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SwipeTunes',
      theme: base.copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF65DFA3),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0E1116),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        cardTheme: CardTheme(
          color: const Color(0xFF161B22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
      home: Consumer<SwipeTunesController>(
        builder: (context, controller, _) {
          if (controller.isAuthenticated) {
            return const HomeShell();
          }
          return const LoginPage();
        },
      ),
    );
  }
}
