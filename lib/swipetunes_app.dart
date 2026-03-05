import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:swipetunes/controllers/swipetunes_controller.dart';
import 'package:swipetunes/pages/home_shell.dart';
import 'package:swipetunes/pages/login_page.dart';

class SwipeTunesApp extends StatelessWidget {
  const SwipeTunesApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(brightness: Brightness.light, useMaterial3: true);
    const bg = Color(0xFFF6F0CF);
    const surface = Color(0xFFFFFBEB);
    const mint = Color(0xFF8EDFC6);
    const pink = Color(0xFFF3A4B0);
    const ink = Color(0xFF222222);
    const outline = Color(0xFF97B0FF);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SwipeTunes',
      theme: base.copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: mint,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: bg,
        textTheme: base.textTheme.apply(
          bodyColor: ink,
          displayColor: ink,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          backgroundColor: bg,
          foregroundColor: outline,
          elevation: 0,
        ),
        cardTheme: CardTheme(
          color: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE7DFB8)),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: bg,
          indicatorColor: mint,
          iconTheme: MaterialStateProperty.resolveWith((states) {
            final selected = states.contains(MaterialState.selected);
            return IconThemeData(color: selected ? outline : Colors.black45);
          }),
          labelTextStyle: MaterialStateProperty.resolveWith((states) {
            final selected = states.contains(MaterialState.selected);
            return TextStyle(
              color: selected ? outline : Colors.black45,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            );
          }),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: mint,
            foregroundColor: ink,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: ink,
            side: const BorderSide(color: Color(0xFFD9CF9E)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            foregroundColor: ink,
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: pink,
          contentTextStyle: TextStyle(color: ink, fontWeight: FontWeight.w600),
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
