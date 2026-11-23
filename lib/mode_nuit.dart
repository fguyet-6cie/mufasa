// Mode nuit : écran sombre à dominante rouge, très peu lumineux, pour rester
// discret et garder sa vision de nuit.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final modeNuit = ValueNotifier<bool>(false);

Future<void> chargerModeNuit() async {
  try {
    final p = await SharedPreferences.getInstance();
    modeNuit.value = p.getBool('modeNuit') ?? false;
  } catch (_) {}
}

Future<void> changerModeNuit(bool v) async {
  modeNuit.value = v;
  final p = await SharedPreferences.getInstance();
  await p.setBool('modeNuit', v);
}

/// Carte de nuit : fond sombre, routes et textes en rouge sourd.
const filtreCarteNuit = ColorFilter.matrix(<double>[
  -0.18, -0.35, -0.07, 0, 150, //
  -0.03, -0.06, -0.01, 0, 25,
  -0.02, -0.04, -0.01, 0, 18,
  0, 0, 0, 1, 0,
]);

/// Thème sombre et rouge pour les menus, fiches et réglages.
final themeNuit = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF7A0000),
    brightness: Brightness.dark,
    primary: const Color(0xFFB71C1C),
    surface: const Color(0xFF120404),
  ),
  scaffoldBackgroundColor: const Color(0xFF0A0202),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1A0505),
    foregroundColor: Color(0xFFB04040),
  ),
);

/// Voile sombre posé sur tout l'écran (ne bloque pas les touchers).
Widget voileNuit(Widget enfant) => ValueListenableBuilder<bool>(
      valueListenable: modeNuit,
      builder: (_, nuit, __) => Stack(children: [
        enfant,
        if (nuit)
          const Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(color: Color(0x80000000)),
            ),
          ),
      ]),
    );
