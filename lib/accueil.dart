// Écran d'accueil aux couleurs de la 6e compagnie du 21e RIMa :
// carmin de la compagnie, rouge et bleu des troupes de marine, insigne.
import 'package:flutter/material.dart';

/// Couleurs de la compagnie, utilisées dans toute l'appli.
class CouleursCie {
  static const carmin = Color(0xFF960018);
  static const carminFonce = Color(0xFF5A0010);
  static const rougeMarine = Color(0xFFC8102E);
  static const bleuMarine = Color(0xFF1B2A5C);
}

class AccueilScreen extends StatelessWidget {
  final VoidCallback onEntrer;
  const AccueilScreen({super.key, required this.onEntrer});

  @override
  Widget build(BuildContext context) {
    final hauteur = MediaQuery.of(context).size.height;
    return Scaffold(
      body: GestureDetector(
        onTap: onEntrer,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [CouleursCie.carmin, CouleursCie.carminFonce],
            ),
          ),
          child: Column(
            children: [
              const _BandeMarine(),
              Expanded(
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/images/insigne_6cie.png',
                            height: hauteur * 0.36,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'MUFASA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 10,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '6e COMPAGNIE · 21e RIMa',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Scientia nostra ad serviendum',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 32),
                          OutlinedButton(
                            onPressed: onEntrer,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(
                                  color: Colors.white, width: 2),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 48, vertical: 14),
                            ),
                            child: const Text('ENTRER',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 3)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const _BandeMarine(bas: true),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bande rouge et bleu des troupes de marine.
class _BandeMarine extends StatelessWidget {
  final bool bas;
  const _BandeMarine({this.bas = false});

  @override
  Widget build(BuildContext context) {
    final marge = bas
        ? MediaQuery.of(context).padding.bottom
        : MediaQuery.of(context).padding.top;
    return Column(children: [
      if (!bas) Container(height: marge, color: CouleursCie.bleuMarine),
      Row(children: [
        Expanded(child: Container(height: 10, color: CouleursCie.bleuMarine)),
        Expanded(child: Container(height: 10, color: CouleursCie.rougeMarine)),
      ]),
      if (bas) Container(height: marge, color: CouleursCie.bleuMarine),
    ]);
  }
}
