import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/home_screen.dart';
import 'screens/welcome_screen.dart';
import 'store.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore();
  await store.load();
  runApp(CamTripApp(store: store));
}

class CamTripApp extends StatelessWidget {
  final AppStore store;
  const CamTripApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CamTrip',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: C.navy, primary: C.navy, surface: C.ivory),
        scaffoldBackgroundColor: C.ivory,
        fontFamily: GoogleFonts.ibmPlexSansKr().fontFamily,
        splashFactory: InkRipple.splashFactory,
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: C.navy,
            shape: const RoundedRectangleBorder(),
            minimumSize: const Size(44, 44),
          ),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(color: C.navy),
      ),
      home: ListenableBuilder(
        listenable: store,
        builder: (context, _) => store.onboarded ? HomeScreen(store: store) : WelcomeScreen(store: store),
      ),
    );
  }
}
