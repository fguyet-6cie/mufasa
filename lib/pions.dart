// Pions des amis sur la carte : carré bleu, cadre de la couleur de la
// section, numéro (section ou GOLF), tête de lion pour le CDU ; flèche
// « moi » ; bulle bleue quand on touche un pion.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'cot.dart';
import 'hierarchie.dart';
import 'mgrs.dart';

/// Couleur du cadre : 1 bleu, 2 rouge, 3 jaune, 4 vert, SK blanc.
Color couleurSection(Place p) => switch (p.fonction.aSection ? p.section : 0) {
      1 => const Color(0xFF0A2F80),
      2 => const Color(0xFFD32F2F),
      3 => const Color(0xFFF9C80E),
      4 => const Color(0xFF2E9D3A),
      _ => Colors.white,
    };

const bleuAmi = Color(0xFF8CC4FF);
const bleuMonGroupe = Color(0xFF2563C9);
const bleuBulle = Color(0xFFCFE6FF);

/// Taille du carré selon la fonction (le chef d'équipe a la même taille
/// qu'un équipier).
double tailleCarre(Fonction f) => switch (f) {
      Fonction.chefSection => 28,
      Fonction.chefGroupe => 25,
      _ => 20,
    };

class PionAmi extends StatelessWidget {
  final Place place;
  final bool monGroupe;
  final bool monTrinome;
  final bool perime;
  const PionAmi(
      {super.key,
      required this.place,
      this.monGroupe = false,
      this.monTrinome = false,
      this.perime = false});

  @override
  Widget build(BuildContext context) {
    if (place.fonction == Fonction.cdu) {
      return Opacity(
        opacity: perime ? 0.45 : 1,
        child: Image.asset('assets/images/lion_cdu.png', width: 46, height: 54),
      );
    }
    final cote = tailleCarre(place.fonction);
    final fonce = monGroupe || monTrinome;
    return Opacity(
      opacity: perime ? 0.45 : 1,
      child: Container(
        width: cote,
        height: cote,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fonce ? bleuMonGroupe : bleuAmi,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: couleurSection(place), width: 2.5),
          boxShadow: [
            const BoxShadow(color: Colors.black, spreadRadius: 1),
            if (monTrinome)
              const BoxShadow(
                  color: Color(0xFFFFD400), blurRadius: 9, spreadRadius: 4),
          ],
        ),
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.all(1),
            child: Text(
              place.numeroCarre,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: -0.5,
                color: fonce ? Colors.white : const Color(0xFF0B2545),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ma position : flèche bleu marine dans un rond blanc, dans le sens de la
/// marche ([cap] en degrés, null si je ne bouge pas).
class FlecheMoi extends StatelessWidget {
  final double? cap;
  const FlecheMoi({super.key, this.cap});

  @override
  Widget build(BuildContext context) => Container(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Color(0xFF0D2B6B), spreadRadius: 2),
            BoxShadow(color: Colors.black38, blurRadius: 6),
          ],
        ),
        child: Transform.rotate(
          angle: (cap ?? 0) * math.pi / 180,
          child: CustomPaint(painter: _Fleche(cap != null)),
        ),
      );
}

class _Fleche extends CustomPainter {
  final bool enMarche;
  _Fleche(this.enMarche);
  @override
  void paint(Canvas canvas, Size s) {
    final c = Offset(s.width / 2, s.height / 2);
    final p = Paint()..color = const Color(0xFF0D2B6B);
    if (!enMarche) {
      canvas.drawCircle(c, 7, p);
      return;
    }
    canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - 11)
          ..lineTo(c.dx + 9, c.dy + 10)
          ..lineTo(c.dx, c.dy + 5)
          ..lineTo(c.dx - 9, c.dy + 10)
          ..close(),
        p);
  }

  @override
  bool shouldRepaint(_Fleche old) => old.enMarche != enMarche;
}

/// Il y a combien de temps, en clair.
String ilYA(DateTime t) {
  final d = DateTime.now().toUtc().difference(t);
  if (d.inSeconds < 60) return 'il y a ${d.inSeconds.clamp(0, 59)} s';
  if (d.inMinutes < 60) return 'il y a ${d.inMinutes} min';
  return 'il y a ${d.inHours} h ${d.inMinutes % 60} min';
}

/// Bulle bleu pastel affichée au-dessus d'un ami touché.
class BulleAmi extends StatelessWidget {
  final CotEvenement c;
  final VoidCallback onFermer;
  const BulleAmi({super.key, required this.c, required this.onFermer});

  @override
  Widget build(BuildContext context) {
    final mgrs = versMgrs(c.lat, c.lon);
    final desc = c.place.description;
    return GestureDetector(
      onTap: onFermer,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: BoxDecoration(
              color: bleuBulle,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(color: Colors.black38, blurRadius: 8)
              ],
            ),
            child: DefaultTextStyle(
              style: const TextStyle(color: Colors.black, fontSize: 13),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.indicatif,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  if (desc.isNotEmpty) Text(desc),
                  if (mgrs.isNotEmpty)
                    Text.rich(TextSpan(children: [
                      const TextSpan(text: 'MGRS : '),
                      TextSpan(
                          text: mgrs,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ])),
                  Text('Position reçue ${ilYA(c.heure)}',
                      style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),
          ),
          CustomPaint(size: const Size(16, 8), painter: _Pointe()),
        ],
      ),
    );
  }
}

class _Pointe extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) => canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(s.width, 0)
        ..lineTo(s.width / 2, s.height)
        ..close(),
      Paint()..color = bleuBulle);
  @override
  bool shouldRepaint(_Pointe old) => false;
}

/// Légende affichée dans le panneau « Ce que je vois ».
class Legende extends StatelessWidget {
  const Legende({super.key});

  Widget _carre(Color cadre, {Color fond = bleuAmi, List<BoxShadow>? halo}) =>
      Container(
        width: 16,
        height: 16,
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: fond,
          border: Border.all(color: cadre, width: 2.5),
          boxShadow: [
            const BoxShadow(color: Colors.black, spreadRadius: 1),
            ...?halo
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    Widget ligne(List<Widget> w) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: w));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ligne([
          const Text('Cadre :'),
          for (var i = 1; i <= 4; i++) ...[
            _carre(couleurSection(Place(Fonction.chefSection, section: i))),
            Text('CARMIN $i'),
          ],
          _carre(Colors.white),
          const Text('SK'),
        ]),
        ligne([
          _carre(Colors.grey, fond: bleuMonGroupe),
          const Text('Mon groupe'),
          _carre(Colors.grey, fond: bleuMonGroupe, halo: const [
            BoxShadow(color: Color(0xFFFFD400), blurRadius: 6, spreadRadius: 3)
          ]),
          const Text('Mon trinôme'),
        ]),
        const Text('Chiffre = n° de section (chef de section) ou de GOLF.'),
        const Text('Rond rouge = ennemi · losange orange = point particulier.'),
      ],
    );
  }
}
